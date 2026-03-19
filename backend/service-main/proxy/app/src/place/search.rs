use std::collections::HashMap;
use std::collections::HashSet;
use std::sync::Arc;
use tokio::sync::{RwLock, RwLockReadGuard};

use actix_web;
use actix_web::web;
use futures_util;
use tokio;

use crate::cache;
use crate::db;
use crate::http;
use crate::place;
use crate::place::object::GooglePlacesSearchResponsePlace;

/// Parse field mask string into vector
fn parse_field_mask(field_mask: &str) -> Vec<String> {
    field_mask
        .split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

/// Compute missing fields from requested vs cached
fn compute_missing_fields(
    requested: &[String],
    cached: &std::collections::HashSet<String>,
) -> Vec<String> {
    requested
        .iter()
        .filter(|f| !cached.contains(*f))
        .cloned()
        .collect()
}

/// Merge two place objects - new data overwrites existing for non-null fields
fn merge_place_data(
    existing: place::object::GooglePlacesSearchResponsePlace,
    new_data: place::object::GooglePlacesSearchResponsePlace,
) -> place::object::GooglePlacesSearchResponsePlace {
    let mut existing_value = serde_json::to_value(&existing).unwrap_or_default();
    let new_value = serde_json::to_value(&new_data).unwrap_or_default();

    if let (serde_json::Value::Object(existing_map), serde_json::Value::Object(new_map)) =
        (&mut existing_value, new_value)
    {
        for (key, value) in new_map {
            if !value.is_null() {
                existing_map.insert(key, value);
            }
        }
    }

    serde_json::from_value(existing_value).unwrap_or(existing)
}

pub async fn nearby_search(
    param: place::object::GooglePlacesNearbySearchParamater,
    cache_worker: web::Data<Arc<RwLock<cache::worker::CacheWorker>>>,
    quad_tree: web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
) -> actix_web::Result<(
    Option<Vec<place::object::GooglePlacesSearchResponsePlace>>,
    place::object::SearchMetrics,
)> {
    const BASE_ZOOM: usize = 12;

    // 1. Extract client parameters.
    let client_param = param.get_client_paramater_ref();
    let result_offset = client_param.result_offset;
    let request_param = param.get_request_paramater();
    let result_limit = request_param.get_max_result_count().unwrap_or(20);
    let place_types = request_param.get_types();

    // 2. Snap to tile center at BASE_ZOOM.
    let (base_lon, base_lat) = place::metrics::snap_to_tile_center(
        client_param.longitude,
        client_param.latitude,
        BASE_ZOOM,
    );

    // 3. Compute tile side length and search radius.
    let tile_side = place::metrics::compute_tile_side_length(base_lat, BASE_ZOOM);
    let tile_radius = tile_side * 0.707;

    // 4. Compute spiral offset for this page.
    let (dx, dy) = place::metrics::compute_spiral_offset(result_offset);

    // 5. Compute target tile center.
    let (tile_lon, tile_lat) =
        place::metrics::compute_spiral_tile_center(base_lon, base_lat, dx, dy, tile_side);

    // 6. Compute quadkey prefix for the target tile.
    let quadkey = place::metrics::compute_quadkeys(tile_lon, tile_lat, BASE_ZOOM);

    // 7. Check if tile has cached data.
    let tile_cached = {
        let quad_tree_guard = quad_tree.read().await;
        quad_tree_guard.tile_has_data(&quadkey)
    };

    if tile_cached {
        // Retrieve cached place IDs from the trie.
        let cacheids: HashSet<place::object::GooglePlaceSearchPlaceId> = {
            let quad_tree_guard = quad_tree.read().await;
            quad_tree_guard
                .get(quadkey.clone(), Some(&place_types))
                .unwrap_or_default()
        };

        let mut cache_places = get_nearby_places_from_cache(&param, cacheids, &cache_worker).await;
        if cache_places.len() >= result_limit {
            let count = cache_places.len();
            cache_places.truncate(result_limit);
            return Ok((
                Some(cache_places),
                place::object::SearchMetrics {
                    is_hit: true,
                    upstream_response_time: None,
                    result_count: count,
                },
            ));
        }
    }

    // 8. Cache miss — fetch from Google Places API for this tile.
    let tile_param = param.to_tile_param(tile_lat, tile_lon, tile_radius);

    if let Ok((Some(response), duration)) = fetch_nearby_places_data(&tile_param, http_client).await
    {
        let response_clone = response.clone();

        put_cache_worker(response, BASE_ZOOM, cache_worker, quad_tree.clone());

        if let Some(mut places) = response_clone.get_places() {
            let count = places.len();
            places.truncate(result_limit);
            return Ok((
                Some(places),
                place::object::SearchMetrics {
                    is_hit: false,
                    upstream_response_time: Some(duration),
                    result_count: count,
                },
            ));
        }

        // 0 results — mark tile as searched to avoid re-querying.
        let quad_tree_inner = quad_tree.clone();
        let quadkey_clone = quadkey.clone();
        tokio::spawn(async move {
            let mut guard = quad_tree_inner.write().await;
            guard.mark_tile_searched(&quadkey_clone);
        });

        return Ok((
            Some(Vec::new()),
            place::object::SearchMetrics {
                is_hit: false,
                upstream_response_time: Some(duration),
                result_count: 0,
            },
        ));
    }

    Ok((
        None,
        place::object::SearchMetrics {
            is_hit: false,
            upstream_response_time: None,
            result_count: 0,
        },
    ))
}

async fn fetch_nearby_places_data(
    param: &place::object::GooglePlacesNearbySearchParamater,
    http_client: web::Data<Arc<http::request::HttpClient>>,
) -> actix_web::Result<(Option<place::object::GooglePlacesSearchResponse>, f64)> {
    let endpoint = std::env::var("GOOGLE_API_NEARBY_SEARCH_ENDPOINT").unwrap();
    let header_field = param.get_header_field();
    let body = param.get_request_paramater();
    let field_mask = param.get_field_mask();
    let header_flow = Box::new(http::object::GooglePlacesHeader::new(field_mask));

    let start = std::time::Instant::now();
    let response = match http_client
        .post(&endpoint, Some(header_field), None, body, Some(header_flow))
        .await
    {
        Ok(response) => response,
        Err(e) => return Err(actix_web::error::ErrorInternalServerError(e)),
    };
    let duration = start.elapsed().as_secs_f64();

    // If status code 200, return response from google places api.
    if response.get_status_code() == 200 {
        let places_data: Option<place::object::GooglePlacesSearchResponse> = response.get_body();
        return Ok((places_data, duration));
    }

    eprintln!("Failed http request: {:?}", response.get_status_code());

    Ok((None, duration))
}

async fn get_nearby_places_from_cache(
    param: &place::object::GooglePlacesNearbySearchParamater,
    cacheids: HashSet<place::object::GooglePlaceSearchPlaceId>,
    cache_worker: &Arc<RwLock<cache::worker::CacheWorker>>,
) -> Vec<place::object::GooglePlacesSearchResponsePlace> {
    let mut handles = Vec::new();
    for id in cacheids {
        let worker_clone = cache_worker.clone();
        let param_clone = param.clone();

        // Get multiple place data in parallel processing.
        let handle = tokio::spawn(async move {
            let worker = worker_clone.read().await;
            get_nearby_place_from_cache(&param_clone, &id, worker)
        });

        handles.push(handle);
    }

    let results: Vec<Option<place::object::GooglePlacesSearchResponsePlace>> =
        futures_util::future::join_all(handles)
            .await
            .into_iter()
            .filter_map(|res| res.ok())
            .collect();

    let places: Vec<place::object::GooglePlacesSearchResponsePlace> =
        results.into_iter().filter_map(|p| p).collect();

    places
}

fn get_nearby_place_from_cache(
    param: &place::object::GooglePlacesNearbySearchParamater,
    cacheid: &place::object::GooglePlaceSearchPlaceId,
    cache_worker: RwLockReadGuard<'_, cache::worker::CacheWorker>,
) -> Option<place::object::GooglePlacesSearchResponsePlace> {
    if let Some(cache) = cache_worker.get(cacheid.make_hash()) {
        // Get cache byte data from cache worker.
        let data_vec = cache.get_data_vec();
        let first_item = data_vec.first().unwrap();
        let cache_bytes = first_item.as_ref().unwrap();
        let place_object: place::object::GooglePlacesSearchResponsePlace =
            serde_json::from_slice(&cache_bytes).ok().unwrap();

        // Check whether to match place type.
        let request_param = param.get_request_paramater();
        let request_place_types: HashSet<place::object::GooglePlaceType> =
            request_param.get_types().into_iter().collect();

        if !request_place_types.is_empty() {
            let place_types: HashSet<place::object::GooglePlaceType> = place_object
                .get_types()
                .unwrap_or_default()
                .into_iter()
                .collect();
            let match_type = request_place_types.iter().any(|t| place_types.contains(t));

            if !match_type {
                return None;
            }
        }
        return Some(place_object);
    }

    return None;
}

pub async fn get_place_detail(
    param: &place::object::GooglePlacesPlaceDetailBodyParamater,
    cache_worker: web::Data<Arc<RwLock<cache::worker::CacheWorker>>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<Vec<place::object::GooglePlacesSearchResponsePlace>> {
    let base_endpoint = std::env::var("GOOGLE_API_PLACE_DETAIL_ENDPOINT").unwrap();
    let field_mask = param.get_field_mask();
    let language_code = param.get_language_code();
    let region_code = param.get_region_code();
    let session_token = param.get_session_token();

    let mut handles = Vec::new();

    for place_id in param.get_place_ids() {
        let cache_worker_clone = cache_worker.clone();
        let http_client_clone = http_client.clone();
        let pg_repository_clone = pg_repository.clone();
        let endpoint = base_endpoint.clone();
        let field_mask_clone = field_mask.clone();
        let language_code_clone = language_code.clone();
        let region_code_clone = region_code.clone();
        let session_token_clone = session_token.clone();

        let handle = tokio::spawn(async move {
            get_single_place_detail(
                place_id,
                endpoint,
                field_mask_clone,
                language_code_clone,
                region_code_clone,
                session_token_clone,
                cache_worker_clone,
                http_client_clone,
                pg_repository_clone,
            )
            .await
        });

        handles.push(handle);
    }

    let results: Vec<Option<place::object::GooglePlacesSearchResponsePlace>> =
        futures_util::future::join_all(handles)
            .await
            .into_iter()
            .filter_map(|res| res.ok())
            .collect();

    let places: Vec<place::object::GooglePlacesSearchResponsePlace> =
        results.into_iter().filter_map(|p| p).collect();

    Ok(places)
}

async fn get_single_place_detail(
    place_id: String,
    base_endpoint: String,
    field_mask: String,
    language_code: Option<String>,
    region_code: Option<String>,
    session_token: Option<String>,
    cache_worker: web::Data<Arc<RwLock<cache::worker::CacheWorker>>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> Option<place::object::GooglePlacesSearchResponsePlace> {
    let placeid_key = place::object::GooglePlaceSearchPlaceId::new(place_id.clone());
    let requested_fields = parse_field_mask(&field_mask);

    // Step 1: Check PostgreSQL metadata
    let metadata = pg_repository
        .get_place_cache_metadata(&place_id)
        .await
        .ok()
        .flatten();

    // Step 2: Check in-memory cache
    let cached_place: Option<place::object::GooglePlacesSearchResponsePlace> = {
        let read_worker = cache_worker.read().await;
        read_worker.get(placeid_key.make_hash()).and_then(|cache| {
            cache
                .get_front_data()
                .and_then(|byte| serde_json::from_slice(&byte).ok())
        })
    };

    // Step 3: Determine fields to fetch
    let (fields_to_fetch, is_incremental) = if let Some(ref meta) = metadata {
        let cached_fields = meta.get_field_masks_set();
        let missing = compute_missing_fields(&requested_fields, &cached_fields);

        if missing.is_empty() && cached_place.is_some() {
            // All fields cached and in-memory - just update access time
            let pg_repo = pg_repository.clone();
            let pid = place_id.clone();
            tokio::spawn(async move {
                let _ = pg_repo.update_place_cache_accessed_at(&pid).await;
            });
            return cached_place;
        }

        if cached_place.is_none() {
            // In-memory evicted - refetch all known fields + missing
            let mut all_fields = cached_fields;
            for f in &requested_fields {
                all_fields.insert(f.clone());
            }
            (all_fields.into_iter().collect::<Vec<_>>().join(","), false)
        } else if !missing.is_empty() {
            // Incremental fetch - only missing fields + id for merging
            let mut fetch_fields: HashSet<String> = missing.into_iter().collect();
            fetch_fields.insert("id".to_string());
            (fetch_fields.into_iter().collect::<Vec<_>>().join(","), true)
        } else {
            (field_mask.clone(), false)
        }
    } else {
        // No metadata - fetch all requested fields
        (field_mask.clone(), false)
    };

    // Step 4: Fetch from Google Places API
    let mut endpoint = base_endpoint;
    endpoint.push_str(&place_id);

    let header_flow = Box::new(http::object::GooglePlacesHeader::new(fields_to_fetch));

    let mut queries: HashMap<String, String> = HashMap::new();
    if let Some(lang) = language_code {
        queries.insert("languageCode".to_string(), lang);
    }
    if let Some(region) = region_code {
        queries.insert("regionCode".to_string(), region);
    }
    if let Some(token) = session_token {
        queries.insert("sessionToken".to_string(), token);
    }

    let response = match http_client
        .get(&endpoint, None, Some(queries), Some(header_flow))
        .await
    {
        Ok(resp) => resp,
        Err(e) => {
            eprintln!("Failed http request for place_id {}: {:?}", place_id, e);
            return cached_place; // Return cached data on error
        }
    };

    if response.get_status_code() != 200 {
        eprintln!(
            "API error for place_id {}: {}",
            place_id,
            response.get_status_code()
        );
        return cached_place;
    }

    let fetched_place: place::object::GooglePlacesSearchResponsePlace = response.get_body()?;

    // Step 5: Merge with existing data if incremental
    let final_place = if is_incremental {
        if let Some(existing) = cached_place {
            merge_place_data(existing, fetched_place)
        } else {
            fetched_place
        }
    } else {
        fetched_place
    };

    // Step 6: Update in-memory cache
    let cache_data =
        cache::object::CacheMultipleData::new(placeid_key.make_hash(), final_place.clone());
    let cache_worker_clone = cache_worker.clone();
    tokio::spawn(async move {
        let write_worker = cache_worker_clone.write().await;
        write_worker.send_put_message(vec![cache_data]).await;
    });

    // Step 7: Update PostgreSQL metadata
    let mut new_metadata =
        metadata.unwrap_or_else(|| db::object::PlaceCacheMetadata::new(place_id.clone(), vec![]));
    new_metadata.merge_fields(&requested_fields);
    new_metadata.update_is_detailed();
    new_metadata.touch();

    let pg_repo = pg_repository.clone();
    tokio::spawn(async move {
        let _ = pg_repo.upsert_place_cache_metadata(&new_metadata).await;
    });

    Some(final_place)
}

pub async fn search_nearby_transports(
    param: place::object::GooglePlacesNearbySearchParamater,
    cache_worker: web::Data<Arc<RwLock<cache::worker::CacheWorker>>>,
    quad_tree: web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
) -> actix_web::Result<(
    Option<Vec<place::object::GooglePlacesSearchResponsePlace>>,
    place::object::SearchMetrics,
)> {
    // Check whether exist nearest transports from location where contained request paramater.

    // At first, compute optimize zoom level.
    let circle = param.get_request_paramater().get_restriction().get_circle();
    let radius = circle.radius;
    let center = circle.get_center();
    let zoom = place::metrics::compute_zoom_level(radius, center.latitude);

    // Compute ground resolution and radius in optimized zoom level
    let gr = place::metrics::compute_ground_resolution(center.latitude, zoom);
    let edge_length = radius / gr;

    // Compute world coordinate of four edges.
    let (x, y) =
        place::metrics::compute_pixel_coordinate(center.longitude, center.latitude, zoom as usize);
    let (tl_x, tl_y) = ((x - edge_length).max(0.0), (y - edge_length).max(0.0));
    let (tr_x, tr_y) = (x + edge_length, (y - edge_length).max(0.0));
    let (bl_x, bl_y) = ((x - edge_length).max(0.0), y + edge_length);
    let (br_x, br_y) = (x + edge_length, y + edge_length);

    // Compute coordinate of four eges.
    let (tl_lon, tl_lat) = place::metrics::compute_coordinate(tl_x, tl_y, zoom as usize);
    let (tr_lon, tr_lat) = place::metrics::compute_coordinate(tr_x, tr_y, zoom as usize);
    let (bl_lon, bl_lat) = place::metrics::compute_coordinate(bl_x, bl_y, zoom as usize);
    let (br_lon, br_lat) = place::metrics::compute_coordinate(br_x, br_y, zoom as usize);

    let coordinates = vec![
        (tl_lon, tl_lat),
        (tr_lon, tr_lat),
        (bl_lon, bl_lat),
        (br_lon, br_lat),
    ];

    // Try get cache.
    let mut cacheids: HashSet<place::object::GooglePlaceSearchPlaceId> = HashSet::new();
    let place_types = param.get_request_paramater().get_types();

    {
        let quad_tree_read = quad_tree.read().await;
        for (lon, lat) in coordinates.iter() {
            let quadkeys = place::metrics::compute_quadkeys(*lon, *lat, zoom as usize);
            let (prefix_key, _) = quadkeys.split_at(std::cmp::min(10, quadkeys.len()));
            if let Some(placeids) = quad_tree_read.get(prefix_key.to_string(), Some(&place_types)) {
                cacheids.extend(placeids);
            }
        }
    }

    let mut cache_places = get_nearby_places_from_cache(&param, cacheids, &cache_worker).await;

    // If exist cache data of nearest transports, return it.
    if cache_places.len() >= 10 {
        let count = cache_places.len();
        cache_places.truncate(10);
        return Ok((
            Some(cache_places),
            place::object::SearchMetrics {
                is_hit: true,
                upstream_response_time: None,
                result_count: count,
            },
        ));
    }

    // If doesn't exist cache data, nearby search request.
    if let Ok((Some(response), duration)) = fetch_nearby_places_data(&param, http_client).await {
        let response_clone = response.clone();

        put_cache_worker(response, zoom as usize, cache_worker, quad_tree);

        if let Some(mut places) = response_clone.get_places() {
            let count = places.len();
            places.truncate(10);
            return Ok((
                Some(places),
                place::object::SearchMetrics {
                    is_hit: false,
                    upstream_response_time: Some(duration),
                    result_count: count,
                },
            ));
        }
        return Ok((
            None,
            place::object::SearchMetrics {
                is_hit: false,
                upstream_response_time: Some(duration),
                result_count: 0,
            },
        ));
    }

    Ok((
        None,
        place::object::SearchMetrics {
            is_hit: false,
            upstream_response_time: None,
            result_count: 0,
        },
    ))
}

fn put_cache_worker(
    response: place::object::GooglePlacesSearchResponse,
    zoom: usize,
    cache_worker: web::Data<Arc<RwLock<cache::worker::CacheWorker>>>,
    quad_tree: web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
) {
    let cache_worker_inner = cache_worker.clone();
    let quad_tree_inner = quad_tree.clone();

    tokio::spawn(async move {
        // Save place data in cache worker.
        if let Some(places) = response.get_places() {
            let worker_read = cache_worker_inner.read().await;
            let caches: Vec<cache::object::CacheMultipleData> = places
                .iter()
                .map(|p| {
                    let placeid_key =
                        place::object::GooglePlaceSearchPlaceId::new(p.get_place_id().unwrap());
                    return cache::object::CacheMultipleData::new(
                        placeid_key.make_hash(),
                        p.clone(),
                    );
                })
                .collect();

            worker_read.send_put_message(caches).await;
        }

        // Save place ids in quad node tree.
        if let Some(places) = response.get_places() {
            let quad_tree_read = quad_tree_inner.read().await;
            quad_tree_read.send_insert_event(places, zoom).await;
        }
    });
}

/// Calls Google Places Text Search API with FieldMask="places.id" and page_size=20
/// to obtain only place IDs at minimal cost.
async fn fetch_ids_only_from_google(
    param: &place::object::GooglePlacesTextSearchRequestParamater,
    http_client: &web::Data<Arc<http::request::HttpClient>>,
) -> (Vec<String>, f64) {
    let endpoint = std::env::var("GOOGLE_API_TEXT_SEARCH_ENDPOINT").unwrap();
    let id_only_param = param.to_id_only_param();
    let header_flow = Box::new(http::object::GooglePlacesHeader::new(
        "places.id".to_string(),
    ));

    let start = std::time::Instant::now();
    let response = match http_client
        .post(&endpoint, None, None, id_only_param, Some(header_flow))
        .await
    {
        Ok(response) => response,
        Err(e) => {
            eprintln!("Failed to fetch IDs from Google: {:?}", e);
            return (Vec::new(), start.elapsed().as_secs_f64());
        }
    };
    let duration = start.elapsed().as_secs_f64();

    if response.get_status_code() == 200 {
        if let Some(text_response) =
            response.get_body::<place::object::GooglePlacesTextSearchResponse>()
        {
            if let Some(places) = text_response.places {
                return (
                    places
                        .into_iter()
                        .filter_map(|p| p.get_place_id())
                        .collect(),
                    duration,
                );
            }
        }
    }

    (Vec::new(), duration)
}

/// Checks whether a place exists in cache and satisfies the requested field mask and type filter.
/// Similar to the cache validation pattern used in `get_place_detail`.
fn get_text_search_place_from_cache(
    place_id: &str,
    cache_worker: tokio::sync::RwLockReadGuard<'_, cache::worker::CacheWorker>,
    mask: &place::object::FieldMask,
    type_filter: Option<&str>,
) -> Option<place::object::GooglePlacesSearchResponsePlace> {
    let placeid_key = place::object::GooglePlaceSearchPlaceId::new(place_id.to_string());
    let cache = cache_worker.get(placeid_key.make_hash())?;
    let data = cache.get_front_data()?;
    let place: place::object::GooglePlacesSearchResponsePlace =
        serde_json::from_slice(&data).ok()?;

    // Check field mask compatibility
    if !place.is_cache_compatible(mask) {
        return None;
    }

    // Check type filter
    if let Some(tf) = type_filter {
        if let Some(types) = place.get_raw_types() {
            if !types.iter().any(|t| t == tf) {
                return None;
            }
        } else {
            return None;
        }
    }

    Some(place)
}

pub async fn text_search(
    param: place::object::GooglePlacesTextSearchParamater,
    cache_worker: web::Data<Arc<RwLock<cache::worker::CacheWorker>>>,
    quad_tree: web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
) -> actix_web::Result<(
    Option<Vec<GooglePlacesSearchResponsePlace>>,
    place::object::SearchMetrics,
)> {
    let field_mask = param.get_field_mask();
    let request_param = param.get_request_paramater();
    let mask = place::object::FieldMask::from_text_search_mask(&field_mask);
    let type_filter = request_param.get_included_type().map(|s| s.to_string());
    let place_type: Vec<place::object::GooglePlaceType> =
        request_param.get_included_type().into_iter().collect();

    // ── Phase 1: Geo-Cache (only if location_bias present) ──
    if let Some(location_bias) = request_param.get_location_bias() {
        if let Some(circle) = location_bias.get_circle() {
            let center = circle.get_center();
            let radius = circle.radius;
            let zoom = place::metrics::compute_zoom_level(radius, center.latitude);
            let zoom_usize = zoom as usize;

            let gr = place::metrics::compute_ground_resolution(center.latitude, zoom);
            let edge_length = radius / gr;

            let (x, y) = place::metrics::compute_pixel_coordinate(
                center.longitude,
                center.latitude,
                zoom_usize,
            );

            let corners = [
                ((x - edge_length).max(0.0), (y - edge_length).max(0.0)),
                (x + edge_length, (y - edge_length).max(0.0)),
                ((x - edge_length).max(0.0), y + edge_length),
                (x + edge_length, y + edge_length),
            ];

            let mut cacheids: HashSet<place::object::GooglePlaceSearchPlaceId> = HashSet::new();
            {
                let quad_tree_read = quad_tree.read().await;
                for (px, py) in corners.iter() {
                    let (lon, lat) = place::metrics::compute_coordinate(*px, *py, zoom_usize);
                    let quadkeys = place::metrics::compute_quadkeys(lon, lat, zoom_usize);
                    let (prefix_key, _) = quadkeys.split_at(std::cmp::min(10, quadkeys.len()));
                    if let Some(placeids) =
                        quad_tree_read.get(prefix_key.to_string(), Some(&place_type))
                    {
                        for id in placeids {
                            cacheids.insert(id);
                        }
                    }
                }
            }

            if !cacheids.is_empty() {
                let mut handles = Vec::new();
                for id in cacheids {
                    let worker_clone = cache_worker.clone();
                    let mask_clone = mask.clone();
                    let type_filter_clone = type_filter.clone();
                    let id_clone = id.as_str().to_string();

                    let handle = tokio::spawn(async move {
                        let worker = worker_clone.read().await;
                        get_text_search_place_from_cache(
                            &id_clone,
                            worker,
                            &mask_clone,
                            type_filter_clone.as_deref(),
                        )
                    });
                    handles.push(handle);
                }

                let mut places: Vec<GooglePlacesSearchResponsePlace> =
                    futures_util::future::join_all(handles)
                        .await
                        .into_iter()
                        .filter_map(|res| res.ok())
                        .filter_map(|p| p)
                        .collect();

                if !places.is_empty() {
                    let page_size =
                        param.get_request_paramater().get_page_size().unwrap_or(20) as usize;
                    let count = places.len();
                    places.truncate(page_size);
                    return Ok((
                        Some(places),
                        place::object::SearchMetrics {
                            is_hit: true,
                            upstream_response_time: None,
                            result_count: count,
                        },
                    ));
                }
            }
        }
    }

    // ── Phase 2: ID-first Cache Lookup (cost-saver) ──
    let (ids, duration_id) = fetch_ids_only_from_google(&request_param, &http_client).await;
    if !ids.is_empty() {
        let mut handles = Vec::new();

        for id in ids.iter() {
            let worker_clone = cache_worker.clone();
            let mask_clone = mask.clone();
            let type_filter_clone = type_filter.clone();
            let id_clone = id.clone();

            let handle = tokio::spawn(async move {
                let worker = worker_clone.read().await;
                get_text_search_place_from_cache(
                    &id_clone,
                    worker,
                    &mask_clone,
                    type_filter_clone.as_deref(),
                )
            });

            handles.push(handle);
        }

        let results: Vec<Option<GooglePlacesSearchResponsePlace>> =
            futures_util::future::join_all(handles)
                .await
                .into_iter()
                .filter_map(|res| res.ok())
                .collect();

        let mut cached_places: Vec<GooglePlacesSearchResponsePlace> =
            results.into_iter().filter_map(|p| p).collect();

        if cached_places.len() >= 10 {
            let count = cached_places.len();
            cached_places.truncate(20);
            return Ok((
                Some(cached_places),
                place::object::SearchMetrics {
                    is_hit: false,
                    upstream_response_time: Some(duration_id),
                    result_count: count,
                },
            ));
        }
    }

    // ── Phase 3: Full API Fallback ──
    let endpoint = std::env::var("GOOGLE_API_TEXT_SEARCH_ENDPOINT").unwrap();
    let header_flow = Box::new(http::object::GooglePlacesHeader::new(field_mask));

    let start = std::time::Instant::now();
    let response = http_client
        .post(&endpoint, None, None, request_param, Some(header_flow))
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;
    let duration_full = start.elapsed().as_secs_f64();

    if response.get_status_code() == 200 {
        let response_obj: place::object::GooglePlacesTextSearchResponse =
            response.get_body().unwrap();

        if let Some(ref places) = response_obj.places {
            // Cache results in background.
            let count = places.len();
            let places_to_cache = places.clone();
            let cache_worker_clone = cache_worker.clone();
            let quad_tree_clone = quad_tree.clone();

            tokio::spawn(async move {
                // Insert into W-TinyLFU cache.
                let worker_read = cache_worker_clone.read().await;
                let caches: Vec<cache::object::CacheMultipleData> = places_to_cache
                    .iter()
                    .filter_map(|p| {
                        let place_id = p.get_place_id()?;
                        let placeid_key = place::object::GooglePlaceSearchPlaceId::new(place_id);
                        Some(cache::object::CacheMultipleData::new(
                            placeid_key.make_hash(),
                            p.clone(),
                        ))
                    })
                    .collect();
                worker_read.send_put_message(caches).await;

                // Insert into QuadTree for places that have location data.
                let places_with_location: Vec<GooglePlacesSearchResponsePlace> = places_to_cache
                    .into_iter()
                    .filter(|p| p.get_latlng().is_some())
                    .collect();
                if !places_with_location.is_empty() {
                    let quad_tree_read = quad_tree_clone.read().await;
                    quad_tree_read
                        .send_insert_event(places_with_location, 18)
                        .await;
                }
            });

            let mut result_places = places.clone();
            result_places.truncate(10);
            return Ok((
                Some(result_places),
                place::object::SearchMetrics {
                    is_hit: false,
                    upstream_response_time: Some(duration_full),
                    result_count: count,
                },
            ));
        }

        return Ok((
            response_obj.places,
            place::object::SearchMetrics {
                is_hit: false,
                upstream_response_time: Some(duration_full),
                result_count: 0,
            },
        ));
    }

    Ok((
        None,
        place::object::SearchMetrics {
            is_hit: false,
            upstream_response_time: Some(duration_full),
            result_count: 0,
        },
    ))
}

pub async fn select_random_popular_spots(
    latitude: f64,
    longitude: f64,
    radius: f64,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    cache_worker: web::Data<Arc<RwLock<cache::worker::CacheWorker>>>,
    quad_tree: web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
) -> actix_web::Result<Vec<String>> {
    let included_types = vec!["restaurant".to_string(), "cafe".to_string(), "bar".to_string()];
    let field_mask = "places.id".to_string();

    let client_param = place::object::PlaceSearchClientParamater {
        latitude,
        longitude,
        window_width: 0.0,
        window_height: 0.0,
        map_zoom_level: 12,
        result_offset: 0,
        result_limit: 20,
    };

    let body_param = place::object::GooglePlacesNearbySearchBodyParamater::new(
        Some(included_types),
        Some(20),
        Some("POPULARITY".to_string()),
        latitude,
        longitude,
        radius,
    );

    let nearby_param = place::object::GooglePlacesNearbySearchParamater::new(
        body_param,
        field_mask,
        client_param,
    );

    let (places, _metrics) = nearby_search(nearby_param, cache_worker, quad_tree, http_client).await?;

    let mut place_ids: Vec<String> = places
        .unwrap_or_default()
        .iter()
        .filter_map(|p| p.get_place_id())
        .collect();

    if place_ids.len() > 4 {
        fastrand::shuffle(&mut place_ids);
        place_ids.truncate(4);
    }

    Ok(place_ids)
}
