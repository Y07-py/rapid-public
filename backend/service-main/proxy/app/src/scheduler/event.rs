use std::sync::Arc;

use aws_config;
use aws_sdk_scheduler;
use aws_sdk_scheduler::types::{ActionAfterCompletion, FlexibleTimeWindow, Target};
use chrono;

use crate::db;

#[derive(Clone)]
pub struct AmazonEventScheduleManager {
    client: aws_sdk_scheduler::Client,
    pg_repository: Arc<db::repository::PostgresRepository>,
}

impl AmazonEventScheduleManager {
    pub async fn new(pg_repository: Arc<db::repository::PostgresRepository>) -> Self {
        let config = aws_config::defaults(aws_config::BehaviorVersion::latest())
            .region(aws_config::Region::new("ap-south-1"))
            .load()
            .await;

        let client = aws_sdk_scheduler::Client::new(&config);

        Self {
            client,
            pg_repository,
        }
    }

    /// Update or create the voice chat aggregation scheduler.
    /// This scheduler triggers the `make_voice_chat_event` Lambda at 3:00 AM JST.
    pub async fn update_voice_chat_aggregation_scheduler(&self) -> Result<(), String> {
        let jst = chrono::FixedOffset::east_opt(9 * 3600).ok_or("Failed to create JST offset")?;
        let now = chrono::Utc::now().with_timezone(&jst);

        // Calculate the next 3:00 AM JST.
        // If it's currently past 3:00 AM, the next run should be tomorrow at 3:00 AM.
        let mut next_run = now
            .date_naive()
            .and_hms_opt(3, 0, 0)
            .ok_or("Failed to create next run time")?
            .and_local_timezone(jst)
            .single()
            .ok_or("Failed to localize next run time")?;

        if next_run <= now {
            next_run = next_run + chrono::Duration::days(1);
        }

        let expression = format!("at({})", next_run.format("%Y-%m-%dT%H:%M:%S"));
        let schedule_name = "voice-chat-aggregation-scheduler";
        let lambda_arn = "arn:aws:lambda:ap-south-1:523199240655:function:make_voice_chat_event";
        let role_arn = "arn:aws:iam::523199240655:role/EventBridgeSchedulerLambdaRole";

        let target = Target::builder()
            .arn(lambda_arn)
            .role_arn(role_arn)
            .build()
            .map_err(|e| e.to_string())?;

        let flexible_time_window = FlexibleTimeWindow::builder()
            .mode(aws_sdk_scheduler::types::FlexibleTimeWindowMode::Off)
            .build()
            .map_err(|e| e.to_string())?;

        // Try creating the schedule first.
        let create_res = self
            .client
            .create_schedule()
            .name(schedule_name)
            .schedule_expression(&expression)
            .schedule_expression_timezone("Asia/Tokyo")
            .target(target.clone())
            .flexible_time_window(flexible_time_window.clone())
            .action_after_completion(ActionAfterCompletion::Delete)
            .send()
            .await;

        match create_res {
            Ok(_) => {
                println!(
                    "Successfully created schedule '{}' for {}.",
                    schedule_name, expression
                );
                Ok(())
            }
            Err(e) => {
                let err_msg = e.to_string();
                if err_msg.contains("ConflictException") || err_msg.contains("already exists") {
                    println!(
                        "Schedule '{}' already exists. Updating it to {}.",
                        schedule_name, expression
                    );
                    self.client
                        .update_schedule()
                        .name(schedule_name)
                        .schedule_expression(&expression)
                        .schedule_expression_timezone("Asia/Tokyo")
                        .target(target)
                        .flexible_time_window(flexible_time_window)
                        .action_after_completion(ActionAfterCompletion::Delete)
                        .send()
                        .await
                        .map(|_| ())
                        .map_err(|e| e.to_string())
                } else {
                    Err(format!("Failed to create schedule: {}", err_msg))
                }
            }
        }
    }
}
