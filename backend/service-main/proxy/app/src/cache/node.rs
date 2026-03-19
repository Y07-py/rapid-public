use std::hash::{DefaultHasher, Hash, Hasher};
use std::sync::{Arc, Mutex};
use std::usize;

pub const MEAN_WEIGHT: usize = 1;

#[derive(Debug, Clone)]
pub enum NodeState {
    Active,
    Dead,
    Retired,
}

#[derive(Debug, PartialEq, Eq, Clone)]
pub enum QueueType {
    Window,
    Probation,
    Protected,
}

#[derive(Debug, Clone)]
pub struct CacheNode<V: Clone + Send + Sync + 'static + Hash + PartialEq + Eq> {
    key: u64,
    value: V,
    weight: usize,
    queue_type: QueueType,
    expire_time: Option<i64>,

    // Eviction list pointer.
    next_index: Option<usize>,
    prev_index: Option<usize>,
    index: Option<usize>,
    state: NodeState,
}

impl<V: Clone + Send + Sync + 'static + Hash + PartialEq + Eq> CacheNode<V> {
    pub fn new(
        value: V,
        weight: usize,
        queue_type: QueueType,
        expire_time: Option<i64>,
    ) -> Arc<Mutex<Self>> {
        let mut hasher = DefaultHasher::new();
        value.hash(&mut hasher);
        let key = hasher.finish();

        Arc::new(Mutex::new(Self {
            key,
            value,
            weight,
            queue_type,
            expire_time,
            next_index: None,
            prev_index: None,
            index: None,
            state: NodeState::Active,
        }))
    }

    pub fn get_key(&self) -> u64 {
        self.key.clone()
    }

    pub fn get_value(&self) -> V {
        self.value.clone()
    }

    pub fn update_value(&mut self, value: V, weight: usize, expire_time: Option<i64>) {
        self.value = value;
        self.weight = weight;
        self.expire_time = expire_time;
    }

    pub fn get_weight(&self) -> usize {
        self.weight.clone()
    }

    pub fn get_queue_type(&self) -> QueueType {
        self.queue_type.clone()
    }

    pub fn set_queue_type(&mut self, queue_type: QueueType) {
        self.queue_type = queue_type
    }

    pub fn in_probation(&self) -> bool {
        self.queue_type == QueueType::Probation
    }

    pub fn in_protected(&self) -> bool {
        self.queue_type == QueueType::Protected
    }

    pub fn get_expire_time(&self) -> Option<i64> {
        if let Some(expire_time) = self.expire_time.as_ref() {
            return Some(expire_time.clone());
        }

        return None;
    }

    pub fn change_state(&mut self, state: NodeState) {
        self.state = state;
    }

    pub fn set_index(&mut self, index: usize) {
        self.index = Some(index);
    }

    pub fn set_next_index(&mut self, next_index: Option<usize>) {
        self.next_index = next_index;
    }

    pub fn set_prev_index(&mut self, prev_index: Option<usize>) {
        self.prev_index = prev_index
    }

    pub fn get_next_index(&self) -> Option<usize> {
        self.next_index
    }

    pub fn get_prev_index(&self) -> Option<usize> {
        self.prev_index
    }
}
