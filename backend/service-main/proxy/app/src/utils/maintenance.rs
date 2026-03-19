use actix_web::Error;
use actix_web::dev::{Service, ServiceRequest, ServiceResponse, Transform, forward_ready};
use futures_util::future::LocalBoxFuture;
use std::future::{Ready, ready};
use std::rc::Rc;
use std::sync::Arc;
use tokio::sync::RwLock;

pub struct MaintenanceMiddleware {
    pub is_maintenance: Arc<RwLock<bool>>,
}

impl<S, B> Transform<S, ServiceRequest> for MaintenanceMiddleware
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    S::Future: 'static,
    B: 'static,
{
    type Response = ServiceResponse<B>;
    type Error = Error;
    type InitError = ();
    type Transform = MaintenanceMiddlewareService<S>;
    type Future = Ready<Result<Self::Transform, Self::InitError>>;

    fn new_transform(&self, service: S) -> Self::Future {
        ready(Ok(MaintenanceMiddlewareService {
            service: Rc::new(service),
            is_maintenance: self.is_maintenance.clone(),
        }))
    }
}

pub struct MaintenanceMiddlewareService<S> {
    service: Rc<S>,
    is_maintenance: Arc<RwLock<bool>>,
}

impl<S, B> Service<ServiceRequest> for MaintenanceMiddlewareService<S>
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    S::Future: 'static,
    B: 'static,
{
    type Response = ServiceResponse<B>;
    type Error = Error;
    type Future = LocalBoxFuture<'static, Result<Self::Response, Self::Error>>;

    forward_ready!(service);

    fn call(&self, req: ServiceRequest) -> Self::Future {
        let is_maint_clone = self.is_maintenance.clone();
        let srv = self.service.clone();

        Box::pin(async move {
            let path = req.path();
            // allow heath check, internal endpoints, and status checks to bypass maintenance check
            if path != "/internal/maintenance"
                && path != "/health"
                && path != "/api/health"
                && path != "/api/system/maintenance/status"
            {
                let is_maint = *is_maint_clone.read().await;
                if is_maint {
                    return Err(actix_web::error::ErrorServiceUnavailable(
                        "Server is currently under maintenance",
                    ));
                }
            }
            srv.call(req).await
        })
    }
}
