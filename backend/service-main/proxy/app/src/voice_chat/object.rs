use std::hash::Hash;

use serde::{Deserialize, Serialize};

use crate::db;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FetchVoiceChatRoomParamater {
    pub user_id: uuid::Uuid,
    pub page_offset: usize,
    pub page_limit: usize,
    pub filter: FetchVoiceChatRoomFilter,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FetchVoiceChatRoomFilter {
    pub from_age: usize,
    pub to_age: usize,
    pub sex: String,
    pub residence: Option<FetchVoiceChatRoomResidence>,
    pub radius: Option<usize>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FetchVoiceChatRoomResidence {
    pub name: String,
    pub latitude: f64,
    pub longitude: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VoiceChatRoomWithRecruitment {
    pub voice_chat_room: db::object::VoiceChatRoom,
    pub recruitment: Option<db::object::RecruitmentWithRelations>,
}

impl VoiceChatRoomWithRecruitment {
    pub fn new(
        voice_chat_room: db::object::VoiceChatRoom,
        recruitment: Option<db::object::RecruitmentWithRelations>,
    ) -> Self {
        Self {
            voice_chat_room,
            recruitment,
        }
    }
}

#[derive(Debug, Clone, Eq, Serialize, Deserialize)]
pub struct WaitingUser {
    pub user_id: uuid::Uuid,
    pub entered_at: chrono::DateTime<chrono::Utc>,
    pub sex: String,
    pub place_id: String,
}

impl PartialEq for WaitingUser {
    fn eq(&self, other: &Self) -> bool {
        self.user_id == other.user_id
    }
}

impl Hash for WaitingUser {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        self.user_id.hash(state);
    }
}
