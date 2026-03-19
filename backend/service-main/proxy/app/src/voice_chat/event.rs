use std::sync::Arc;

use actix_web::web;
use tokio::sync::RwLock;

use crate::voice_chat;

pub async fn enter_voice_chat_user(
    user: &voice_chat::object::WaitingUser,
    waiting_queue: web::Data<Arc<RwLock<voice_chat::waiting::WaitingQueue>>>,
) -> Option<voice_chat::object::WaitingUser> {
    let mut queue = waiting_queue.write().await;
    if let Some((other, _)) = queue.pop(user) {
        Some(other)
    } else {
        queue.push(user);
        None
    }
}

pub async fn delete_voice_chat_user(
    user: &voice_chat::object::WaitingUser,
    waiting_queue: web::Data<Arc<RwLock<voice_chat::waiting::WaitingQueue>>>,
) {
    let mut queue = waiting_queue.write().await;
    queue.delete(user);
}
