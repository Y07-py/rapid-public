use std::sync::Arc;

use crate::http;
use crate::nlp::object;

pub struct NLPClient {
    http_client: Arc<http::request::HttpClient>,
    sentiment_endpoint: String,
    moderate_endpoint: String,
}

impl NLPClient {
    pub fn new(http_client: Arc<http::request::HttpClient>) -> Self {
        let sentiment_endpoint = std::env::var("GOOGLE_API_DOCUMENT_ANALYZE_SENTIMENT_ENDPOINT")
            .unwrap_or_else(|_| {
                "https://language.googleapis.com/v1/documents:analyzeSentiment".to_string()
            });
        let moderate_endpoint = std::env::var("GOOGLE_API_DOCUMENT_ANALYZE_MODERATE_ENDPOINT")
            .unwrap_or_else(|_| {
                "https://language.googleapis.com/v1/documents:moderateText".to_string()
            });

        Self {
            http_client,
            sentiment_endpoint,
            moderate_endpoint,
        }
    }

    pub async fn analyze_sentiment(
        &self,
        param: &object::AnalyzeSentimentRequestParamater,
    ) -> Result<Option<object::AnalyzeSentimentDocumentResponse>, String> {
        let header_flow = Box::new(http::object::GoogleDocumentAnalyzeHeader::new());
        let response = self
            .http_client
            .post(
                &self.sentiment_endpoint,
                None,
                None,
                param,
                Some(header_flow),
            )
            .await
            .map_err(|e| e.to_string())?;

        if response.get_status_code() == 200 {
            let body = response.get_body_as_string().unwrap();
            let result: object::AnalyzeSentimentDocumentResponse =
                serde_json::from_str(&body).map_err(|e| e.to_string())?;

            return Ok(Some(result));
        }

        Ok(None)
    }

    pub async fn analyze_moderate(
        &self,
        param: &object::AnalyzeModerateRequestParamater,
    ) -> Result<Option<object::AnalyzeModerateDocumentResponse>, String> {
        let header_flow = Box::new(http::object::GoogleDocumentAnalyzeHeader::new());
        let response = self
            .http_client
            .post(
                &self.moderate_endpoint,
                None,
                None,
                param,
                Some(header_flow),
            )
            .await
            .map_err(|e| e.to_string())?;

        if response.get_status_code() == 200 {
            let body = response.get_body_as_string().unwrap();
            let result: object::AnalyzeModerateDocumentResponse =
                serde_json::from_str(&body).map_err(|e| e.to_string())?;

            return Ok(Some(result));
        }

        Ok(None)
    }
}
