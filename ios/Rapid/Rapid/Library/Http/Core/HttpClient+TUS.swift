//
//  HttpClient+TUS.swift
//  Rapid
//
//  Created by Claude on 2026/02/07.
//

import Foundation
import TUSKit

// MARK: - TUS resumable upload
extension HttpClient {
    public func tusUpload(
        url: String,
        headers: [String: String]? = nil,
        metadata: [String: String]? = nil,
        content: Data,
        chunkSize: Int = 5 * (1 << 20)
    ) async throws -> AsyncThrowingStream<HttpUploadEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream<HttpUploadEvent, Error>.makeStream()

        guard let uploadURL = URL(string: url) else {
            continuation.finish(throwing: HttpError.connectionError("Invalid upload URL"))
            return stream
        }

        var customHeaders = headers ?? [:]
        
        // Add TUS metadata header
        if let metadata = metadata {
            let encodedMetadata = metadata.map { (key, value) -> String in
                let base64Value = Data(value.utf8).base64EncodedString()
                return "\(key) \(base64Value)"
            }.joined(separator: ",")
            
            if !encodedMetadata.isEmpty {
                customHeaders["Upload-Metadata"] = encodedMetadata
            }
        }

        if let auth = self.auth {
            let token = try await auth.getToken()
            customHeaders["Authorization"] = "Bearer \(token)"
        }

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try content.write(to: fileURL)

        let manager = TUSUploadManager(
            uploadURL: uploadURL,
            fileURL: fileURL,
            customHeaders: customHeaders,
            continuation: continuation,
            chunkSize: chunkSize
        )
        try manager.start()

        return stream
    }
    
    public func tusMultiPartUpload(url: String) async throws {
        
    }
}

private final class TUSUploadManager: NSObject, TUSClientDelegate {
    private var tusClient: TUSClient?
    private var selfRetain: TUSUploadManager?
    private let continuation: AsyncThrowingStream<HttpUploadEvent, Error>.Continuation
    private let uploadURL: URL
    private let fileURL: URL
    private let customHeaders: [String: String]
    private let chunkSize: Int

    init(
        uploadURL: URL,
        fileURL: URL,
        customHeaders: [String: String],
        continuation: AsyncThrowingStream<HttpUploadEvent, Error>.Continuation,
        chunkSize: Int
    ) {
        self.uploadURL = uploadURL
        self.fileURL = fileURL
        self.customHeaders = customHeaders
        self.continuation = continuation
        self.chunkSize = chunkSize
        super.init()
    }

    func start() throws {
        selfRetain = self

        let sessionId = UUID().uuidString
        let config = URLSessionConfiguration.background(withIdentifier: "com.rapid.tus.\(sessionId)")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true

        let client = try TUSClient(
            server: uploadURL,
            sessionIdentifier: sessionId,
            sessionConfiguration: config,
            chunkSize: chunkSize
        )
        client.delegate = self
        self.tusClient = client

        let _ = try client.uploadFileAt(
            filePath: fileURL,
            uploadURL: nil,
            customHeaders: customHeaders
        )

        continuation.yield(.started)
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: fileURL)
        tusClient = nil
        selfRetain = nil
    }

    // MARK: - TUSClientDelegate

    func progressFor(id: UUID, context: [String: String]?, bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
        continuation.yield(.progress(bytesUpload: bytesUploaded, totalBytes: totalBytes))
    }

    func didStartUpload(id: UUID, context: [String: String]?, client: TUSClient) {}

    func didFinishUpload(id: UUID, url: URL, context: [String: String]?, client: TUSClient) {
        continuation.yield(.finished(url: url))
        continuation.finish()
        cleanup()
    }

    func uploadFailed(id: UUID, error: any Error, context: [String: String]?, client: TUSClient) {
        continuation.finish(throwing: error)
        cleanup()
    }

    func fileError(error: TUSClientError, client: TUSClient) {
        continuation.finish(throwing: error)
        cleanup()
    }

    func totalProgress(bytesUploaded: Int, totalBytes: Int, client: TUSClient) {}
}
