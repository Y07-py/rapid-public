use std::sync::Arc;

use actix_web::web;

use crate::db;
use crate::http;
use crate::nlp;
use crate::notification;
use crate::recruitment;

pub async fn post_recruitment(
    mut rec: recruitment::objects::PostRecruitmentRequest,
    nlp_client: web::Data<Arc<nlp::client::NLPClient>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> Result<(), String> {
    let user_id_str = rec.recruitment.user_id.unwrap().to_string();

    if let Some(message) = &rec.recruitment.message {
        if !message.is_empty() {
            // Check moderate
            let moderate_paramater =
                nlp::object::AnalyzeModerateRequestParamater::new(message, None);
            let moderate_result = nlp_client.analyze_moderate(&moderate_paramater).await?;

            if let Some(result) = moderate_result {
                if result
                    .moderation_categories
                    .iter()
                    .any(|c| c.confidence >= 0.5)
                {
                    // Send reject notification
                    notification::recruitment::send_recruitment_notification(
                        &user_id_str,
                        true,
                        http_client,
                        postgrest_client,
                    )
                    .await
                    .map_err(|e| e.to_string())?;

                    return Err(
                        "募集メッセージに不適切な内容が含まれている可能性があります。".to_string(),
                    );
                }
            }

            // Calculate sentiment score
            let sentiment_paramater =
                nlp::object::AnalyzeSentimentRequestParamater::new(message, None);
            let sentiment_result = nlp_client.analyze_sentiment(&sentiment_paramater).await?;

            if let Some(res) = sentiment_result {
                // Set the message_score to the sentiment score (-1.0 to 1.0)
                rec.recruitment.message_score = Some(res.document_sentiment.score);
            }
        }
    }

    // Insert into database
    postgrest_client.post_recruitment(&rec).await?;

    // Send approve notification
    notification::recruitment::send_recruitment_notification(
        &user_id_str,
        false,
        http_client,
        postgrest_client,
    )
    .await
    .map_err(|e| e.to_string())?;

    Ok(())
}
