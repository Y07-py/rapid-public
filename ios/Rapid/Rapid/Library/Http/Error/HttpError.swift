//
//  HttpError.swift
//  Http
//
//  Created by 木本瑛介 on 2025/12/31.
//

import Foundation

public enum HttpError: Error {
    case connectionError(String)
    case retryError(String)
    
    // MARK: - Client error
    case badRequestError(Int)
    case unauthorizedError(Int)
    case paymentRequiredError(Int)
    case forbiddenError(Int)
    case notFoundError(Int)
    case methodNotAllowedError(Int)
    case notAcceptableError(Int)
    case proxyAuthenticationRequiredError(Int)
    case requestTimeoutError(Int)
    case conflictError(Int)
    case goneError(Int)
    case lengthRequiredError(Int)
    case preconditionFailedError(Int)
    case contentTooLargeError(Int)
    case uriTooLongError(Int)
    case unsupportedMediaTypeError(Int)
    case rangeNotSatisfiableError(Int)
    case expectationFailedError(Int)
    case iamATeapotError(Int)
    case misdirectedRequestError(Int)
    case unprocessableEntityError(Int)
    case lockedError(Int)
    case failedDependencyError(Int)
    case tooEearlyError(Int)
    case upgradeRequiredError(Int)
    case preconditionRequiredError(Int)
    case tooManyRequestsError(Int)
    case requestHeaderFieldsTooLargeError(Int)
    case unavailableForLegalReasonsError(Int)
    
    // MARK: - Server error
    case internalServerError(Int)
    case notImplementedError(Int)
    case proxyError(Int)
    case insecureProtocolError(Int)
    case badGatewayError(Int)
    case serviceUnavailableError(Int)
    case gatewayTimeoutError(Int)
    case httpVersionNotSupportedError(Int)
    case variantAlsoNegotiatesError(Int)
    case loopDetectedError(Int)
    case networkAuthenticationRequiredError(Int)
    case tooManyHeadersError(Int)
    case insufficientStorageError(Int)
    case notExtendedError(Int)
    case unknownError
    
    var errorDescription: String {
        switch self {
        case .connectionError(let message):
            return "Connection Error: \(message)"
        case .retryError(let message):
            return "Retry Error: \(message)"
            
            // MARK: - Client error
        case .badRequestError(let code):
            return "Status code \(code): Bad Request. The server cannot process the request due to a client error."
        case .unauthorizedError(let code):
            return "Status code \(code): Unauthorized. Authentication is required and has failed or has not been provided."
        case .paymentRequiredError(let code):
            return "Status code \(code): Payment Required. This code is reserved for future use."
        case .forbiddenError(let code):
            return "Status code \(code): Forbidden. You do not have permission to access this resource."
        case .notFoundError(let code):
            return "Status code \(code): Not Found. The requested resource could not be found on the server."
        case .methodNotAllowedError(let code):
            return "Status code \(code): Method Not Allowed. The request method is not supported for the requested resource."
        case .notAcceptableError(let code):
            return "Status code \(code): Not Acceptable. The target resource does not have a current representation that is acceptable."
        case .proxyAuthenticationRequiredError(let code):
            return "Status code \(code): Proxy Authentication Required. Authentication is required via a proxy."
        case .requestTimeoutError(let code):
            return "Status code \(code): Request Timeout. The server timed out waiting for the request."
        case .conflictError(let code):
            return "Status code \(code): Conflict. The request could not be completed due to a conflict with the current state of the resource."
        case .goneError(let code):
            return "Status code \(code): Gone. The requested resource is no longer available and will not be available again."
        case .lengthRequiredError(let code):
            return "Status code \(code): Length Required. The request did not specify the length of its content."
        case .preconditionFailedError(let code):
            return "Status code \(code): Precondition Failed. The server does not meet one of the preconditions specified in the request."
        case .contentTooLargeError(let code):
            return "Status code \(code): Content Too Large. The request entity is larger than limits defined by the server."
        case .uriTooLongError(let code):
            return "Status code \(code): URI Too Long. The URI provided was too long for the server to process."
        case .unsupportedMediaTypeError(let code):
            return "Status code \(code): Unsupported Media Type. The media format of the requested data is not supported."
        case .rangeNotSatisfiableError(let code):
            return "Status code \(code): Range Not Satisfiable. The range specified by the Range header field cannot be fulfilled."
        case .expectationFailedError(let code):
            return "Status code \(code): Expectation Failed. The expectation given in the Expect request-header field could not be met."
        case .iamATeapotError(let code):
            return "Status code \(code): I'm a teapot. The server refuses to brew coffee because it is, permanently, a teapot."
        case .misdirectedRequestError(let code):
            return "Status code \(code): Misdirected Request. The request was directed at a server that is not able to produce a response."
        case .unprocessableEntityError(let code):
            return "Status code \(code): Unprocessable Entity. The server understands the content type but was unable to process the contained instructions."
        case .lockedError(let code):
            return "Status code \(code): Locked. The resource that is being accessed is locked."
        case .failedDependencyError(let code):
            return "Status code \(code): Failed Dependency. The request failed due to failure of a previous request."
        case .tooEearlyError(let code):
            return "Status code \(code): Too Early. The server is unwilling to risk processing a request that might be replayed."
        case .upgradeRequiredError(let code):
            return "Status code \(code): Upgrade Required. The client should switch to a different protocol."
        case .preconditionRequiredError(let code):
            return "Status code \(code): Precondition Required. The origin server requires the request to be conditional."
        case .tooManyRequestsError(let code):
            return "Status code \(code): Too Many Requests. The user has sent too many requests in a given amount of time."
        case .requestHeaderFieldsTooLargeError(let code):
            return "Status code \(code): Request Header Fields Too Large. The server is unwilling to process the request because its header fields are too large."
        case .unavailableForLegalReasonsError(let code):
            return "Status code \(code): Unavailable For Legal Reasons. The user requested a resource that cannot legally be provided."
            
            // MARK: - Server error
        case .internalServerError(let code):
            return "Status code \(code): Internal Server Error. The server encountered an unexpected condition."
        case .notImplementedError(let code):
            return "Status code \(code): Not Implemented. The server does not support the functionality required to fulfill the request."
        case .proxyError(let code):
            return "Status code \(code): Proxy Error. An error occurred with the proxy server."
        case .insecureProtocolError(let code):
            return "Status code \(code): Insecure Protocol. The request was made using an insecure protocol."
        case .badGatewayError(let code):
            return "Status code \(code): Bad Gateway. The server received an invalid response from the upstream server."
        case .serviceUnavailableError(let code):
            return "Status code \(code): Service Unavailable. The server is currently unable to handle the request due to maintenance or overload."
        case .gatewayTimeoutError(let code):
            return "Status code \(code): Gateway Timeout. The gateway did not receive a timely response from the upstream server."
        case .httpVersionNotSupportedError(let code):
            return "Status code \(code): HTTP Version Not Supported. The server does not support the HTTP protocol version used in the request."
        case .variantAlsoNegotiatesError(let code):
            return "Status code \(code): Variant Also Negotiates. Transparent content negotiation for the request results in a circular reference."
        case .loopDetectedError(let code):
            return "Status code \(code): Loop Detected. The server detected an infinite loop while processing the request."
        case .networkAuthenticationRequiredError(let code):
            return "Status code \(code): Network Authentication Required. The client needs to authenticate to gain network access."
        case .tooManyHeadersError(let code):
            return "Status code \(code): Too Many Headers. The request contains too many header fields."
        case .insufficientStorageError(let code):
            return "Status code \(code): Insufficient Storage. The server is unable to store the representation needed to complete the request."
        case .notExtendedError(let code):
            return "Status code \(code): Not Extended. Further extensions to the request are required for the server to fulfill it."
            
        default:
            return "Unknown Error: An unexpected error occurred."
        }
    }
}
