use chrono;
use serde::{Deserialize, Serialize};
use serde_json;
use sqlx;
use uuid;

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct Identity {
    pub id: uuid::Uuid,
    pub canonical_user_id: Option<uuid::Uuid>,
    pub supabase_user_id: uuid::Uuid,
    pub providers: Option<Vec<String>>,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub raw_user_meta_data: serde_json::Value,
    pub app_meta_data: serde_json::Value,
    pub last_sign_in_at: Option<chrono::DateTime<chrono::Utc>>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

impl Identity {
    pub fn new(
        supabse_user_id: uuid::Uuid,
        raw_user_meta_data: serde_json::Value,
        app_meta_data: serde_json::Value,
        created_at: chrono::DateTime<chrono::Utc>,
        updated_at: chrono::DateTime<chrono::Utc>,
    ) -> Self {
        Identity {
            id: uuid::Uuid::new_v4(),
            canonical_user_id: None,
            supabase_user_id: supabse_user_id,
            providers: None,
            email: None,
            phone: None,
            raw_user_meta_data: raw_user_meta_data,
            app_meta_data: app_meta_data,
            last_sign_in_at: None,
            created_at: created_at,
            updated_at: updated_at,
        }
    }

    pub fn set_providers(&mut self, providers: Vec<String>) {
        self.providers = Some(providers);
    }

    pub fn set_email(&mut self, email: String) {
        self.email = Some(email);
    }

    pub fn set_phone(&mut self, phone: String) {
        self.phone = Some(phone);
    }

    pub fn set_last_signin_at(&mut self, last_signin_at: chrono::DateTime<chrono::Utc>) {
        self.last_sign_in_at = Some(last_signin_at);
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct VoiceChatRoom {
    pub room_id: uuid::Uuid,
    pub user_id: uuid::Uuid,
    pub message: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub expires_at: chrono::DateTime<chrono::Utc>,
    pub recruitment_id: Option<uuid::Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct UserDevice {
    pub id: uuid::Uuid,
    pub user_id: uuid::Uuid,
    pub voip_endpoint_arn: String,
    pub device_token: String,
    pub is_enabled: bool,
    pub device_type: String,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

impl UserDevice {
    pub fn new(
        user_id: &uuid::Uuid,
        voip_endpoint_arn: &str,
        device_token: &str,
        device_type: &str,
    ) -> Self {
        let id = uuid::Uuid::new_v4();

        Self {
            id,
            user_id: user_id.clone(),
            voip_endpoint_arn: voip_endpoint_arn.to_string(),
            device_token: device_token.to_string(),
            is_enabled: true,
            device_type: device_type.to_string(),
            updated_at: chrono::Utc::now(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InquiryMessage {
    pub user_id: uuid::Uuid,
    #[serde(rename = "type")]
    pub inquiry_type: String,
    pub message: String,
    pub send_date: chrono::DateTime<chrono::Utc>,
}

// ------------ Supabase table ---------------
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecruitmentHashTags {
    pub recruitment_id: uuid::Uuid,
    pub hash_tag: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecruitmentPlaceTypes {
    pub recruitment_id: uuid::Uuid,
    pub place_type: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecruitmentPlaces {
    pub recruitment_id: uuid::Uuid,
    pub place_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Recruitments {
    pub recruitment_id: uuid::Uuid,
    pub post_date: Option<chrono::DateTime<chrono::Utc>>,
    pub expires_date: Option<chrono::DateTime<chrono::Utc>>,
    pub view_count: Option<usize>,
    pub post_user_age: Option<i8>,
    pub post_user_sex: Option<String>,
    pub message_score: Option<f64>,
    pub message: Option<String>,
    pub status: Option<String>,
    pub user_id: Option<uuid::Uuid>,
}

/// Response struct for PostgREST nested join query.
/// Combines recruitments with hashtags, places, and place_types.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecruitmentWithRelations {
    pub recruitment_id: uuid::Uuid,
    pub post_date: Option<chrono::DateTime<chrono::Utc>>,
    pub expires_date: Option<chrono::DateTime<chrono::Utc>>,
    pub view_count: Option<usize>,
    pub post_user_age: Option<i8>,
    pub post_user_sex: Option<String>,
    pub message_score: Option<f64>,
    pub message: Option<String>,
    pub status: Option<String>,
    pub user_id: Option<uuid::Uuid>,
    // Relations from PostgREST join
    pub recruitment_hash_tags: Option<Vec<RecruitmentHashTags>>,
    pub recruitment_places: Option<Vec<RecruitmentPlaces>>,
    pub recruitment_place_types: Option<Vec<RecruitmentPlaceTypes>>,
}

impl RecruitmentWithRelations {
    pub fn get_recruitment_id(&self) -> uuid::Uuid {
        self.recruitment_id.clone()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecruitmentWithLike {
    pub like: Option<LikeRecruitment>,
    pub recruitment_with_relations: RecruitmentWithRelations,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FcmPayload {
    pub fcm_token: String,
    pub device_type: String,
    pub app_version: String,
    pub device_model: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LikePair {
    pub id: uuid::Uuid,
    pub from_user_id: uuid::Uuid,
    pub to_user_id: uuid::Uuid,
    pub liked_at: chrono::DateTime<chrono::Utc>,
    pub matched: bool,
    pub is_read: bool,
    pub recruitment_id: uuid::Uuid,
    pub grade: String,
}

impl LikePair {
    pub fn get_grade(&self) -> String {
        self.grade.clone()
    }
}

impl LikePair {
    pub fn get_recruitment_id(&self) -> uuid::Uuid {
        self.recruitment_id.clone()
    }

    pub fn make_like_recruitment(&self, grade: String) -> LikeRecruitment {
        LikeRecruitment {
            id: uuid::Uuid::new_v4(),
            user_id: self.from_user_id.clone(),
            recruitment_id: self.recruitment_id.clone(),
            liked_at: self.liked_at.clone(),
            grade: grade,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatchPair {
    pub id: uuid::Uuid,
    pub user_id: uuid::Uuid,
    pub match_user_id: uuid::Uuid,
    pub matched_at: chrono::DateTime<chrono::Utc>,
    pub room_id: uuid::Uuid,
}

impl MatchPair {
    pub fn new(user_id: &uuid::Uuid, match_user_id: &uuid::Uuid, room_id: &uuid::Uuid) -> Self {
        let id = uuid::Uuid::new_v4();
        let matched_at = chrono::Utc::now();

        Self {
            id,
            user_id: user_id.clone(),
            match_user_id: match_user_id.clone(),
            matched_at,
            room_id: room_id.clone(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LikeRecruitment {
    pub id: uuid::Uuid,
    pub user_id: uuid::Uuid,
    pub recruitment_id: uuid::Uuid,
    pub liked_at: chrono::DateTime<chrono::Utc>,
    pub grade: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatRoom {
    pub room_id: uuid::Uuid,
    pub to_user_id: uuid::Uuid,
    pub from_user_id: uuid::Uuid,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub recruitment_id: uuid::Uuid,
    pub talk_count: Option<i32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub message_id: uuid::Uuid,
    pub from_user_id: uuid::Uuid,
    pub to_user_id: uuid::Uuid,
    pub room_id: uuid::Uuid,
    pub context: String,
    pub context_type: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
    pub checked: bool,
    pub checked_at: Option<chrono::DateTime<chrono::Utc>>,
}

/// Metadata tracking which fields are cached for each place
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct PlaceCacheMetadata {
    pub place_id: String,
    pub is_detailed: bool,
    pub field_masks: String, // Comma-separated field names
    pub accessed_at: i64,    // Unix timestamp
    pub created_at: i64,
    pub updated_at: i64,
}

impl PlaceCacheMetadata {
    pub fn new(place_id: String, field_masks: Vec<String>) -> Self {
        let now = chrono::Utc::now().timestamp();
        Self {
            place_id,
            is_detailed: false,
            field_masks: field_masks.join(","),
            accessed_at: now,
            created_at: now,
            updated_at: now,
        }
    }

    pub fn get_field_masks_set(&self) -> std::collections::HashSet<String> {
        self.field_masks
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect()
    }

    pub fn merge_fields(&mut self, new_fields: &[String]) {
        let mut existing = self.get_field_masks_set();
        for field in new_fields {
            existing.insert(field.clone());
        }
        self.field_masks = existing.into_iter().collect::<Vec<_>>().join(",");
        self.updated_at = chrono::Utc::now().timestamp();
    }

    pub fn update_is_detailed(&mut self) {
        const DETAILED_FIELDS: [&str; 8] = [
            "reviews",
            "currentOpeningHours",
            "currentSecondaryOpeningHours",
            "regularOpeningHours",
            "regularSecondaryOpeningHours",
            "priceLevel",
            "priceRange",
            "websiteUri",
        ];
        let existing = self.get_field_masks_set();
        self.is_detailed = DETAILED_FIELDS.iter().all(|f| existing.contains(*f));
    }

    pub fn touch(&mut self) {
        self.accessed_at = chrono::Utc::now().timestamp();
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RapidUser {
    pub user_id: uuid::Uuid,
    pub user_name: Option<String>,
    pub birth_date: Option<chrono::DateTime<chrono::Utc>>,
    pub residence: Option<String>,
    pub thought_marriage: Option<String>,
    pub blood_type: Option<String>,
    pub academic_background: Option<String>,
    pub income: Option<String>,
    pub profession: Option<String>,
    pub drinking_frequency: Option<String>,
    pub child_status: Option<String>,
    pub height: Option<u8>,
    pub body_type: Option<String>,
    pub mbti: Option<String>,
    pub holiday_type: Option<String>,
    pub sex: Option<String>,
    pub introduction: Option<String>,
    pub setting_status: Option<bool>,
    pub smoking_frequency: Option<String>,
    pub user_score: Option<f64>,
    pub subscription_status: Option<String>,
    pub total_point: Option<isize>,
    pub is_identity_verified: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub identity_verified_status: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BlockedUser {
    pub id: uuid::Uuid,
    pub user_id: uuid::Uuid,
    pub blocked_user_id: uuid::Uuid,
    pub blocked_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NotificationMessage {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message_id: Option<uuid::Uuid>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub message: Option<String>,
    pub message_type: Option<String>,
    pub user_id: Option<uuid::Uuid>,
    pub is_read: Option<bool>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "snake_case")]
pub enum UserProfileImageSafeStatus {
    Safe,
    Check,
    Bad,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct UploadProfileImageMetaData {
    pub id: uuid::Uuid,
    pub user_id: uuid::Uuid,
    pub old_image_id: Option<uuid::Uuid>,
    pub new_image_id: uuid::Uuid,
    pub safe_status: UserProfileImageSafeStatus,
    pub internal_path: Option<String>,
    pub image_index: Option<i64>,
    pub upload_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct UploadProfileImageMetaDataRequest {
    pub metadata: Vec<UploadProfileImageMetaData>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct UploadIdentityVerificationMetaData {
    pub id: uuid::Uuid,
    pub user_id: uuid::Uuid,
    pub new_image_id: uuid::Uuid,
    pub identification_type: String,
    pub internal_path: Option<String>,
    pub upload_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct UploadIdentityVerificationMetaDataRequest {
    pub metadata: UploadIdentityVerificationMetaData,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatNotificationSetting {
    pub id: uuid::Uuid,
    pub user_id: uuid::Uuid,
    pub room_id: uuid::Uuid,
    pub is_on: bool,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyWordTag {
    pub id: uuid::Uuid,
    pub user_id: uuid::Uuid,
    pub keyword: String,
    pub category: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UploadProfileMetaData {
    pub user: RapidUser,
    pub keywords: Vec<KeyWordTag>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProfileImageRecord {
    pub id: uuid::Uuid,
    pub user_id: uuid::Uuid,
    pub image_index: Option<i64>,
    pub storage_path: Option<String>,
    pub created_at: Option<chrono::DateTime<chrono::Utc>>,
    pub updated_at: Option<chrono::DateTime<chrono::Utc>>,
}
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct PlaceSearchCacheHitLog {
    pub id: uuid::Uuid,
    pub user_id: Option<uuid::Uuid>,
    pub is_hit: bool,
    pub search_type: String,
    pub cache_key: Option<String>,
    pub response_time: f64,
    pub upstream_response_time: Option<f64>,
    pub result_count: Option<i32>,
    pub query_params: Option<serde_json::Value>,
    pub request_date: chrono::DateTime<chrono::Utc>,
}

impl PlaceSearchCacheHitLog {
    pub fn new(
        user_id: Option<uuid::Uuid>,
        is_hit: bool,
        search_type: String,
        cache_key: Option<String>,
        response_time: f64,
        upstream_response_time: Option<f64>,
        result_count: Option<i32>,
        query_params: Option<serde_json::Value>,
    ) -> Self {
        Self {
            id: uuid::Uuid::new_v4(),
            user_id,
            is_hit,
            search_type,
            cache_key,
            response_time,
            upstream_response_time,
            result_count,
            query_params,
            request_date: chrono::Utc::now(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaintenanceStatus {
    pub is_maintenance: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatRoomReport {
    pub report_user_id: uuid::Uuid,
    pub target_user_id: uuid::Uuid,
    pub room_id: uuid::Uuid,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub report_type: String,
    pub report: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VoiceChatEvent {
    pub event_id: uuid::Uuid,
    pub place_ids: serde_json::Value,
    pub created_at: Option<chrono::DateTime<chrono::Utc>>,
    pub expires_at: Option<chrono::DateTime<chrono::Utc>>,
    pub status: Option<String>,
}

impl VoiceChatEvent {
    pub fn new(
        place_ids: Vec<String>,
        expires_at: Option<chrono::DateTime<chrono::Utc>>,
        status: Option<String>,
    ) -> Self {
        Self {
            event_id: uuid::Uuid::new_v4(),
            place_ids: serde_json::json!(place_ids),
            created_at: Some(chrono::Utc::now()),
            expires_at,
            status,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VoiceChatEventJoinedUser {
    pub user_id: uuid::Uuid,
    pub event_id: uuid::Uuid,
    pub selected_place_id: String,
    pub participated_at: chrono::DateTime<chrono::Utc>,
    pub sex: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VoiceChatEventPair {
    pub id: uuid::Uuid,
    pub to_user_id: uuid::Uuid,
    pub from_user_id: uuid::Uuid,
    pub event_id: uuid::Uuid,
    pub selected_place_id: String,
}

impl VoiceChatEventPair {
    pub fn new(
        to_user_id: &uuid::Uuid,
        from_user_id: &uuid::Uuid,
        event_id: &uuid::Uuid,
        place_id: &str,
    ) -> Self {
        Self {
            id: uuid::Uuid::new_v4(),
            to_user_id: to_user_id.clone(),
            from_user_id: from_user_id.clone(),
            event_id: event_id.clone(),
            selected_place_id: place_id.to_string(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VoiceChatEventLikedUser {
    pub id: uuid::Uuid,
    pub to_user_id: uuid::Uuid,
    pub from_user_id: uuid::Uuid,
    pub liked_at: chrono::DateTime<chrono::Utc>,
    pub event_id: uuid::Uuid,
}
