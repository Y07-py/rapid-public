use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use serde_with::{DurationSeconds, TimestampSeconds, TimestampSecondsWithFrac, serde_as};
use std::{collections::HashMap, time::Duration};
use uuid::Uuid;

#[serde_as]
#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Session {
    pub provider_token: Option<String>,
    pub provider_refresh_token: Option<String>,
    pub access_token: String,
    pub token_type: String,

    #[serde_as(as = "DurationSeconds<u64>")]
    pub expires_in: Duration,

    #[serde_as(as = "TimestampSeconds<i64>")]
    pub expires_at: DateTime<Utc>,

    pub refresh_token: String,
    pub weak_password: Option<WeakPassword>,
    pub user: User,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct WeakPassword {
    pub reasons: Vec<String>,
}

#[serde_as]
#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct User {
    pub id: Uuid,
    pub app_metadata: HashMap<String, Value>,
    pub user_metadata: HashMap<String, Value>,
    pub aud: String,

    #[serde_as(as = "Option<TimestampSecondsWithFrac<f64>>")]
    pub confirmation_sent_at: Option<DateTime<Utc>>,
    #[serde_as(as = "Option<TimestampSecondsWithFrac<f64>>")]
    pub recovery_sent_at: Option<DateTime<Utc>>,
    #[serde_as(as = "Option<TimestampSecondsWithFrac<f64>>")]
    pub email_change_sent_at: Option<DateTime<Utc>>,
    pub new_email: Option<String>,
    #[serde_as(as = "Option<TimestampSecondsWithFrac<f64>>")]
    pub invalid_at: Option<DateTime<Utc>>,

    pub action_link: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,

    #[serde_as(as = "TimestampSecondsWithFrac<f64>")]
    pub created_at: DateTime<Utc>,
    #[serde_as(as = "Option<TimestampSecondsWithFrac<f64>>")]
    pub confirmed_at: Option<DateTime<Utc>>,
    #[serde_as(as = "Option<TimestampSecondsWithFrac<f64>>")]
    pub email_confirmed_at: Option<DateTime<Utc>>,
    #[serde_as(as = "Option<TimestampSecondsWithFrac<f64>>")]
    pub phone_confirmed_at: Option<DateTime<Utc>>,
    #[serde_as(as = "Option<TimestampSecondsWithFrac<f64>>")]
    pub last_sign_in_at: Option<DateTime<Utc>>,
    pub role: Option<String>,
    #[serde_as(as = "TimestampSecondsWithFrac<f64>")]
    pub updated_at: DateTime<Utc>,

    pub identities: Option<Vec<UserIdentity>>,
    pub is_anonymous: bool,
    pub factors: Option<Vec<Factor>>,
}

#[serde_as]
#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserIdentity {
    pub id: String,
    pub identity_id: Uuid,
    pub user_id: Uuid,
    pub identity_data: Option<HashMap<String, Value>>,
    pub provider: String,

    #[serde_as(as = "Option<TimestampSecondsWithFrac<f64>>")]
    pub created_at: Option<DateTime<Utc>>,
    #[serde_as(as = "Option<TimestampSecondsWithFrac<f64>>")]
    pub last_sign_in_at: Option<DateTime<Utc>>,
    #[serde_as(as = "Option<TimestampSecondsWithFrac<f64>>")]
    pub updated_at: Option<DateTime<Utc>>,
}

#[serde_as]
#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Factor {
    pub id: String,
    pub friendly_name: Option<String>,
    pub factor_type: String,
    pub status: FactorStatus,

    #[serde_as(as = "TimestampSecondsWithFrac<f64>")]
    pub created_at: DateTime<Utc>,
    #[serde_as(as = "TimestampSecondsWithFrac<f64>")]
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FactorStatus {
    Verified,
    Unverified,
}

// Claims of Supabase JWT
#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,
    pub aud: String,
    pub iss: String,
    pub exp: usize,
    pub role: Option<String>,
    pub email: Option<String>,
}
