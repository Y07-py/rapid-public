use std::str::FromStr;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceToken {
    pub user_id: uuid::Uuid,
    pub device_token: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CallObject {
    pub user_id: uuid::Uuid,
    pub payload: CallPayload,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Aps {
    #[serde(rename = "content-available")]
    content_available: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CallPayload {
    aps: Aps,
    call_id: String,
    caller_name: String,
    handle: String,
}

impl CallPayload {
    pub fn get_handle_with_uuid(&self) -> uuid::Uuid {
        let handle_uuid = uuid::Uuid::from_str(&self.handle).unwrap();
        handle_uuid
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SnsMessage {
    #[serde(rename = "default")]
    default: String,

    #[serde(rename = "APNS_VOIP", skip_serializing_if = "Option::is_none")]
    apns_voip: Option<String>,

    #[serde(rename = "APNS_VOIP_SANDBOX", skip_serializing_if = "Option::is_none")]
    apns_voip_sandbox: Option<String>,
}

impl SnsMessage {
    pub fn new(default: String, payload: String, is_sandbox: bool) -> Self {
        if is_sandbox {
            Self {
                default,
                apns_voip: None,
                apns_voip_sandbox: Some(payload),
            }
        } else {
            Self {
                default,
                apns_voip: Some(payload),
                apns_voip_sandbox: None,
            }
        }
    }
}
