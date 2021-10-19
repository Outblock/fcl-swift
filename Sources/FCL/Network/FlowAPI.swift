//
//  File.swift
//
//
//  Created by lmcmz on 29/8/21.
//

import AsyncHTTPClient
import Combine
import Flow
import Foundation
import NIO
import NIOHTTP1

class API {
    internal let defaultUserAgent = "Flow SWIFT SDK"
    internal var cancellables = Set<AnyCancellable>()
    let client = HTTPClient(eventLoopGroupProvider: .createNew)

    // TODO: Improve this
    internal var canContinue = true

    func fetchService<T>(url: URL, method: HTTPMethod) -> EventLoopFuture<T> where T: Decodable {
        let eventLoop = EmbeddedEventLoop()
        let promise = eventLoop.makePromise(of: T.self)
        guard var request = try? HTTPClient.Request(url: url, method: method)
        else {
            promise.fail(Flow.FError.urlInvaild)
            return promise.futureResult
        }
        request.headers.add(name: "User-Agent", value: defaultUserAgent)

        let call = client.execute(request: request)
        call.whenSuccess { response in
            let decodeModel: T? = self.decodeToModel(body: response.body)
            guard let model = decodeModel else {
                promise.fail(Flow.FError.decodeFailure)
                return
            }
            promise.succeed(model)
        }
        call.whenFailure { error in
            promise.fail(error)
        }
        return promise.futureResult
    }

    func fetchService<T, V>(url: URL, method: HTTPMethod, body: V? = nil) -> EventLoopFuture<T> where T: Decodable, V: Encodable {
        let eventLoop = EmbeddedEventLoop()
        let promise = eventLoop.makePromise(of: T.self)
        guard let encodeModel = body, let data = try? JSONEncoder().encode(encodeModel) else {
            promise.fail(Flow.FError.encodeFailure)
            return promise.futureResult
        }
        guard var request = try? HTTPClient.Request(url: url, method: method, body: HTTPClient.Body.data(data))
        else {
            promise.fail(Flow.FError.urlInvaild)
            return promise.futureResult
        }
        request.headers.add(name: "User-Agent", value: defaultUserAgent)

        let call = client.execute(request: request)
        call.whenSuccess { response in
            let decodeModel: T? = self.decodeToModel(body: response.body)
            guard let model = decodeModel else {
                promise.fail(Flow.FError.decodeFailure)
                return
            }
            promise.succeed(model)
        }
        call.whenFailure { error in
            promise.fail(error)
        }
        return promise.futureResult
    }

    func execHttpPost(url: String, method: HTTPMethod = .POST) -> Future<AuthnResponse, Error> {
        return Future { promise in

            guard let url = URL(string: url) else {
                promise(.failure(Flow.FError.urlInvaild))
                return
            }

            let call: EventLoopFuture<AuthnResponse> = self.fetchService(url: url, method: method)
            call.whenSuccess { result in
                switch result.status {
                case .approved:
                    promise(.success(result))
                case .declined:
                    promise(.failure(Flow.FError.declined))
                case .pending:
                    self.canContinue = true
                    guard let local = result.local, let updates = result.updates else { return }
                    //                    SafariWebViewManager.openSafariWebView(service: local) {
                    //                        self.canContinue = false
                    //                    }
                    self.poll(service: updates, canContinue: self.canContinue).sink { completion in
                        // TODO: Handle special error
                        if case let .failure(error) = completion {
                            promise(.failure(error))
                        }
                    } receiveValue: { result in
                        promise(.success(result))
                    }.store(in: &self.cancellables)
                }
            }
        }
    }

    func poll(service: Service, canContinue _: Bool) -> Future<AuthnResponse, Error> {
        return Future { promise in

            if !self.canContinue {
                promise(.failure(Flow.FError.declined))
                return
            }

            guard let url = service.endpoint else {
                promise(.failure(Flow.FError.urlInvaild))
                return
            }

            guard let method = service.method?.http else {
                promise(.failure(Flow.FError.generic))
                return
            }

            let call: EventLoopFuture<AuthnResponse> = self.fetchService(url: url, method: method)

            call.whenSuccess { result in
                print("polling ---> \(result.status.rawValue)")
                switch result.status {
                case .approved:
                    promise(.success(result))
                case .declined:
                    // TODO: Need to discuss here, whether decline is an error case or not
                    promise(.success(result))
                case .pending:
                    // TODO: Improve this
                    DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) {
                        self.poll(service: service, canContinue: self.canContinue)
                            .sink { completion in
                                if case let .failure(error) = completion {
                                    promise(.failure(error))
                                }
                            } receiveValue: { result in
                                promise(.success(result))
                            }
                            .store(in: &self.cancellables)
                    }
                }
            }

            call.whenFailure { error in
                promise(.failure(error))
            }
        }
    }

    func decodeToModel<T: Decodable>(body: ByteBuffer?) -> T? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            _ = try decoder.decode(T.self, from: body!)
        } catch {
            print(error)
        }

        guard let data = body,
              let model = try? decoder.decode(T.self, from: data) else {
            return nil
        }

        return model
    }
}

func buildURL(url: URL, params: [String: String]?) -> URL? {
    let paramLocation = "l6n"
    guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return nil
    }

    var queryItems: [URLQueryItem] = []

    if let location = fcl.config.get(key: .location) {
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
