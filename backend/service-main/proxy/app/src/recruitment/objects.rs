use serde::{Deserialize, Serialize};
use uuid;

use crate::db;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FetchRecruitmentRequestParamaterWithAgeRange {
    pub from_age: i8,
    pub to_age: i8,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FetchRecruitmentRequestParamaterWithFilter {
    pub age_range: Option<FetchRecruitmentRequestParamaterWithAgeRange>,
    pub residence_radius: Option<f64>,
    pub location_keyword: Option<String>,
    pub sort_login: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FetchRecruitmentRequestParamater {
    pub user_id: uuid::Uuid,
    pub offset: usize,
    pub limit: usize,
    pub filter_paramater: Option<FetchRecruitmentRequestParamaterWithFilter>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PostRecruitmentRequest {
    pub recruitment: db::object::Recruitments,
    pub places: Vec<db::object::RecruitmentPlaces>,
    pub hash_tags: Vec<db::object::RecruitmentHashTags>,
    pub place_types: Vec<db::object::RecruitmentPlaceTypes>,
}
