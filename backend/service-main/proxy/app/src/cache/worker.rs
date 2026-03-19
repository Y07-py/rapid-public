use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

use actix_web;
use actix_web::error::Result;
use dashmap::DashMap;
use tokio;
use tokio::sync::{RwLock, mpsc};

use crate::cache;
use crate::cache::factory::NodeFactory;
use crate::cache::frequency::FrequencySketch;
use crate::cache::node::{CacheNode, MEAN_WEIGHT, NodeState, QueueType};
use crate::cache::object::{BackgroundEvent, CacheMultipleData, EventType, EvictionQueue};

const WINDOW_CAPACITY: f64 = 0.10;
const PROBATION_CAPACITY: f64 = 0.45;

#[derive(Debug, Clone)]
pub struct CacheWorkerPutMessage {
    caches: Vec<cache::object::CacheMultipleData>,
}

impl CacheWorkerPutMessage {
    pub fn new(caches: Vec<cache::object::CacheMultipleData>) -> Self {
        Self { caches }
    }
}

fn build_data_store(maximum_node: usize) -> Arc<DashMap<u64, usize>> {
    let capacity = (maximum_node as f64 / 0.75).ceil() as usize;
    let data_store: DashMap<u64, usize> = DashMap::with_capacity(capacity);

    Arc::new(data_store)
}

#[derive(Debug)]
pub struct CacheWorker {
    // The store of cache data.
    pub data_store: Arc<DashMap<u64, usize>>,

    // The buffer for all cache node to execute eviction.
    pub node_buffer: Vec<Arc<Mutex<CacheNode<CacheMultipleData>>>>,

    // The builder to make cache node that have weak reference or strong reference.
    pub node_factory: NodeFactory<CacheMultipleData>,

    // Total weight of the cache.
    pub current_weight: AtomicUsize,

    // The object to enable background cleanup of old cache data.
    pub event_sender: mpsc::UnboundedSender<BackgroundEvent>,

    // The sender for to send put event message.
    pub event_put_sender: tokio::sync::mpsc::Sender<CacheWorkerPutMessage>,

    pub window_queue: EvictionQueue,
    pub probation_queue: EvictionQueue,
    pub protected_queue: EvictionQueue,

    pub frequency_sketch: Arc<Mutex<FrequencySketch>>,
}

impl CacheWorker {
    pub fn new(maximum_weight: usize) -> Arc<RwLock<Self>> {
        // Build store of cache data.
        let maximum_node = (maximum_weight as f64 / MEAN_WEIGHT as f64).ceil() as usize;
        let data_store = build_data_store(maximum_node);
        let node_buffer: Vec<Arc<Mutex<CacheNode<CacheMultipleData>>>> = Vec::new();
        let current_weight = AtomicUsize::new(0);
        let node_factory = NodeFactory::<CacheMultipleData>::new();

        // Build channel to clean up old cache data.
        let (sender, receiver) = mpsc::unbounded_channel::<BackgroundEvent>();

        // Compute capacity of eviction list.
        let window_maximum_capacity = (maximum_weight as f64 * WINDOW_CAPACITY).round() as usize;
        let probation_maximum_capacity = ((maximum_weight - window_maximum_capacity) as f64
            * PROBATION_CAPACITY)
            .round() as usize;
        let protected_maximum_capacity =
            maximum_weight - window_maximum_capacity - probation_maximum_capacity;

        // Initialize frequency sketch.
        let width = (2 * maximum_node).div_ceil(8).next_power_of_two();
        let frequency_sketch = FrequencySketch::new(width as u64, maximum_node as u64);

        // Build sender and receiver for putting cache.
        let (tx, mut rx) = tokio::sync::mpsc::channel::<CacheWorkerPutMessage>(1024);

        let worker = CacheWorker {
            data_store,
            node_buffer,
            node_factory,
            current_weight,
            event_sender: sender,
            event_put_sender: tx,
            window_queue: EvictionQueue::new(window_maximum_capacity),
            probation_queue: EvictionQueue::new(probation_maximum_capacity),
            protected_queue: EvictionQueue::new(protected_maximum_capacity),
            frequency_sketch,
        };

        let worker_arc = Arc::new(RwLock::new(worker));

        // launch maintenance tasks in asynchronous runtime.
        let worker_arc_for_task = worker_arc.clone();
        tokio::spawn(async move {
            Self::maintenance_loop(worker_arc_for_task, receiver).await;
        });

        let worker_inner = worker_arc.clone();
        tokio::spawn(async move {
            while let Some(msg) = rx.recv().await {
                let mut guard = worker_inner.write().await;
                guard.multiple_put(msg.caches);
            }
        });

        worker_arc
    }

    pub fn get(&self, key: u64) -> Option<CacheMultipleData> {
        // If target node is not exist, skip process.
        let target_index = match self.data_store.get(&key) {
            Some(entry) => *entry.value(),
            None => return None,
        };

        // Get node from node buffer
        if let Some(target_node_mutex) = self.node_buffer.get(target_index) {
            let target_node_mutex_clone = target_node_mutex.clone();
            let frequency_sketch_clone = self.frequency_sketch.clone();
            let event_sender_clone = self.event_sender.clone();
            let target_node = target_node_mutex
                .lock()
                .expect("Failed to lock target node.");

            // Check expiry time. If expired, return None.
            // It will be treated as cache miss, and overwritten upon next put, or removed by TinyLFU.
            if let Some(expire_time) = target_node.get_expire_time() {
                if chrono::Utc::now().timestamp() > expire_time {
                    return None;
                }
            }

            let value = target_node.get_value();
            let value_clone = value.clone();

            tokio::task::spawn_blocking(move || {
                let target_node_clone = target_node_mutex_clone
                    .lock()
                    .expect("Failed to lock target node.");
                let mut sketch = frequency_sketch_clone
                    .lock()
                    .expect("Failed to lock frequency sketch.");

                // Update frequnecy sketch.
                sketch.increment(&value_clone);

                if target_node_clone.in_probation() {
                    if let Some(err) = event_sender_clone
                        .send(BackgroundEvent::new(
                            target_index,
                            EventType::Promotion(QueueType::Probation),
                        ))
                        .err()
                    {
                        eprintln!("Failed to send probation event. {:?}", err);
                    }
                }

                if target_node_clone.in_protected() {
                    if let Some(err) = event_sender_clone
                        .send(BackgroundEvent::new(
                            target_index,
                            EventType::Promotion(QueueType::Protected),
                        ))
                        .err()
                    {
                        eprintln!("Failed to send protected event. {:?}", err);
                    }
                }
            });

            return Some(value);
        }

        None
    }

    pub async fn send_put_message(&self, caches: Vec<cache::object::CacheMultipleData>) {
        let sender_clone = self.event_put_sender.clone();
        let event_msg = CacheWorkerPutMessage::new(caches);

        if let Some(err) = sender_clone.send(event_msg).await.err() {
            eprintln!("Failed to send message to put cache. {:?}", err);
        }
    }

    pub fn multiple_put(&mut self, caches: Vec<cache::object::CacheMultipleData>) {
        for cache in caches.into_iter() {
            // Place cache data will be expired after 24 hours.
            let expires_at = chrono::Utc::now() + chrono::Duration::hours(24);

            let result = self.put(cache.get_key(), cache, Some(expires_at.timestamp()));

            if let Some(e) = result.err() {
                eprintln!("Failed cache put. {:?}", e);
            }
        }
    }

    pub fn put(
        &mut self,
        key: u64,
        value: CacheMultipleData,
        expire_time: Option<i64>,
    ) -> Result<()> {
        let weight = value.get_weight();

        // 1. Attempt to find an existing entry for the key
        let existing_index = self.data_store.get(&key).map(|e| *e.value());

        if let Some(index) = existing_index {
            // --- OVERWRITE LOGIC ---
            // Get metadata before detaching to ensure consistency
            let old_metadata = {
                let mutex = self.node_buffer.get(index).unwrap();
                if let Ok(mut node) = mutex.lock() {
                    let metadata = (node.get_weight(), node.get_queue_type());
                    // Update the actual data in the existing node
                    node.update_value(value, weight, expire_time);
                    Some(metadata)
                } else {
                    None
                }
            };

            if let Some((old_weight, old_q)) = old_metadata {
                // Detach from the old LRU position
                self.detach_node(index, old_q, old_weight);
                // Adjust global weight counters
                self.current_weight.fetch_sub(old_weight, Ordering::SeqCst);
                self.current_weight.fetch_add(weight, Ordering::SeqCst);

                // Re-insert at the front of the Window queue
                if let Ok(mut node) = self.node_buffer[index].lock() {
                    node.set_queue_type(QueueType::Window);
                }
                self.push_front_logic(index, weight as u64, QueueType::Window)?;
                self.check_and_evict()?;
            }
        } else {
            // --- NEW INSERTION LOGIC ---
            let index = self.node_buffer.len();
            let mutex = self
                .node_factory
                .build(value, weight, QueueType::Window, expire_time);

            if let Ok(mut node) = mutex.lock() {
                node.set_index(index);
            }

            // Register in the data_store and append to the node_buffer
            self.data_store.insert(key, index);
            self.node_buffer.push(mutex);
            self.current_weight.fetch_add(weight, Ordering::SeqCst);

            // Position the new node at the front of the Window queue
            self.push_front_logic(index, weight as u64, QueueType::Window)?;
            // Perform TinyLFU eviction if capacity is exceeded
            self.check_and_evict()?;
        }

        Ok(())
    }

    fn set_node_state(&mut self, node_index: usize, node_state: NodeState) {
        let node_mutex = self.node_buffer.get_mut(node_index).unwrap();

        match node_mutex.lock() {
            Ok(mut node) => {
                node.change_state(node_state);
            }
            Err(poisoned) => {
                println!("Faield change state in set note state: {:?}", poisoned);
            }
        }
    }

    fn get_frequency(&self, index: usize) -> Option<u64> {
        let node_mutex = self.node_buffer.get(index)?;
        match node_mutex.lock() {
            Ok(node) => {
                let node_value = node.get_value();

                match self.frequency_sketch.lock() {
                    Ok(frequency_sketch) => {
                        return Some(frequency_sketch.frequency(node_value));
                    }
                    Err(_) => return None,
                }
            }
            Err(_) => None,
        }
    }

    fn check_and_evict(&mut self) -> Result<()> {
        while self.window_queue.current_capacity > self.window_queue.maximum_capacity {
            let (evicted_node_index, evicted_weight) = match self.pop_tail_logic(QueueType::Window)
            {
                Some(v) => v,
                None => break,
            };

            // Get frequency of the node being pushed out of the Window
            let window_frequency = self.get_frequency(evicted_node_index).unwrap_or(0);

            // Get frequency of the victim candidate in the Probation queue
            let lru_node_index = self.probation_queue.tail_index;
            let lru_frequency = lru_node_index.and_then(|idx| self.get_frequency(idx));

            // W-TinyLFU Admission Policy
            let admit = match lru_frequency {
                Some(lf) => window_frequency > lf,
                None => true, // Admit if Probation is empty
            };

            if admit {
                // Move to Main Space (Probation)
                self.set_node_queue_type(evicted_node_index, QueueType::Probation); // Corrected to Probation

                self.push_front_logic(
                    evicted_node_index,
                    evicted_weight as u64,
                    QueueType::Probation,
                )?;

                // Check if Main Space is now over capacity
                self.check_main_space_capacity_and_evict()?;
            } else {
                // REJECT: Properly retire and clean up the node
                // This is essential to prevent memory leaks and maintain correct weight counts
                self.set_node_state(evicted_node_index, NodeState::Retired);

                // Send cleanup event to background task
                self.event_sender
                    .send(BackgroundEvent::new(evicted_node_index, EventType::Cleanup))
                    .expect("Failed to send cleanup task");

                // Subtract weight from total current weight
                self.current_weight
                    .fetch_sub(evicted_weight, Ordering::SeqCst);
            }
        }

        Ok(())
    }

    fn check_main_space_capacity_and_evict(&mut self) -> Result<()> {
        let mut current_main_weight =
            self.probation_queue.current_capacity + self.protected_queue.current_capacity;
        let max_main_weight =
            self.probation_queue.maximum_capacity + self.protected_queue.maximum_capacity;

        while current_main_weight > max_main_weight {
            // First, attempt to evict from the Probation queue (the admission pool)
            if let Some((idx, weight)) = self.pop_tail_logic(QueueType::Probation) {
                self.set_node_state(idx, NodeState::Retired);

                // Send cleanup event to physically remove data and update data_store
                self.event_sender
                    .send(BackgroundEvent::new(idx, EventType::Cleanup))
                    .expect("Failed to send cleanup task");

                self.current_weight.fetch_sub(weight, Ordering::SeqCst);
                current_main_weight -= weight;
            }
            // If Probation is empty, we must degrade a node from Protected to Probation first
            else if self.protected_queue.current_capacity > self.protected_queue.maximum_capacity
            {
                if let Some((idx, weight)) = self.pop_tail_logic(QueueType::Protected) {
                    // IMPORTANT: Sync the node's internal state to the new queue type
                    self.set_node_queue_type(idx, QueueType::Probation);

                    self.push_front_logic(idx, weight as u64, QueueType::Probation)?;
                    // Total main weight doesn't change, but it will be evicted in the next iteration
                } else {
                    break;
                }
            } else {
                break;
            }
        }
        Ok(())
    }

    fn set_node_queue_type(&mut self, node_index: usize, queue_type: QueueType) {
        let node_mutex = self.node_buffer.get_mut(node_index).unwrap();

        match node_mutex.lock() {
            Ok(mut node) => {
                node.set_queue_type(queue_type);
            }
            Err(poisoned) => {
                println!("noe mutex poisoned: {:?}", poisoned);
            }
        }
    }

    fn push_front_logic(
        &mut self,
        new_node_index: usize,
        target_weight: u64,
        target_queue_type: QueueType,
    ) -> Result<()> {
        let target_queue = self.get_queue_mut(target_queue_type.clone());

        let old_head_index = target_queue.head_index;

        // Update new node.
        if let Some(mutex) = self.node_buffer.get(new_node_index) {
            if let Ok(mut node) = mutex.lock() {
                node.set_next_index(old_head_index);
                node.set_prev_index(None);
            }
        }

        // Update old head.
        if let Some(old_h_idx) = old_head_index {
            if let Some(mutex) = self.node_buffer.get(old_h_idx) {
                if let Ok(mut node) = mutex.lock() {
                    node.set_prev_index(Some(new_node_index));
                }
            }
        }

        // Update queue pointers.
        let queue = self.get_queue_mut(target_queue_type);
        queue.head_index = Some(new_node_index);

        if queue.tail_index.is_none() {
            queue.tail_index = Some(new_node_index);
        }
        queue.current_capacity += target_weight as usize;

        Ok(())
    }

    fn pop_tail_logic(&mut self, queue_type: QueueType) -> Option<(usize, usize)> {
        let queue = self.get_queue_mut(queue_type.clone());
        let tail_idx = queue.tail_index?;

        let (weight, prev_idx) = {
            let mutex = self.node_buffer.get(tail_idx)?;
            let node = mutex.lock().ok()?;
            (node.get_weight(), node.get_prev_index())
        };

        // Detail tail
        let queue = self.get_queue_mut(queue_type);
        queue.tail_index = prev_idx;
        queue.current_capacity = queue.current_capacity.saturating_sub(weight);

        if let Some(p_idx) = prev_idx {
            if let Some(mutex) = self.node_buffer.get(p_idx) {
                if let Ok(mut node) = mutex.lock() {
                    node.set_next_index(None);
                }
            }
        } else {
            queue.head_index = None;
        }

        Some((tail_idx, weight))
    }

    fn run_cleanup_task(&mut self, event: &BackgroundEvent) {
        // 1. Acquire the lock on the target node to mark it as Dead and retrieve its key
        let key_to_remove = if let Some(node_mutex) = self.node_buffer.get(event.node_index) {
            match node_mutex.lock() {
                Ok(mut node) => {
                    // Ensure the node is marked as Dead to prevent any future access from GET
                    node.change_state(NodeState::Dead);
                    Some(node.get_key())
                }
                Err(poisoned) => {
                    eprintln!("Cache node poisoned: {:?}", poisoned);
                    None
                }
            }
        } else {
            None
        };

        // 2. Physically remove the entry from the lookup map (DashMap)
        // Without this, future GET calls for this key would return a Dead node index.
        if let Some(key) = key_to_remove {
            self.data_store.remove(&key);
        }

        // NOTE: We do not subtract current_weight here because it's already
        // subtracted synchronously by the eviction loops (`check_and_evict`
        // and `check_main_space_capacity_and_evict`) before this task runs.
    }

    async fn maintenance_loop(
        worker_arc: Arc<RwLock<Self>>,
        mut receiver: mpsc::UnboundedReceiver<BackgroundEvent>,
    ) {
        while let Some(event) = receiver.recv().await {
            // Execute cleanup logic. Rock thread for writing cache when only receive event.
            let mut worker = worker_arc.write().await;
            match event.event_type {
                EventType::Cleanup => worker.run_cleanup_task(&event),
                EventType::Promotion(q) => {
                    worker.execute_promotion(event.node_index, q, QueueType::Protected)
                }
            }
        }
    }

    fn execute_promotion(
        &mut self,
        node_index: usize,
        current_queue_type: QueueType,
        promotion_queue_type: QueueType,
    ) {
        // Get current weight of the specific node.
        let weight = match self.node_buffer.get(node_index) {
            Some(m) => m.lock().unwrap().get_weight(),
            None => return,
        };

        // Detach the specific node from its current position
        self.detach_node(node_index, current_queue_type, weight);

        // Update the nodes's internal stats.
        if let Ok(mut target_node) = self.node_buffer[node_index].lock() {
            target_node.set_queue_type(promotion_queue_type.clone());
        }

        // Push to the front of the target queue.
        let _ = self.push_front_logic(node_index, weight as u64, promotion_queue_type);
    }

    fn detach_node(&mut self, index: usize, q_type: QueueType, weight: usize) {
        let (prev, next) = {
            let node = self.node_buffer[index].lock().expect("Lock fail");
            (node.get_prev_index(), node.get_next_index())
        };

        // Reconnect to previous and next node.
        if let Some(prev) = prev {
            if let Ok(mut n) = self.node_buffer[prev].lock() {
                n.set_next_index(next);
            }
        }
        if let Some(next) = next {
            if let Ok(mut n) = self.node_buffer[next].lock() {
                n.set_prev_index(prev);
            }
        }

        // Update head and tail of queue.
        let queue = self.get_queue_mut(q_type);
        if queue.head_index == Some(index) {
            queue.head_index = next;
        }
        if queue.tail_index == Some(index) {
            queue.tail_index = prev;
        }

        queue.current_capacity = queue.current_capacity.saturating_sub(weight);
    }

    fn get_queue_mut(&mut self, q_type: QueueType) -> &mut EvictionQueue {
        match q_type {
            QueueType::Window => &mut self.window_queue,
            QueueType::Probation => &mut self.probation_queue,
            QueueType::Protected => &mut self.protected_queue,
        }
    }
}
