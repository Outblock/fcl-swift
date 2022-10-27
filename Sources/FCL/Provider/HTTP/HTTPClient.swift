//
//  File.swift
//  File
//
//  Created by lmcmz on 4/10/21.
//

import Combine
import Foundation

extension FCL {
    final class HTTPClient {
        internal let defaultUserAgent = "Flow SWIFT SDK"
        
        var delegate: HTTPSessionDelegate?
        
        enum HTTPMethod: String {
            case get = "GET"
            case post = "POST"
        }

        func fetchService(url: URL, method: HTTPMethod = .get, params: [String: String]? = [:], data: Data? = nil) async throws -> FCL.Response {
            guard let fullURL = buildURL(url: url, params: params) else {
                throw FCLError.generic
            }
            var request = URLRequest(url: fullURL)
            request.httpMethod = method.rawValue

            if let httpBody = data {
                request.httpBody = httpBody
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("application/json", forHTTPHeaderField: "Accept")
            }

            if let location = fcl.config.get(.location) {
                request.addValue(location, forHTTPHeaderField: "referer")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let config = URLSessionConfiguration.default

            let (data, _) = try await URLSession(configuration: config).data(for: request)
            let model = try decoder.decode(FCL.Response.self, from: data)
            return model
        }

        func execHttpPost(service: Service?, data: Data? = nil) async throws -> FCL.Response {
            guard let ser = service, let url = ser.endpoint, let param = ser.params else {
                throw FCLError.generic
            }

            return try await execHttpPost(url: url, params: param, data: data)
        }

        func execHttpPost(url: URL, method: HTTPMethod = .post, params: [String: String]? = [:], data: Data? = nil) async throws -> FCL.Response {
            var configData: Data?
            if let baseConfig = try? BaseConfigRequest().toDictionary() {
                var body: [String: Any]? = [:]
                if let data = data {
                    body = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                }

                let configDict = baseConfig.merging(body ?? [:]) { _, new in new }
                configData = try? JSONSerialization.data(withJSONObject: configDict)
            }

            let result = try await fetchService(url: url, method: method, params: params, data: configData ?? data)
            switch result.status {
            case .approved:
                return result
            case .declined:
                return result
            case .pending:
                delegate?.isPending = true
                guard let local = result.local,
                      let updates = result.updates ?? result.authorizationUpdates
                else {
                    throw FCLError.generic
                }

                try delegate?.openAuthenticationSession(service: local)

                return try await poll(service: updates)
            }
        }

        private func poll(service: Service) async throws -> FCL.Response {
            if !(delegate?.isPending ?? false) {
                throw FCLError.declined
            }

            guard let url = service.endpoint else {
                throw FCLError.invaildURL
            }

            let result = try await fetchService(url: url, method: .get, params: service.params)
            switch result.status {
            case .approved:
                delegate?.closeSession()
                SafariWebViewManager.dismiss()
                return result
            case .declined:
                delegate?.closeSession()
                SafariWebViewManager.dismiss()
                return result
            case .pending:
                try await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000)
                return try await poll(service: service)
            }
        }
    }
}

internal func buildURL(url: URL, params: [String: String]?) -> URL? {
    let paramLocation = "l6n"
    guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return nil
    }

    var queryItems: [URLQueryItem] = urlComponents.queryItems ?? []

    if let location = fcl.config.get(.location) {
        queryItems.append(URLQueryItem(name: paramLocation, value: location))
    }

    for (name, value) in params ?? [:] {
        if name != paramLocation {
            queryItems.append(
                URLQueryItem(name: name, value: value)
            )
        }
    }

    urlComponents.queryItems = queryItems
    return urlComponents.url
}
