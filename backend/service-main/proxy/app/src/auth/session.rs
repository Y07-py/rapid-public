use std::sync::Arc;
use tokio::sync::RwLock;

use actix_web::{self, web};
use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode, decode_header};

use crate::auth::error::AuthSessionError;
use crate::auth::object::SessionJWKs;
use crate::cache::worker::CacheWorker;
use crate::http;
use crate::models::auth::{Claims, Session};
use crate::{cache, db};

pub async fn inquiry_session(
    session: &Session,
    pg_repository: actix_web::web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<Option<db::object::Identity>> {
    // extract identity
    let identity = extract_identity(session);
    let selected_identity = pg_repository
        .select_identity(&identity)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    if selected_identity.is_some() {
        return Ok(selected_identity);
    }

    // If doesn't exist identity.
    pg_repository
        .insert_identity(&identity)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(Some(identity))
}

fn extract_identity(session: &Session) -> db::object::Identity {
    let mut identity = db::object::Identity::new(
        session.user.id.clone(),
        serde_json::to_value(&session.user.user_metadata).unwrap(),
        serde_json::to_value(&session.user.app_metadata).unwrap(),
        session.user.created_at.clone(),
        session.user.updated_at.clone(),
    );

    if let Some(providers) = session.user.app_metadata.get("providers") {
        if let Some(array) = providers.as_array() {
            let provider_vec: Vec<String> = array
                .iter()
                .filter_map(|v| v.as_str())
                .map(|s| s.to_string())
                .collect();
            identity.set_providers(provider_vec);
        }
    }

    if let Some(email) = session.user.email.as_ref() {
        identity.set_email(email.clone());
    }

    if let Some(phone) = session.user.phone.as_ref() {
        identity.set_phone(phone.clone());
    }

    if let Some(last_signin_at) = session.user.last_sign_in_at {
        identity.set_last_signin_at(last_signin_at);
    }

    identity
}

#[derive(Debug, Clone)]
pub struct AuthSession {
    jwks_endpoint: String,
    auth_endpoint: String,
    cache_worker: Arc<RwLock<CacheWorker>>,
}

impl AuthSession {
    pub fn new(cache_weight: usize) -> Result<Self, AuthSessionError> {
        let jwks_endpoint = std::env::var("SUPABASE_JWKS_ENDPOINT").unwrap();
        let auth_endpoint = std::env::var("SUPABASE_AUTH_ENDPOINT").unwrap();

        let cache_worker = CacheWorker::new(cache_weight);

        let auth_session = AuthSession {
            jwks_endpoint,
            auth_endpoint,
            cache_worker,
        };

        Ok(auth_session)
    }

    /// Verifies the user's JWT token and returns the user_id (sub claim) if valid.
    /// Returns `Ok(Some(user_id))` if authenticated, `Ok(None)` if not authenticated,
    /// or `Err` if verification fails.
    pub async fn user_verification(
        &self,
        header: &actix_web::http::header::HeaderMap,
        http_client: web::Data<Arc<http::request::HttpClient>>,
    ) -> Result<Option<String>, AuthSessionError> {
        let token = header
            .get(actix_web::http::header::AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .and_then(|s| s.strip_prefix("Bearer "))
            .map(str::trim);

        let Some(token) = token else {
            return Err(AuthSessionError::VerificationError(format!(
                "Verification token is not setted in the header field."
            )));
        };

        self.user_verification_with_token(token, http_client).await
    }

    async fn user_verification_with_token(
        &self,
        token: &str,
        http_client: web::Data<Arc<http::request::HttpClient>>,
    ) -> Result<Option<String>, AuthSessionError> {
        // If the token matches the service role key, it's an admin/internal request.
        if let Ok(service_role_key) = std::env::var("SUPABASE_SERVICE_ROLE_KEY") {
            if token == service_role_key {
                return Ok(Some("service_role".to_string()));
            }
        }

        // Decoding token field into json web token header.
        let jwt_header = match decode_header(token) {
            Ok(header) => header,
            Err(e) => {
                return Err(AuthSessionError::DecodingError(format!(
                    "Failed to decode jwt header. {:?}",
                    e
                )));
            }
        };

        // Get jwks from cache or network.
        let jwks = match self.get_jwks(http_client.clone()).await {
            Ok(jwks) => jwks,
            Err(e) => return Err(e),
        };

        if let Some((kid, mut decoding_key)) = self.jwks_decoder(jwks) {
            // Verify whether the cached kid matches the kid from the client.
            if kid != jwt_header.kid.unwrap_or_default() {
                // If kid is different, jwks cache data is old. So fetch new jwks from ./well-known/jwks.json
                decoding_key = match self.fetch_jwks(http_client).await {
                    Ok(jwks) => {
                        let decoding_pair = self.jwks_decoder(jwks.unwrap());

                        if decoding_pair.is_none() {
                            return Err(AuthSessionError::UnknownError(
                                "Decoding jwks is not exist.".to_string(),
                            ));
                        }

                        decoding_pair.unwrap().1
                    }
                    Err(e) => return Err(e),
                }
            }

            match self.check_role_and_get_sub(token, decoding_key).await {
                Ok(user_id) => return Ok(user_id),
                Err(e) => return Err(e),
            }
        }

        Ok(None)
    }

    async fn get_jwks(
        &self,
        http_client: web::Data<Arc<http::request::HttpClient>>,
    ) -> Result<SessionJWKs, AuthSessionError> {
        // If jwks is exist, return it. This function's caching strategy first checks whether the relevant
        // data exists in the cache. If it does not exist, it fetches the latest jwks
        // file from the network and overwrites the existing data in the cache with the latest data.

        // Check cache data.
        if let Some(jwks) = self.get_jwks_cache().await {
            return Ok(jwks);
        }

        // If cache data is not exist, fetch from ./well-known/jwks.json
        match self.fetch_jwks(http_client).await {
            Ok(jwks) => Ok(jwks.unwrap()),
            Err(e) => Err(e),
        }
    }

    fn jwks_decoder(&self, jwks: SessionJWKs) -> Option<(String, DecodingKey)> {
        // Function to retrieve the authentication filr for JWKs=based authentication from
        // Supabasse. When fetching the authentication file, it does not store the data in
        // a cache but always attempts to retrieve.

        for key in jwks.keys.iter() {
            // Json web token cryptographic algorithm is ES256.
            if key.alg == "ES256" {
                let decoding_key = DecodingKey::from_ec_components(&key.x, &key.y)
                    .ok()
                    .unwrap();

                return Some((key.kid.clone(), decoding_key));
            }
        }

        None
    }

    /// Checks the JWT claims and returns the user_id (sub) if the role is "authenticated".
    async fn check_role_and_get_sub(
        &self,
        token: &str,
        decoding_key: DecodingKey,
    ) -> Result<Option<String>, AuthSessionError> {
        let mut validation = Validation::new(Algorithm::ES256);
        validation.set_audience(&["authenticated"]);
        validation.set_issuer(&[&self.auth_endpoint]);
        validation.leeway = 5;

        let decoded_result = decode::<Claims>(token, &decoding_key, &validation);

        let token_data = match decoded_result {
            Ok(token_data) => token_data,
            Err(e) => {
                return Err(AuthSessionError::DecodingError(format!(
                    "Failed decoding jwt. {:?}",
                    e
                )));
            }
        };

        if token_data.claims.sub.is_empty() {
            return Ok(None);
        }

        if let Some(role) = token_data.claims.role {
            if role == "authenticated" {
                return Ok(Some(token_data.claims.sub));
            }
        }

        Ok(None)
    }

    async fn fetch_jwks(
        &self,
        http_client: web::Data<Arc<http::request::HttpClient>>,
    ) -> Result<Option<SessionJWKs>, AuthSessionError> {
        // A function to execute a series of actions when the kid in the token sent by
        // the client differs from the cached kid: retrieve the latest JWK from the supabase's
        // ./well-known/jwks.json and replace the pld cache with it.

        let response = match http_client.get(&self.jwks_endpoint, None, None, None).await {
            Ok(response) => response,
            Err(e) => {
                return Err(AuthSessionError::HttpRequestError(format!(
                    "Failed to fetch jwks.json. {:?}",
                    e
                )));
            }
        };

        // Check http response status code.
        if response.get_status_code() == 200 {
            let jwks: Option<SessionJWKs> = response.get_body();

            // Update old cache data of jwks
            if let Some(jwks) = jwks {
                let jwks_endpoint: &str = self.jwks_endpoint.as_ref();
                let cache_key = cache::object::CacheDataKey::new(jwks_endpoint.to_string());
                let jwks_cache =
                    cache::object::CacheMultipleData::new(cache_key.get_key(), jwks.clone());

                let mut worker = self.cache_worker.write().await;
                let worker_result = worker.put(cache_key.get_key(), jwks_cache, None);

                if let Some(e) = worker_result.err() {
                    return Err(AuthSessionError::CachePutError(format!("{:?}", e)));
                }

                return Ok(Some(jwks));
            }
        }

        Ok(None)
    }

    async fn get_jwks_cache(&self) -> Option<SessionJWKs> {
        let jwks_endpoint: &str = self.jwks_endpoint.as_ref();
        let cache_key = cache::object::CacheDataKey::new(jwks_endpoint.to_string());

        // Read cache worker that wrapped RwLock.
        let cache_worker = self.cache_worker.read().await;

        let jwks = match cache_worker.get(cache_key.get_key()) {
            Some(cache) => {
                let data = cache.get_front_data().unwrap();
                let jwks: SessionJWKs = serde_json::from_slice(&data).unwrap();
                Some(jwks)
            }
            None => None,
        };

        return jwks;
    }
}
