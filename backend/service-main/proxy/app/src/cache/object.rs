use chrono;
use serde::Serialize;
use std::cmp::Eq;
use std::hash::{DefaultHasher, Hash, Hasher};
use std::marker;

use crate::cache::node::QueueType;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct CacheMultipleData {
    // A structure that enables multiple data entires to be associated with a single key.
    key: u64,
    data_vec: Vec<Option<Vec<u8>>>,
    created_at: chrono::DateTime<chrono::Utc>,
}

impl CacheMultipleData {
    pub fn new<V: Serialize>(key: u64, value: V) -> Self {
        let mut data_vec: Vec<Option<Vec<u8>>> = Vec::new();
        let data = serde_json::to_vec(&value).ok();
        data_vec.push(data);

        let created_at = chrono::Utc::now();

        Self {
            key,
            data_vec,
            created_at,
        }
    }

    pub fn get_key(&self) -> u64 {
        self.key
    }

    pub fn get_data_vec(&self) -> Vec<Option<Vec<u8>>> {
        self.data_vec.clone()
    }

    pub fn get_front_data(&self) -> Option<Vec<u8>> {
        let front = self.data_vec.first().unwrap();
        front.clone()
    }

    pub fn get_weight(&self) -> usize {
        let mut weight = 0;
        for byte in self.data_vec.iter() {
            if let Some(byte) = byte {
                weight += byte.len();
            }
        }

        weight
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct CacheDataKey<V: Hash> {
    key: u64,
    create_at: chrono::DateTime<chrono::Utc>,
    _marker: marker::PhantomData<V>,
}

impl<V: Hash> CacheDataKey<V> {
    pub fn new(value: V) -> Self {
        let mut hasher = DefaultHasher::new();
        value.hash(&mut hasher);
        let key = hasher.finish();

        Self {
            key,
            create_at: chrono::Utc::now(),
            _marker: marker::PhantomData,
        }
    }

    pub fn get_key(&self) -> u64 {
        self.key
    }
}

#[derive(Debug, Clone)]
pub enum EventType {
    Cleanup,
    Promotion(QueueType),
}

#[derive(Debug, Clone)]
pub struct BackgroundEvent {
    pub node_index: usize,
    pub event_type: EventType,
}

impl BackgroundEvent {
    pub fn new(index: usize, event_type: EventType) -> Self {
        Self {
            node_index: index,
            event_type,
        }
    }
}

#[derive(Debug, Clone)]
pub struct EvictionQueue {
    pub head_index: Option<usize>,
    pub tail_index: Option<usize>,
    pub maximum_capacity: usize,
    pub current_capacity: usize,
}

impl EvictionQueue {
    pub fn new(maximum_capacity: usize) -> Self {
        Self {
            head_index: None,
            tail_index: None,
            maximum_capacity,
            current_capacity: 0,
        }
    }
}
