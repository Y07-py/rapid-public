use crossbeam_channel;
use tokio;

use std::hash::{DefaultHasher, Hash, Hasher};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

use crate::cache;

const RESET_MASK: u64 = 0x7777777777777777;
const ONE_MASK: u64 = 0x1111111111111111;

struct ResetEvent {}

impl ResetEvent {
    pub fn new() -> Self {
        Self {}
    }
}

#[derive(Debug, Clone)]
pub struct FrequencySketch {
    sample_size: u64,
    block_mask: u64,
    table: Arc<[AtomicU64]>,
    size: u64,
    reset_sender: crossbeam_channel::Sender<ResetEvent>,
}

impl FrequencySketch {
    pub fn new(width: u64, sample_size: u64) -> Arc<Mutex<Self>> {
        let size = width;
        let atomic_vec: Vec<AtomicU64> = (0..size).map(|_| AtomicU64::new(0)).collect();
        let table: Arc<[AtomicU64]> = atomic_vec.into();
        let block_mask = ((table.len() >> 3) - 1) as u64;

        // Background worker channel
        let (sender, receiver) = crossbeam_channel::unbounded::<ResetEvent>();

        let worker = Self {
            sample_size,
            block_mask: block_mask,
            table,
            size,
            reset_sender: sender,
        };

        let worker_arc = Arc::new(Mutex::new(worker));

        let worker_arc_clone = worker_arc.clone();
        tokio::spawn(async move {
            tokio::task::spawn_blocking(move || {
                loop {
                    match receiver.recv() {
                        Ok(_) => {
                            let mut worker =
                                worker_arc_clone.try_lock().expect("Failed reset event");

                            worker.reset();
                        }
                        Err(e) => {
                            eprintln!("Failed receive event.: {:?}", e);
                        }
                    }
                }
            })
        });

        worker_arc
    }

    pub fn frequency(&self, v: cache::object::CacheMultipleData) -> u64 {
        let mut hasher = DefaultHasher::new();
        v.hash(&mut hasher);
        let block_hash = self.spread(hasher.finish());
        let counter_hash = self.rehash(block_hash);
        let block = (block_hash & self.block_mask) << 3;

        let mut frequency = u64::MAX;

        for i in 0..4 {
            let h = counter_hash >> (i << 3);
            let index = (h >> 1) & 15;
            let offset = h & 1;
            let slot = block + offset + (i << 1);
            let count = (self.table[slot as usize].load(Ordering::Relaxed) >> (index << 2)) & 0xf;
            frequency = u64::min(frequency, count);
        }

        frequency
    }

    pub fn increment(&mut self, v: &cache::object::CacheMultipleData) {
        let mut hasher = DefaultHasher::new();
        v.hash(&mut hasher);
        let block_hash = self.spread(hasher.finish());
        let counter_hash = self.rehash(block_hash);
        let block = (block_hash & self.block_mask) << 3;

        let h0 = counter_hash;
        let h1 = counter_hash >> 8;
        let h2 = counter_hash >> 16;
        let h3 = counter_hash >> 24;

        let index0 = (h0 >> 1) & 15;
        let index1 = (h1 >> 1) & 15;
        let index2 = (h2 >> 1) & 15;
        let index3 = (h3 >> 1) & 15;

        let slot0 = block + (h0 & 1);
        let slot1 = block + (h1 & 1) + 2;
        let slot2 = block + (h2 & 1) + 4;
        let slot3 = block + (h3 & 1) + 6;

        let added = self.increment_at(slot0, index0)
            | self.increment_at(slot1, index1)
            | self.increment_at(slot2, index2)
            | self.increment_at(slot3, index3);

        if added && (self.size + 1 == self.sample_size) {
            self.size += 1;
            self.reset_sender
                .try_send(ResetEvent::new())
                .expect("Failed send reset event.");
        }
    }

    fn spread(&self, mut x: u64) -> u64 {
        x ^= x >> 17;
        x *= 0xed5ab4bb;
        x ^= x >> 11;
        x *= 0xac4c1b51;
        x ^= x >> 15;

        x
    }

    fn rehash(&self, mut x: u64) -> u64 {
        x *= 0x31848bab;
        x ^= x >> 14;

        x
    }

    fn increment_at(&mut self, i: u64, j: u64) -> bool {
        let offset = j << 2;
        let mask = 0xf << offset;

        self.table[i as usize]
            .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |current_value| {
                if current_value & mask != mask {
                    let new_value = current_value + (1 << offset);
                    Some(new_value)
                } else {
                    None
                }
            })
            .is_ok()
    }

    fn reset(&mut self) {
        let mut count: u64 = 0;
        for i in 0..self.table.len() {
            count += ((self.table[i].load(Ordering::Relaxed) & ONE_MASK).ilog2() + 1) as u64;
            let _ =
                self.table[i].fetch_update(Ordering::Relaxed, Ordering::Relaxed, |current_value| {
                    let new_value = (current_value >> 1) & RESET_MASK;
                    Some(new_value)
                });
        }
        self.size = (self.size - (count >> 2)) >> 1;
    }
}
