mod auth;
mod cache;
mod db;
mod http;
mod models;
mod nlp;
mod notification;
mod place;
mod recruitment;
mod s3;
mod scheduler;
mod sns;
mod user;
mod utils;
mod vision;
mod voice_chat;

use std::sync::Arc;
use tokio::sync::RwLock;

use actix_web::{get, post, web};
use dotenv;
use std::io;

use crate::auth::session;
use crate::models::auth::Session;

#[get("/api/health")]
async fn health_check() -> impl actix_web::Responder {
    actix_web::HttpResponse::Ok()
}

#[post("/api/voice_chat/leave_event")]
async fn leave_voice_chat_event(
    req: actix_web::HttpRequest,
    body: web::Json<voice_chat::object::WaitingUser>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    waiting_queue: web::Data<Arc<RwLock<voice_chat::waiting::WaitingQueue>>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verification_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized users.",
            ));
        }
    };

    if verification_user_id != body.0.user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match request user.",
        ));
    }

    voice_chat::event::delete_voice_chat_user(&body.0, waiting_queue).await;

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/voice_chat/join_event")]
async fn join_voice_chat_event(
    req: actix_web::HttpRequest,
    body: web::Json<voice_chat::object::WaitingUser>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
    waiting_queue: web::Data<Arc<RwLock<voice_chat::waiting::WaitingQueue>>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verification_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized users.",
            ));
        }
    };

    if verification_user_id != body.0.user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match request user.",
        ));
    }

    println!(
        "ℹ️ [{:?}] user {} is joining voice chat event.",
        chrono::Utc::now(),
        body.0.user_id
    );

    let partner = voice_chat::event::enter_voice_chat_user(&body.0, waiting_queue).await;

    if let Some(partner) = partner {
        println!(
            "✅ [{:?}] matched user {} with partner {}.",
            chrono::Utc::now(),
            body.0.user_id,
            partner.user_id
        );

        let call_id = uuid::Uuid::new_v4().to_string();

        // Notify current user (caller)
        if let Err(e) = notification::voice_chat::send_voice_chat_matched_notification(
            http_client.clone(),
            postgrest_client.clone(),
            body.0.user_id,
            partner.user_id,
            &call_id,
            "caller",
        )
        .await
        {
            tracing::error!("Failed to send matched notification to caller: {}", e);
        }

        // Notify partner (callee)
        if let Err(e) = notification::voice_chat::send_voice_chat_matched_notification(
            http_client.clone(),
            postgrest_client.clone(),
            partner.user_id,
            body.0.user_id,
            &call_id,
            "callee",
        )
        .await
        {
            tracing::error!("Failed to send matched notification to callee: {}", e);
        }
    } else {
        println!(
            "⏳ [{:?}] user {} is now waiting in the queue.",
            chrono::Utc::now(),
            body.0.user_id
        );
    }

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[get("/api/voice_chat/start_event")]
async fn start_voice_chat_event(
    req: actix_web::HttpRequest,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    scheduler: web::Data<Arc<scheduler::event::AmazonEventScheduleManager>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    // Basic service-role check (for Lambda/Event Bridge)
    let token = req
        .headers()
        .get(actix_web::http::header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.strip_prefix("Bearer "))
        .map(str::trim);

    if let Some(t) = token {
        if let Ok(service_role_key) = std::env::var("SUPABASE_SERVICE_ROLE_KEY") {
            if t != service_role_key {
                return Err(actix_web::error::ErrorUnauthorized(
                    "Unauthorized access to event api",
                ));
            }
        } else {
            return Err(actix_web::error::ErrorInternalServerError(
                "Missing service role key",
            ));
        }
    } else {
        return Err(actix_web::error::ErrorUnauthorized(
            "Unauthorized access to event api",
        ));
    }

    // Broadcast notification to all users
    if let Err(e) = notification::voice_chat::broadcast_voice_chat_event_started(
        http_client.clone(),
        postgrest_client.clone(),
    )
    .await
    {
        tracing::error!("Failed to broadcast voice chat event notification: {}", e);
    }

    // Set finish voice chat event (3:00 AM JST)
    if let Err(e) = scheduler.update_voice_chat_aggregation_scheduler().await {
        tracing::error!("Failed to schedule next voice chat aggregation: {}", e);
    }

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[get("/api/voice_chat/make_event")]
async fn make_voice_chat_event(
    req: actix_web::HttpRequest,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
    quad_tree: web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
    cache_worker: web::Data<Arc<RwLock<cache::worker::CacheWorker>>>,
    waiting_queue: web::Data<Arc<RwLock<voice_chat::waiting::WaitingQueue>>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    // Basic service-role check (for Lambda/Event Bridge)
    let token = req
        .headers()
        .get(actix_web::http::header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.strip_prefix("Bearer "))
        .map(str::trim);

    if let Some(t) = token {
        if let Ok(service_role_key) = std::env::var("SUPABASE_SERVICE_ROLE_KEY") {
            if t != service_role_key {
                return Err(actix_web::error::ErrorUnauthorized(
                    "Unauthorized access to event api",
                ));
            }
        } else {
            return Err(actix_web::error::ErrorInternalServerError(
                "Missing service role key",
            ));
        }
    } else {
        return Err(actix_web::error::ErrorUnauthorized(
            "Unauthorized access to event api",
        ));
    }

    // Parameters for Tokyo Station
    let latitude = 35.681236;
    let longitude = 139.767125;
    let radius = 1000.0;

    let place_ids = place::search::select_random_popular_spots(
        latitude,
        longitude,
        radius,
        http_client,
        cache_worker,
        quad_tree,
    )
    .await?;

    if !place_ids.is_empty() {
        let expires_at = chrono::Utc::now() + chrono::Duration::hours(24);
        let record = db::object::VoiceChatEvent::new(
            place_ids.clone(),
            Some(expires_at),
            Some("voting".to_string()),
        );

        {
            let mut queue = waiting_queue.write().await;
            queue.set_placeids(&place_ids);
        }

        postgrest_client
            .insert_voice_chat_event(record)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;
    }

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/voice_chat/send_call_message")]
async fn send_call_message(
    req: actix_web::HttpRequest,
    body: web::Json<sns::object::CallObject>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    sns_voip_manager: web::Data<Arc<sns::voip::SnsVoIPManager>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verification_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized users.",
            ));
        }
    };

    if verification_user_id != body.0.user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match request user.",
        ));
    }

    sns_voip_manager
        .send_call_message(&body.0.payload)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/voice_chat/fetch_voice_chat_rooms")]
async fn fetch_voice_chat_rooms(
    req: actix_web::HttpRequest,
    body: web::Json<voice_chat::object::FetchVoiceChatRoomParamater>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verification_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized users.",
            ));
        }
    };

    if verification_user_id != body.0.user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match request user.",
        ));
    }

    let voice_chat_rooms = voice_chat::fetcher::fetch_voice_chat_room(&body.0, postgrest_client)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().json(voice_chat_rooms))
}

#[post("/api/sns/voip/regist_voip_device")]
async fn regist_voip_device(
    req: actix_web::HttpRequest,
    body: web::Json<sns::object::DeviceToken>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    sns_voip_manager: web::Data<Arc<sns::voip::SnsVoIPManager>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verification_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized users.",
            ));
        }
    };

    if verification_user_id != body.0.user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match request user.",
        ));
    }

    sns_voip_manager
        .regist_voip_device(&body.0)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/user/make_voice_chat_room")]
async fn make_voice_chat_room(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::VoiceChatRoom>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgres_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verification_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized users.",
            ));
        }
    };

    if verification_user_id != body.0.user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match request user.",
        ));
    }

    postgres_client
        .insert_voice_chat_room_record(&body.0)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/user/blocking_user")]
async fn blocking_user(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::BlockedUser>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgres_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verification_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized users.",
            ));
        }
    };

    if verification_user_id != body.0.user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match request user.",
        ));
    }

    postgres_client
        .insert_blocked_user(&body.0)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/user/make_chatroom")]
async fn make_chatroom(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::ChatRoom>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verified_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
    };

    // Verify that the authenticated user is the one creating the chatroom
    if verified_user_id != body.0.from_user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match the chatroom creator.",
        ));
    }

    // Check if the `to_user_id` and `from_user_id` pair exists (reverse relationship).
    // This verifies that the other user has already liked the authenticated user.
    let like_pair = postgrest_client
        .exist_like_pair(&body.0)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    let mut like_pair = match like_pair {
        Some(pair) => pair,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized valid user from client request.",
            ));
        }
    };

    // Update the matched flag on the correct like pair
    like_pair.matched = true;
    postgrest_client
        .upsert_like_pair(&like_pair)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    // Insert chat room
    postgrest_client
        .insert_chat_room(&body.0)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    // Insert match pair
    postgrest_client
        .insert_match_pair(&body.0)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    // Send match notification to the to_user_id.
    // Notification failure is non-fatal — the chatroom and match pair are already persisted.
    if let Err(e) =
        notification::chat::send_match_notification(&body.0, &http_client, &postgrest_client).await
    {
        tracing::error!("Failed to send match notification: {}", e);
    }

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/user/send_message")]
async fn send_message(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::ChatMessage>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verified_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
    };

    // Verify that the authenticated user is the message sender
    if verified_user_id != body.0.from_user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match the message sender.",
        ));
    }

    // Update talk count in talk room.
    postgrest_client
        .update_talk_count(&body.0)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    // Insert chat message into Supabase
    postgrest_client
        .insert_chat_message(&body.0)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    // Send notification to the recipient (to_user_id).
    // Notification failure is non-fatal — the message is already persisted.
    if let Err(e) =
        notification::chat::send_message_notification(&body.0, &http_client, &postgrest_client)
            .await
    {
        tracing::error!("Failed to send message notification: {}", e);
    }

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/user/send_like")]
async fn send_like(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::LikePair>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    if verification_result.is_none() {
        return Err(actix_web::error::ErrorUnauthorized(
            "client is not recognized legitimate user.",
        ));
    }

    notification::like::send_like(body.0, http_client.clone(), postgrest_client.clone())
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/user/post_chat_room_report")]
async fn post_chat_room_report(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::ChatRoomReport>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    println!(
        "ℹ️ [{:?}] received request for post chat room report.",
        chrono::Utc::now()
    );
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => {
            println!("❌ User verification error: {:?}", auth_err);
            return Err(actix_web::error::ErrorInternalServerError(auth_err));
        }
    };

    let verified_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            println!("❌ User verification failed: client is not recognized legitimate user.");
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
    };
    println!("ℹ️ Verified user_id: {}", verified_user_id);

    if verified_user_id != body.0.report_user_id.to_string() {
        println!(
            "❌ User ID mismatch: verified_user_id={}, report_user_id={}",
            verified_user_id, body.0.report_user_id
        );
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match request user.",
        ));
    }

    println!(
        "ℹ️ Inserting chat room report for room_id: {}",
        body.0.room_id
    );
    pg_repository
        .insert_chat_room_report(&body.0)
        .await
        .map_err(|e| {
            println!("❌ Failed to insert chat room report: {}", e);
            actix_web::error::ErrorInternalServerError(e)
        })?;

    println!("✅ Successfully posted chat room report.");
    Ok(actix_web::HttpResponse::Ok().finish())
}

#[get("/api/user/get_reported_room_ids")]
async fn get_reported_room_ids(
    req: actix_web::HttpRequest,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verified_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
    };

    let user_uuid = uuid::Uuid::parse_str(&verified_user_id)
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    let room_ids = pg_repository
        .fetch_reported_room_ids(user_uuid)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().json(room_ids))
}

#[post("/api/user/update_user_profile")]
async fn update_user_profile(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::RapidUser>,
    auth_session: web::Data<session::AuthSession>,
    nlp_client: web::Data<Arc<nlp::client::NLPClient>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verified_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
    };

    if verified_user_id != body.0.user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match request user.",
        ));
    }

    user::profile::update_user_profile(&body.0, nlp_client, http_client, postgrest_client)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/user/upload_profile")]
async fn upload_profile(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::UploadProfileMetaData>,
    auth_session: web::Data<session::AuthSession>,
    nlp_client: web::Data<Arc<nlp::client::NLPClient>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verified_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
    };

    if verified_user_id != body.0.user.user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match request user.",
        ));
    }

    user::profile::upload_profile(&body.0, nlp_client, http_client, postgrest_client)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/user/post_inquiry_message")]
async fn post_inquiry_message(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::InquiryMessage>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verified_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
    };

    if verified_user_id != body.0.user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match request user.",
        ));
    }

    pg_repository
        .insert_inquiry_message(&body.0)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/fcm/regist")]
async fn regist_fcm(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::FcmPayload>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    println!(
        "ℹ️ [{:?}] received request for regist fcm payload.",
        chrono::Utc::now()
    );
    let user_id = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(Some(user_id)) => user_id,
        Ok(None) => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };
    println!("ℹ️ Successfully user authentication for regist fcm payload.");

    postgrest_client
        .upsert_fcm_token(user_id, &body.0)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    println!("✅ Successfully completed registration of fcm payload.");

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/nearby_search")]
async fn nearby_search(
    req: actix_web::HttpRequest,
    body: web::Json<place::object::GooglePlacesNearbySearchParamater>,
    cache_worker: web::Data<Arc<RwLock<cache::worker::CacheWorker>>>,
    quad_tree: web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    // User verification
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    if verification_result.is_none() {
        return Err(actix_web::error::ErrorUnauthorized(
            "client is not recognized legitimate user.",
        ));
    }

    // Execute nearby search.
    let start = std::time::Instant::now();
    let query_params = serde_json::to_value(&body.0).ok();
    let (resp_field, metrics) =
        place::search::nearby_search(body.0, cache_worker, quad_tree, http_client)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;
    let total_duration = start.elapsed().as_secs_f64();

    // Log metrics
    let pg_repo = pg_repository.clone();
    let verified_user_id = uuid::Uuid::parse_str(&verification_result.unwrap()).unwrap();
    tokio::spawn(async move {
        let log = db::object::PlaceSearchCacheHitLog::new(
            Some(verified_user_id),
            metrics.is_hit,
            "nearby_search".to_string(),
            None,
            total_duration,
            metrics.upstream_response_time,
            Some(metrics.result_count as i32),
            query_params,
        );
        let _ = pg_repo.insert_place_search_cache_hit_log(&log).await;
    });

    Ok(actix_web::HttpResponse::Ok().json(resp_field))
}

#[post("/api/text_search")]
async fn text_search(
    req: actix_web::HttpRequest,
    body: web::Json<place::object::GooglePlacesTextSearchParamater>,
    cache_worker: web::Data<Arc<RwLock<cache::worker::CacheWorker>>>,
    quad_tree: web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    // User verification
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    if verification_result.is_none() {
        return Err(actix_web::error::ErrorUnauthorized(
            "client is not recognized legitimate user.",
        ));
    }

    let start = std::time::Instant::now();
    let query_params = serde_json::to_value(&body.0).ok();
    let (places, metrics) =
        place::search::text_search(body.0, cache_worker, quad_tree, http_client)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;
    let total_duration = start.elapsed().as_secs_f64();

    // Log metrics
    let pg_repo = pg_repository.clone();
    let verified_user_id = uuid::Uuid::parse_str(&verification_result.unwrap()).unwrap();
    tokio::spawn(async move {
        let log = db::object::PlaceSearchCacheHitLog::new(
            Some(verified_user_id),
            metrics.is_hit,
            "text_search".to_string(),
            None,
            total_duration,
            metrics.upstream_response_time,
            Some(metrics.result_count as i32),
            query_params,
        );
        let _ = pg_repo.insert_place_search_cache_hit_log(&log).await;
    });

    Ok(actix_web::HttpResponse::Ok().json(places))
}

#[post("/api/search_nearby_transports")]
async fn search_nearby_transports(
    req: actix_web::HttpRequest,
    body: web::Json<place::object::GooglePlacesNearbySearchParamater>,
    cache_worker: web::Data<Arc<RwLock<cache::worker::CacheWorker>>>,
    quad_tree: web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    // User verification
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    if verification_result.is_none() {
        return Err(actix_web::error::ErrorUnauthorized(
            "client is not recognized legitimate user.",
        ));
    }

    let start = std::time::Instant::now();
    let query_params = serde_json::to_value(&body.0).ok();
    let (resp_field, metrics) =
        place::search::search_nearby_transports(body.0, cache_worker, quad_tree, http_client)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;
    let total_duration = start.elapsed().as_secs_f64();

    // Log metrics
    let pg_repo = pg_repository.clone();
    let verified_user_id = uuid::Uuid::parse_str(&verification_result.unwrap()).unwrap();
    tokio::spawn(async move {
        let log = db::object::PlaceSearchCacheHitLog::new(
            Some(verified_user_id),
            metrics.is_hit,
            "nearby_transports".to_string(),
            None,
            total_duration,
            metrics.upstream_response_time,
            Some(metrics.result_count as i32),
            query_params,
        );
        let _ = pg_repo.insert_place_search_cache_hit_log(&log).await;
    });

    Ok(actix_web::HttpResponse::Ok().json(resp_field))
}

#[post("/api/fetch_recruitment")]
async fn fetch_recruitment(
    req: actix_web::HttpRequest,
    body: web::Json<recruitment::objects::FetchRecruitmentRequestParamater>,
    quad_tree: web::Data<Arc<RwLock<place::trie::QuadNodeTrieTree>>>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    // User verification
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verified_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
    };

    if verified_user_id != body.user_id.to_string() {
        return Err(actix_web::error::ErrorUnauthorized(
            "client is not recognized legitimate user.",
        ));
    }

    // Fetch recruitment data with nested joins from Supabase.
    let recruitments =
        recruitment::fetch::fetch_recruitment(&body.0, quad_tree, http_client, postgrest_client)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().json(recruitments))
}

#[post("/api/post_recruitment")]
async fn post_recruitment(
    req: actix_web::HttpRequest,
    body: web::Json<recruitment::objects::PostRecruitmentRequest>,
    auth_session: web::Data<session::AuthSession>,
    nlp_client: web::Data<Arc<nlp::client::NLPClient>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    // User verification
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verified_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
    };

    let request_user_id = match body.recruitment.user_id {
        Some(id) => id.to_string(),
        None => {
            return Err(actix_web::error::ErrorBadRequest(
                "user_id is required in recruitment data.",
            ));
        }
    };

    if verified_user_id != request_user_id {
        return Err(actix_web::error::ErrorUnauthorized(
            "authenticated user does not match request user.",
        ));
    }

    // Insert recruitment and related data with moderation
    recruitment::post::post_recruitment(body.0, nlp_client, http_client, postgrest_client)
        .await
        .map_err(|e| actix_web::error::ErrorBadRequest(e))?;

    println!(
        "✅ Successfully posted recruitment for user: {}",
        verified_user_id
    );

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/get_place_details")]
async fn get_place_details(
    req: actix_web::HttpRequest,
    body: web::Json<place::object::GooglePlacesPlaceDetailBodyParamater>,
    cache_worker: web::Data<Arc<RwLock<cache::worker::CacheWorker>>>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    // User verification
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    if verification_result.is_none() {
        return Err(actix_web::error::ErrorUnauthorized(
            "client is not recognized legitimate user.",
        ));
    }

    // Execute fetch places details.
    let place_details =
        place::search::get_place_detail(&body.0, cache_worker, http_client, pg_repository)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().json(place_details))
}

#[post("/api/user/verification")]
async fn user_verification(
    req: actix_web::HttpRequest,
    session: web::Json<Session>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
) -> actix_web::Result<impl actix_web::Responder, actix_web::Error> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client)
        .await
    {
        Ok(result) => result,
        Err(e) => return Err(actix_web::error::ErrorInternalServerError(e)),
    };

    if verification_result.is_none() {
        return Err(actix_web::error::ErrorUnauthorized(
            "client is not recognized legitimate user.",
        ));
    }

    match session::inquiry_session(&session, pg_repository).await {
        Ok(identity) => {
            if let Some(identity) = identity {
                Ok(actix_web::HttpResponse::Ok().json(identity))
            } else {
                return Ok(actix_web::HttpResponse::Ok().finish());
            }
        }
        Err(err) => Err(err),
    }
}

#[post("/api/user/upload_profile_image_metadata")]
async fn upload_profile_image_metadata(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::UploadProfileImageMetaDataRequest>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    println!("📝 [API] Request: upload_profile_image_metadata");
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => {
            println!(
                "❌ [API] Auth error in upload_profile_image_metadata: {:?}",
                auth_err
            );
            return Err(actix_web::error::ErrorInternalServerError(auth_err));
        }
    };

    let verified_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            println!("❌ [API] Unauthorized upload_profile_image_metadata");
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
    };

    println!(
        "👤 [API] Verified user for profile image metadata: {}",
        verified_user_id
    );

    let user_uuid = uuid::Uuid::parse_str(&verified_user_id)
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    for meta in &body.metadata {
        println!(
            "📝 [API] Inserting metadata: new_image_id={}, old_image_id={:?}",
            meta.new_image_id, meta.old_image_id
        );
        pg_repository
            .insert_profile_image_upload_metadata(user_uuid, meta)
            .await
            .map_err(|e| {
                println!("❌ [DB] Failed to insert profile image metadata: {:?}", e);
                actix_web::error::ErrorInternalServerError(e)
            })?;
    }

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[post("/api/user/upload_identity_verification_metadata")]
async fn upload_identity_verification_metadata(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::UploadIdentityVerificationMetaDataRequest>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    println!("🔍 [API] Request: upload_identity_verification_metadata");
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let verified_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
    };

    let user_uuid = uuid::Uuid::parse_str(&verified_user_id)
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    println!(
        "📝 [API] Inserting identity metadata for user_id={}",
        user_uuid
    );
    pg_repository
        .insert_identity_verification_metadata(user_uuid, &body.metadata)
        .await
        .map_err(|e| {
            println!(
                "❌ [DB] Failed to insert identity verification metadata: {:?}",
                e
            );
            actix_web::error::ErrorInternalServerError(e)
        })?;

    println!("📝 [API] Updating identity verification status to 'authenticating'");
    postgrest_client
        .update_user_identity_verification_status(&user_uuid, false, Some("authenticating"))
        .await
        .map_err(|e| {
            println!(
                "❌ [API] Failed to update user identity verification status: {:?}",
                e
            );
            actix_web::error::ErrorInternalServerError(e)
        })?;

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[get("/api/user/under_review_metadata")]
async fn fetch_under_review_metadata(
    req: actix_web::HttpRequest,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    println!("🔍 [API] Request: fetch_under_review_metadata");
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => {
            println!("❌ [API] Auth failed: {:?}", auth_err);
            return Err(actix_web::error::ErrorInternalServerError(auth_err));
        }
    };

    let verified_user_id = match verification_result {
        Some(user_id) => user_id,
        None => {
            println!("❌ [API] Unauthorized");
            return Err(actix_web::error::ErrorUnauthorized(
                "client is not recognized legitimate user.",
            ));
        }
    };

    let user_uuid = uuid::Uuid::parse_str(&verified_user_id)
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    let metadata_list = pg_repository
        .fetch_profile_image_upload_metadata(user_uuid)
        .await
        .map_err(|e| {
            println!(
                "❌ [DB] fetch_profile_image_upload_metadata failed: {:?}",
                e
            );
            actix_web::error::ErrorInternalServerError(e)
        })?;

    println!(
        "✅ [API] Handled fetch_under_review_metadata: found {} images",
        metadata_list.len()
    );
    Ok(actix_web::HttpResponse::Ok().json(metadata_list))
}

#[get("/api/user/under_review_image/{new_image_id}")]
async fn serve_under_review_image(
    req: actix_web::HttpRequest,
    path: web::Path<uuid::Uuid>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client)
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    if verification_result.is_none() {
        return Err(actix_web::error::ErrorUnauthorized(
            "client is not recognized legitimate user.",
        ));
    }

    let new_image_id = path.into_inner();

    let internal_path = pg_repository
        .get_internal_path_by_new_image_id(new_image_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    if let Some(path) = internal_path {
        let content =
            std::fs::read(path).map_err(|e| actix_web::error::ErrorInternalServerError(e))?;
        Ok(actix_web::HttpResponse::Ok()
            .content_type("image/jpeg")
            .body(content))
    } else {
        Err(actix_web::error::ErrorNotFound("image not found"))
    }
}

#[post("/api/upload_hook")]
async fn upload_hook(
    body: web::Json<models::tus::TusHook>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
    vision_client: web::Data<Arc<vision::safe_search::VisionClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    println!(
        "🔔 [TUS Hook] Request received. Hook: {}, Offset: {}, Size: {}",
        body.hook_type, body.event.upload.offset, body.event.upload.size
    );
    println!("📦 [TUS Hook] MetaData: {:?}", body.event.upload.meta_data);
    println!("📂 [TUS Hook] Storage: {:?}", body.event.upload.storage);

    // Only process when transfer is complete (offset equals size)
    if body.event.upload.offset < body.event.upload.size {
        println!("⏳ [TUS Hook] Upload not complete yet, skipping processing.");
        return Ok(actix_web::HttpResponse::Ok()
            .insert_header(("Content-Type", "application/json"))
            .body("{}"));
    }

    // Only process post-finish event to avoid double-processing (post-receive + post-finish)
    if body.hook_type != "post-finish" {
        println!(
            "ℹ️ [TUS Hook] Ignored hook type (only post-finish is processed for finalization): {}",
            body.hook_type
        );
        return Ok(actix_web::HttpResponse::Ok()
            .insert_header(("Content-Type", "application/json"))
            .body("{}"));
    }

    if let Some(new_image_id_str) = body.event.upload.meta_data.get("newImageId") {
        if let Some(temp_path) = body.event.upload.storage.get("Path") {
            println!(
                "✅ [TUS Hook] Upload finished: newImageId={}, TempPath={}",
                new_image_id_str, temp_path
            );

            let new_image_uuid = uuid::Uuid::parse_str(new_image_id_str)
                .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

            // Try updating profile image metadata first
            let _ = pg_repository
                .update_profile_image_internal_path(new_image_uuid, temp_path)
                .await;

            // Try updating identity verification metadata too (one of them will likely match or neither if it's unknown)
            let _ = pg_repository
                .update_identity_verification_internal_path(new_image_uuid, temp_path)
                .await;

            // 2. Fetch full metadata to handle replacement (for profile images)
            let metadata = pg_repository
                .get_metadata_by_new_image_id(new_image_uuid)
                .await
                .map_err(|e| {
                    println!(
                        "❌ [DB] Failed to fetch metadata for image_id {}: {:?}",
                        new_image_uuid, e
                    );
                    actix_web::error::ErrorInternalServerError(e)
                })?;

            if let Some(meta) = metadata {
                let user_id_str = meta.user_id.to_string();

                // 3. Analyze image with Google Cloud Vision API
                println!(
                    "🔍 [TUS Hook] Analyzing image: image_id={}, user_id={}",
                    new_image_id_str, user_id_str
                );
                let is_safe = match vision_client
                    .analyze_and_report(new_image_id_str, &user_id_str, temp_path)
                    .await
                {
                    Ok(safe) => {
                        println!("✅ [Vision API] Analysis result: safe={}", safe);
                        safe
                    }
                    Err(e) => {
                        eprintln!(
                            "❌ [Vision API] Error while analyzing {}: {:?}",
                            new_image_id_str, e
                        );
                        false // Default to unsafe on error for safety
                    }
                };

                // 4. If image is safe, automatically replace in storage and cleanup
                if is_safe {
                    println!(
                        "🚀 [TUS Hook] Image is safe. Automatically uploading to Supabase Storage."
                    );

                    // Upload to storage
                    if let Err(e) = postgrest_client
                        .upload_profile_image_to_storage(&user_id_str, &new_image_id_str, temp_path)
                        .await
                    {
                        eprintln!(
                            "❌ [TUS Hook] Failed to upload to Supabase Storage: {:?}",
                            e
                        );
                        return Err(actix_web::error::ErrorInternalServerError(e));
                    }

                    // Record to profile_images table
                    let storage_path = format!(
                        "profile/users/{}/{}.jpg",
                        user_id_str.to_lowercase(),
                        new_image_id_str
                    );
                    let profile_image_record = db::object::ProfileImageRecord {
                        id: new_image_uuid,
                        user_id: meta.user_id,
                        image_index: meta.image_index,
                        storage_path: Some(storage_path),
                        created_at: Some(chrono::Utc::now()),
                        updated_at: Some(chrono::Utc::now()),
                    };

                    if let Err(e) = postgrest_client
                        .upsert_profile_image_record(&profile_image_record)
                        .await
                    {
                        eprintln!(
                            "❌ [TUS Hook] Failed to insert profile image record: {:?}",
                            e
                        );
                    }

                    // Delete old image from storage if applicable
                    if let Some(old_id) = meta.old_image_id {
                        println!(
                            "🗑️ [TUS Hook] Replacing image: deleting old_image_id={} from storage",
                            old_id
                        );
                        let _ = postgrest_client
                            .delete_profile_image_from_storage(&user_id_str, &old_id.to_string())
                            .await;
                    }

                    // Cleanup TUS temporary file
                    if let Some(file_id) = temp_path.split('/').last() {
                        let tusd_url = format!("http://tusd:8080/api/upload/{}", file_id);
                        let mut delete_headers = std::collections::HashMap::new();
                        delete_headers.insert("Tus-Resumable".to_string(), "1.0.0".to_string());
                        let _ = http_client
                            .delete(&tusd_url, Some(delete_headers), None)
                            .await;
                    }

                    // Cleanup Metadata record from database
                    let _ = pg_repository
                        .delete_profile_image_upload_metadata(new_image_uuid)
                        .await;

                    println!("✅ [TUS Hook] Automatic replacement and cleanup completed.");

                    // Send notification to the user about automatic approval
                    let review_info = vision::object::ReviewProfileImage {
                        review_id: uuid::Uuid::new_v4().to_string(),
                        user_id: user_id_str.clone(),
                        message: "プロフィールの画像が承認されました。".to_string(),
                        image_id: new_image_id_str.clone(),
                        image_index: meta.image_index,
                        message_at: chrono::Utc::now().to_rfc3339(),
                        status: "approve".to_string(),
                    };

                    if let Err(e) = notification::review::send_review_notification(
                        &review_info,
                        http_client.clone(),
                        postgrest_client.clone(),
                    )
                    .await
                    {
                        eprintln!(
                            "⚠️ [TUS Hook] Failed to send automatic approval notification: {:?}",
                            e
                        );
                    }
                } else {
                    println!(
                        "⏳ [TUS Hook] Image is NOT safe (or requires manual review). Waiting for administrator."
                    );
                }
            } else {
                // Check if it was an identity verification image
                if let Ok(Some(_)) = pg_repository
                    .get_identity_verification_metadata_by_new_image_id(new_image_uuid)
                    .await
                {
                    println!(
                        "👤 [TUS Hook] Identity verification image received. Waiting for manual review."
                    );
                } else {
                    eprintln!(
                        "⚠️ [TUS Hook] No metadata found for image_id: {}",
                        new_image_id_str
                    );
                }
            }
        }
    }

    Ok(actix_web::HttpResponse::Ok()
        .insert_header(("Content-Type", "application/json"))
        .body("{}"))
}

#[post("/api/user/under_review_image/send_review_profile_image")]
async fn send_review_profile_image(
    req: actix_web::HttpRequest,
    body: web::Json<vision::object::ReviewProfileImage>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let verification_result = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    if verification_result.is_none() {
        return Err(actix_web::error::ErrorUnauthorized(
            "client is not recognized legitimate user",
        ));
    }

    // Parse string ID back to UUID for database operations
    let image_id = uuid::Uuid::parse_str(&body.image_id).map_err(|e| {
        actix_web::error::ErrorBadRequest(format!("Invalid image_id format: {}", e))
    })?;

    // Fetch the full metadata to handle image replacement in storage
    let metadata = pg_repository
        .get_metadata_by_new_image_id(image_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    if let Some(meta) = &metadata {
        // If approved, transfer to Supabase Storage
        if body.status == "approve" {
            if let Some(local_path) = &meta.internal_path {
                println!("🚀 [Proxy] Approving image: uploading to Supabase Storage");
                postgrest_client
                    .upload_profile_image_to_storage(
                        &meta.user_id.to_string(),
                        &meta.new_image_id.to_string(),
                        local_path,
                    )
                    .await
                    .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

                // Record to profile_images table
                let user_id_str = meta.user_id.to_string();
                let new_image_id_str = meta.new_image_id.to_string();
                let storage_path = format!(
                    "profile/users/{}/{}.jpg",
                    user_id_str.to_lowercase(),
                    new_image_id_str
                );
                let profile_image_record = db::object::ProfileImageRecord {
                    id: meta.new_image_id,
                    user_id: meta.user_id,
                    image_index: meta.image_index,
                    storage_path: Some(storage_path),
                    created_at: Some(chrono::Utc::now()),
                    updated_at: Some(chrono::Utc::now()),
                };

                if let Err(e) = postgrest_client
                    .upsert_profile_image_record(&profile_image_record)
                    .await
                {
                    eprintln!("❌ [Proxy] Failed to insert profile image record: {:?}", e);
                }

                // If this replaces an old image, delete the old one from storage
                if let Some(old_id) = meta.old_image_id {
                    println!(
                        "🗑️ [Proxy] Replacing image: deleting old image {} from storage",
                        old_id
                    );
                    let _ = postgrest_client
                        .delete_profile_image_from_storage(
                            &meta.user_id.to_string(),
                            &old_id.to_string(),
                        )
                        .await;
                }
            }
        }

        // Cleanup: Delete the file via tusd API to avoid permission issues with local filesystem
        if let Some(path) = &meta.internal_path {
            if let Some(file_id) = path.split('/').last() {
                // Ensure the tusd endpoint is correct. Internal port is 8080.
                let tusd_url = format!("http://tusd:8080/api/upload/{}", file_id);
                println!("🗑️ [Proxy] Requesting tusd to delete file: {}", tusd_url);

                let mut delete_headers = std::collections::HashMap::new();
                delete_headers.insert("Tus-Resumable".to_string(), "1.0.0".to_string());

                let _ = http_client
                    .delete(&tusd_url, Some(delete_headers), None)
                    .await;
            }
        }
    }

    // Cleanup: Delete the metadata from the database
    pg_repository
        .delete_profile_image_upload_metadata(image_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    // Attach image_index to the review info for the notification
    let mut review_info = body.0.clone();
    if let Some(meta) = &metadata {
        review_info.image_index = meta.image_index;
    }

    // Move notification to the end. Only send if all previous operations were successful.
    notification::review::send_review_notification(
        &review_info,
        http_client,
        postgrest_client.clone(),
    )
    .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[get("/api/user/identity_verification_image/{image_id}")]
async fn get_identity_verification_image(
    req: actix_web::HttpRequest,
    path: web::Path<String>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let _ = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let image_id = uuid::Uuid::parse_str(&path.into_inner()).map_err(|e| {
        actix_web::error::ErrorBadRequest(format!("Invalid image_id format: {}", e))
    })?;

    let internal_path = pg_repository
        .get_identity_verification_metadata_by_new_image_id(image_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?
        .and_then(|m| m.internal_path);

    if let Some(path) = internal_path {
        let bytes =
            std::fs::read(path).map_err(|e| actix_web::error::ErrorInternalServerError(e))?;
        Ok(actix_web::HttpResponse::Ok()
            .content_type("image/jpeg")
            .body(bytes))
    } else {
        Ok(actix_web::HttpResponse::NotFound().finish())
    }
}

#[post("/api/user/identity/review_result")]
async fn receive_identity_review_result(
    req: actix_web::HttpRequest,
    body: web::Json<serde_json::Value>,
    auth_session: web::Data<session::AuthSession>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
    pg_repository: web::Data<Arc<db::repository::PostgresRepository>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let _ = match auth_session
        .user_verification(req.headers(), http_client.clone())
        .await
    {
        Ok(result) => result,
        Err(auth_err) => return Err(actix_web::error::ErrorInternalServerError(auth_err)),
    };

    let user_id_str = body["user_id"]
        .as_str()
        .ok_or_else(|| actix_web::error::ErrorBadRequest("user_id is required"))?;
    let image_id_str = body["image_id"]
        .as_str()
        .ok_or_else(|| actix_web::error::ErrorBadRequest("image_id is required"))?;
    let status = body["status"]
        .as_str()
        .ok_or_else(|| actix_web::error::ErrorBadRequest("status is required"))?;
    let reason = body["reason"].as_str().map(|s| s.to_string());

    let user_id =
        uuid::Uuid::parse_str(user_id_str).map_err(|e| actix_web::error::ErrorBadRequest(e))?;
    let image_id =
        uuid::Uuid::parse_str(image_id_str).map_err(|e| actix_web::error::ErrorBadRequest(e))?;

    // 1. Update user verification status
    let (is_verified, status_str) = if status == "approve" {
        (true, "approved")
    } else {
        (false, "rejected")
    };

    if let Err(e) = postgrest_client
        .update_user_identity_verification_status(&user_id, is_verified, Some(status_str))
        .await
    {
        eprintln!("❌ [Proxy] Failed to update user identity status: {:?}", e);
        return Err(actix_web::error::ErrorInternalServerError(e));
    }

    // 2. Cleanup: Fetch metadata to get internal_path
    if let Ok(Some(meta)) = pg_repository
        .get_identity_verification_metadata_by_new_image_id(image_id)
        .await
    {
        if let Some(path) = meta.internal_path {
            if let Some(file_id) = path.split('/').last() {
                let tusd_url = format!("http://tusd:8080/api/upload/{}", file_id);
                let _ = http_client
                    .delete(
                        &tusd_url,
                        Some(
                            vec![("Tus-Resumable", "1.0.0")]
                                .into_iter()
                                .map(|(k, v)| (k.to_string(), v.to_string()))
                                .collect(),
                        ),
                        None,
                    )
                    .await;
            }
        }
    }

    // 3. Delete metadata from database
    pg_repository
        .delete_identity_verification_metadata_by_new_image_id(image_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    // 4. Send notification to the user
    if let Err(e) = notification::review::send_identity_verification_notification(
        &user_id,
        status,
        reason,
        http_client,
        postgrest_client,
    )
    .await
    {
        eprintln!(
            "⚠️ [Proxy] Failed to send identity verification notification: {:?}",
            e
        );
    }

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[get("/api/system/maintenance/status")]
async fn check_maintenance_mode(
    is_maintenance: web::Data<Arc<RwLock<bool>>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    let mode = *is_maintenance.read().await;
    Ok(actix_web::HttpResponse::Ok().json(serde_json::json!({
        "is_maintenance": mode
    })))
}

#[post("/api/internal/maintenance")]
async fn set_maintenance_mode(
    req: actix_web::HttpRequest,
    body: web::Json<db::object::MaintenanceStatus>,
    is_maintenance: web::Data<Arc<RwLock<bool>>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
    postgrest_client: web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> actix_web::Result<actix_web::HttpResponse> {
    // Basic service-role check
    let token = req
        .headers()
        .get(actix_web::http::header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.strip_prefix("Bearer "))
        .map(str::trim);

    if let Some(t) = token {
        if let Ok(service_role_key) = std::env::var("SUPABASE_SERVICE_ROLE_KEY") {
            if t != service_role_key {
                return Err(actix_web::error::ErrorUnauthorized(
                    "Unauthorized access to internal api",
                ));
            }
        } else {
            return Err(actix_web::error::ErrorInternalServerError(
                "Missing service role key",
            ));
        }
    } else {
        return Err(actix_web::error::ErrorUnauthorized(
            "Unauthorized access to internal api",
        ));
    }

    let mut lock = is_maintenance.write().await;
    *lock = body.is_maintenance;

    println!(
        "🔄 [Proxy Internal] Maintenance mode set to: {}",
        body.is_maintenance
    );
    println!("📣 Broadcasting maintenance mode notification to iOS clients...");

    // Broadcast in the background to not block the response
    let is_maint = body.is_maintenance;
    let http_client_clone = http_client.clone();
    let postgrest_client_clone = postgrest_client.clone();

    tokio::spawn(async move {
        let res = notification::maintenance::broadcast_maintenance_mode(
            is_maint,
            http_client_clone,
            postgrest_client_clone,
        )
        .await;

        if let Err(e) = res {
            eprintln!("⚠️ [Proxy] Failed to broadcast maintenance mode: {:?}", e);
        }
    });

    Ok(actix_web::HttpResponse::Ok().finish())
}

#[get("/api/places/{place_id}/photos/{photo_reference}/media")]
async fn fetch_places_photo(
    path: web::Path<(String, String)>,
    query: web::Query<place::object::PhotoQuery>,
    amazon_s3: web::Data<Arc<s3::bucket::AmazonS3>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
) -> actix_web::Result<impl actix_web::Responder, actix_web::Error> {
    let (place_id, photo_reference) = path.into_inner();
    let media = query.into_inner();

    // Make photo reference model.
    let expires_in = chrono::Duration::hours(24);
    let reference = place::object::GooglePlacesPhotoReference::new(
        place_id,
        photo_reference,
        media,
        expires_in,
    );

    // If exists photo in s3, return redirect url to s3 bucket.
    if let Some(result) = amazon_s3
        .fetch_places_photo_from_bucket(&reference)
        .await
        .ok()
    {
        if let Some(redirect_response) = result {
            return Ok(redirect_response);
        }
    }

    // If dosen't exist photo reference in s3, return bytes stream from google.
    let response = amazon_s3
        .fetch_places_photo_from_google(&reference, http_client)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

    Ok(response)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // initialize logging.
    // utils::logging::init();

    dotenv::dotenv().ok();

    // Initialize Firebase config from JSON file.
    utils::config::init().map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;

    // Establish connection to postgres.
    let pg_repository = Arc::new(
        db::repository::PostgresRepository::new()
            .await
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?,
    );

    // Background cleanup for stale place cache metadata (every hour, delete > 24h old)
    let pg_repo_cleanup = pg_repository.clone();
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(3600));
        loop {
            interval.tick().await;
            match pg_repo_cleanup
                .delete_stale_place_cache_metadata(86400)
                .await
            {
                Ok(count) => println!(
                    "[Cleanup] Removed {} stale place cache metadata entries",
                    count
                ),
                Err(e) => eprintln!("[Cleanup] Failed to clean place cache metadata: {:?}", e),
            }
        }
    });

    // Initialize Amazon S3 Client.
    let amazon_s3 = Arc::new(s3::bucket::AmazonS3::new(pg_repository.clone()).await);

    // Get memory info from os.
    let mem_info = match sys_info::mem_info() {
        Ok(mem_info) => mem_info,
        Err(e) => {
            return Err(io::Error::new(
                std::io::ErrorKind::Other,
                format!("Failed to get memory info. {:?}", e),
            ));
        }
    };

    // Free memory of can use for cache.
    let free_memory = mem_info.free;
    println!(
        "Successfully allocate free memory of {:?} byte",
        free_memory
    );

    // Initialize Auth session
    let auth_cache_weight = (free_memory as f64 * 0.1).ceil() as usize;
    let auth_session = auth::session::AuthSession::new(auth_cache_weight).map_err(|e| {
        io::Error::new(
            std::io::ErrorKind::Other,
            format!("Failed initialize auth session: {:?}", e),
        )
    })?;

    // Initialize Cache worker
    let cache_weight = (free_memory - auth_cache_weight as u64) as usize;
    let cache_worker = cache::worker::CacheWorker::new(cache_weight);

    // Initialize quad node trie tree.
    let key_length = 20;
    let quad_node_trie_tree = place::trie::QuadNodeTrieTree::new(key_length);

    // Build http client
    let http_client = Arc::new(http::request::HttpClient::new());

    // Controll supabase table.
    let supabaase_postgrest = Arc::new(db::postgrest::SupabsePostgrest::new());

    // Build sns Voip Manager
    let sns_voip_manager = Arc::new(sns::voip::SnsVoIPManager::new(pg_repository.clone()).await);

    // Build Vision Client
    let vision_client = Arc::new(vision::safe_search::VisionClient::new(http_client.clone()));

    // Build NLP Client
    let nlp_client = Arc::new(nlp::client::NLPClient::new(http_client.clone()));

    // Build Scheduler Manager
    let event_scheduler =
        Arc::new(scheduler::event::AmazonEventScheduleManager::new(pg_repository.clone()).await);

    // Build Voice Chat Waiting Queue
    let waiting_queue = Arc::new(RwLock::new(voice_chat::waiting::WaitingQueue::new()));

    let maintenance_mode = Arc::new(RwLock::new(
        pg_repository.get_maintenance_mode().await.unwrap_or(false),
    ));
    println!(
        "🛡️ Server starting with Maintenance Mode: {}",
        *maintenance_mode.read().await
    );

    let server_maintenance_mode = maintenance_mode.clone();
    actix_web::HttpServer::new(move || {
        let app_maintenance_state = server_maintenance_mode.clone();

        actix_web::App::new()
            .app_data(web::Data::new(pg_repository.clone()))
            .app_data(web::Data::new(amazon_s3.clone()))
            .app_data(web::Data::new(auth_session.clone()))
            .app_data(web::Data::new(cache_worker.clone()))
            .app_data(web::Data::new(quad_node_trie_tree.clone()))
            .app_data(web::Data::new(http_client.clone()))
            .app_data(web::Data::new(supabaase_postgrest.clone()))
            .app_data(web::Data::new(sns_voip_manager.clone()))
            .app_data(web::Data::new(vision_client.clone()))
            .app_data(web::Data::new(nlp_client.clone()))
            .app_data(web::Data::new(event_scheduler.clone()))
            .app_data(web::Data::new(app_maintenance_state.clone()))
            .app_data(web::Data::new(waiting_queue.clone()))
            .wrap(utils::maintenance::MaintenanceMiddleware {
                is_maintenance: app_maintenance_state.clone(),
            })
            .service(health_check)
            .service(nearby_search)
            .service(user_verification)
            .service(fetch_recruitment)
            .service(post_recruitment)
            .service(fetch_places_photo)
            .service(get_place_details)
            .service(search_nearby_transports)
            .service(text_search)
            .service(regist_fcm)
            .service(update_user_profile)
            .service(post_chat_room_report)
            .service(get_reported_room_ids)
            .service(upload_profile)
            .service(post_inquiry_message)
            .service(send_like)
            .service(make_chatroom)
            .service(send_message)
            .service(blocking_user)
            .service(make_voice_chat_room)
            .service(regist_voip_device)
            .service(fetch_voice_chat_rooms)
            .service(send_call_message)
            .service(upload_profile_image_metadata)
            .service(upload_identity_verification_metadata)
            .service(upload_hook)
            .service(fetch_under_review_metadata)
            .service(serve_under_review_image)
            .service(send_review_profile_image)
            .service(get_identity_verification_image)
            .service(receive_identity_review_result)
            .service(set_maintenance_mode)
            .service(check_maintenance_mode)
            .service(make_voice_chat_event)
            .service(start_voice_chat_event)
            .service(join_voice_chat_event)
            .service(leave_voice_chat_event)
    })
    .bind(("0.0.0.0", 8080))?
    .run()
    .await
}
