//
//  File.swift
//  File
//
//  Created by lmcmz on 4/10/21.
//

import Combine
import Foundation

extension API {
    func fetchService(url: URL, method: String = "GET", params: [String: String]? = [:], data: Data? = nil) -> AnyPublisher<AuthnResponse, Error> {
        guard let fullURL = buildURL(url: url, params: params) else {
            return Result.Publisher(FCLError.generic).eraseToAnyPublisher()
        }
        var request = URLRequest(url: fullURL)
        request.httpMethod = method
        request.httpBody = data
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if let location = fcl.config.get(key: .location) {
            request.addValue(location, forHTTPHeaderField: "referer")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // TODO: Need to check extract config
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config).dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: AuthnResponse.self, decoder: decoder)
            .eraseToAnyPublisher()
    }

    func execHttpPost(url: URL, params: [String: String]? = [:], data: Data? = nil) -> Future<AuthnResponse, Error> {
        return Future { promise in
            self.fetchService(url: url, method: "POST", params: params, data: data)
                .sink { completion in
                    if case let .failure(error) = completion {
                        print(error)
                    }
                } receiveValue: { result in
                    switch result.status {
                    case .approved:
                        promise(.success(result))
                    case .declined:
                        promise(.failure(FCLError.declined))
                    case .pending:
                        self.canContinue = true
                        guard let local = result.local, let updates = result.updates else {
                            promise(.failure(FCLError.generic))
                            return
                        }
                        do {
                            try fcl.openAuthenticationSession(service: local)
                        } catch {
                            promise(.failure(error))
                        }

                        self.poll(service: updates) { result in
                            switch result {
                            case let .success(response):
                                promise(.success(response))
                            case let .failure(error):
                                promise(.failure(error))
                            }
                        }
                    }
                }.store(in: &self.cancellables)
        }
    }

    private func poll(service: Service, completion: @escaping (Result<AuthnResponse, Error>) -> Void) {
        if !canContinue {
            completion(Result.failure(FCLError.declined))
            return
        }

        guard let url = service.endpoint else {
            completion(Result.failure(FCLError.invaildURL))
            return
        }

        fetchService(url: url, method: "GET", params: service.params)
            .sink { complete in
                if case let .failure(error) = complete {
                    completion(Result<AuthnResponse, Error>.failure(error))
                }

            } receiveValue: { result in
                switch result.status {
                case .approved:
                    fcl.closeSession()
                    completion(Result<AuthnResponse, Error>.success(result))
                case .declined:
                    completion(Result.failure(FCLError.declined))
                case .pending:
                    // TODO: Improve this
                    DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) {
                        self.poll(service: service) { response in
                            completion(response)
                        }
                    }
                }
            }.store(in: &cancellables)
    }
}
