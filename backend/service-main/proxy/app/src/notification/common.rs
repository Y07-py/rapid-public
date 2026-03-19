use dotenv;
use std::collections::HashMap;
use std::sync::Arc;

use jsonwebtoken::{Algorithm, EncodingKey, Header, encode};

use crate::http;
use crate::notification::objects::{
    FcmMessage, FcmMessageBody, FcmNotification, JwtClaims, TokenResponse,
};
use crate::utils::config;

#[derive(Debug, thiserror::Error)]
pub enum FcmError {
    #[error("Config error: {0}")]
    ConfigError(#[from] config::ConfigError),
    #[error("JWT encoding error: {0}")]
    JwtError(#[from] jsonwebtoken::errors::Error),
    #[error("HTTP request error: {0}")]
    HttpError(String),
    #[error("Token exchange error: {0}")]
    TokenExchangeError(String),
    #[error("FCM send error: {0}")]
    FcmSendError(String),
}

pub async fn get_access_token(
    http_client: &Arc<http::request::HttpClient>,
) -> Result<String, FcmError> {
    let firebase_config = config::get()?;

    let now = chrono::Utc::now().timestamp();
    let fcm_scope = dotenv::var("FCM_SCOPE").unwrap();

    let claims = JwtClaims {
        iss: firebase_config.client_email.clone(),
        sub: firebase_config.client_email.clone(),
        aud: firebase_config.token_uri.clone(),
        iat: now,
        exp: now + 3600,
        scope: fcm_scope,
    };

    let mut header = Header::new(Algorithm::RS256);
    header.kid = Some(firebase_config.private_key_id.clone());

    let encoding_key = EncodingKey::from_rsa_pem(firebase_config.private_key.as_bytes())?;
    let jwt = encode(&header, &claims, &encoding_key)?;

    let mut form_data = HashMap::new();
    form_data.insert(
        "grant_type".to_string(),
        "urn:ietf:params:oauth:grant-type:jwt-bearer".to_string(),
    );
    form_data.insert("assertion".to_string(), jwt);

    let token_uri = dotenv::var("GOOGLE_TOKEN_URI").unwrap();

    println!("ℹ️ [FCM] Attempting to exchange OAuth2 token for Firebase (ISS: {})", firebase_config.client_email);
    let response = http_client
        .post_form(&token_uri, form_data)
        .await
        .map_err(|e| {
            println!("❌ [FCM] HTTP request failed during token exchange: {:?}", e);
            FcmError::HttpError(e.to_string())
        })?;

    if !response.is_success() {
        let error_body = response.get_body_as_string().unwrap_or_default();
        println!("❌ [FCM] Token exchange failed. Status: {}, Body: {}", response.get_status_code(), error_body);

        return Err(FcmError::TokenExchangeError(format!(
            "Failed to exchange token: status={}, body={}",
            response.get_status_code(),
            error_body
        )));
    }
    println!("✅ [FCM] Successfully obtained access token.");

    let token_response: TokenResponse = response.get_body().ok_or_else(|| {
        println!("❌ [FCM] Failed to parse token response body.");
        FcmError::TokenExchangeError("Failed to parse token response".to_string())
    })?;

    Ok(token_response.access_token)
}

pub async fn send_fcm_notification(
    http_client: &Arc<http::request::HttpClient>,
    fcm_token: &str,
    title: &str,
    body: &str,
    data: HashMap<String, String>,
) -> Result<(), FcmError> {
    let firebase_config = config::get()?;
    let access_token = match get_access_token(http_client).await {
        Ok(token) => token,
        Err(e) => {
            return Err(e);
        }
    };

    let fcm_endpoint = format!(
        "https://fcm.googleapis.com/v1/projects/{}/messages:send",
        firebase_config.project_id
    );

    let message = FcmMessage {
        message: FcmMessageBody {
            token: fcm_token.to_string(),
            notification: FcmNotification {
                title: title.to_string(),
                body: body.to_string(),
            },
            data,
        },
    };

    let mut headers = HashMap::new();
    headers.insert(
        "Authorization".to_string(),
        format!("Bearer {}", access_token),
    );
    headers.insert("Content-Type".to_string(), "application/json".to_string());

    let response = http_client
        .post(&fcm_endpoint, Some(headers), None, message, None)
        .await
        .map_err(|e| FcmError::HttpError(e.to_string()))?;

    let status = response.get_status_code();

    if !response.is_success() {
        let error_body = response.get_body_as_string().unwrap_or_default();
        return Err(FcmError::FcmSendError(format!(
            "Failed to send FCM: status={}, body={}",
            status, error_body
        )));
    }

    Ok(())
}
