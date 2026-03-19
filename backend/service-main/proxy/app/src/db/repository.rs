use sqlx;

use crate::{db, place};

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

    pub async fn delete_identity_verification_metadata_by_new_image_id(
        &self,
        new_image_id: uuid::Uuid,
    ) -> Result<(), sqlx::Error> {
        sqlx::query("DELETE FROM identity_verification_upload_metadata WHERE new_image_id = $1")
            .bind(new_image_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn insert_photo_reference(
        &self,
        reference: place::object::GooglePlacesPhotoReference,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "INSERT INTO google_places_photo_references \
                (id, place_id, reference, max_height_px, max_width_px, expires_at, created_at) \
            VALUES ($1, $2, $3, $4, $5, $6, $7) \
            ON CONFLICT (id) \
            DO UPDATE SET \
                place_id = EXCLUDED.place_id,\
                reference = EXCLUDED.reference,\
                max_height_px = EXCLUDED.max_height_px,\
                max_width_px = EXCLUDED.max_width_px,\
                expires_at = EXCLUDED.expires_at,\
                created_at = EXCLUDED.created_at",
        )
        .bind(reference.id)
        .bind(reference.place_id)
        .bind(reference.reference)
        .bind(reference.max_height_px)
        .bind(reference.max_width_px)
        .bind(reference.expires_at)
        .bind(reference.created_at)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn select_photo_reference(
        &self,
        key: i64,
    ) -> Result<Option<place::object::GooglePlacesPhotoReference>, sqlx::Error> {
        // Perform the conparison at a time 60 seconds prior to the current time.
        let expires_time = (chrono::Utc::now() - chrono::Duration::seconds(60)).timestamp();

        // Use a pre-hashed key to verify whether the corresponding data exists.
        let reference: Option<place::object::GooglePlacesPhotoReference> =
            sqlx::query_as::<_, place::object::GooglePlacesPhotoReference>(
                "SELECT * FROM google_places_photo_references WHERE id = $1　AND expires_at < $2",
            )
            .bind(key)
            .bind(expires_time)
            .fetch_optional(&self.pool)
            .await?;

        Ok(reference)
    }

    pub async fn delete_photo_reference(
        &self,
    ) -> Result<Vec<place::object::GooglePlacesPhotoReference>, sqlx::Error> {
        let now = chrono::Utc::now().timestamp();
        let deleted_rows: Vec<place::object::GooglePlacesPhotoReference> =
            sqlx::query_as::<_, place::object::GooglePlacesPhotoReference>(
                "DELETE FROM google_places_photo_references WHERE expires_at < $1 \
            RETURNING id, place_id, reference, max_height_px, max_width_px, expires_at, created_at",
            )
            .bind(now)
            .fetch_all(&self.pool)
            .await?;

        Ok(deleted_rows)
    }

    pub async fn select_identity(
        &self,
        identity: &db::object::Identity,
    ) -> Result<Option<db::object::Identity>, sqlx::Error> {
        let selected_identity: Option<db::object::Identity> =
            sqlx::query_as::<_, db::object::Identity>(
                "SELECT * FROM identities WHERE supabase_user_id = $1",
            )
            .bind(identity.id)
            .fetch_optional(&self.pool)
            .await?;

        Ok(selected_identity)
    }

    pub async fn insert_identity(
        &self,
        identity: &db::object::Identity,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "INSERT INTO identities (\
            canonical_user_id,\
            supabase_user_id,\
            providers,\
            email,\
            phone,\
            raw_user_meta_data,\
            app_meta_data,\
            last_sign_in_at\
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
        )
        .bind(identity.canonical_user_id)
        .bind(identity.supabase_user_id)
        .bind(&identity.providers)
        .bind(&identity.email)
        .bind(&identity.phone)
        .bind(&identity.raw_user_meta_data)
        .bind(&identity.app_meta_data)
        .bind(identity.last_sign_in_at)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    // ============ Place Cache Metadata Operations ============

    pub async fn get_place_cache_metadata(
        &self,
        place_id: &str,
    ) -> Result<Option<db::object::PlaceCacheMetadata>, sqlx::Error> {
        sqlx::query_as::<_, db::object::PlaceCacheMetadata>(
            "SELECT * FROM place_cache_metadata WHERE place_id = $1",
        )
        .bind(place_id)
        .fetch_optional(&self.pool)
        .await
    }

    pub async fn upsert_place_cache_metadata(
        &self,
        metadata: &db::object::PlaceCacheMetadata,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "INSERT INTO place_cache_metadata \
                (place_id, is_detailed, field_masks, accessed_at, created_at, updated_at) \
            VALUES ($1, $2, $3, $4, $5, $6) \
            ON CONFLICT (place_id) \
            DO UPDATE SET \
                is_detailed = EXCLUDED.is_detailed, \
                field_masks = EXCLUDED.field_masks, \
                accessed_at = EXCLUDED.accessed_at, \
                updated_at = EXCLUDED.updated_at",
        )
        .bind(&metadata.place_id)
        .bind(metadata.is_detailed)
        .bind(&metadata.field_masks)
        .bind(metadata.accessed_at)
        .bind(metadata.created_at)
        .bind(metadata.updated_at)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn update_place_cache_accessed_at(&self, place_id: &str) -> Result<(), sqlx::Error> {
        let now = chrono::Utc::now().timestamp();
        sqlx::query(
            "UPDATE place_cache_metadata SET accessed_at = $1, updated_at = $1 WHERE place_id = $2",
        )
        .bind(now)
        .bind(place_id)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn delete_stale_place_cache_metadata(
        &self,
        max_age_seconds: i64,
    ) -> Result<u64, sqlx::Error> {
        let cutoff = (chrono::Utc::now() - chrono::Duration::seconds(max_age_seconds)).timestamp();
        let result = sqlx::query("DELETE FROM place_cache_metadata WHERE accessed_at < $1")
            .bind(cutoff)
            .execute(&self.pool)
            .await?;
        Ok(result.rows_affected())
    }

    pub async fn insert_user_device(
        &self,
        user_device: &db::object::UserDevice,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "INSERT INTO user_devices \
            (id, user_id, voip_endpoint_arn, device_token, is_enabled, device_type, updated_at) \
            VALUES ($1, $2, $3, $4, $5, $6, $7) \
            ON CONFLICT (user_id) DO NOTHING",
        )
        .bind(&user_device.id)
        .bind(&user_device.user_id)
        .bind(&user_device.voip_endpoint_arn)
        .bind(&user_device.device_token)
        .bind(&user_device.is_enabled)
        .bind(&user_device.device_type)
        .bind(&user_device.updated_at)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn select_user_device(
        &self,
        user_id: &uuid::Uuid,
    ) -> Result<Option<db::object::UserDevice>, sqlx::Error> {
        let user_device: Option<db::object::UserDevice> =
            sqlx::query_as::<_, db::object::UserDevice>(
                "SELECT * FROM user_devices WHERE user_id = $1",
            )
            .bind(user_id)
            .fetch_optional(&self.pool)
            .await?;

        Ok(user_device)
    }

    pub async fn insert_profile_image_upload_metadata(
        &self,
        user_id: uuid::Uuid,
        metadata: &db::object::UploadProfileImageMetaData,
    ) -> Result<(), sqlx::Error> {
        let safe_status = match metadata.safe_status {
            db::object::UserProfileImageSafeStatus::Safe => "safe",
            db::object::UserProfileImageSafeStatus::Check => "check",
            db::object::UserProfileImageSafeStatus::Bad => "bad",
        };

        sqlx::query(
            "INSERT INTO profile_image_upload_metadata \
            (id, user_id, old_image_id, new_image_id, safe_status, upload_at, image_index) \
            VALUES ($1, $2, $3, $4, $5, $6, $7)",
        )
        .bind(&metadata.id)
        .bind(&user_id)
        .bind(&metadata.old_image_id)
        .bind(&metadata.new_image_id)
        .bind(safe_status)
        .bind(&metadata.upload_at)
        .bind(metadata.image_index)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn update_profile_image_internal_path(
        &self,
        new_image_id: uuid::Uuid,
        internal_path: &str,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "UPDATE profile_image_upload_metadata SET internal_path = $1 WHERE new_image_id = $2",
        )
        .bind(internal_path)
        .bind(new_image_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn fetch_profile_image_upload_metadata(
        &self,
        user_id: uuid::Uuid,
    ) -> Result<Vec<db::object::UploadProfileImageMetaData>, sqlx::Error> {
        let rows = sqlx::query(
            "SELECT id, user_id, old_image_id, new_image_id, safe_status, internal_path, upload_at, image_index \
             FROM profile_image_upload_metadata \
             WHERE user_id = $1 AND internal_path IS NOT NULL",
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await?;

        let mut metadata_list = Vec::new();
        for row in rows {
            use sqlx::Row;
            let safe_status_str: String = row.get("safe_status");
            let safe_status = match safe_status_str.as_str() {
                "safe" => db::object::UserProfileImageSafeStatus::Safe,
                "check" => db::object::UserProfileImageSafeStatus::Check,
                "bad" => db::object::UserProfileImageSafeStatus::Bad,
                _ => db::object::UserProfileImageSafeStatus::Check,
            };

            metadata_list.push(db::object::UploadProfileImageMetaData {
                id: row.get("id"),
                user_id: row.get("user_id"),
                old_image_id: row.get("old_image_id"),
                new_image_id: row.get("new_image_id"),
                safe_status,
                internal_path: row.get("internal_path"),
                upload_at: row.get("upload_at"),
                image_index: row.get("image_index"),
            });
        }

        Ok(metadata_list)
    }

    pub async fn get_internal_path_by_new_image_id(
        &self,
        new_image_id: uuid::Uuid,
    ) -> Result<Option<String>, sqlx::Error> {
        let row = sqlx::query(
            "SELECT internal_path FROM profile_image_upload_metadata WHERE new_image_id = $1",
        )
        .bind(new_image_id)
        .fetch_optional(&self.pool)
        .await?;

        if let Some(row) = row {
            use sqlx::Row;
            Ok(row.get("internal_path"))
        } else {
            Ok(None)
        }
    }

    pub async fn get_metadata_by_new_image_id(
        &self,
        new_image_id: uuid::Uuid,
    ) -> Result<Option<db::object::UploadProfileImageMetaData>, sqlx::Error> {
        let row = sqlx::query(
            "SELECT id, user_id, old_image_id, new_image_id, safe_status, internal_path, upload_at, image_index \
             FROM profile_image_upload_metadata \
             WHERE new_image_id = $1",
        )
        .bind(new_image_id)
        .fetch_optional(&self.pool)
        .await?;

        if let Some(row) = row {
            use sqlx::Row;
            let safe_status_str: String = row.get("safe_status");
            let safe_status = match safe_status_str.as_str() {
                "safe" => db::object::UserProfileImageSafeStatus::Safe,
                "check" => db::object::UserProfileImageSafeStatus::Check,
                "bad" => db::object::UserProfileImageSafeStatus::Bad,
                _ => db::object::UserProfileImageSafeStatus::Check,
            };

            Ok(Some(db::object::UploadProfileImageMetaData {
                id: row.get("id"),
                user_id: row.get("user_id"),
                old_image_id: row.get("old_image_id"),
                new_image_id: row.get("new_image_id"),
                safe_status,
                internal_path: row.get("internal_path"),
                upload_at: row.get("upload_at"),
                image_index: row.get("image_index"),
            }))
        } else {
            Ok(None)
        }
    }

    pub async fn delete_profile_image_upload_metadata(
        &self,
        new_image_id: uuid::Uuid,
    ) -> Result<(), sqlx::Error> {
        sqlx::query("DELETE FROM profile_image_upload_metadata WHERE new_image_id = $1")
            .bind(new_image_id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    pub async fn insert_identity_verification_metadata(
        &self,
        user_id: uuid::Uuid,
        metadata: &db::object::UploadIdentityVerificationMetaData,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "INSERT INTO identity_verification_upload_metadata \
            (id, user_id, new_image_id, identification_type, upload_at) \
            VALUES ($1, $2, $3, $4, $5)",
        )
        .bind(&metadata.id)
        .bind(&user_id)
        .bind(&metadata.new_image_id)
        .bind(&metadata.identification_type)
        .bind(&metadata.upload_at)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn update_identity_verification_internal_path(
        &self,
        new_image_id: uuid::Uuid,
        internal_path: &str,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "UPDATE identity_verification_upload_metadata SET internal_path = $1 WHERE new_image_id = $2",
        )
        .bind(internal_path)
        .bind(new_image_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn get_identity_verification_metadata_by_new_image_id(
        &self,
        new_image_id: uuid::Uuid,
    ) -> Result<Option<db::object::UploadIdentityVerificationMetaData>, sqlx::Error> {
        let row = sqlx::query(
            "SELECT id, user_id, new_image_id, identification_type, internal_path, upload_at \
             FROM identity_verification_upload_metadata \
             WHERE new_image_id = $1",
        )
        .bind(new_image_id)
        .fetch_optional(&self.pool)
        .await?;

        if let Some(row) = row {
            use sqlx::Row;

            Ok(Some(db::object::UploadIdentityVerificationMetaData {
                id: row.get("id"),
                user_id: row.get("user_id"),
                new_image_id: row.get("new_image_id"),
                identification_type: row.get("identification_type"),
                internal_path: row.get("internal_path"),
                upload_at: row.get("upload_at"),
            }))
        } else {
            Ok(None)
        }
    }
    pub async fn insert_inquiry_message(
        &self,
        message: &db::object::InquiryMessage,
    ) -> Result<(), sqlx::Error> {
        let id = uuid::Uuid::new_v4();
        sqlx::query(
            "INSERT INTO inquiry_messages (id, user_id, inquiry_type, message, send_date) \
             VALUES ($1, $2, $3, $4, $5)",
        )
        .bind(&id)
        .bind(&message.user_id)
        .bind(&message.inquiry_type)
        .bind(&message.message)
        .bind(&message.send_date)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn insert_place_search_cache_hit_log(
        &self,
        log: &db::object::PlaceSearchCacheHitLog,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "INSERT INTO place_search_cache_hit_logs (\
            id, user_id, is_hit, search_type, cache_key, response_time, \
            upstream_response_time, result_count, query_params, request_date\
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)",
        )
        .bind(log.id)
        .bind(log.user_id)
        .bind(log.is_hit)
        .bind(&log.search_type)
        .bind(&log.cache_key)
        .bind(log.response_time)
        .bind(log.upstream_response_time)
        .bind(log.result_count)
        .bind(&log.query_params)
        .bind(log.request_date)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub async fn get_maintenance_mode(&self) -> Result<bool, sqlx::Error> {
        let row = sqlx::query("SELECT value FROM system_settings WHERE key = 'maintenance_mode'")
            .fetch_one(&self.pool)
            .await?;

        use sqlx::Row;
        let value: String = row.get("value");
        Ok(value == "true")
    }

    pub async fn fetch_reported_room_ids(
        &self,
        user_id: uuid::Uuid,
    ) -> Result<Vec<uuid::Uuid>, sqlx::Error> {
        let rows = sqlx::query("SELECT room_id FROM chat_room_reports WHERE report_user_id = $1")
            .bind(user_id)
            .fetch_all(&self.pool)
            .await?;

        use sqlx::Row;
        let room_ids = rows.into_iter().map(|r| r.get("room_id")).collect();
        Ok(room_ids)
    }

    pub async fn insert_chat_room_report(
        &self,
        report: &db::object::ChatRoomReport,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "INSERT INTO chat_room_reports \
             (report_user_id, target_user_id, room_id, created_at, report_type, report) \
             VALUES ($1, $2, $3, $4, $5, $6)",
        )
        .bind(&report.report_user_id)
        .bind(&report.target_user_id)
        .bind(&report.room_id)
        .bind(&report.created_at)
        .bind(&report.report_type)
        .bind(&report.report)
        .execute(&self.pool)
        .await?;

        Ok(())
    }
}
