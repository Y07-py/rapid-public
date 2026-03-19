use base64;
use base64::Engine;
use std::sync::Arc;

use crate::http;
use crate::vision::object;
use serde_json;

pub struct VisionClient {
    http_client: Arc<http::request::HttpClient>,
    api_key: String,
}

impl VisionClient {
    pub fn new(http_client: Arc<http::request::HttpClient>) -> Self {
        let api_key = std::env::var("GMS_API_KEY").expect("GMS_API_KEY must be set");
        Self {
            http_client,
            api_key,
        }
    }

    async fn analyze_image(
        &self,
        path: &str,
    ) -> Result<object::VisionResponse, Box<dyn std::error::Error>> {
        let bytes = std::fs::read(path)?;
        let content = base64::engine::general_purpose::STANDARD.encode(bytes);

        let request_payload = object::VisionRequest {
            requests: vec![object::AnnotateImageRequest {
                image: object::ImageSource { content },
                features: vec![
                    object::Feature {
                        feature_type: "SAFE_SEARCH_DETECTION".to_string(),
                    },
                    object::Feature {
                        feature_type: "LABEL_DETECTION".to_string(),
                    },
                ],
            }],
        };

        let url = format!(
            "https://vision.googleapis.com/v1/images:annotate?key={}",
            self.api_key
        );

        let response = self
            .http_client
            .post(&url, None, None, request_payload, None)
            .await
            .map_err(|e| format!("Vision API request failed: {:?}", e))?;

        if response.is_success() {
            let vision_response: object::VisionResponse = response.get_body().ok_or_else(|| {
                format!(
                    "Failed to parse Vision API response: {}",
                    response.get_body_as_string().unwrap_or_default()
                )
            })?;
            Ok(vision_response)
        } else {
            Err(format!(
                "Vision API returned error {}: {}",
                response.get_status_code(),
                response.get_body_as_string().unwrap_or_default()
            )
            .into())
        }
    }

    pub async fn analyze_and_report(
        &self,
        image_id: &str,
        user_id: &str,
        path: &str,
    ) -> Result<bool, Box<dyn std::error::Error>> {
        println!("🔍 [Vision API] Analyzing image: {}", path);
        let response = self.analyze_image(path).await?;

        // Take only the first response to avoid potential duplicate reports per image
        if let Some(res) = response.responses.into_iter().next() {
            if let Some(safe_search) = res.safe_search_annotation {
                println!(
                    "🛡️ [Vision API] Safe Search: Adult={}, Spoof={}, Medical={}, Violence={}, Racy={}",
                    safe_search.adult,
                    safe_search.spoof,
                    safe_search.medical,
                    safe_search.violence,
                    safe_search.racy
                );

                let suspicious_levels = ["POSSIBLE", "LIKELY", "VERY_LIKELY"];
                let is_suspicious = suspicious_levels.contains(&safe_search.adult.as_str())
                    || suspicious_levels.contains(&safe_search.spoof.as_str())
                    || suspicious_levels.contains(&safe_search.medical.as_str())
                    || suspicious_levels.contains(&safe_search.violence.as_str())
                    || suspicious_levels.contains(&safe_search.racy.as_str());

                if is_suspicious {
                    let labels = res.label_annotations.map(|ls| {
                        serde_json::Value::Array(
                            ls.into_iter()
                                .map(|l| {
                                    serde_json::json!({
                                        "description": l.description,
                                        "score": l.score
                                    })
                                })
                                .collect(),
                        )
                    });

                    let payload = serde_json::json!({
                        "image_id": image_id,
                        "user_id": user_id,
                        "safe_search": {
                            "adult": safe_search.adult,
                            "spoof": safe_search.spoof,
                            "medical": safe_search.medical,
                            "violence": safe_search.violence,
                            "racy": safe_search.racy,
                        },
                        "labels": labels,
                    });

                    // Send to activity-log service
                    let client = reqwest::Client::new();
                    let result = client
                        .post("http://10.0.4.117:8081/admin/review/report")
                        .json(&payload)
                        .send()
                        .await;

                    match result {
                        Ok(_) => println!(
                            "✅ [Proxy] Sent suspicious image report to activity-log for image {}",
                            image_id
                        ),
                        Err(e) => {
                            eprintln!("❌ [Proxy] Failed to send report to activity-log: {:?}", e)
                        }
                    }

                    // Return false if suspicious
                    return Ok(false);
                }
            }
        }

        // Return true if safe or no data found
        Ok(true)
    }
}
