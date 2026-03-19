use std::{str::FromStr, sync::Arc};

use aws_config;
use aws_sdk_sns;

use crate::{db, sns};

#[derive(Clone)]
pub struct SnsVoIPManager {
    client: aws_sdk_sns::Client,
    voip_arn: String,
    pg_repository: Arc<db::repository::PostgresRepository>,
}

impl SnsVoIPManager {
    pub async fn new(pg_repository: Arc<db::repository::PostgresRepository>) -> Self {
        let voip_arn = std::env::var("AWS_SNS_VOIP_ARN").unwrap();
        let config = aws_config::defaults(aws_config::BehaviorVersion::latest())
            .load()
            .await;

        Self {
            client: aws_sdk_sns::Client::new(&config),
            voip_arn: voip_arn,
            pg_repository,
        }
    }

    pub async fn regist_voip_device(
        &self,
        device: &sns::object::DeviceToken,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let result = self
            .client
            .create_platform_endpoint()
            .platform_application_arn(&self.voip_arn)
            .token(&device.device_token)
            .send()
            .await?;

        let arn_endpoint = result.endpoint_arn.unwrap_or_default().to_string();

        let user_device = self.make_user_device(
            &device.user_id.to_string(),
            &device.device_token,
            &arn_endpoint,
        );

        self.pg_repository.insert_user_device(&user_device).await?;

        Ok(())
    }

    fn make_user_device(
        &self,
        user_id: &str,
        device_token: &str,
        arn_endpoint: &str,
    ) -> db::object::UserDevice {
        let user_id_uuid = uuid::Uuid::from_str(user_id).unwrap();
        let user_device =
            db::object::UserDevice::new(&user_id_uuid, arn_endpoint, device_token, "ios");

        user_device
    }

    pub async fn send_call_message(
        &self,
        payload: &sns::object::CallPayload,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let apns_string = serde_json::to_string(payload)?;
        let sns_payload =
            sns::object::SnsMessage::new("Incoming Call".to_string(), apns_string, true);
        let body = serde_json::to_string(&sns_payload)?;

        if let Some(user_device) = self
            .pg_repository
            .select_user_device(&payload.get_handle_with_uuid())
            .await?
        {
            let endpoint_arn = user_device.voip_endpoint_arn;
            let push_type_attr = aws_sdk_sns::types::MessageAttributeValue::builder()
                .data_type("String")
                .string_value("voip")
                .build()?;
            let response = self
                .client
                .publish()
                .target_arn(endpoint_arn)
                .message(body)
                .message_structure("json")
                .message_attributes("AWS.SNS.MOBILE.APNS.PUSH_TYPE", push_type_attr)
                .send()
                .await?;

            println!(
                "Successfully to send voip message: {:?}",
                response.message_id()
            );
        }

        Ok(())
    }
}
