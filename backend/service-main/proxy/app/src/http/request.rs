use std::collections::HashMap;

use reqwest;
use reqwest_middleware;
use reqwest_retry;

use crate::http::object;

#[derive(Debug)]
pub struct HttpClient {
    client: reqwest_middleware::ClientWithMiddleware,
}

impl HttpClient {
    pub fn new() -> Self {
        let retry_policy =
            reqwest_retry::policies::ExponentialBackoff::builder().build_with_max_retries(3);
        let inner_client = reqwest::Client::builder()
            .pool_max_idle_per_host(10)
            .build()
            .unwrap();
        let client = reqwest_middleware::ClientBuilder::new(inner_client)
            .with(reqwest_retry::RetryTransientMiddleware::new_with_policy(
                retry_policy,
            ))
            .build();

        Self { client }
    }

    pub async fn get(
        &self,
        url: &str,
        headers: Option<HashMap<String, String>>,
        queries: Option<HashMap<String, String>>,
        header_flow: Option<Box<dyn object::HeaderFlow>>,
    ) -> Result<object::HttpResponse, reqwest_middleware::Error> {
        let mut http_request = object::HttpRequest::new(&self.client);
        http_request = http_request
            .set_url(url.to_string())
            .set_method(reqwest::Method::GET);

        if let Some(headers) = headers {
            http_request = http_request.set_headers(headers);
        }

        if let Some(queries) = queries {
            http_request = http_request.set_queries(queries);
        }

        if let Some(header_flow) = header_flow {
            http_request = header_flow.set_header(http_request);
        }

        http_request.execute().await
    }

    pub async fn get_stream(
        &self,
        url: &str,
        headers: Option<HashMap<String, String>>,
        queries: Option<HashMap<String, String>>,
        header_flow: Option<Box<dyn object::HeaderFlow>>,
    ) -> Result<
        std::pin::Pin<Box<dyn futures_util::Stream<Item = reqwest::Result<bytes::Bytes>> + Send>>,
        reqwest_middleware::Error,
    > {
        let mut http_request = object::HttpRequest::new(&self.client);
        http_request = http_request
            .set_url(url.to_string())
            .set_method(reqwest::Method::GET);

        if let Some(headers) = headers {
            http_request = http_request.set_headers(headers);
        }

        if let Some(queries) = queries {
            http_request = http_request.set_queries(queries);
        }

        if let Some(header_flow) = header_flow {
            http_request = header_flow.set_header(http_request);
        }

        http_request.execute_stream().await
    }

    pub async fn post<T: serde::Serialize>(
        &self,
        url: &str,
        headers: Option<HashMap<String, String>>,
        queries: Option<HashMap<String, String>>,
        body: T,
        header_flow: Option<Box<dyn object::HeaderFlow>>,
    ) -> Result<object::HttpResponse, reqwest_middleware::Error> {
        let mut http_request = object::HttpRequest::new(&self.client);
        http_request = http_request
            .set_url(url.to_string())
            .set_method(reqwest::Method::POST)
            .set_body(&body);

        if let Some(headers) = headers {
            http_request = http_request.set_headers(headers);
        }

        // Compute content-length
        if let Some(bytes) = serde_json::to_vec(&body).ok() {
            let content_length = bytes.len();
            http_request =
                http_request.set_header("Content-Length".to_string(), content_length.to_string());
        };

        if let Some(queries) = queries {
            http_request = http_request.set_queries(queries);
        }

        if let Some(header_flow) = header_flow {
            http_request = header_flow.set_header(http_request);
        }

        http_request.execute().await
    }

    pub async fn post_form(
        &self,
        url: &str,
        form_data: HashMap<String, String>,
    ) -> Result<object::HttpResponse, reqwest_middleware::Error> {
        let mut http_request = object::HttpRequest::new(&self.client);
        http_request = http_request
            .set_url(url.to_string())
            .set_method(reqwest::Method::POST)
            .set_form_body(&form_data)
            .set_header(
                "Content-Type".to_string(),
                "application/x-www-form-urlencoded".to_string(),
            );

        http_request.execute().await
    }

    pub async fn delete(
        &self,
        url: &str,
        headers: Option<HashMap<String, String>>,
        queries: Option<HashMap<String, String>>,
    ) -> Result<object::HttpResponse, reqwest_middleware::Error> {
        let mut http_request = object::HttpRequest::new(&self.client);
        http_request = http_request
            .set_url(url.to_string())
            .set_method(reqwest::Method::DELETE);

        if let Some(headers) = headers {
            http_request = http_request.set_headers(headers);
        }

        if let Some(queries) = queries {
            http_request = http_request.set_queries(queries);
        }

        http_request.execute().await
    }
}
