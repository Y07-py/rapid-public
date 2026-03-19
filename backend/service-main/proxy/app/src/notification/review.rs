use std::collections::HashMap;
use std::sync::Arc;

use crate::db;
use crate::http;
use crate::notification::common::send_fcm_notification;
use crate::vision;

pub async fn send_review_notification(
    review_info: &vision::object::ReviewProfileImage,
    http_client: actix_web::web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: actix_web::web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<()> {
    let user_id = review_info.user_id.to_string();
    
    // If the user_id is not a valid UUID (e.g., "Unknown"), we cannot fetch FCM token
    if uuid::Uuid::parse_str(&user_id).is_err() {
        println!("⚠️ [Proxy] Skipping notification: user_id '{}' is not a valid UUID", user_id);
        return Ok(());
    }

    let status_type = if review_info.status == "approve" {
        "profile_image_approved"
    } else {
        "profile_image_rejected"
    };

    // 1. Try to get image index if it wasn't provided, to make the message more descriptive
    // We use the profile_images table as requested to ensure we have the latest state
    let mut image_index = review_info.image_index;
    if image_index.is_none() {
        let resp = postgrest_client
            .from("profile_images")
            .select("image_index")
            .eq("id", &review_info.image_id)
            .execute()
            .await;
        
        if let Ok(resp) = resp {
            let context = resp.text().await.unwrap_or_default();
            if let Ok(records) = serde_json::from_str::<Vec<serde_json::Value>>(&context) {
                if let Some(first) = records.first() {
                    image_index = first["image_index"].as_i64();
                }
            }
        }
    }

    // 2. Build a more descriptive message
    let base_message = if review_info.status == "approve" {
        if let Some(idx) = image_index {
            format!("プロフィール画像（{}枚目）が承認されました。", idx + 1)
        } else {
            "プロフィール画像が承認されました。".to_string()
        }
    } else {
        if let Some(idx) = image_index {
            format!("規約に基づき、プロフィール画像（{}枚目）を非承認としました。", idx + 1)
        } else {
            "規約に基づき、プロフィール画像を非承認としました。".to_string()
        }
    };

    // 3. Granular Idempotency check:
    // Only skip if a notification for THIS EXACT image_id was already sent in the last 5 minutes.
    // This allows updates to different slots or different images in the same slot to still trigger notifications.
    let five_minutes_ago = (chrono::Utc::now() - chrono::Duration::minutes(5)).to_rfc3339();
    let existing_logs = postgrest_client
        .from("notification_messages")
        .select("message_id")
        .eq("user_id", &user_id)
        .eq("message_type", status_type)
        .ilike("message", &format!("%[{}]%", review_info.image_id))
        .gte("created_at", &five_minutes_ago)
        .execute()
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    let body_text = existing_logs.text().await.unwrap_or_default();
    if body_text.contains("message_id") && body_text != "[]" {
        println!("ℹ️ [Proxy] Notification already logged for image_id: {} with type: {}", review_info.image_id, status_type);
        return Ok(());
    }

    let fcm = postgrest_client
        .select_fcm_token(&user_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    if let Some(fcm_payload) = fcm {
        let mut data = HashMap::new();
        data.insert("notification_type".to_string(), "review_result".to_string());
        data.insert("image_id".to_string(), review_info.image_id.to_string());
        data.insert("user_id".to_string(), review_info.user_id.to_string());
        data.insert("status".to_string(), review_info.status.clone());

        send_fcm_notification(
            &http_client,
            &fcm_payload.fcm_token,
            "Rapid",
            &base_message,
            data,
        )
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;
    }

    // 4. Log to notification_messages table
    // We append the image_id in brackets for our granular idempotency check.
    let log_message = format!("{} [{}]", base_message, review_info.image_id);
    let notification_log = db::object::NotificationMessage {
        message_id: None,
        created_at: chrono::Utc::now(),
        message: Some(log_message),
        message_type: Some(status_type.to_string()),
        user_id: Some(uuid::Uuid::parse_str(&user_id).unwrap_or_default()),
        is_read: Some(false),
    };

    postgrest_client
        .insert_notification_message(&notification_log)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(())
}

pub async fn send_identity_verification_notification(
    user_id: &uuid::Uuid,
    status: &str,
    reason: Option<String>,
    http_client: actix_web::web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: actix_web::web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<()> {
    let user_id_str = user_id.to_string();
    
    let status_type = if status == "approve" {
        "identity_verification_approved"
    } else {
        "identity_verification_rejected"
    };

    // Idempotency check: Don't log if a similar matching notification was recorded in the last 5 minutes
    let five_minutes_ago = (chrono::Utc::now() - chrono::Duration::minutes(5)).to_rfc3339();
    let existing = postgrest_client
        .from("notification_messages")
        .select("message_id")
        .eq("user_id", &user_id_str)
        .eq("message_type", status_type)
        .gte("created_at", &five_minutes_ago)
        .execute()
        .await;

    if let Ok(resp) = existing {
        let text = resp.text().await.unwrap_or_default();
        if text.contains("message_id") && text != "[]" {
            println!("ℹ️ [Proxy] Identity notification already logged for user: {} with type: {}", user_id_str, status_type);
            return Ok(());
        }
    }

    let message = if status == "approve" {
        "本人確認が完了しました。全ての機能をご利用いただけます。".to_string()
    } else {
        format!(
            "本人確認書類に不備がありました。再度アップロードをお願いします。{}",
            reason.map(|r| format!("\n理由: {}", r)).unwrap_or_default()
        )
    };

    let fcm = postgrest_client
        .select_fcm_token(&user_id_str)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    if let Some(fcm_payload) = fcm {
        let mut data = HashMap::new();
        data.insert("notification_type".to_string(), "identity_verification_result".to_string());
        data.insert("user_id".to_string(), user_id_str);
        data.insert("status".to_string(), status.to_string());

        send_fcm_notification(
            &http_client,
            &fcm_payload.fcm_token,
            "Rapid",
            &message,
            data,
        )
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;
    }

    // Log to notification_messages table in Supabase
    let notification_log = db::object::NotificationMessage {
        message_id: None,
        created_at: chrono::Utc::now(),
        message: Some(message),
        message_type: Some(status_type.to_string()),
        user_id: Some(*user_id),
        is_read: Some(false),
    };

    postgrest_client
        .insert_notification_message(&notification_log)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(())
}


