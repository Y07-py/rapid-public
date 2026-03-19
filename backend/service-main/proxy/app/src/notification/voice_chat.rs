use std::collections::HashMap;
use std::sync::Arc;

use crate::db;
use crate::http;
use crate::notification::common::send_fcm_notification;

pub async fn broadcast_voice_chat_event_started(
    http_client: actix_web::web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: actix_web::web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<()> {
    let tokens = postgrest_client
        .get_all_fcm_tokens()
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    let title = "スポットの集計完了";
    let message =
        "投票受付が終了しました！ 今日のボイスチャットのお相手の候補を確認してみましょう。";

    println!(
        "📣 [Broadcast] Sending voice chat event started FCM to {} active devices...",
        tokens.len()
    );

    // Send notifications concurrently
    for token in tokens {
        let mut data = HashMap::new();
        data.insert(
            "notification_type".to_string(),
            "voice_chat_started".to_string(),
        );

        let http_client_clone = http_client.clone();

        tokio::spawn(async move {
            let res = send_fcm_notification(&http_client_clone, &token, title, message, data).await;

            if let Err(e) = res {
                eprintln!("⚠️ [Broadcast] Failed to send FMC to {}: {:?}", token, e);
            }
        });
    }

    Ok(())
}

pub async fn send_voice_chat_matched_notification(
    http_client: actix_web::web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: actix_web::web::Data<Arc<db::postgrest::SupabsePostgrest>>,
    to_user_id: uuid::Uuid,
    opponent_user_id: uuid::Uuid,
    call_id: &str,
    role: &str,
) -> actix_web::Result<()> {
    let fcm = postgrest_client
        .select_fcm_token(&to_user_id.to_string())
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    let opponent = postgrest_client
        .select_user(&opponent_user_id.to_string())
        .await
        .ok()
        .flatten();

    let opponent_name = opponent
        .and_then(|u| u.user_name)
        .unwrap_or("誰か".to_string());

    let title = "マッチング成立！";
    let message = format!(
        "{}さんとマッチしました。ボイスチャットを開始します。",
        opponent_name
    );

    if let Some(fcm_payload) = fcm {
        let mut data = HashMap::new();
        data.insert(
            "notification_type".to_string(),
            "voice_chat_matched".to_string(),
        );
        data.insert("call_id".to_string(), call_id.to_string());
        data.insert("role".to_string(), role.to_string());
        data.insert("opponent_user_id".to_string(), opponent_user_id.to_string());
        data.insert("opponent_name".to_string(), opponent_name.clone());

        println!(
            "ℹ️ [Notification] Sending voice chat matched notification to user: {} (token: ...{})",
            to_user_id,
            &fcm_payload.fcm_token[fcm_payload.fcm_token.len().saturating_sub(10)..]
        );

        if let Err(e) = send_fcm_notification(&http_client, &fcm_payload.fcm_token, title, &message, data).await {
             println!("❌ [Notification] Failed to send FCM: {:?}", e);
             return Err(actix_web::error::ErrorInternalServerError(e));
        }
        println!("✅ [Notification] Successfully sent FCM to user: {}", to_user_id);
    } else {
        println!("⚠️ [Notification] FCM token NOT FOUND for user: {}", to_user_id);
    }

    // Log to notification_messages table
    let log_msg = db::object::NotificationMessage {
        message_id: None,
        created_at: chrono::Utc::now(),
        message: Some(message),
        message_type: Some("voice_chat_matched".to_string()),
        user_id: Some(to_user_id),
        is_read: Some(false),
    };

    let _ = postgrest_client.insert_notification_message(&log_msg).await;

    Ok(())
}
