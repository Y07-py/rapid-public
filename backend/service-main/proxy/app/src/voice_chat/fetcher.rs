use std::sync::Arc;

use actix_web;
use tokio;

use crate::db;
use crate::recruitment;
use crate::voice_chat;
use crate::voice_chat::object::VoiceChatRoomWithRecruitment;

pub async fn fetch_voice_chat_room(
    paramater: &voice_chat::object::FetchVoiceChatRoomParamater,
    postgrest_client: actix_web::web::Data<Arc<db::postgrest::SupabsePostgrest>>,
) -> Result<Option<Vec<VoiceChatRoomWithRecruitment>>, String> {
    let blocked_ids = postgrest_client
        .fetch_blocked_user_ids(&paramater.user_id)
        .await?;

    let voice_chat_rooms = postgrest_client
        .select_voice_chat_rooms(
            paramater.page_offset,
            paramater.page_limit,
            paramater.filter.clone(),
            Some(blocked_ids),
        )
        .await?;

    if let Some(voice_chat_rooms) = voice_chat_rooms {
        let mut handles = Vec::new();
        for room in voice_chat_rooms {
            if room.user_id.to_string() == paramater.user_id.to_string() {
                continue;
            }
            let postgrest_client_clone = postgrest_client.clone();
            let handle: tokio::task::JoinHandle<Option<VoiceChatRoomWithRecruitment>> =
                tokio::spawn(async move {
                    let recruitment = if let Some(recruitment_id) = room.recruitment_id {
                        recruitment::fetch::fetch_recruitment_with_id(
                            &recruitment_id,
                            postgrest_client_clone,
                        )
                        .await
                        .ok()
                        .flatten()
                    } else {
                        None
                    };

                    let voice_chat_room = VoiceChatRoomWithRecruitment::new(room, recruitment);
                    Some(voice_chat_room)
                });

            handles.push(handle);
        }

        let results: Vec<Option<voice_chat::object::VoiceChatRoomWithRecruitment>> =
            futures_util::future::join_all(handles)
                .await
                .into_iter()
                .filter_map(|res| res.ok())
                .collect();

        let voice_chat_rooms: Vec<VoiceChatRoomWithRecruitment> =
            results.into_iter().filter_map(|p| p).collect();

        return Ok(Some(voice_chat_rooms));
    }

    Ok(None)
}
