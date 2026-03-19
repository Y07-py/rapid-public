use serde::{Deserialize, Serialize};

#[derive(Serialize)]
pub struct VisionRequest {
    pub requests: Vec<AnnotateImageRequest>,
}

#[derive(Serialize)]
pub struct AnnotateImageRequest {
    pub image: ImageSource,
    pub features: Vec<Feature>,
}

#[derive(Serialize)]
pub struct ImageSource {
    pub content: String,
}

#[derive(Serialize)]
pub struct Feature {
    #[serde(rename = "type")]
    pub feature_type: String,
}

#[derive(Deserialize, Debug)]
pub struct VisionResponse {
    pub responses: Vec<AnnotateImageResponse>,
}

#[derive(Deserialize, Debug)]
pub struct AnnotateImageResponse {
    #[serde(rename = "safeSearchAnnotation")]
    pub safe_search_annotation: Option<SafeSearchAnnotation>,
    #[serde(rename = "labelAnnotations")]
    pub label_annotations: Option<Vec<LabelAnnotation>>,
}

#[derive(Deserialize, Debug)]
pub struct SafeSearchAnnotation {
    pub adult: String,
    pub spoof: String,
    pub medical: String,
    pub violence: String,
    pub racy: String,
}

#[derive(Deserialize, Debug)]
pub struct LabelAnnotation {
    pub description: String,
    pub score: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReviewProfileImage {
    pub review_id: String,
    pub user_id: String,
    pub message: String,
    pub image_id: String,
    pub image_index: Option<i64>,
    pub message_at: String,
    pub status: String, // "approve" or "reject"
}
