use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Debug, Clone, sqlx::FromRow)]
pub struct ReportPayload {
    pub image_id: String,
    pub user_id: String,
    pub safe_search: serde_json::Value,
    pub labels: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct IdentityVerificationReport {
    pub id: uuid::Uuid,
    pub user_id: uuid::Uuid,
    pub new_image_id: uuid::Uuid,
    pub identification_type: String,
    pub upload_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IdentityReviewAction {
    pub user_id: uuid::Uuid,
    pub image_id: uuid::Uuid,
    pub status: String, // "approve" or "reject"
    pub reason: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReviewProfileImage {
    pub review_id: String,
    pub user_id: String,
    pub message: String,
    pub image_id: String,
    pub message_at: String,
    pub status: String, // "approve" or "reject"
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct InquiryMessage {
    pub id: uuid::Uuid,
    pub user_id: uuid::Uuid,
    pub inquiry_type: String,
    pub message: String,
    pub send_date: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaintenanceStatus {
    pub is_maintenance: bool,
}
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct ChatRoomReport {
    pub id: uuid::Uuid,
    pub report_user_id: uuid::Uuid,
    pub target_user_id: uuid::Uuid,
    pub room_id: uuid::Uuid,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub report_type: String,
    pub report: String,
}
