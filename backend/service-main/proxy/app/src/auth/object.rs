use std::{fmt::Debug, hash::Hash};

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, Hash, PartialEq, Eq)]
pub struct SessionJWKs {
    pub keys: Vec<SessionJWKsAlg>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Hash, PartialEq, Eq)]
pub struct SessionJWKsAlg {
    pub alg: String,
    pub crv: String,
    pub ext: bool,
    pub key_ops: Vec<String>,
    pub kid: String,
    pub kty: String,
    pub r#use: String,
    pub x: String,
    pub y: String,
}
