//
//  HttpRequest.swift
//  Http
//
//  Created by 木本瑛介 on 2025/12/31.
//

import Foundation

public struct HttpRequest {
    private var url: URL
    private var method: HttpMethod
    private var headers: [String: String]
    private var content: Data? = nil
    private var timeout: TimeInterval? = nil
    private var auth: HttpAuth? = nil
    
    public init(url: String, method: HttpMethod) {
        guard let url = URL(string: url) else { fatalError("Failed to parse url. url: \(url)") }
        
        self.url = url
        self.method = method
        self.headers = ["Content-Type": "application/json"]
    }
}

extension HttpRequest {
    public mutating func setHeaders(headers: [String: String]) -> Self {
        self.headers.merge(headers) { (_, new) in new }
        return self
    }
    
    public mutating func setHeader(key: String, value: String) -> Self {
        return self.setHeaders(headers: [key : value])
    }
    
    public mutating func setContent<T: Codable>(
        content: T,
        dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .iso8601,
        dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64,
    ) -> Self {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = dateEncodingStrategy
        encoder.dataEncodingStrategy = dataEncodingStrategy
        let data = try! encoder.encode(content)
        self.content = data
        return self
    }
    
    public mutating func setTimeout(timeout: TimeInterval) -> Self {
        self.timeout = timeout
        return self
    }
    
    public mutating func setAuth(auth: HttpAuth) -> Self {
        self.auth = auth
        return self
    }
}

extension HttpRequest {
    public func request() async throws -> URLRequest {
        var urlRequest = URLRequest(url: self.url)
        urlRequest.httpMethod = self.method.rawValue
        urlRequest.allHTTPHeaderFields = self.headers
        
        if let content = self.content {
            urlRequest.httpBody = content
        }
        
        if let auth = self.auth {
            let token = try await auth.getToken()
            urlRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let timeout = self.timeout {
            urlRequest.timeoutInterval = timeout
        }
        
        return urlRequest
    }
}
