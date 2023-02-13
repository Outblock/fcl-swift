//
//  File.swift
//
//
//  Created by Hao Fu on 26/9/2022.
//

import Combine
import Flow
import Foundation
import Starscream
import UIKit
import WalletConnectPairing
import WalletConnectSign
import WalletConnectUtils
import Gzip

extension WebSocket: WebSocketConnecting {}

internal class SocketFactory: WebSocketFactory {
    var socket: WebSocket?
    func create(with url: URL) -> WebSocketConnecting {
        let socket = WebSocket(url: url)
        self.socket = socket
        return socket
    }
}

extension FCL {
    enum WCMethod: String, CaseIterable {
        case authn = "flow_authn"
        case authz = "flow_authz"
        case preAuthz = "flow_pre_authz"
        case userSignature = "flow_user_sign"
        case unknow

        public init(service: ServiceType) {
            switch service {
            case .authn:
                self = .authn
            case .authz:
                self = .authz
            case .userSignature:
                self = .userSignature
            case .preAuthz:
                self = .preAuthz
            default:
                self = .unknow
            }
        }
    }

    enum WCFlowBlockchain: String, CaseIterable {
        case mainnet
        case testnet

        var blockchain: Blockchain? {
            switch self {
            case .mainnet:
                return Blockchain("flow:mainnet")
            case .testnet:
                return Blockchain("flow:testnet")
            }
        }
    }

    class WalletConnectProvider: FCLStrategy {
        var sessions: [Session] = []
        var pairings: [Pairing] = []
        var currentProposal: Session.Proposal?
        var currentSession: Session?
        private var publishers = [AnyCancellable]()

        init() {
            setUpWCSubscribing()
            reloadSession()
            reloadPair()

            // try? Sign.instance.cleanup()
        }

        func execService<T>(url _: URL, method: FCL.ServiceType, request: T?) async throws -> FCL.Response where T: Encodable {
            guard let env = fcl.config.get(.env),
                  let network = WCFlowBlockchain.allCases.first(where: { $0.rawValue == env }),
                  let blockchain = network.blockchain
            else {
                throw FCLError.invaildNetwork
            }

            if method == .authn {
                do {
                    currentProposal = nil
                    try await connectToWallet()
                    let response = try await Sign.instance.sessionSettlePublisher.async()
                    currentSession = response

                    if let data = response.topic.data(using: .utf8) {
                        try? fcl.keychain.add(data: data, forKey: .StorageKey.wcSession.rawValue)
                    }

                    guard let data = try? JSONEncoder().encode(BaseConfigRequest()),
                          let dataString = String(data: data, encoding: .utf8)
                    else {
                        throw FCLError.encodeFailure
                    }
                    let authnRequest = Request(topic: response.topic,
                                               method: WCMethod.authn.rawValue,
                                               params: AnyCodable([dataString]),
                                               chainId: blockchain)
                    try await Sign.instance.request(params: authnRequest)
                    let authnResponse = try await Sign.instance.sessionResponsePublisher.async()

                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase

                    guard case let .response(value) = authnResponse.result,
                          let string = try? value.asJSONEncodedString(),
                          let data = string.data(using: .utf8),
                          let model = try? decoder.decode(FCL.Response.self, from: data)
                    else {
                        throw FCLError.decodeFailure
                    }
                    return model
                } catch {
                    Task {
                        try? fcl.keychain.deleteAll()
                        await disconnectAll()
                    }
                    print("authn error ===> \(error)")
                    throw error
                }
            }

            guard let data = try? fcl.keychain.readData(key: .StorageKey.wcSession.rawValue),
                  let sessionTopic = String(data: data, encoding: .utf8)
            else {
                throw FCLError.unauthenticated
            }

            guard let request = request,
                  let data = try? JSONEncoder().encode(request),
                  let compressedData = try? data.gzipped(level: .bestCompression)
            else {
                throw FCLError.encodeFailure
            }
            
            let dataString = compressedData.base64EncodedString()

            let request1 = Request(topic: sessionTopic,
                                   method: WCMethod(service: method).rawValue,
                                   params: AnyCodable([dataString]),
                                   chainId: blockchain)

            try await Sign.instance.request(params: request1)
            try connectWithExampleWallet()

            let authzResponse = try await Sign.instance.sessionResponsePublisher.async()

            guard case let .response(value) = authzResponse.result else {
                throw FCLError.invaildAuthzReponse
            }

            let string = try value.asJSONEncodedString()
            let responseData = string.data(using: .utf8)!
            let model = try JSONDecoder().decode(FCL.Response.self, from: responseData)
            return model
        }

        private func reloadSessionAndPair() {
            pairings = Pair.instance.getPairings()
            sessions = Sign.instance.getSessions()
        }

        private func reloadSession() {
            pairings = Pair.instance.getPairings()
        }

        private func reloadPair() {
            sessions = Sign.instance.getSessions()
        }

        public func disconnect(topic: String? = nil) async throws {
            if let topic {
                try await Pair.instance.disconnect(topic: topic)
            } else {
                if let currentSession {
                    try await Pair.instance.disconnect(topic: currentSession.topic)
                }
            }
        }

        public func disconnectAll() async {
            await withTaskGroup(of: Void.self) { group in
                Sign.instance.getSessions().forEach { session in
                    group.addTask {
                        try? await Pair.instance.disconnect(topic: session.topic)
                    }
                }

                Pair.instance.getPairings().forEach { pair in
                    group.addTask {
                        try? await Pair.instance.disconnect(topic: pair.topic)
                    }
                }
            }
        }

        private func connectToWallet() async throws {
            reloadSessionAndPair()
            let methods: Set<String> = Set(WCMethod.allCases.map { $0.rawValue })

            guard let env = fcl.config.get(.env),
                  let network = WCFlowBlockchain.allCases.first(where: { $0.rawValue == env }),
                  let blockchain = network.blockchain
            else {
                throw FCLError.invaildNetwork
            }

            guard let endpoint = fcl.config.get(.authn) else {
                throw Flow.FError.urlEmpty
            }

            var topic: String?
            if let existingPairing = pairings.first(where: { $0.peer?.url == endpoint }) {
                topic = existingPairing.topic
            } else if let data = try? fcl.keychain.readData(key: .StorageKey.wcSession.rawValue),
                      let sessionTopic = String(data: data, encoding: .utf8)
            {
                topic = sessionTopic
            }

            let blockchains: Set<Blockchain> = Set([blockchain])
            let namespaces: [String: ProposalNamespace] = [blockchain.namespace: ProposalNamespace(chains: blockchains, methods: methods, events: [], extensions: nil)]

            if let topic {
                try await Sign.instance.connect(requiredNamespaces: namespaces, topic: topic)
                try connectWithExampleWallet(uri: nil)
            } else {
                let uri = try await Pair.instance.create()
                try await Sign.instance.connect(requiredNamespaces: namespaces, topic: uri.topic)
                try connectWithExampleWallet(uri: uri)
            }
        }

        private func connectWithExampleWallet(uri: WalletConnectURI? = nil) throws {
            guard let endpoint = fcl.config.get(.authn) else {
                throw Flow.FError.urlEmpty
            }
            var url = URL(string: endpoint)
            if let encodedURI = uri?.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {
                url = URL(string: "\(endpoint)/wc?uri=\(encodedURI)")
            }

            DispatchQueue.main.async {
                if let url {
                    UIApplication.shared.open(url, options: [:])
                }
            }
        }

        func setUpWCSubscribing() {
            Sign.instance.socketConnectionStatusPublisher
                .receive(on: DispatchQueue.main)
                .sink { status in
                    if status == .connected {
                        print("Client connected")
                    }
                }.store(in: &publishers)

            Sign.instance.sessionResponsePublisher
                .receive(on: DispatchQueue.main)
                .sink { response in
                    print("Session Response ===> \(response)")
                }.store(in: &publishers)

            Sign.instance.sessionProposalPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] sessionProposal in
                    print("[RESPONDER] WC: Did receive session proposal")
                    self?.currentProposal = sessionProposal
                    self?.reloadSessionAndPair()
                }.store(in: &publishers)

            Sign.instance.sessionSettlePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] response in
                    print("Session Settle ===> \(response)")
                    self?.reloadSessionAndPair()
                }.store(in: &publishers)

            Sign.instance.sessionRequestPublisher
                .receive(on: DispatchQueue.main)
                .sink { _ in
                    print("[RESPONDER] WC: Did receive session request")
                }.store(in: &publishers)

            Sign.instance.sessionDeletePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.reloadSessionAndPair()
                }.store(in: &publishers)
        }
    }
}
