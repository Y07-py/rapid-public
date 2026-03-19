use std::collections::HashMap;
use std::sync::Arc;

use crate::db;
use crate::http;
use crate::notification::common::send_fcm_notification;

pub async fn send_recruitment_notification(
    user_id: &str,
    rejected: bool,
    http_client: actix_web::web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: actix_web::web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<()> {
    let fcm = postgrest_client
        .select_fcm_token(user_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    if let Some(fcm_payload) = fcm {
        let mut data = HashMap::new();
        data.insert(
            "notification_type".to_string(),
            "recruitment_moderate".to_string(),
        );
        data.insert("user_id".to_string(), user_id.to_string());

        let body = if rejected {
            "規約に基づき、投稿された募集を非承認としました。内容を修正して再度お試しください。"
                .to_string()
        } else {
            "新しい募集が承認されました！".to_string()
        };

        send_fcm_notification(&http_client, &fcm_payload.fcm_token, "Rapid", &body, data)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

        // Log to notification_messages table
        let notification_log = db::object::NotificationMessage {
            message_id: None,
            created_at: chrono::Utc::now(),
            message: Some(body),
            message_type: Some("recruitment_moderate".to_string()),
            user_id: Some(uuid::Uuid::parse_str(user_id).unwrap_or_default()),
            is_read: Some(false),
        };

        postgrest_client
            .insert_notification_message(&notification_log)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;
    }

    Ok(())
}
