use std::cmp::Reverse;
use std::collections::HashMap;

use priority_queue;

use crate::voice_chat;

#[derive(Debug, Clone)]
pub struct WaitingQueue {
    place_queue: HashMap<String, QueueNode>,
}

impl WaitingQueue {
    pub fn new() -> Self {
        let place_queue = HashMap::new();

        Self { place_queue }
    }

    pub fn set_placeids(&mut self, place_ids: &Vec<String>) {
        for id in place_ids.iter() {
            let node = QueueNode::new();
            self.place_queue.insert(id.to_string(), node);
        }
    }

    pub fn remove_all(&mut self) {
        self.place_queue.clear();
    }

    pub fn push(&mut self, user: &voice_chat::object::WaitingUser) {
        if let Some(node) = self.place_queue.get_mut(&user.place_id.to_string()) {
            node.add(user);
        } else {
            let mut node = QueueNode::new();
            node.add(user);
            self.place_queue.insert(user.place_id.to_string(), node);
        }
    }

    pub fn pop(
        &mut self,
        user: &voice_chat::object::WaitingUser,
    ) -> Option<(
        voice_chat::object::WaitingUser,
        Reverse<chrono::DateTime<chrono::Utc>>,
    )> {
        if let Some(node) = self.place_queue.get_mut(&user.place_id.to_string()) {
            if let Some(other_user) = node.pop(&user.sex) {
                return Some(other_user);
            }
        }

        None
    }

    pub fn delete(&mut self, user: &voice_chat::object::WaitingUser) {
        if let Some(node) = self.place_queue.get_mut(&user.place_id.to_string()) {
            node.delete_user(user);
        }
    }
}

#[derive(Debug, Clone)]
struct QueueNode {
    man_queue: priority_queue::PriorityQueue<
        voice_chat::object::WaitingUser,
        Reverse<chrono::DateTime<chrono::Utc>>,
    >,
    woman_queue: priority_queue::PriorityQueue<
        voice_chat::object::WaitingUser,
        Reverse<chrono::DateTime<chrono::Utc>>,
    >,
}

impl QueueNode {
    pub fn new() -> Self {
        let man_queue = priority_queue::PriorityQueue::new();
        let woman_queue = priority_queue::PriorityQueue::new();

        Self {
            man_queue,
            woman_queue,
        }
    }

    pub fn delete_user(&mut self, user: &voice_chat::object::WaitingUser) {
        if user.sex == "man" {
            self.man_queue.remove(user);
        } else {
            self.woman_queue.remove(user);
        }
    }

    pub fn pop(
        &mut self,
        sex: &str,
    ) -> Option<(
        voice_chat::object::WaitingUser,
        Reverse<chrono::DateTime<chrono::Utc>>,
    )> {
        if sex == "woman" {
            return self.man_queue.pop();
        } else {
            return self.woman_queue.pop();
        }
    }

    pub fn add(&mut self, user: &voice_chat::object::WaitingUser) {
        let priority = Reverse(user.entered_at);
        if user.sex == "man" {
            self.man_queue.push(user.clone(), priority);
        } else {
            self.woman_queue.push(user.clone(), priority);
        }
    }
}
