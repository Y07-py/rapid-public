use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TusUpload {
    #[serde(rename = "ID")]
    pub id: String,
    pub size: i64,
    pub offset: i64,
    pub is_final: bool,
    pub is_partial: bool,
    pub meta_data: HashMap<String, String>,
    pub storage: HashMap<String, String>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TusHttpRequest {
    pub method: String,
    #[serde(rename = "URI")]
    pub uri: String,
    pub remote_addr: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TusEvent {
    pub upload: TusUpload,
    #[serde(rename = "HTTPRequest")]
    pub http_request: TusHttpRequest,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TusHook {
    pub event: TusEvent,
    #[serde(rename = "Type")]
    pub hook_type: String,
}
