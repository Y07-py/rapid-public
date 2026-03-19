use std::collections::HashMap;

use futures_util::StreamExt;
use reqwest;
use reqwest::header;
use reqwest_middleware::ClientWithMiddleware;
use serde::de::DeserializeOwned;

#[derive(Debug, Clone)]
pub struct HttpRequest {
    client: ClientWithMiddleware,
    headers: Option<HashMap<String, String>>,
    method: Option<reqwest::Method>,
    body: Option<Vec<u8>>,
    url: Option<reqwest::Url>,
    queries: Option<HashMap<String, String>>,
}

impl HttpRequest {
    pub fn new(client: &ClientWithMiddleware) -> Self {
        Self {
            client: client.clone(),
            headers: None,
            method: None,
            body: None,
            url: None,
            queries: None,
        }
    }

    pub fn set_header(mut self, key: String, value: String) -> Self {
        let header_map = self.headers.get_or_insert(HashMap::new());
        header_map.insert(key, value);
        self.headers = Some(header_map.clone());
        self
    }

    pub fn set_headers(mut self, headers: HashMap<String, String>) -> Self {
        let header_map = self.headers.get_or_insert(HashMap::new());
        for (key, value) in headers {
            header_map.insert(key, value);
        }
        self.headers = Some(header_map.clone());
        self
    }

    pub fn set_method(mut self, method: reqwest::Method) -> Self {
        self.method = Some(method);
        self
    }

    pub fn set_url(mut self, url: String) -> Self {
        match reqwest::Url::parse(&url) {
            Ok(url) => {
                self.url = Some(url);
            }
            Err(e) => {
                eprintln!("Failed to parse url: {:?}", e);
            }
        }
        self
    }

    pub fn set_body<T: serde::Serialize>(mut self, body: &T) -> Self {
        if let Some(bytes) = serde_json::to_vec(body).ok() {
            self.body = Some(bytes);
        }
        self
    }

    pub fn set_queries(mut self, queries: HashMap<String, String>) -> Self {
        let query_map = self.queries.get_or_insert(HashMap::new());
        for (key, value) in queries {
            query_map.insert(key, value);
        }
        self.queries = Some(query_map.clone());
        self
    }

    pub async fn execute(&self) -> Result<HttpResponse, reqwest_middleware::Error> {
        let method = self.method.as_ref().expect("Method not set").clone();
        let url = self.url.as_ref().expect("URL not set").clone();

        let mut builder = self.client.request(method, url);

        if let Some(headers) = self.headers.as_ref() {
            for (key, value) in headers.iter() {
                builder = builder.header(key, value);
            }
        }

        if let Some(query) = self.queries.as_ref() {
            builder = builder.query(query);
        }

        if let Some(body) = self.body.as_ref() {
            builder = builder.body(body.clone());
        }

        match builder.send().await {
            Ok(response) => {
                let mut http_response = HttpResponse::new(response.status().as_u16() as usize)
                    .set_header(response.headers().clone())
                    .set_content_length(response.content_length())
                    .set_version(response.version());

                let mut stream = response.bytes_stream();
                let mut chunks: Vec<u8> = Vec::new();
                while let Some(chunk) = stream.next().await.transpose()? {
                    chunks.extend_from_slice(&chunk);
                }
                http_response = http_response.set_body(chunks);

                Ok(http_response)
            }
            Err(e) => Err(e),
        }
    }
}

#[derive(Debug)]
pub struct HttpResponse {
    status_code: usize,
    headers: Option<header::HeaderMap<header::HeaderValue>>,
    body: Option<Vec<u8>>,
    content_length: Option<u64>,
    version: Option<reqwest::Version>,
}

impl HttpResponse {
    pub fn new(status_code: usize) -> Self {
        Self {
            status_code,
            headers: None,
            body: None,
            content_length: None,
            version: None,
        }
    }

    pub fn set_header(mut self, header: header::HeaderMap<header::HeaderValue>) -> Self {
        self.headers = Some(header);
        self
    }

    pub fn set_body(mut self, body: Vec<u8>) -> Self {
        self.body = Some(body);
        self
    }

    pub fn set_content_length(mut self, content_length: Option<u64>) -> Self {
        self.content_length = content_length;
        self
    }

    pub fn set_version(mut self, version: reqwest::Version) -> Self {
        self.version = Some(version);
        self
    }

    pub fn get_status_code(&self) -> usize {
        self.status_code
    }

    pub fn get_body<T: DeserializeOwned>(&self) -> Option<T> {
        if let Some(body) = self.body.as_ref() {
            return serde_json::from_slice(body).ok();
        }
        None
    }

    pub fn get_body_as_string(&self) -> Option<String> {
        self.body.as_ref().and_then(|b| String::from_utf8(b.clone()).ok())
    }

    pub fn get_body_as_bytes(&self) -> Option<Vec<u8>> {
        self.body.clone()
    }

    pub fn is_success(&self) -> bool {
        self.status_code >= 200 && self.status_code < 300
    }
}

pub trait HeaderFlow: Send + Sync + 'static {
    fn set_header(&self, request: HttpRequest) -> HttpRequest;
}
