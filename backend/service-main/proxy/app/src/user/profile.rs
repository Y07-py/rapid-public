use std::sync::Arc;

use actix_web::web;

use crate::db;
use crate::http;
use crate::nlp;
use crate::notification;
use crate::user;

pub async fn update_user_profile(
    profile: &db::object::RapidUser,
    nlp_client: web::Data<Arc<nlp::client::NLPClient>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> Result<(), String> {
    let mut user_score = 0.0;
    let mut is_introduction_clean = true;
    if let Some(introduction) = profile.introduction.clone() {
        // Check whether change introduction
        let mut is_changed = false;
        if let Some(user_profille) = postgrest_client
            .select_user(&profile.user_id.to_string())
            .await
            .map_err(|e| e.to_string())?
        {
            if let Some(introduction_origin) = user_profille.introduction {
                is_changed = introduction_origin != introduction;
            }
        }

        if !introduction.is_empty() && is_changed {
            let moderate_paramater =
                nlp::object::AnalyzeModerateRequestParamater::new(&introduction, None);
            let moderate_result = nlp_client
                .analyze_moderate(&moderate_paramater)
                .await
                .map_err(|e| e.to_string())?;

            // Check moderate
            if let Some(moderate_result) = moderate_result {
                let moderate_categories = moderate_result.moderation_categories;
                if moderate_categories.iter().any(|e| e.confidence >= 0.5) {
                    // reject update introduction.
                    is_introduction_clean = false;
                } else {
                    let sentiment_paramater =
                        nlp::object::AnalyzeSentimentRequestParamater::new(&introduction, None);
                    let sentiment_result = nlp_client
                        .analyze_sentiment(&sentiment_paramater)
                        .await
                        .map_err(|e| e.to_string())?;
                    if let Some(sentiment_result) = sentiment_result {
                        let sentiment_score = sentiment_result.document_sentiment.score;
                        let ideai_size = 240;
                        let intro_score = user::metrics::compute_introduction_score(
                            &introduction,
                            ideai_size,
                            sentiment_score,
                            0.02,
                            0.4,
                        );
                        user_score += 0.5 * intro_score;
                    }
                }
            }
        }
    }

    // Calculate the percentage of non-None attributes
    let fields = [
        profile.user_name.is_some(),
        profile.birth_date.is_some(),
        profile.residence.is_some(),
        profile.thought_marriage.is_some(),
        profile.blood_type.is_some(),
        profile.academic_background.is_some(),
        profile.income.is_some(),
        profile.profession.is_some(),
        profile.drinking_frequency.is_some(),
        profile.child_status.is_some(),
        profile.height.is_some(),
        profile.body_type.is_some(),
        profile.mbti.is_some(),
        profile.holiday_type.is_some(),
        profile.sex.is_some(),
        profile.introduction.is_some(),
        profile.smoking_frequency.is_some(),
        profile.user_score.is_some(),
        profile.subscription_status.is_some(),
        profile.total_point.is_some(),
    ];

    let non_none_count = fields.iter().filter(|&&f| f).count();
    let total_fields = fields.len();
    let ratio = non_none_count as f64 / total_fields as f64;
    user_score += 0.5 * ratio;

    postgrest_client
        .update_user(profile, user_score, is_introduction_clean)
        .await?;

    notification::profile::send_introduction_notification(
        &profile.user_id.to_string(),
        !is_introduction_clean,
        http_client,
        postgrest_client,
    )
    .await
    .map_err(|e| e.to_string())?;

    Ok(())
}

pub async fn upload_profile(
    payload: &db::object::UploadProfileMetaData,
    nlp_client: web::Data<Arc<nlp::client::NLPClient>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> Result<(), String> {
    // 1. Update user profile (includes moderation and scoring)
    update_user_profile(&payload.user, nlp_client, http_client, postgrest_client.clone()).await?;

    // 2. Update keyword tags
    postgrest_client
        .upsert_user_keyword_tags(&payload.user.user_id, &payload.keywords)
        .await?;

    Ok(())
}
