use chrono::{DateTime, Utc};
use dotenv;
use postgrest::Postgrest;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;

use crate::db::object::{VoiceChatEvent, VoiceChatEventJoinedUser};
use crate::voice_chat::object::FetchVoiceChatRoomFilter;
use crate::{
    db::{
        self,
        object::{
            BlockedUser, ChatMessage, ChatNotificationSetting, ChatRoom, FcmPayload, LikePair,
            LikeRecruitment, MatchPair, RapidUser, RecruitmentWithRelations, Recruitments,
            VoiceChatEventLikedUser,
        },
    },
    recruitment,
};

/// FCM token row stored in Supabase.
/// The `updated_at` field uses server time and is not sent from the client.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FcmTokenRow {
    pub user_id: String,
    pub fcm_token: String,
    pub device_type: String,
    pub app_version: String,
    pub device_model: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub updated_at: Option<DateTime<Utc>>,
}

impl FcmTokenRow {
    pub fn new(user_id: String, payload: &FcmPayload) -> Self {
        Self {
            user_id,
            fcm_token: payload.fcm_token.clone(),
            device_type: payload.device_type.clone(),
            app_version: payload.app_version.clone(),
            device_model: payload.device_model.clone(),
            updated_at: Some(Utc::now()),
        }
    }
}

#[derive(Clone)]
pub struct SupabsePostgrest {
    client: Postgrest,
    storage_url: String,
    api_key: String,
}

impl SupabsePostgrest {
    pub fn new() -> Self {
        let endpoint = dotenv::var("SUPABASE_ENDPOINT").unwrap();
        let rest_endpoint = format!("{}/rest/v1", endpoint);
        let storage_endpoint = format!("{}/storage/v1/object", endpoint);
        let apikey = dotenv::var("SUPABASE_SERVICE_ROLE_KEY").unwrap();

        let client = Postgrest::new(rest_endpoint)
            .insert_header("apikey", apikey.clone())
            .insert_header("Authorization", format!("Bearer {}", apikey));

        Self {
            client,
            storage_url: storage_endpoint,
            api_key: apikey,
        }
    }

    pub fn from(&self, table: &str) -> postgrest::Builder {
        self.client.from(table)
    }

    /// Upserts an FCM token for a user.
    /// If the user_id already exists, updates the fcm_token and updated_at.
    /// If the user_id does not exist, inserts a new row.
    pub async fn upsert_fcm_token(
        &self,
        user_id: String,
        payload: &FcmPayload,
    ) -> Result<(), String> {
        println!("ℹ️ Start upserting FCM token for user_id: {}", user_id);
        let row = FcmTokenRow::new(user_id, payload);
        let body = serde_json::to_string(&row).map_err(|e| e.to_string())?;

        let response = self
            .client
            .from("fcm_payloads")
            .upsert(body)
            .on_conflict("user_id")
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            println!("✅ Successfully upserted FCM token.");
            Ok(())
        } else {
            let error_body = response.text().await.unwrap_or_default();
            println!("❌ Failed to upsert FCM token: {}", error_body);
            Err(format!("Failed to upsert FCM token: {}", error_body))
        }
    }

    pub async fn select_fcm_token(&self, user_id: &str) -> Result<Option<FcmPayload>, String> {
        let response = self
            .client
            .from("fcm_payloads")
            .select("*")
            .eq("user_id", user_id.to_string())
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            let context = response.text().await.map_err(|e| e.to_string())?;
            let payloads: Vec<FcmPayload> = serde_json::from_str(&context)
                .map_err(|e| format!("Failed to parse JSON: {}", e))?;

            if let Some(payload) = payloads.first() {
                return Ok(Some(payload.clone()));
            }
            return Ok(None);
        } else {
            let error_body = response.text().await.unwrap_or_default();
            Err(format!("Failed to select FCM token: {}", error_body))
        }
    }

    /// Fetches all FCM tokens stored in the fcm_payloads table.
    pub async fn get_all_fcm_tokens(&self) -> Result<Vec<String>, String> {
        let response = self
            .client
            .from("fcm_payloads")
            .select("fcm_token")
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            let context = response.text().await.map_err(|e| e.to_string())?;
            let rows: Vec<serde_json::Value> = serde_json::from_str(&context)
                .map_err(|e| format!("Failed to parse JSON: {}", e))?;

            let tokens = rows
                .into_iter()
                .filter_map(|r| r["fcm_token"].as_str().map(|s| s.to_string()))
                .collect();
            Ok(tokens)
        } else {
            let error_body = response.text().await.unwrap_or_default();
            Err(format!("Failed to fetch all FCM tokens: {}", error_body))
        }
    }

    pub async fn select_recruitment(
        &self,
        recruitment_id: uuid::Uuid,
    ) -> Result<Option<Recruitments>, String> {
        let response = self
            .client
            .from("recruitments")
            .select("*")
            .eq("recruitment_id", recruitment_id.to_string())
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            let context = response.text().await.map_err(|e| e.to_string())?;
            let payloads: Vec<Recruitments> = serde_json::from_str(&context)
                .map_err(|e| format!("Failed to parse JSON: {}", e))?;

            if let Some(payload) = payloads.first() {
                return Ok(Some(payload.clone()));
            }

            return Ok(None);
        } else {
            let error_body = response.text().await.unwrap_or_default();
            Err(format!("Failed to select recruitment: {}", error_body))
        }
    }

    /// Upserts like pair.
    pub async fn upsert_like_pair(&self, like_pair: &LikePair) -> Result<(), String> {
        let body = serde_json::to_string(&like_pair).map_err(|e| e.to_string())?;

        let response = self
            .client
            .from("like_pairs")
            .upsert(body)
            .on_conflict("from_user_id,to_user_id")
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            // If matched, also update the partner's like row to matched = true
            if like_pair.matched {
                let _ = self
                    .client
                    .from("like_pairs")
                    .update(r#"{"matched": true}"#)
                    .eq("from_user_id", like_pair.to_user_id.to_string())
                    .eq("to_user_id", like_pair.from_user_id.to_string())
                    .execute()
                    .await;
            }
            Ok(())
        } else {
            let error_body = response.text().await.unwrap_or_default();
            Err(format!("Failed to upsert like pair: {}", error_body))
        }
    }

    /// Upsert like user data.
    pub async fn upsert_like_user(&self, like_pair: &LikePair) -> Result<(), String> {
        let like_recruitment = like_pair.make_like_recruitment(like_pair.get_grade());
        let body = serde_json::to_string(&like_recruitment).map_err(|e| e.to_string())?;

        let response = self
            .client
            .from("like_recruitments")
            .upsert(body)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            Ok(())
        } else {
            let error_body = response.text().await.unwrap_or_default();
            Err(format!("Failed to upsert like recruitment: {}", error_body))
        }
    }

    /// Select like recruitment
    pub async fn select_like_recruitment(
        &self,
        recruitment: &RecruitmentWithRelations,
        user_id: &str,
    ) -> Result<Option<LikeRecruitment>, String> {
        let recruitment_id = recruitment.get_recruitment_id();

        let response = self
            .client
            .from("like_recruitments")
            .select("*")
            .eq("recruitment_id", recruitment_id.to_string())
            .eq("user_id", user_id.to_string())
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            let context = response.text().await.unwrap_or_default();
            let like_recruitments: Vec<LikeRecruitment> =
                serde_json::from_str(&context).map_err(|e| e.to_string())?;
            if let Some(like_recruitment) = like_recruitments.first() {
                return Ok(Some(like_recruitment.clone()));
            }
        } else {
            let error_body = response.text().await.unwrap_or_default();
            return Err(format!("Failed to select like recruitment: {}", error_body));
        }

        Ok(None)
    }

    /// Check　if the pair of `to_user_id` and `from_user_id` exists in the like_pairs table,
    /// and if a matching record exists, return it.
    pub async fn exist_like_pair(&self, chat_room: &ChatRoom) -> Result<Option<LikePair>, String> {
        // In this process, the pairs of `from_user_id` and `to_user_id` should actually be
        // stored in the `like_pairs` table in reverse relation, which constitutes a valid user request.
        let response = self
            .client
            .from("like_pairs")
            .select("*")
            .eq("from_user_id", chat_room.to_user_id.to_string())
            .eq("to_user_id", chat_room.from_user_id.to_string())
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            let context = response.text().await.unwrap_or_default();
            let like_pairs: Vec<LikePair> =
                serde_json::from_str(&context).map_err(|e| e.to_string())?;
            if let Some(like_pair) = like_pairs.first() {
                return Ok(Some(like_pair.clone()));
            }
        } else {
            let error_body = response.text().await.unwrap_or_default();
            return Err(format!("Failed to select like pairs: {}", error_body));
        }

        Ok(None)
    }

    pub async fn insert_chat_room(&self, chat_room: &ChatRoom) -> Result<(), String> {
        let body = serde_json::to_string(chat_room).map_err(|e| e.to_string())?;

        let response = self
            .client
            .from("chat_rooms")
            .insert(body)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let error_body = response.text().await.map_err(|e| e.to_string())?;
            return Err(format!("Failed insert chat room. {}", error_body));
        }

        Ok(())
    }

    pub async fn select_chat_room(&self, room_id: &uuid::Uuid) -> Result<Option<ChatRoom>, String> {
        let response = self
            .client
            .from("chat_rooms")
            .select("*")
            .eq("room_id", room_id.to_string())
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            let context = response.text().await.map_err(|e| e.to_string())?;
            let chat_rooms: Vec<ChatRoom> =
                serde_json::from_str(&context).map_err(|e| e.to_string())?;

            if let Some(chat_room) = chat_rooms.first() {
                return Ok(Some(chat_room.clone()));
            }
        }

        Ok(None)
    }

    pub async fn insert_match_pair(&self, chat_room: &ChatRoom) -> Result<(), String> {
        let match_pair1 = MatchPair::new(
            &chat_room.to_user_id,
            &chat_room.from_user_id,
            &chat_room.room_id,
        );
        let match_context1 = serde_json::to_string(&match_pair1).map_err(|e| e.to_string())?;
        let response1 = self
            .client
            .from("match_pairs")
            .insert(match_context1)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        let match_pair2 = MatchPair::new(
            &chat_room.from_user_id,
            &chat_room.to_user_id,
            &chat_room.room_id,
        );
        let match_context2 = serde_json::to_string(&match_pair2).map_err(|e| e.to_string())?;
        let response2 = self
            .client
            .from("match_pairs")
            .insert(match_context2)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response1.status().is_success() || !response2.status().is_success() {
            let error1 = response1.text().await.map_err(|e| e.to_string())?;
            let error2 = response2.text().await.map_err(|e| e.to_string())?;
            return Err(format!(
                "Failed insert match pair. error1 = {}, error2 = {}",
                error1, error2
            ));
        }

        Ok(())
    }

    pub async fn insert_chat_message(&self, chat_message: &ChatMessage) -> Result<(), String> {
        let body = serde_json::to_string(chat_message).map_err(|e| e.to_string())?;

        let response = self
            .client
            .from("chat_messages")
            .insert(body)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let error_body = response.text().await.map_err(|e| e.to_string())?;
            return Err(format!("Failed to insert chat message: {}", error_body));
        }

        Ok(())
    }

    pub async fn update_talk_count(&self, chat_message: &ChatMessage) -> Result<(), String> {
        let prev_response = self
            .client
            .from("chat_messages")
            .select("*")
            .eq("room_id", chat_message.room_id.to_string())
            .order("created_at.desc")
            .limit(1)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !prev_response.status().is_success() {
            let error_body = prev_response.text().await.unwrap_or_default();
            return Err(format!(
                "Failed to select previous messages: {}",
                error_body
            ));
        }

        let prev_context = prev_response.text().await.map_err(|e| e.to_string())?;
        let prev_messages: Vec<ChatMessage> =
            serde_json::from_str(&prev_context).map_err(|e| e.to_string())?;

        let should_decrement = match prev_messages.first() {
            Some(prev_message) => prev_message.from_user_id != chat_message.from_user_id,
            None => true, // No previous messages (this is the first message)
        };

        if should_decrement {
            let chat_room = self.select_chat_room(&chat_message.room_id).await?;

            if let Some(chat_room) = chat_room {
                if let Some(mut current_talk_count) = chat_room.talk_count {
                    if current_talk_count > 0 {
                        current_talk_count -= 1;
                        let column = format!(r#"{{"talk_count": {}}}"#, current_talk_count);
                        let update_response = self
                            .client
                            .from("chat_rooms")
                            .update(column)
                            .eq("room_id", chat_message.room_id.to_string())
                            .execute()
                            .await
                            .map_err(|e| e.to_string())?;

                        if !update_response.status().is_success() {
                            let error_body = update_response.text().await.unwrap_or_default();
                            return Err(format!("Failed to update talk count: {}", error_body));
                        }
                    }
                }
            }
        }

        Ok(())
    }

    pub async fn select_user(&self, user_id: &str) -> Result<Option<RapidUser>, String> {
        let response = self
            .client
            .from("users")
            .select("*")
            .eq("user_id", user_id)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            let context = response.text().await.map_err(|e| e.to_string())?;
            let users: Vec<RapidUser> =
                serde_json::from_str(&context).map_err(|e| e.to_string())?;
            if let Some(user) = users.first() {
                return Ok(Some(user.clone()));
            }
        } else {
            let error_context = response.text().await.map_err(|e| e.to_string())?;
            return Err(format!("Failed to select user: {}", error_context));
        }

        Ok(None)
    }

    pub async fn update_user(
        &self,
        user: &RapidUser,
        user_score: f64,
        is_introduction_clean: bool,
    ) -> Result<(), String> {
        let mut update_body = serde_json::to_value(user).map_err(|e| e.to_string())?;
        if let Some(obj) = update_body.as_object_mut() {
            obj.insert("user_score".to_string(), serde_json::json!(user_score));
            if !is_introduction_clean {
                obj.remove("introduction");
            }

            // Initialize identity_verified_status if it's not present (new user or first profile setup)
            if obj.get("identity_verified_status").is_none() {
                // To avoid overwriting existing status, we check if it already has a value in DB
                if let Ok(Some(existing)) = self.select_user(&user.user_id.to_string()).await {
                    if existing.identity_verified_status.is_none() {
                        obj.insert(
                            "identity_verified_status".to_string(),
                            serde_json::json!("unverified"),
                        );
                    }
                } else {
                    // New user
                    obj.insert(
                        "identity_verified_status".to_string(),
                        serde_json::json!("unverified"),
                    );
                    obj.insert("is_identity_verified".to_string(), serde_json::json!(false));
                }
            }
        }

        let body_json = serde_json::to_string(&update_body).map_err(|e| e.to_string())?;

        let response = self
            .client
            .from("users")
            .upsert(body_json)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let error_body = response.text().await.unwrap_or_default();
            return Err(format!("Failed to upsert user: {}", error_body));
        }

        Ok(())
    }

    pub async fn insert_blocked_user(&self, blocked_user: &BlockedUser) -> Result<(), String> {
        let body = serde_json::to_string(blocked_user).map_err(|e| e.to_string())?;

        let response = self
            .client
            .from("blocked_users")
            .insert(body)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let error_context = response.text().await.map_err(|e| e.to_string())?;
            return Err(format!("Failed to insert blocked users: {}", error_context));
        }

        Ok(())
    }

    pub async fn insert_voice_chat_room_record(
        &self,
        record: &db::object::VoiceChatRoom,
    ) -> Result<(), String> {
        let body = serde_json::to_string(record).map_err(|e| e.to_string())?;

        let response = self
            .client
            .from("voice_chat_rooms")
            .insert(body)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let error_context = response.text().await.map_err(|e| e.to_string())?;
            return Err(format!(
                "Failed to insert record into voice chat rooms: {}",
                error_context
            ));
        }

        Ok(())
    }

    pub async fn select_voice_chat_rooms(
        &self,
        offset: usize,
        limit: usize,
        f: FetchVoiceChatRoomFilter,
        blocked_ids: Option<HashSet<String>>,
    ) -> Result<Option<Vec<db::object::VoiceChatRoom>>, String> {
        let low = offset;
        let high = offset + limit - 1;

        let mut builder = self
            .client
            .from("voice_chat_rooms")
            .select("*, users!inner(*)");

        // Filter by age
        let now = Utc::now();
        let lower_birth_date = now - chrono::Duration::days(((f.to_age + 1) * 365) as i64);
        let higher_birth_date = now - chrono::Duration::days((f.from_age * 365) as i64);

        builder = builder.gte("users.birth_date", lower_birth_date.to_rfc3339());
        builder = builder.lte("users.birth_date", higher_birth_date.to_rfc3339());
        builder = builder.eq("users.sex", f.sex);

        // Filter by residence
        if let Some(res) = f.residence {
            builder = builder.eq("users.residence", res.name);
        }

        if let Some(blocked_ids) = blocked_ids {
            if !blocked_ids.is_empty() {
                let ids_str = blocked_ids.into_iter().collect::<Vec<String>>().join(",");
                builder = builder.not("in", "user_id", format!("({})", ids_str));
            }
        }

        let response = builder
            .order("created_at.desc") // Let's use descending to show new rooms first
            .order("room_id")
            .range(low, high)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            let context = response.text().await.map_err(|e| e.to_string())?;
            let voice_chat_rooms: Vec<db::object::VoiceChatRoom> =
                serde_json::from_str(&context).map_err(|e| e.to_string())?;

            return Ok(Some(voice_chat_rooms));
        }

        Ok(None)
    }

    pub async fn insert_notification_message(
        &self,
        message: &db::object::NotificationMessage,
    ) -> Result<(), String> {
        let body = serde_json::to_string(message).map_err(|e| e.to_string())?;

        let response = self
            .client
            .from("notification_messages")
            .insert(body)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let error_body = response.text().await.unwrap_or_default();
            return Err(format!(
                "Failed to insert notification message: {}",
                error_body
            ));
        }

        Ok(())
    }

    pub async fn upload_profile_image_to_storage(
        &self,
        user_id: &str,
        image_id: &str,
        file_path: &str,
    ) -> Result<(), String> {
        let url = format!(
            "{}/profile/users/{}/{}.jpg",
            self.storage_url,
            user_id.to_lowercase(),
            image_id
        );
        let file_content = tokio::fs::read(file_path)
            .await
            .map_err(|e| e.to_string())?;

        let client = reqwest::Client::new();
        let response = client
            .post(url)
            .header("apikey", &self.api_key)
            .header("Authorization", format!("Bearer {}", self.api_key))
            .header("Content-Type", "image/jpeg")
            .header("x-upsert", "true")
            .body(file_content)
            .send()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            Ok(())
        } else {
            let error_body = response.text().await.unwrap_or_default();
            Err(format!("Failed to upload image to storage: {}", error_body))
        }
    }

    pub async fn delete_profile_image_from_storage(
        &self,
        user_id: &str,
        image_id: &str,
    ) -> Result<(), String> {
        let url = format!(
            "{}/profile/users/{}/{}.jpg",
            self.storage_url,
            user_id.to_lowercase(),
            image_id
        );

        let client = reqwest::Client::new();
        let response = client
            .delete(url)
            .header("apikey", &self.api_key)
            .header("Authorization", format!("Bearer {}", self.api_key))
            .send()
            .await
            .map_err(|e| e.to_string())?;

        // 404 is acceptable for delete
        if !(response.status().is_success() || response.status() == reqwest::StatusCode::NOT_FOUND)
        {
            let error_body = response.text().await.unwrap_or_default();
            return Err(format!(
                "Failed to delete image from storage: {}",
                error_body
            ));
        }
        Ok(())
    }

    pub async fn select_chat_notification_setting(
        &self,
        user_id: &uuid::Uuid,
        room_id: &uuid::Uuid,
    ) -> Result<Option<ChatNotificationSetting>, String> {
        let response = self
            .client
            .from("chat_notification_settings")
            .select("*")
            .eq("user_id", user_id.to_string())
            .eq("room_id", room_id.to_string())
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            let context = response.text().await.map_err(|e| e.to_string())?;
            let settings: Vec<ChatNotificationSetting> =
                serde_json::from_str(&context).map_err(|e| e.to_string())?;
            return Ok(settings.first().cloned());
        }

        Ok(None)
    }

    pub async fn is_blocked(
        &self,
        user_id: &uuid::Uuid,
        blocked_user_id: &uuid::Uuid,
    ) -> Result<bool, String> {
        let response = self
            .client
            .from("blocked_users")
            .select("id")
            .eq("user_id", user_id.to_string())
            .eq("blocked_user_id", blocked_user_id.to_string())
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            let context = response.text().await.map_err(|e| e.to_string())?;
            let blocked_users: Vec<serde_json::Value> =
                serde_json::from_str(&context).map_err(|e| e.to_string())?;
            return Ok(!blocked_users.is_empty());
        }

        Ok(false)
    }

    pub async fn fetch_blocked_user_ids(
        &self,
        user_id: &uuid::Uuid,
    ) -> Result<std::collections::HashSet<String>, String> {
        let response = self
            .client
            .from("blocked_users")
            .select("user_id, blocked_user_id")
            .or(format!(
                "user_id.eq.{},blocked_user_id.eq.{}",
                user_id.to_string(),
                user_id.to_string()
            ))
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        let mut blocked_ids = std::collections::HashSet::new();
        if response.status().is_success() {
            let context = response.text().await.map_err(|e| e.to_string())?;
            let records: Vec<serde_json::Value> =
                serde_json::from_str(&context).map_err(|e| e.to_string())?;
            let user_id_str = user_id.to_string();
            for record in records {
                if let Some(uid) = record.get("user_id").and_then(|v| v.as_str()) {
                    if uid != user_id_str {
                        blocked_ids.insert(uid.to_string());
                    }
                }
                if let Some(buid) = record.get("blocked_user_id").and_then(|v| v.as_str()) {
                    if buid != user_id_str {
                        blocked_ids.insert(buid.to_string());
                    }
                }
            }
        }
        Ok(blocked_ids)
    }

    pub async fn upsert_user_keyword_tags(
        &self,
        user_id: &uuid::Uuid,
        keywords: &[db::object::KeyWordTag],
    ) -> Result<(), String> {
        // 1. Delete existing keywords for the user
        let delete_response = self
            .client
            .from("user_keyword_tags")
            .eq("user_id", user_id.to_string())
            .delete()
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !delete_response.status().is_success() {
            let status = delete_response.status();
            // 404 is acceptable for delete in some contexts, but PostgREST usually returns 200/204
            if status.as_u16() != 404 && !status.is_success() {
                let error_body = delete_response.text().await.unwrap_or_default();
                return Err(format!(
                    "Failed to delete existing keyword tags: {}",
                    error_body
                ));
            }
        }

        // 2. Insert new keywords
        if !keywords.is_empty() {
            let body = serde_json::to_string(keywords).map_err(|e| e.to_string())?;
            let insert_response = self
                .client
                .from("user_keyword_tags")
                .insert(body)
                .execute()
                .await
                .map_err(|e| e.to_string())?;

            if !insert_response.status().is_success() {
                let error_body = insert_response.text().await.unwrap_or_default();
                return Err(format!("Failed to insert keyword tags: {}", error_body));
            }
        }

        Ok(())
    }

    pub async fn upsert_profile_image_record(
        &self,
        record: &db::object::ProfileImageRecord,
    ) -> Result<(), String> {
        // 1. Delete existing record with the same ID (if any)
        let _ = self
            .client
            .from("profile_images")
            .delete()
            .eq("id", record.id.to_string())
            .execute()
            .await;

        // 2. If it's a specific index, also clear any other image at that index for this user
        if let Some(index) = record.image_index {
            let _ = self
                .client
                .from("profile_images")
                .delete()
                .eq("user_id", record.user_id.to_string())
                .eq("image_index", index.to_string())
                .execute()
                .await;
        }

        // 3. Insert new record
        let body = serde_json::to_string(record).map_err(|e| e.to_string())?;
        let response = self
            .client
            .from("profile_images")
            .insert(body)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let error_body = response.text().await.unwrap_or_default();
            return Err(format!(
                "Failed to insert profile image record: {}",
                error_body
            ));
        }

        Ok(())
    }

    pub async fn update_user_identity_verification_status(
        &self,
        user_id: &uuid::Uuid,
        is_verified: bool,
        identity_verified_status: Option<&str>,
    ) -> Result<(), String> {
        let mut update_json = serde_json::json!({
            "is_identity_verified": is_verified
        });

        if let Some(status) = identity_verified_status {
            update_json["identity_verified_status"] = serde_json::json!(status);
        }

        let body = update_json.to_string();

        let response = self
            .client
            .from("users")
            .update(body)
            .eq("user_id", user_id.to_string())
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let error_body = response.text().await.unwrap_or_default();
            return Err(format!(
                "Failed to update identity verification status: {}",
                error_body
            ));
        }

        Ok(())
    }

    pub async fn post_recruitment(
        &self,
        request: &recruitment::objects::PostRecruitmentRequest,
    ) -> Result<(), String> {
        // 1. Insert recruitment
        let rec_body = serde_json::to_string(&request.recruitment).map_err(|e| e.to_string())?;
        let rec_response = self
            .client
            .from("recruitments")
            .insert(rec_body)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !rec_response.status().is_success() {
            let error_body = rec_response.text().await.unwrap_or_default();
            return Err(format!("Failed to insert recruitment: {}", error_body));
        }

        // 2. Insert places
        if !request.places.is_empty() {
            let places_body = serde_json::to_string(&request.places).map_err(|e| e.to_string())?;
            let places_response = self
                .client
                .from("recruitment_places")
                .insert(places_body)
                .execute()
                .await
                .map_err(|e| e.to_string())?;

            if !places_response.status().is_success() {
                let error_body = places_response.text().await.unwrap_or_default();
                return Err(format!(
                    "Failed to insert recruitment places: {}",
                    error_body
                ));
            }
        }

        // 3. Insert hashtags
        if !request.hash_tags.is_empty() {
            let tags_body = serde_json::to_string(&request.hash_tags).map_err(|e| e.to_string())?;
            let tags_response = self
                .client
                .from("recruitment_hash_tags")
                .insert(tags_body)
                .execute()
                .await
                .map_err(|e| e.to_string())?;

            if !tags_response.status().is_success() {
                let error_body = tags_response.text().await.unwrap_or_default();
                return Err(format!(
                    "Failed to insert recruitment hash tags: {}",
                    error_body
                ));
            }
        }

        // 4. Insert place types
        if !request.place_types.is_empty() {
            let types_body =
                serde_json::to_string(&request.place_types).map_err(|e| e.to_string())?;
            let types_response = self
                .client
                .from("recruitment_place_types")
                .insert(types_body)
                .execute()
                .await
                .map_err(|e| e.to_string())?;

            if !types_response.status().is_success() {
                let error_body = types_response.text().await.unwrap_or_default();
                return Err(format!(
                    "Failed to insert recruitment place types: {}",
                    error_body
                ));
            }
        }

        Ok(())
    }

    pub async fn insert_voice_chat_event(
        &self,
        record: db::object::VoiceChatEvent,
    ) -> Result<(), String> {
        let body = serde_json::to_string(&record).map_err(|e| e.to_string())?;

        let response = self
            .client
            .from("voice_chat_events")
            .insert(body)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let error_context = response.text().await.map_err(|e| e.to_string())?;
            return Err(format!(
                "Failed to insert voice chat event: {}",
                error_context
            ));
        }

        Ok(())
    }

    pub async fn select_latest_voice_chat_event(&self) -> Result<Option<VoiceChatEvent>, String> {
        let response = self
            .client
            .from("voice_chat_events")
            .select("*")
            .order("created_at.desc")
            .limit(1)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if response.status().is_success() {
            let context = response.text().await.map_err(|e| e.to_string())?;
            let events: Vec<VoiceChatEvent> = serde_json::from_str(&context)
                .map_err(|e| format!("Failed to parse VoiceChatEvent JSON: {}", e))?;

            Ok(events.into_iter().next())
        } else {
            let error_body = response.text().await.unwrap_or_default();
            Err(format!(
                "Failed to select latest voice chat event: {}",
                error_body
            ))
        }
    }

    pub async fn select_voice_chat_event_joined_users(
        &self,
    ) -> Result<Option<Vec<VoiceChatEventJoinedUser>>, String> {
        if let Some(event) = self
            .select_latest_voice_chat_event()
            .await
            .map_err(|e| e.to_string())?
        {
            let record_response = self
                .client
                .from("voice_chat_event_joined_users")
                .select("*")
                .eq("event_id", event.event_id.to_string())
                .execute()
                .await
                .map_err(|e| e.to_string())?;

            if record_response.status().is_success() {
                let record = record_response.text().await.map_err(|e| e.to_string())?;
                let joined_users: Vec<VoiceChatEventJoinedUser> =
                    serde_json::from_str(&record).map_err(|e| e.to_string())?;
                return Ok(Some(joined_users));
            }

            let error_body = record_response.text().await.unwrap_or_default();
            return Err(format!(
                "Failed to select latest voice chat event: {}",
                error_body
            ));
        }

        Ok(None)
    }

    pub async fn insert_voice_chat_event_pairs(
        &self,
        pairs: &Vec<db::object::VoiceChatEventPair>,
    ) -> Result<(), String> {
        let body = serde_json::to_string(pairs).map_err(|e| e.to_string())?;
        let response = self
            .client
            .from("voice_chat_event_pairs")
            .insert(body)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let error_body = response.text().await.map_err(|e| e.to_string())?;
            return Err(format!(
                "Failed insert voice chat event pairs: {}",
                error_body
            ));
        }

        Ok(())
    }

    pub async fn update_voice_chat_event_status(
        &self,
        event_id: uuid::Uuid,
        status: &str,
    ) -> Result<(), String> {
        let body = serde_json::json!({ "status": status }).to_string();

        let response = self
            .client
            .from("voice_chat_events")
            .update(body)
            .eq("event_id", event_id.to_string())
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let error_context = response.text().await.map_err(|e| e.to_string())?;
            return Err(format!(
                "Failed to update voice chat event status: {}",
                error_context
            ));
        }

        Ok(())
    }

    pub async fn insert_voice_chat_event_liked_user(
        &self,
        record: &VoiceChatEventLikedUser,
    ) -> Result<(), String> {
        let body = serde_json::to_string(record).map_err(|e| e.to_string())?;

        let response = self
            .client
            .from("voice_chat_event_liked_users")
            .insert(body)
            .execute()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let error_context = response.text().await.map_err(|e| e.to_string())?;
            return Err(format!(
                "Failed to insert record into voice chat event liked users: {}",
                error_context
            ));
        }

        Ok(())
    }
}

