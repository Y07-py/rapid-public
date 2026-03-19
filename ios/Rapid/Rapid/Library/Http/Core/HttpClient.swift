//
//  Http.swift
//  Http
//
//  Created by 木本瑛介 on 2025/12/31.
//

import Foundation

public final class HttpClient {
    private let session: URLSession
    let auth: HttpAuth?
    private let timeout: TimeInterval?
    private let retryPolicy: HttpRetryPolicy?
    
    static let shared = HttpClient()
    
    public init(auth: HttpAuth? = nil, timeout: TimeInterval? = nil, retryPolicy: HttpRetryPolicy? = nil) {
        self.session = URLSession.shared
        self.auth = auth
        self.timeout = timeout
        self.retryPolicy = retryPolicy
    }
}

// MARK: - Method chain
extension HttpClient {
    public func setAuth(httpAuth auth: HttpAuth) -> Self {
        return .init(auth: auth, timeout: self.timeout, retryPolicy: self.retryPolicy)
    }
    
    public func setTimeInterval(timeInterval interval: TimeInterval) -> Self {
        return .init(auth: self.auth, timeout: interval, retryPolicy: self.retryPolicy)
    }
    
    public func setRetryPolicy(retryPolicy policy: HttpRetryPolicy) -> Self {
        return .init(auth: self.auth, timeout: self.timeout, retryPolicy: policy)
    }
}

// MARK: - Http request
extension HttpClient {
    public func send(req: HttpRequest) async throws -> HttpResponse {
        let urlRequest = try await req.request()
        
        if let policy = self.retryPolicy {
            var retryCount = 0
            while let timeSleep = backoff(retryPolicy: policy, retryCount: retryCount) {
                let (data, sessionResponse) = try await self.session.data(for: urlRequest)
                
                if let response = sessionResponse as? HTTPURLResponse {
                    let httpResponse = HttpResponse(
                        statusCode: response.statusCode,
                        content: data,
                        headers: response.allHeaderFields
                    )
                    
                    if httpResponse.statusCode == 503 {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .receiveMaintenanceNotification, object: nil)
                        }
                    }

                    if httpResponse.retriable && httpResponse.statusCode != 503 {
                        retryCount += 1
                        try await Task.sleep(nanoseconds: UInt64(timeSleep * 1_000_000_000))
                        continue
                    }
                    
                    return httpResponse
                } else {
                    throw HttpError.connectionError("Failed to establish a network connection.")
                }
            }
            
            throw HttpError.retryError("Exceeded maximum number of retry attempts.")
        }
        
        let (data, sessionResponse) = try await self.session.data(for: urlRequest)
        if let response = sessionResponse as? HTTPURLResponse {
            let httpResponse = HttpResponse(
                statusCode: response.statusCode,
                content: data,
                headers: response.allHeaderFields
            )
            
            if httpResponse.statusCode == 503 {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .receiveMaintenanceNotification, object: nil)
                }
            }
            
            return httpResponse
        }
        
        throw HttpError.connectionError("Failed to establish a network connection.")
    }
    
    private func backoff(retryPolicy policy: HttpRetryPolicy, retryCount: Int) -> TimeInterval? {
        switch policy {
        case .fixedBackoff(let maxRetry, let interval):
            if retryCount >= maxRetry {
                return nil
            }
            
            return interval
        case .exponentialBackoff(let maxRetry, let interval):
            if retryCount >= maxRetry {
                return nil
            }
            
            let randomNumber: Double = Double.random(in: 1...1000) / 1000.0
            
            return min(pow(2.0, Double(retryCount)) + randomNumber, interval)
        }
    }
}

// MARK: - Http method.
extension HttpClient {
    public func get(url: String, headers: [String: String]? = nil) async throws -> HttpResponse {
        var request = HttpRequest(url: url, method: .get)
        
        if let auth = self.auth {
            request = request.setAuth(auth: auth)
        }
        
        if let timeout = self.timeout {
            request = request.setTimeout(timeout: timeout)
        }
        
        if let headers = headers {
            request = request.setHeaders(headers: headers)
        }
        
        let response = try await self.send(req: request)
        
        if response.ok {
            return response
        }
        
        throw response.error()
    }
    
    public func post<T: Codable>(
        url: String,
        content: T,
        headers: [String: String]? = nil,
        dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .iso8601,
        dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64
    ) async throws -> HttpResponse {
        var request = HttpRequest(url: url, method: .post)
        request = request.setContent(
            content: content,
            dateEncodingStrategy: dateEncodingStrategy,
            dataEncodingStrategy: dataEncodingStrategy
        )
        
        if let auth = self.auth {
            request = request.setAuth(auth: auth)
        }
        
        if let timeout = self.timeout {
            request = request.setTimeout(timeout: timeout)
        }
        
        if let headers = headers {
            request = request.setHeaders(headers: headers)
        }
        
        let response = try await self.send(req: request)
        
        if response.ok {
            return response
        }
        
        throw response.error()
    }
}
