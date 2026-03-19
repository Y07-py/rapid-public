use crate::db::object::ReportPayload;
use sqlx;

pub struct PostgresRepository {
    pool: sqlx::PgPool,
}

impl PostgresRepository {
    pub async fn new() -> Result<Self, sqlx::Error> {
        let user = std::env::var("POSTGRES_USER").expect("POSTGRES_USER must be set");
        let pw = std::env::var("POSTGRES_PASSWORD").expect("POSTGRES_PASSWORD must be set");
        let host = std::env::var("POSTGRES_HOST").expect("POSTGRES_HOST must be set");
        let port = std::env::var("POSTGRES_PORT").expect("POSTGRES_PORT must be set");
        let db = std::env::var("POSTGRES_DB").expect("POSTGRES_DB must be set");
        let url = format!("postgres://{}:{}@{}:{}/{}", user, pw, host, port, db);

        let pool = sqlx::postgres::PgPoolOptions::new()
            .max_connections(20)
            .min_connections(2)
            .acquire_timeout(std::time::Duration::from_secs(10))
            .idle_timeout(std::time::Duration::from_secs(300))
            .connect(&url)
            .await?;

        println!("✅ [Postgres] Connection pool established (max: 20)");
        Ok(Self { pool })
    }

    pub async fn list_reports(&self) -> Result<Vec<ReportPayload>, sqlx::Error> {
        sqlx::query_as::<_, ReportPayload>(
            "SELECT image_id::text, user_id, safe_search, labels FROM review_reports ORDER BY created_at DESC"
        )
        .fetch_all(&self.pool)
        .await
    }

    pub async fn insert_report(&self, payload: &ReportPayload) -> Result<(), sqlx::Error> {
        sqlx::query(
            "INSERT INTO review_reports (image_id, user_id, safe_search, labels) VALUES ($1, $2, $3, $4) ON CONFLICT (image_id) DO NOTHING"
        )
        .bind(uuid::Uuid::parse_str(&payload.image_id).unwrap_or_default())
        .bind(&payload.user_id)
        .bind(&payload.safe_search)
        .bind(&payload.labels)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn delete_report(&self, image_id: &str) -> Result<(), sqlx::Error> {
        sqlx::query("DELETE FROM review_reports WHERE image_id = $1")
            .bind(uuid::Uuid::parse_str(image_id).unwrap_or_default())
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn list_identity_reports(
        &self,
    ) -> Result<Vec<crate::db::object::IdentityVerificationReport>, sqlx::Error> {
        sqlx::query_as::<_, crate::db::object::IdentityVerificationReport>(
            "SELECT id, user_id, new_image_id, identification_type, upload_at FROM identity_verification_upload_metadata ORDER BY upload_at DESC"
        )
        .fetch_all(&self.pool)
        .await
    }

    pub async fn delete_identity_report(&self, image_id: uuid::Uuid) -> Result<(), sqlx::Error> {
        sqlx::query("DELETE FROM identity_verification_upload_metadata WHERE new_image_id = $1")
            .bind(image_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn list_inquiry_messages(
        &self,
    ) -> Result<Vec<crate::db::object::InquiryMessage>, sqlx::Error> {
        sqlx::query_as::<_, crate::db::object::InquiryMessage>(
            "SELECT id, user_id, inquiry_type, message, send_date FROM inquiry_messages ORDER BY send_date DESC"
        )
        .fetch_all(&self.pool)
        .await
    }

    pub async fn get_maintenance_mode(&self) -> Result<bool, sqlx::Error> {
        let row = sqlx::query("SELECT value FROM system_settings WHERE key = 'maintenance_mode'")
            .fetch_one(&self.pool)
            .await?;
        use sqlx::Row;
        let value: String = row.get("value");
        Ok(value == "true")
    }

    pub async fn set_maintenance_mode(&self, is_maintenance: bool) -> Result<(), sqlx::Error> {
        let val_str = if is_maintenance { "true" } else { "false" };
        sqlx::query("UPDATE system_settings SET value = $1, updated_at = now() WHERE key = 'maintenance_mode'")
            .bind(val_str)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn list_chat_room_reports(
        &self,
    ) -> Result<Vec<crate::db::object::ChatRoomReport>, sqlx::Error> {
        sqlx::query_as::<_, crate::db::object::ChatRoomReport>(
            "SELECT id, report_user_id, target_user_id, room_id, created_at, report_type, report FROM chat_room_reports ORDER BY created_at DESC"
        )
        .fetch_all(&self.pool)
        .await
    }
}
