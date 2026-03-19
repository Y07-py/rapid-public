use std::collections::HashMap;
use std::sync::Arc;

use crate::db;
use crate::http;
use crate::notification::common::send_fcm_notification;

pub async fn broadcast_maintenance_mode(
    is_maintenance: bool,
    http_client: actix_web::web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: actix_web::web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<()> {
    let tokens = postgrest_client
        .get_all_fcm_tokens()
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    let (title, message) = if is_maintenance {
        (
            "サーバーメンテナンス開始のお知らせ",
            "サービスを一時的に停止しています。ご不便をおかけしますが、再開までしばらくお待ちください。",
        )
    } else {
        (
            "サーバーメンテナンス終了のお知らせ",
            "メンテナンスが完了しました。サービスをご利用いただけます。",
        )
    };

    println!(
        "📣 [Broadcast] Sending maintenance mode FCM to {} active devices...",
        tokens.len()
    );

    // Send notifications concurrently (fire-and-forget logic for efficiency)
    for token in tokens {
        let mut data = HashMap::new();
        data.insert("notification_type".to_string(), "maintenance".to_string());
        data.insert("is_maintenance".to_string(), is_maintenance.to_string());

        let http_client_clone = http_client.clone();

        tokio::spawn(async move {
            let res = send_fcm_notification(&http_client_clone, &token, title, message, data).await;

            if let Err(e) = res {
                eprintln!("⚠️ [Broadcast] Failed to send FCM to {}: {:?}", token, e);
            }
        });
    }

    Ok(())
}
