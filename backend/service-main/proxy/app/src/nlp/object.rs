use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AnalyzeSentimentRequestParamater {
    pub document: AnalyzeDocument,
    pub encoding_type: AnalyzeEncodingType,
}

impl AnalyzeSentimentRequestParamater {
    pub fn new(content: &str, content_uri: Option<&str>) -> Self {
        let document = AnalyzeDocument::new(content, content_uri);
        let encoding_type = AnalyzeEncodingType::Utf8;

        Self {
            document,
            encoding_type,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AnalyzeModerateRequestParamater {
    pub document: AnalyzeDocument,
    pub model_version: AnalyzeModelVersion,
}

impl AnalyzeModerateRequestParamater {
    pub fn new(content: &str, content_uri: Option<&str>) -> Self {
        let document = AnalyzeDocument::new(content, content_uri);
        let model_version = AnalyzeModelVersion::ModelVersion2;

        Self {
            document,
            model_version,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AnalyzeDocument {
    pub r#type: AnalyzeDocumentType,
    pub language_code: String,
    pub content: String,
    pub gcs_content_uri: Option<String>,
}

impl AnalyzeDocument {
    pub fn new(content: &str, content_uri: Option<&str>) -> Self {
        let document_type = AnalyzeDocumentType::PlainText;
        let language_code = "ja".to_string();

        Self {
            r#type: document_type,
            language_code,
            content: content.to_string(),
            gcs_content_uri: Some(content_uri.unwrap_or_default().to_string()),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum AnalyzeDocumentType {
    TypeUnSpecified,
    PlainText,
    HTML,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum AnalyzeModelVersion {
    ModelVersionUnspecified,
    ModelVersion1,
    ModelVersion2,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum AnalyzeEncodingType {
    None,
    Utf8,
    Utf16,
    Utf32,
}

// Analyze Sentiment Response
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AnalyzeSentimentDocumentResponse {
    pub document_sentiment: AnalyzeSentimentDocumentSentiment,
    pub language_code: String,
    pub sentences: Option<Vec<AnalyzeSentimentDocumentSentence>>,
    pub language_supported: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalyzeSentimentDocumentSentiment {
    pub magnitude: f64,
    pub score: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalyzeSentimentDocumentSentence {
    pub text: AnalyzeTextSpan,
    pub sentiment: AnalyzeSentimentDocumentSentiment,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AnalyzeTextSpan {
    pub content: String,
    pub begin_offset: i64,
}

// Analyze Moderate Response
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AnalyzeModerateDocumentResponse {
    pub moderation_categories: Vec<AnalyzeModerateClassificationCategory>,
    pub language_code: String,
    pub language_supported: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalyzeModerateClassificationCategory {
    pub name: String,
    pub confidence: f64,
    pub severity: Option<f64>,
}
