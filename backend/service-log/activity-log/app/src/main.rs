use actix_cors::Cors;
use actix_web::{App, HttpResponse, HttpServer, Responder, delete, get, post, web};
use std::sync::Arc;

pub mod auth;
pub mod db;
pub mod http;

#[get("/admin/health")]
async fn health_check() -> impl Responder {
    HttpResponse::Ok().finish()
}

#[get("/admin/review/list")]
async fn list_reports(repo: web::Data<Arc<db::repository::PostgresRepository>>) -> impl Responder {
    match repo.list_reports().await {
        Ok(reports) => {
            println!("Listing {} reports from DB", reports.len());
            HttpResponse::Ok().json(reports)
        }
        Err(e) => {
            eprintln!("DB Error (list): {:?}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

#[post("/admin/review/report")]
async fn receive_report(
    payload: web::Json<db::object::ReportPayload>,
    repo: web::Data<Arc<db::repository::PostgresRepository>>,
) -> impl Responder {
    println!("Received report for image: {}", payload.image_id);

    match repo.insert_report(&payload).await {
        Ok(_) => HttpResponse::Ok().json("Report saved to DB"),
        Err(e) => {
            eprintln!("DB Error (receive): {:?}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

#[delete("/admin/review/{image_id}")]
async fn remove_report(
    path: web::Path<String>,
    repo: web::Data<Arc<db::repository::PostgresRepository>>,
) -> impl Responder {
    let image_id = path.into_inner();
    println!("Removing report for image: {}", image_id);

    match repo.delete_report(&image_id).await {
        Ok(_) => HttpResponse::Ok().json("Report removed from DB"),
        Err(e) => {
            eprintln!("DB Error (delete): {:?}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

#[post("/admin/review/action")]
async fn submit_review_action(
    payload: web::Json<db::object::ReviewProfileImage>,
    repo: web::Data<Arc<db::repository::PostgresRepository>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
) -> impl Responder {
    let image_id_str = payload.image_id.to_string();
    println!("Submitting review action for image: {}", image_id_str);

    // 1. Transfer to proxy service
    let token = std::env::var("SUPABASE_SERVICE_ROLE_KEY").unwrap_or_default();
    let proxy_url =
        "https://rapid-backend.com/api/user/under_review_image/send_review_profile_image";

    let mut headers = std::collections::HashMap::new();
    headers.insert("Authorization".to_string(), format!("Bearer {}", token));
    headers.insert("Content-Type".to_string(), "application/json".to_string());

    let transfer_result = http_client
        .post(proxy_url, Some(headers), None, payload.into_inner(), None)
        .await;

    match transfer_result {
        Ok(res) if res.is_success() => {
            println!("✅ [Activity-Log] Review action transferred to proxy");
            // 2. Delete report from local DB upon success
            match repo.delete_report(&image_id_str).await {
                Ok(_) => HttpResponse::Ok().json("Review submitted and report removed"),
                Err(e) => {
                    eprintln!(
                        "⚠️ [Activity-Log] Failed to remove report from DB after transfer: {:?}",
                        e
                    );
                    HttpResponse::Ok().json("Review submitted but failed to remove local report")
                }
            }
        }
        Ok(res) => {
            let body = res.get_body_as_string().unwrap_or_default();
            eprintln!(
                "❌ [Activity-Log] Proxy returned error during review transfer: {} - {}",
                res.get_status_code(),
                body
            );
            HttpResponse::InternalServerError()
                .body(format!("Proxy error: {}", res.get_status_code()))
        }
        Err(e) => {
            eprintln!(
                "❌ [Activity-Log] Failed to connect to proxy for review transfer: {:?}",
                e
            );
            HttpResponse::InternalServerError().body("Failed to contact proxy service")
        }
    }
}

#[get("/admin/review/image/{image_id}")]
async fn proxy_image(
    path: web::Path<String>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
) -> impl Responder {
    let image_id = path.into_inner();
    println!("Proxying image request for ID: {}", image_id);

    let token = std::env::var("SUPABASE_SERVICE_ROLE_KEY").unwrap_or_default();
    let url = format!(
        "https://rapid-backend.com/api/user/under_review_image/{}",
        image_id
    );

    let mut headers = std::collections::HashMap::new();
    headers.insert("Authorization".to_string(), format!("Bearer {}", token));

    match http_client.get(&url, Some(headers), None, None).await {
        Ok(res) if res.is_success() => {
            if let Some(bytes) = res.get_body_as_bytes() {
                HttpResponse::Ok().content_type("image/jpeg").body(bytes)
            } else {
                HttpResponse::InternalServerError().body("Failed to read image bytes")
            }
        }
        Ok(res) => HttpResponse::InternalServerError()
            .body(format!("Proxy error: {}", res.get_status_code())),
        Err(_) => HttpResponse::InternalServerError().body("Failed to contact proxy service"),
    }
}

#[get("/admin/identity/list")]
async fn list_identity_reports(
    repo: web::Data<Arc<db::repository::PostgresRepository>>,
) -> impl Responder {
    match repo.list_identity_reports().await {
        Ok(reports) => HttpResponse::Ok().json(reports),
        Err(e) => {
            eprintln!("DB Error (identity list): {:?}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

#[get("/admin/identity/image/{image_id}")]
async fn proxy_identity_image(
    path: web::Path<String>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
) -> impl Responder {
    let image_id = path.into_inner();
    let token = std::env::var("SUPABASE_SERVICE_ROLE_KEY").unwrap_or_default();
    let url = format!(
        "https://rapid-backend.com/api/user/identity_verification_image/{}",
        image_id
    );

    let mut headers = std::collections::HashMap::new();
    headers.insert("Authorization".to_string(), format!("Bearer {}", token));

    match http_client.get(&url, Some(headers), None, None).await {
        Ok(res) if res.is_success() => {
            if let Some(bytes) = res.get_body_as_bytes() {
                HttpResponse::Ok().content_type("image/jpeg").body(bytes)
            } else {
                HttpResponse::InternalServerError().body("Failed to read image bytes")
            }
        }
        _ => HttpResponse::InternalServerError().body("Failed to proxy identity image"),
    }
}

#[post("/admin/identity/review")]
async fn submit_identity_review(
    payload: web::Json<db::object::IdentityReviewAction>,
    repo: web::Data<Arc<db::repository::PostgresRepository>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
) -> impl Responder {
    println!("Submitting identity review for user: {}", payload.user_id);

    // 1. Transfer to proxy service
    let token = std::env::var("SUPABASE_SERVICE_ROLE_KEY").unwrap_or_default();
    let proxy_url = "https://rapid-backend.com/api/user/identity/review_result";

    let mut headers = std::collections::HashMap::new();
    headers.insert("Authorization".to_string(), format!("Bearer {}", token));
    headers.insert("Content-Type".to_string(), "application/json".to_string());

    let transfer_result = http_client
        .post(proxy_url, Some(headers), None, payload.0.clone(), None)
        .await;

    match transfer_result {
        Ok(res) if res.is_success() => {
            // 2. Delete report from local DB upon success
            let _ = repo.delete_identity_report(payload.image_id).await;
            HttpResponse::Ok().json("Identity review submitted")
        }
        _ => HttpResponse::InternalServerError()
            .body("Failed to contact proxy or proxy returned error"),
    }
}

#[get("/admin/inquiry/list")]
async fn list_inquiry_messages(
    repo: web::Data<Arc<db::repository::PostgresRepository>>,
) -> impl Responder {
    match repo.list_inquiry_messages().await {
        Ok(messages) => HttpResponse::Ok().json(messages),
        Err(e) => {
            eprintln!("DB Error (inquiry list): {:?}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

#[get("/admin/report/list")]
async fn list_chat_room_reports(
    repo: web::Data<Arc<db::repository::PostgresRepository>>,
) -> impl Responder {
    match repo.list_chat_room_reports().await {
        Ok(reports) => HttpResponse::Ok().json(reports),
        Err(e) => {
            eprintln!("DB Error (chat room report list): {:?}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

#[get("/admin/system/maintenance")]
async fn get_maintenance_mode(
    repo: web::Data<Arc<db::repository::PostgresRepository>>,
) -> impl Responder {
    match repo.get_maintenance_mode().await {
        Ok(is_maintenance) => {
            HttpResponse::Ok().json(db::object::MaintenanceStatus { is_maintenance })
        }
        Err(e) => {
            eprintln!("DB Error (get_maintenance_mode): {:?}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

#[post("/admin/system/maintenance")]
async fn toggle_maintenance_mode(
    payload: web::Json<db::object::MaintenanceStatus>,
    repo: web::Data<Arc<db::repository::PostgresRepository>>,
    http_client: web::Data<Arc<http::request::HttpClient>>,
) -> impl Responder {
    let mode = payload.is_maintenance;
    println!("Toggling maintenance mode to: {}", mode);

    match repo.set_maintenance_mode(mode).await {
        Ok(_) => {
            // Notify proxy
            let url = "https://rapid-backend.com/api/internal/maintenance";
            let mut headers = std::collections::HashMap::new();
            headers.insert("Content-Type".to_string(), "application/json".to_string());

            let token = std::env::var("SUPABASE_SERVICE_ROLE_KEY").unwrap_or_default();
            headers.insert("Authorization".to_string(), format!("Bearer {}", token));

            let transfer_result = http_client
                .post(url, Some(headers), None, payload.into_inner(), None)
                .await;

            match transfer_result {
                Ok(res) if res.is_success() => {
                    println!(
                        "✅ Proxy successfully notified of maintenance mode {}",
                        mode
                    );
                    HttpResponse::Ok().json("Maintenance mode updated and proxy notified")
                }
                Ok(res) => {
                    let body = res.get_body_as_string().unwrap_or_default();
                    eprintln!(
                        "❌ Proxy returned error on maintenance toggle: {} - {}",
                        res.get_status_code(),
                        body
                    );
                    HttpResponse::Ok()
                        .json("Maintenance mode updated in DB, but proxy notification failed")
                }
                Err(e) => {
                    eprintln!("❌ Failed to contact proxy on maintenance toggle: {:?}", e);
                    HttpResponse::Ok().json("Maintenance mode updated in DB, but proxy unreachable")
                }
            }
        }
        Err(e) => {
            eprintln!("DB Error (set_maintenance_mode): {:?}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Load .env
    dotenv::dotenv().ok();

    let repo = Arc::new(
        db::repository::PostgresRepository::new()
            .await
            .expect("Failed to initialize repository"),
    );

    let http_client = Arc::new(http::request::HttpClient::new());

    println!("Starting activity-log backend on 0.0.0.0:8081");

    HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allow_any_method()
            .allow_any_header()
            .max_age(3600);

        App::new()
            .wrap(cors)
            .app_data(web::Data::new(repo.clone()))
            .app_data(web::Data::new(http_client.clone()))
            .service(
                web::scope("")
                    .wrap(crate::auth::ClerkAuth::new(vec![
                        "/admin/health".to_string(),
                        "/admin/review/report".to_string(),
                    ]))
                    .service(health_check)
                    .service(receive_report)
                    .service(list_reports)
                    .service(remove_report)
                    .service(submit_review_action)
                    .service(proxy_image)
                    .service(list_identity_reports)
                    .service(submit_identity_review)
                    .service(proxy_identity_image)
                    .service(list_inquiry_messages)
                    .service(list_chat_room_reports)
                    .service(get_maintenance_mode)
                    .service(toggle_maintenance_mode),
            )
    })
    .bind(("0.0.0.0", 8081))?
    .run()
    .await
}
