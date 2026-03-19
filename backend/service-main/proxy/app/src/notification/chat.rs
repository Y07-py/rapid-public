use std::collections::HashMap;
use std::sync::Arc;

use crate::db;
use crate::db::object::{ChatMessage, ChatRoom};
use crate::http;
use crate::notification::common::send_fcm_notification;

const MATCH_MESSAGE_CONTENT: &str = "マッチングが成立しました！";
const CHAT_MESSAGE_CONTENT: &str = "からメッセージを受信しました。";

pub async fn send_match_notification(
    chat_room: &ChatRoom,
    http_client: &Arc<http::request::HttpClient>,
    postgrest_client: &Arc<db::postgrest::SupabsePostgrest>,
) -> Result<(), String> {
    let to_user_id = chat_room.to_user_id.to_string();

    let fcm = postgrest_client.select_fcm_token(&to_user_id).await?;

    if let Some(fcm_payload) = fcm {
        let mut data = HashMap::new();
        data.insert("notification_type".to_string(), "matching".to_string());
        data.insert("user_id".to_string(), chat_room.from_user_id.to_string());
        data.insert("room_id".to_string(), chat_room.room_id.to_string());

        send_fcm_notification(
            http_client,
            &fcm_payload.fcm_token,
            "Rapid",
            MATCH_MESSAGE_CONTENT,
            data,
        )
        .await
        .map_err(|e| e.to_string())?;
    }

    // Log to notification_messages table
    let log_msg = db::object::NotificationMessage {
        message_id: None,
        created_at: chrono::Utc::now(),
        message: Some(MATCH_MESSAGE_CONTENT.to_string()),
        message_type: Some("matching".to_string()),
        user_id: Some(chat_room.to_user_id),
        is_read: Some(false),
    };

    // Idempotency check: Don't log if a similar matching notification was recorded in the last minute
    let one_minute_ago = (chrono::Utc::now() - chrono::Duration::minutes(1)).to_rfc3339();
    let existing = postgrest_client
        .from("notification_messages")
        .select("message_id")
        .eq("user_id", &to_user_id)
        .eq("message_type", "matching")
        .gte("created_at", &one_minute_ago)
        .execute()
        .await;

    if let Ok(resp) = existing {
        let text = resp.text().await.unwrap_or_default();
        if text.contains("message_id") && text != "[]" {
            println!(
                "ℹ️ [Proxy] Matching notification already logged for user: {}",
                to_user_id
            );
            return Ok(());
        }
    }

    let _ = postgrest_client.insert_notification_message(&log_msg).await;

    Ok(())
}

pub async fn send_message_notification(
    chat_message: &ChatMessage,
    http_client: &Arc<http::request::HttpClient>,
    postgrest_client: &Arc<db::postgrest::SupabsePostgrest>,
) -> Result<(), String> {
    let to_user_id = chat_message.to_user_id.to_string();

    // Check if the recipient has muted notifications for this specific room
    if let Ok(Some(setting)) = postgrest_client
        .select_chat_notification_setting(&chat_message.to_user_id, &chat_message.room_id)
        .await
    {
        if !setting.is_on {
            println!(
                "🔇 [Proxy] Notification muted for user: {} in room: {}",
                to_user_id, chat_message.room_id
            );
            return Ok(());
        }
    }

    // Check if the recipient has blocked the sender
    if let Ok(true) = postgrest_client
        .is_blocked(&chat_message.to_user_id, &chat_message.from_user_id)
        .await
    {
        println!(
            "🚫 [Proxy] Notification blocked: recipient {} has blocked sender {}",
            to_user_id, chat_message.from_user_id
        );
        return Ok(());
    }

    // Fetch sender's name
    let sender = postgrest_client
        .select_user(&chat_message.from_user_id.to_string())
        .await
        .ok()
        .flatten();

    let sender_name = sender
        .and_then(|u| u.user_name)
        .unwrap_or("誰か".to_string());
    let full_message = format!("{}さん{}", sender_name, CHAT_MESSAGE_CONTENT);

    let fcm = postgrest_client.select_fcm_token(&to_user_id).await?;

    if let Some(fcm_token) = fcm {
        let mut data = HashMap::new();
        data.insert("notification_type".to_string(), "message".to_string());
        data.insert("user_id".to_string(), chat_message.from_user_id.to_string());
        data.insert("room_id".to_string(), chat_message.room_id.to_string());
        data.insert(
            "message_id".to_string(),
            chat_message.message_id.to_string(),
        );

        send_fcm_notification(
            http_client,
            &fcm_token.fcm_token,
            "Rapid",
            &full_message,
            data,
        )
        .await
        .map_err(|e| e.to_string())?;
    };

    // Log to notification_messages table
    let log_msg = db::object::NotificationMessage {
        message_id: None,
        created_at: chrono::Utc::now(),
        message: Some(full_message),
        message_type: Some("message".to_string()),
        user_id: Some(chat_message.to_user_id),
        is_read: Some(false),
    };

    // Idempotency check for chat messages
    let one_minute_ago = (chrono::Utc::now() - chrono::Duration::minutes(1)).to_rfc3339();
    let existing = postgrest_client
        .from("notification_messages")
        .select("message_id")
        .eq("user_id", &to_user_id)
        .eq("message_type", "message")
        .gte("created_at", &one_minute_ago)
        .execute()
        .await;

    if let Ok(resp) = existing {
        let text = resp.text().await.unwrap_or_default();
        if text.contains("message_id") && text != "[]" {
            return Ok(()); // Already logged recently
        }
    }

    let _ = postgrest_client.insert_notification_message(&log_msg).await;

    Ok(())
}
