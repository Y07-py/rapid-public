use std::collections::HashMap;
use std::sync::Arc;

use crate::db;
use crate::db::object::LikePair;
use crate::http;
use crate::notification::common::send_fcm_notification;

pub async fn send_like(
    body: LikePair,
    http_client: actix_web::web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: actix_web::web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<()> {
    let recruitment = postgrest_client
        .select_recruitment(body.get_recruitment_id())
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    if recruitment.is_none() {
        return Err(actix_web::error::ErrorInternalServerError(format!(
            "recruitment is none."
        )));
    }

    let recruitment = recruitment.unwrap();

    let user_id = recruitment.user_id.unwrap().to_string();

    let fcm = postgrest_client
        .select_fcm_token(&user_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    // Fetch sender's name
    let sender = postgrest_client
        .select_user(&body.from_user_id.to_string())
        .await
        .ok()
        .flatten();

    let sender_name = sender
        .and_then(|u| u.user_name)
        .unwrap_or("誰か".to_string());
    let full_message = if body.matched {
        format!(
            "{}さんとマッチングしました！さっそくトークしてみましょう",
            sender_name
        )
    } else {
        format!("{}さんがあなたの投稿にいいねしました", sender_name)
    };

    if let Some(fcm_payload) = fcm {
        let mut data = HashMap::new();
        data.insert("notification_type".to_string(), "like".to_string());
        data.insert("user_id".to_string(), body.from_user_id.to_string());
        data.insert(
            "recruitment_id".to_string(),
            body.recruitment_id.to_string(),
        );

        send_fcm_notification(
            &http_client,
            &fcm_payload.fcm_token,
            "Rapid",
            &full_message,
            data,
        )
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

        postgrest_client
            .upsert_like_pair(&body)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

        postgrest_client
            .upsert_like_user(&body)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

        // If matched, create chat room and match pairs so it appears in ChatListView
        if body.matched {
            let chat_room = db::object::ChatRoom {
                room_id: uuid::Uuid::new_v4(),
                to_user_id: body.to_user_id,
                from_user_id: body.from_user_id,
                created_at: chrono::Utc::now(),
                recruitment_id: body.recruitment_id,
                talk_count: Some(0),
            };

            // Insert chat room
            if let Err(e) = postgrest_client.insert_chat_room(&chat_room).await {
                println!("⚠️ [Proxy] Failed to insert chat room on match: {:?}", e);
            }
            // Insert match pair (creates records for both users)
            if let Err(e) = postgrest_client.insert_match_pair(&chat_room).await {
                println!("⚠️ [Proxy] Failed to insert match pair on match: {:?}", e);
            }
        }
    }

    // Log to notification_messages table
    let log_msg = db::object::NotificationMessage {
        message_id: None,
        created_at: chrono::Utc::now(),
        message: Some(full_message),
        message_type: Some("like".to_string()),
        user_id: recruitment.user_id,
        is_read: Some(false),
    };

    // Idempotency check for likes
    let one_minute_ago = (chrono::Utc::now() - chrono::Duration::minutes(1)).to_rfc3339();
    let existing = postgrest_client
        .from("notification_messages")
        .select("message_id")
        .eq("user_id", &user_id)
        .eq("message_type", "like")
        .gte("created_at", &one_minute_ago)
        .execute()
        .await;

    if let Ok(resp) = existing {
        let text = resp.text().await.unwrap_or_default();
        if text.contains("message_id") && text != "[]" {
            println!(
                "ℹ️ [Proxy] Like notification already logged for user: {}",
                user_id
            );
            return Ok(());
        }
    }

    let _ = postgrest_client.insert_notification_message(&log_msg).await;

    Ok(())
}

