use std::collections::HashMap;
use std::sync::Arc;

use crate::db;
use crate::http;
use crate::notification::common::send_fcm_notification;

pub async fn send_introduction_notification(
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
        let status_type = if rejected {
            "introduction_rejected"
        } else {
            "introduction_approved"
        };

        // Idempotency check: Don't log if a similar notification was recorded in the last 5 minutes
        let five_minutes_ago = (chrono::Utc::now() - chrono::Duration::minutes(5)).to_rfc3339();
        let existing = postgrest_client
            .from("notification_messages")
            .select("message_id")
            .eq("user_id", &user_id.to_string())
            .eq("message_type", status_type)
            .gte("created_at", &five_minutes_ago)
            .execute()
            .await;

        if let Ok(resp) = existing {
            let text = resp.text().await.unwrap_or_default();
            if text.contains("message_id") && text != "[]" {
                println!("ℹ️ [Proxy] Introduction notification already logged for user: {} with type: {}", user_id, status_type);
                return Ok(());
            }
        }

        let mut data = HashMap::new();
        data.insert(
            "notification_type".to_string(),
            "introduction_moderate".to_string(),
        );
        data.insert("user_id".to_string(), user_id.to_string());

        let body = if rejected {
            "規約に基づき、自己紹介文を非承認としました。内容を修正して再度お試しください。"
                .to_string()
        } else {
            "自己紹介文が承認されました！プロフィールへ反映されます。".to_string()
        };

        send_fcm_notification(&http_client, &fcm_payload.fcm_token, "Rapid", &body, data)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

        // Log to notification_messages table
        let notification_log = db::object::NotificationMessage {
            message_id: None,
            created_at: chrono::Utc::now(),
            message: Some(body),
            message_type: Some(status_type.to_string()),
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
