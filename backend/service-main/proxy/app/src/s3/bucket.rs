use std::sync::Arc;

use actix_web::web;
use aws_config;
use aws_sdk_s3;
use bytes;
use futures_util::StreamExt;
use tokio;

use crate::http;
use crate::{db, place};

#[derive(Clone)]
pub struct AmazonS3 {
    client: aws_sdk_s3::Client,
    pg_repository: Arc<db::repository::PostgresRepository>,
}

impl AmazonS3 {
    pub async fn new(pg_repository: Arc<db::repository::PostgresRepository>) -> Self {
        let config = aws_config::defaults(aws_config::BehaviorVersion::latest())
            .load()
            .await;

        let client = aws_sdk_s3::Client::new(&config);

        // Clone property for background process.
        let client_inner = client.clone();
        let pg_repository_inner = pg_repository.clone();

        tokio::spawn(async move {
            // Execute check whether place photo was exceeded expires at.
            let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(300));

            loop {
                interval.tick().await;

                // Delete photo refenrece if exists exceeded epixres at.
                let delete_result = pg_repository_inner.delete_photo_reference().await;
                if let Some(deleted_rows) = delete_result.as_ref().ok() {
                    println!(
                        "Successfully to delete {:?} photos in postgres.",
                        deleted_rows.len()
                    );
                    for row in deleted_rows.iter() {
                        let s3_result = client_inner
                            .delete_object()
                            .bucket("places-photo-bucket")
                            .key(row.make_hash().to_string())
                            .send()
                            .await;

                        if let Some(err) = s3_result.as_ref().err() {
                            eprintln!("Failed delete object in places photo bucket. {:?}", err);
                        }

                        if let Some(ok) = s3_result.as_ref().ok() {
                            println!("Successfully to delete photos in s3: {:?}", ok);
                        }
                    }
                } else if let Some(err) = delete_result.as_ref().err() {
                    eprint!("Failed to delete photos in postgres. {:?}", err);
                }
            }
        });

        Self {
            client,
            pg_repository,
        }
    }

    pub async fn fetch_places_photo_from_bucket(
        &self,
        reference: &place::object::GooglePlacesPhotoReference,
    ) -> actix_web::Result<Option<actix_web::HttpResponse>> {
        // Make hash key
        let photo_reference_key = reference.make_hash();

        let client = self.client.clone();

        if self
            .pg_repository
            .select_photo_reference(photo_reference_key as i64)
            .await
            .ok()
            .is_some()
        {
            // Generate presigned url.
            let presigning_config = aws_sdk_s3::presigning::PresigningConfig::builder()
                .expires_in(std::time::Duration::from_secs(60 * 15))
                .build()
                .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

            // Request presign for S3.
            let presigned_request = client
                .get_object()
                .bucket("places-photo-bucket")
                .key(photo_reference_key.to_string())
                .presigned(presigning_config)
                .await
                .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

            return Ok(Some(
                actix_web::HttpResponse::TemporaryRedirect()
                    .append_header((
                        reqwest::header::LOCATION.to_string(),
                        presigned_request.uri().to_string(),
                    ))
                    .finish(),
            ));
        }

        Ok(None)
    }

    pub async fn fetch_places_photo_from_google(
        &self,
        reference: &place::object::GooglePlacesPhotoReference,
        http_client: web::Data<Arc<http::request::HttpClient>>,
    ) -> actix_web::Result<actix_web::HttpResponse> {
        // Make photo reference hash key
        let photo_reference_key = reference.make_hash().to_string();

        // Make endpoint of google places photo
        let endpoint = reference.make_url();

        let stream = http_client
            .get_stream(&endpoint, None, None, None)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e))?;

        // Places photo bytes stream upload to s3 in background.
        let (tx, mut rx) = tokio::sync::mpsc::channel::<bytes::Bytes>(100);
        let s3_client_inner = self.client.clone();
        let pg_repository_inner = self.pg_repository.clone();
        let reference_inner = reference.clone();

        tokio::spawn(async move {
            let mut buffer: Vec<u8> = Vec::new();
            while let Some(chunk) = rx.recv().await {
                buffer.extend_from_slice(&chunk);
            }

            // Compute mega bytes of buffer.
            let mbytes = buffer.len() as f64 / 1024.0;

            if mbytes < 5.0 {
                let result = s3_client_inner
                    .put_object()
                    .bucket("places-photo-bucket")
                    .key(photo_reference_key)
                    .body(buffer.into())
                    .send()
                    .await;

                if let Some(err) = result.as_ref().err() {
                    println!("Failed to request photo: {:?}", err);
                }

                // If succcessfully to upload places photo, save photo reference in postgres.
                if result.is_ok() {
                    if let Some(err) = pg_repository_inner
                        .insert_photo_reference(reference_inner)
                        .await
                        .err()
                    {
                        eprintln!("Failed insert photo reference. {:?}", err);
                    }
                }
            } else {
                let upload_res = s3_client_inner
                    .create_multipart_upload()
                    .bucket("places-photo-bucket")
                    .key(&photo_reference_key)
                    .send()
                    .await;

                if let Some(upload_output) = upload_res.as_ref().ok() {
                    let upload_id = upload_output.clone().upload_id.unwrap();
                    let mut completed_parts: Vec<aws_sdk_s3::types::CompletedPart> = Vec::new();

                    // Start multipart upload to s3.
                    for (i, chunk) in buffer.chunks(5 * 1024 * 1024).enumerate() {
                        let part_number = (i + 1) as i32;

                        let upload_part_res = s3_client_inner
                            .upload_part()
                            .bucket("places-photo-bucket")
                            .key(&photo_reference_key)
                            .upload_id(&upload_id)
                            .part_number(part_number)
                            .body(chunk.to_vec().into())
                            .send()
                            .await;

                        if let Some(res) = upload_part_res.as_ref().ok() {
                            completed_parts.push(
                                aws_sdk_s3::types::CompletedPart::builder()
                                    .e_tag(res.clone().e_tag().unwrap())
                                    .part_number(part_number)
                                    .build(),
                            );
                        }

                        if let Some(err) = upload_part_res.as_ref().err() {
                            eprintln!("Failed to multipart upload places photo. {:?}", err);
                        }
                    }

                    // Combine completed part.
                    let completed_upload = aws_sdk_s3::types::CompletedMultipartUpload::builder()
                        .set_parts(Some(completed_parts))
                        .build();

                    // Send to s3 about finish multipart upload
                    let multipart_upload_res = s3_client_inner
                        .complete_multipart_upload()
                        .bucket("places-photo-bucket")
                        .key(&photo_reference_key)
                        .upload_id(&upload_id)
                        .multipart_upload(completed_upload)
                        .send()
                        .await;

                    if let Some(err) = multipart_upload_res.as_ref().err() {
                        eprintln!("Failed multipart upload places photo. {:?}", err);
                    }

                    // If succcessfully to upload places photo, save photo reference in postgres.
                    if multipart_upload_res.is_ok() {
                        if let Some(err) = pg_repository_inner
                            .insert_photo_reference(reference_inner)
                            .await
                            .err()
                        {
                            eprintln!("Failed insert photo reference. {:?}", err);
                        }
                    }
                }
            }
        });

        let processed_stream = stream.map(move |item| match item {
            Ok(bytes) => {
                let _ = tx.try_send(bytes.clone());
                Ok::<bytes::Bytes, actix_web::Error>(bytes)
            }
            Err(e) => Err(actix_web::error::ErrorInternalServerError(e)),
        });

        Ok(actix_web::HttpResponse::Ok()
            .content_type("image/png")
            .streaming(processed_stream))
    }
}
