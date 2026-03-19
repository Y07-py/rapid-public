use jsonwebtoken::{decode, decode_header, DecodingKey, Validation, Algorithm};
use serde::{Deserialize, Serialize};
use once_cell::sync::Lazy;
use std::sync::Arc;
use tokio::sync::RwLock;
use reqwest;
use actix_web::{
    Error, HttpResponse,
    body::EitherBody,
    dev::{Service, ServiceRequest, ServiceResponse, Transform},
};
use futures_util::future::{LocalBoxFuture, Ready, ready};
use std::task::{Context, Poll};
use std::rc::Rc;

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,    // Clerk User ID
    pub exp: usize,
    pub iss: String,
}

#[derive(Debug, Deserialize)]
struct Jwk {
    kid: String,
    n: String,
    e: String,
}

#[derive(Debug, Deserialize)]
struct Jwks {
    keys: Vec<Jwk>,
}

static JWKS_CACHE: Lazy<Arc<RwLock<Option<Jwks>>>> = Lazy::new(|| Arc::new(RwLock::new(None)));

pub async fn verify_token(token: &str) -> Result<Claims, String> {
    let header = decode_header(token).map_err(|e| format!("Invalid header: {}", e))?;
    let kid = header.kid.ok_or_else(|| "Missing kid in header".to_string())?;

    // Get JWKS (cached or fresh)
    let jwks = get_jwks().await.map_err(|e| format!("Failed to get JWKS: {}", e))?;
    
    let jwk = jwks.keys.iter()
        .find(|k| k.kid == kid)
        .ok_or_else(|| "Matching key not found in JWKS".to_string())?;

    let decoding_key = DecodingKey::from_rsa_components(&jwk.n, &jwk.e)
        .map_err(|e| format!("Invalid RSA components: {}", e))?;

    let mut validation = Validation::new(Algorithm::RS256);
    
    // Use explicit issuer from environment
    if let Ok(issuer) = std::env::var("CLERK_ISSUER") {
        validation.set_issuer(&[issuer]);
    }
    
    validation.validate_exp = true;

    // Clerk typically sets the audience if configured, but by default it might be omitted or set to the domain.
    // For now, we'll keep it simple and focus on issuer and expiration.
    validation.required_spec_claims.insert("iss".to_string());
    validation.required_spec_claims.insert("exp".to_string());

    let token_data = decode::<Claims>(token, &decoding_key, &validation)
        .map_err(|e| format!("Token verification failed: {}", e))?;

    Ok(token_data.claims)
}

async fn get_jwks() -> Result<Jwks, String> {
    // 1. Check cache
    if let Some(jwks) = &*JWKS_CACHE.read().await {
        return Ok(Jwks { keys: jwks.keys.clone() });
    }

    // 2. Refresh cache
    let jwks_url = std::env::var("CLERK_JWKS_URL")
        .map_err(|_| "CLERK_JWKS_URL not set in environment".to_string())?;

    println!("Fetching JWKS from: {}", jwks_url);
    let response = reqwest::get(&jwks_url).await
        .map_err(|e| format!("HTTP request failed: {}", e))?;
    
    if !response.status().is_success() {
        return Err(format!("Failed to fetch JWKS: HTTP {}", response.status()));
    }

    let jwks: Jwks = response.json().await
        .map_err(|e| format!("Failed to parse JWKS JSON: {}", e))?;

    let mut cache = JWKS_CACHE.write().await;
    *cache = Some(Jwks { keys: jwks.keys.clone() });

    Ok(jwks)
}

impl Clone for Jwk {
    fn clone(&self) -> Self {
        Self {
            kid: self.kid.clone(),
            n: self.n.clone(),
            e: self.e.clone(),
        }
    }
}

pub struct ClerkAuth {
    pub skip_paths: Vec<String>,
}

impl ClerkAuth {
    pub fn new(skip_paths: Vec<String>) -> Self {
        Self { skip_paths }
    }
}

impl<S, B> Transform<S, ServiceRequest> for ClerkAuth
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    S::Future: 'static,
    B: 'static,
{
    type Response = ServiceResponse<EitherBody<B>>;
    type Error = Error;
    type Transform = ClerkAuthMiddleware<S>;
    type InitError = ();
    type Future = Ready<Result<Self::Transform, Self::InitError>>;

    fn new_transform(&self, service: S) -> Self::Future {
        ready(Ok(ClerkAuthMiddleware {
            service: Rc::new(service),
            skip_paths: self.skip_paths.clone(),
        }))
    }
}

pub struct ClerkAuthMiddleware<S> {
    service: Rc<S>,
    skip_paths: Vec<String>,
}

impl<S, B> Service<ServiceRequest> for ClerkAuthMiddleware<S>
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    S::Future: 'static,
    B: 'static,
{
    type Response = ServiceResponse<EitherBody<B>>;
    type Error = Error;
    type Future = LocalBoxFuture<'static, Result<Self::Response, Self::Error>>;

    fn poll_ready(&self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.service.poll_ready(cx)
    }

    fn call(&self, req: ServiceRequest) -> Self::Future {
        let srv = self.service.clone();
        let path = req.path().to_string();
        let skip = self.skip_paths.contains(&path);

        Box::pin(async move {
            if skip {
                let res = srv.call(req).await?;
                return Ok(res.map_into_left_body());
            }

            let auth_header = req.headers().get("Authorization");
            let token = auth_header
                .and_then(|h| h.to_str().ok())
                .and_then(|s| s.strip_prefix("Bearer "))
                .map(|s| s.to_string());

            if let Some(t) = token {
                match verify_token(&t).await {
                    Ok(_) => {
                        let res = srv.call(req).await?;
                        Ok(res.map_into_left_body())
                    }
                    Err(e) => {
                        eprintln!("Auth Error: {}", e);
                        Ok(req.into_response(
                            HttpResponse::Unauthorized().finish().map_into_right_body(),
                        ))
                    }
                }
            } else {
                Ok(req.into_response(
                    HttpResponse::Unauthorized().finish().map_into_right_body(),
                ))
            }
        })
    }
}
