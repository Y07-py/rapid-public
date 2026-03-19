use chrono;
use serde::{Deserialize, Serialize};
use uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatRoomEvent {
    pub room_id: uuid::Uuid,
    pub start_date: chrono::DateTime<chrono::Utc>,
    pub end_date: chrono::DateTime<chrono::Utc>,
}
