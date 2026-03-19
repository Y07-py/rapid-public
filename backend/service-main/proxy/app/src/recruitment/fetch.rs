use actix_web;
use std::collections::HashSet;
use std::sync::Arc;
use tokio::sync::RwLock;

use crate::{
    db::{self, object::RecruitmentWithLike},
    http, place, recruitment,
};

/// Computes a list of place IDs within a 5km radius based on a coordinate.
async fn compute_radius_place_ids(
    lat: f64,
    lon: f64,
    radius: f64,
    quad_tree: &actix_web::web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
) -> HashSet<String> {
    let zoom_level = place::metrics::compute_zoom_level(radius, lat);
    let gr = place::metrics::compute_ground_resolution(lat, zoom_level);
    let edge_length = radius / gr;
    let (x, y) = place::metrics::compute_pixel_coordinate(lon, lat, zoom_level as usize);

    let corners = [
        ((x - edge_length).max(0.0), (y - edge_length).max(0.0)),
        (x + edge_length, (y - edge_length).max(0.0)),
        ((x - edge_length).max(0.0), y + edge_length),
        (x + edge_length, y + edge_length),
    ];

    let mut result_ids = HashSet::new();
    let quad_guard = quad_tree.read().await;

    for (px, py) in corners.iter() {
        let (lon, lat) = place::metrics::compute_coordinate(*px, *py, zoom_level as usize);
        let quadkeys = place::metrics::compute_quadkeys(lon, lat, zoom_level as usize);
        let (prefix_key, _) = quadkeys.split_at(std::cmp::min(10, quadkeys.len()));
        if let Some(placeids) = quad_guard.get(prefix_key.to_string(), None) {
            for id in placeids {
                result_ids.insert(id.as_str().to_string());
            }
        }
    }

    result_ids
}

/// Fetches place IDs within a 5km radius based on a text keyword.
async fn find_place_ids_by_keyword(
    keyword: &str,
    quad_tree: &actix_web::web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
    http_client: &actix_web::web::Data<Arc<http::request::HttpClient>>,
) -> Result<HashSet<String>, String> {
    let endpoint = std::env::var("GOOGLE_API_TEXT_SEARCH_ENDPOINT").map_err(|e| e.to_string())?;

    let payload = serde_json::json!({
        "textQuery": keyword,
        "pageSize": 5, // Just need a few matching locations
    });

    let header_flow = Box::new(http::object::GooglePlacesHeader::new(
        "places.id,places.location".to_string(),
    ));
    let response = http_client
        .post(&endpoint, None, None, payload, Some(header_flow))
        .await
        .map_err(|e| e.to_string())?;

    let mut result_ids = HashSet::new();

    if response.get_status_code() == 200 {
        if let Some(response_obj) =
            response.get_body::<place::object::GooglePlacesTextSearchResponse>()
        {
            if let Some(places) = response_obj.places {
                for p in places {
                    if let Some(loc) = p.get_latlng() {
                        let ids = compute_radius_place_ids(
                            loc.get_lat().unwrap(),
                            loc.get_lon().unwrap(),
                            5000.0,
                            quad_tree,
                        )
                        .await;
                        result_ids.extend(ids);
                    }
                }
            }
        }
    }

    Ok(result_ids)
}

/// Retrieves the user's residence and translates it to place IDs.
async fn find_place_ids_by_residence(
    user_id: &uuid::Uuid,
    radius: f64,
    postgrest_client: &actix_web::web::Data<Arc<db::postgrest::SupabsePostgrest>>,
    quad_tree: &actix_web::web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
    http_client: &actix_web::web::Data<Arc<http::request::HttpClient>>,
) -> Result<HashSet<String>, String> {
    let rapid_user = postgrest_client.select_user(&user_id.to_string()).await?;
    if let Some(user) = rapid_user {
        if let Some(residence) = user.residence {
            let endpoint =
                std::env::var("GOOGLE_API_TEXT_SEARCH_ENDPOINT").map_err(|e| e.to_string())?;
            let payload = serde_json::json!({
                "textQuery": residence,
                "pageSize": 1,
            });
            let header_flow = Box::new(http::object::GooglePlacesHeader::new(
                "places.location".to_string(),
            ));
            let response = http_client
                .post(&endpoint, None, None, payload, Some(header_flow))
                .await
                .map_err(|e| e.to_string())?;

            if response.get_status_code() == 200 {
                if let Some(response_obj) =
                    response.get_body::<place::object::GooglePlacesTextSearchResponse>()
                {
                    if let Some(places) = response_obj.places {
                        if let Some(p) = places.first() {
                            if let Some(loc) = p.get_latlng() {
                                // Default unit for residence radius is assumed to be km? Let's use it as meters.
                                // If iOS provides Double, maybe it's km. Let's assume it's km and convert to meters.
                                let radius_meters = radius * 1000.0;
                                let ids = compute_radius_place_ids(
                                    loc.get_lat().unwrap(),
                                    loc.get_lon().unwrap(),
                                    radius_meters,
                                    quad_tree,
                                )
                                .await;
                                return Ok(ids);
                            }
                        }
                    }
                }
            }
        }
    }
    Ok(HashSet::new())
}

/// Given place IDs, find matching recruitment IDs
async fn find_recruitment_ids_by_places(
    place_ids: &HashSet<String>,
    postgrest_client: &actix_web::web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> Result<HashSet<String>, String> {
    if place_ids.is_empty() {
        return Ok(HashSet::new());
    }

    let place_ids_vec: Vec<String> = place_ids.iter().cloned().collect();

    let response = postgrest_client
        .from("recruitment_places")
        .select("recruitment_id")
        .in_("place_id", place_ids_vec)
        .execute()
        .await
        .map_err(|e| e.to_string())?;

    let mut recruitment_ids = HashSet::new();
    if response.status().is_success() {
        let body = response.text().await.map_err(|e| e.to_string())?;
        if let Ok(records) = serde_json::from_str::<Vec<serde_json::Value>>(&body) {
            for record in records {
                if let Some(id_str) = record.get("recruitment_id").and_then(|v| v.as_str()) {
                    recruitment_ids.insert(id_str.to_string());
                }
            }
        }
    }

    Ok(recruitment_ids)
}

pub async fn fetch_recruitment(
    param: &recruitment::objects::FetchRecruitmentRequestParamater,
    quad_tree: actix_web::web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
    http_client: actix_web::web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: actix_web::web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<Option<Vec<db::object::RecruitmentWithLike>>> {
    let request_user = postgrest_client
        .select_user(&param.user_id.to_string())
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?
        .unwrap();

    let blocked_user_ids = postgrest_client
        .fetch_blocked_user_ids(&param.user_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    let mut builder = postgrest_client.from("recruitments");

    let select_query = "*,\
        recruitment_hash_tags(*),\
        recruitment_places(*),\
        recruitment_place_types(*)";

    builder = builder.select(select_query);

    // Process filters
    if let Some(filter) = &param.filter_paramater {
        // Location processing
        let mut target_recruitment_ids: Option<HashSet<String>> = None;

        let has_location_filter =
            filter.location_keyword.is_some() || filter.residence_radius.is_some();
        if has_location_filter {
            let place_ids = if let Some(keyword) = &filter.location_keyword {
                find_place_ids_by_keyword(keyword, &quad_tree, &http_client)
                    .await
                    .map_err(actix_web::error::ErrorInternalServerError)?
            } else if let Some(radius) = filter.residence_radius {
                find_place_ids_by_residence(
                    &param.user_id,
                    radius,
                    &postgrest_client,
                    &quad_tree,
                    &http_client,
                )
                .await
                .map_err(actix_web::error::ErrorInternalServerError)?
            } else {
                HashSet::new()
            };

            let rec_ids = find_recruitment_ids_by_places(&place_ids, &postgrest_client)
                .await
                .map_err(actix_web::error::ErrorInternalServerError)?;
            target_recruitment_ids = Some(rec_ids);
        }

        if let Some(rec_ids) = target_recruitment_ids {
            if rec_ids.is_empty() {
                // Return empty if filter matched 0 places or 0 recruitments
                return Ok(Some(Vec::new()));
            } else {
                let rec_ids_vec: Vec<String> = rec_ids.into_iter().collect();
                builder = builder.in_("recruitment_id", rec_ids_vec);
            }
        }

        // Age processing
        if let Some(age_range) = &filter.age_range {
            builder = builder.gte("post_user_age", age_range.from_age.to_string());
            builder = builder.lte("post_user_age", age_range.to_age.to_string());
        }
    }

    if !blocked_user_ids.is_empty() {
        let blocked_ids_str = blocked_user_ids
            .into_iter()
            .collect::<Vec<String>>()
            .join(",");
        builder = builder.not("in", "user_id", format!("({})", blocked_ids_str));
    }

    let from = param.offset;
    let end = param.offset + param.limit - 1;

    let response = builder
        .neq("user_id", param.user_id.to_string())
        .neq("post_user_sex", request_user.sex.unwrap_or("".to_string()))
        .range(from, end)
        .execute()
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    if response.status().is_success() {
        let body = response
            .text()
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

        let recruitments: Vec<db::object::RecruitmentWithRelations> = serde_json::from_str(&body)
            .map_err(|e| {
            actix_web::error::ErrorInternalServerError(format!(
                "Failed to deserialize response: {}",
                e
            ))
        })?;

        let mut recruitment_with_likes: Vec<RecruitmentWithLike> = Vec::new();
        for rec in recruitments.iter() {
            let like_recruitment = postgrest_client
                .select_like_recruitment(rec, &param.user_id.to_string())
                .await
                .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;
            recruitment_with_likes.push(RecruitmentWithLike {
                like: like_recruitment,
                recruitment_with_relations: rec.clone(),
            });
        }

        return Ok(Some(recruitment_with_likes));
    }

    Ok(None)
}

pub async fn fetch_recruitment_with_id(
    recruitment_id: &uuid::Uuid,
    postgrest_client: actix_web::web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> Result<Option<db::object::RecruitmentWithRelations>, String> {
    let select_query = "*,\
        recruitment_hash_tags(*),\
        recruitment_places(*),\
        recruitment_place_types(*)";

    let response = postgrest_client
        .from("recruitments")
        .select(select_query)
        .eq("recruitment_id", recruitment_id.to_string())
        .execute()
        .await
        .map_err(|e| e.to_string())?;

    if response.status().is_success() {
        let context = response.text().await.map_err(|e| e.to_string())?;
        let recruitments: Vec<db::object::RecruitmentWithRelations> =
            serde_json::from_str(&context).map_err(|e| e.to_string())?;

        if let Some(recruitment) = recruitments.first() {
            return Ok(Some(recruitment.clone()));
        }
    }

    Ok(None)
}
