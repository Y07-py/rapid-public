use std::collections::HashMap;

use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize)]
pub struct JwtClaims {
    pub iss: String,
    pub sub: String,
    pub aud: String,
    pub iat: i64,
    pub exp: i64,
    pub scope: String,
}

#[derive(Debug, Deserialize)]
pub struct TokenResponse {
    pub access_token: String,
    #[allow(dead_code)]
    pub token_type: String,
    #[allow(dead_code)]
    pub expires_in: i64,
}

#[derive(Debug, Serialize)]
pub struct FcmMessage {
    pub message: FcmMessageBody,
}

#[derive(Debug, Serialize)]
pub struct FcmMessageBody {
    pub token: String,
    pub notification: FcmNotification,
    #[serde(skip_serializing_if = "HashMap::is_empty")]
    pub data: HashMap<String, String>,
}

#[derive(Debug, Serialize)]
pub struct FcmNotification {
    pub title: String,
    pub body: String,
}
