use std::hash::Hash;
use std::sync::{Arc, Mutex};

use crate::cache::node::{CacheNode, QueueType};

#[derive(Debug, Clone)]
pub struct NodeFactory<V: Clone + Send + Sync + 'static + Hash + PartialEq + Eq> {
    pub _marker: std::marker::PhantomData<V>,
}

impl<V: Clone + Send + Sync + 'static + Hash + PartialEq + Eq> NodeFactory<V> {
    pub fn new() -> Self {
        Self {
            _marker: std::marker::PhantomData,
        }
    }

    pub fn build(
        &mut self,
        value: V,
        weight: usize,
        queue_type: QueueType,
        expire_time: Option<i64>,
    ) -> Arc<Mutex<CacheNode<V>>> {
        CacheNode::new(value, weight, queue_type, expire_time)
    }
}
