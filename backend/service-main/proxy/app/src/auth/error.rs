use thiserror::Error;

#[derive(Error, Debug)]
pub enum AuthSessionError {
    #[error("failed verification")]
    VerificationError(String),

    #[error("failed decoding token")]
    DecodingError(String),

    #[error("http error")]
    HttpRequestError(String),

    #[error("failed put cache data")]
    CachePutError(String),

    #[error("unknown error")]
    UnknownError(String),
}
