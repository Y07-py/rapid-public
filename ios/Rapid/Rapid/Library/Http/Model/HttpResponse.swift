//
//  HttpResponse.swift
//  Http
//
//  Created by 木本瑛介 on 2025/12/31.
//

import Foundation

public struct HttpResponse {
    private var content: Data? = nil
    public var statusCode: Int
    private var headers: [AnyHashable: Any] = [:]
    
    public init(statusCode: Int, content: Data?, headers: [AnyHashable: Any]) {
        self.content = content
        self.statusCode = statusCode
        self.headers = headers
    }
}

extension HttpResponse {
    public var retriable: Bool {
        return self.statusCode == 429 || (self.statusCode >= 500 && self.statusCode < 600)
    }
    
    public var ok: Bool {
        return self.statusCode == 200
    }
    
    public var found: Bool {
        return self.statusCode == 302
    }

    public func header(_ name: String) -> String? {
        return headers[name] as? String
    }
    
    public func decode<T: Codable>(
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .iso8601,
        dataDecodingStrategy: JSONDecoder.DataDecodingStrategy = .base64,
    ) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.dataDecodingStrategy = dataDecodingStrategy
        
        guard let content = self.content else { fatalError("Content must not be nil when decoding." )}
        
        return try decoder.decode(T.self, from: content)
    }
    
    public func error() -> HttpError {
        switch self.statusCode {
        case 400:
            return HttpError.badRequestError(400)
        case 401:
            return HttpError.unauthorizedError(401)
        case 402:
            return HttpError.paymentRequiredError(402)
        case 403:
            return HttpError.forbiddenError(403)
        case 404:
            return HttpError.notFoundError(404)
        case 405:
            return HttpError.methodNotAllowedError(405)
        case 406:
            return HttpError.notAcceptableError(406)
        case 407:
            return HttpError.proxyAuthenticationRequiredError(407)
        case 408:
            return HttpError.requestTimeoutError(408)
        case 409:
            return HttpError.conflictError(409)
        case 410:
            return HttpError.goneError(410)
        case 411:
            return HttpError.lengthRequiredError(411)
        case 412:
            return HttpError.preconditionFailedError(412)
        case 413:
            return HttpError.contentTooLargeError(413)
        case 414:
            return HttpError.uriTooLongError(414)
        case 415:
            return HttpError.unsupportedMediaTypeError(415)
        case 416:
            return HttpError.rangeNotSatisfiableError(416)
        case 417:
            return HttpError.expectationFailedError(417)
        case 418:
            return HttpError.iamATeapotError(418)
        case 421:
            return HttpError.misdirectedRequestError(421)
        case 422:
            return HttpError.unprocessableEntityError(422)
        case 423:
            return HttpError.lockedError(423)
        case 424:
            return HttpError.failedDependencyError(424)
        case 425:
            return HttpError.tooEearlyError(425)
        case 426:
            return HttpError.upgradeRequiredError(426)
        case 428:
            return HttpError.preconditionRequiredError(428)
        case 429:
            return HttpError.tooManyRequestsError(429)
        case 431:
            return HttpError.requestHeaderFieldsTooLargeError(431)
        case 451:
            return HttpError.unavailableForLegalReasonsError(451)
        
        case 500:
            return HttpError.internalServerError(500)
        case 501:
            return HttpError.notImplementedError(501)
        case 502:
            return HttpError.badGatewayError(502)
        case 503:
            return HttpError.serviceUnavailableError(503)
        case 504:
            return HttpError.gatewayTimeoutError(504)
        case 505:
            return HttpError.httpVersionNotSupportedError(505)
        case 506:
            return HttpError.variantAlsoNegotiatesError(506)
        case 507:
            return HttpError.insufficientStorageError(507)
        case 508:
            return HttpError.loopDetectedError(508)
        case 510:
            return HttpError.notExtendedError(510)
        case 511:
            return HttpError.networkAuthenticationRequiredError(511)
        
        default:
            return HttpError.unknownError
        }
    }
}
