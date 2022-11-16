//
//  File.swift
//  
//
//  Created by Hao Fu on 26/9/2022.
//

import Foundation
import Flow
import Combine
import WalletConnectSign
import WalletConnectUtils
import WalletConnectPairing
import UIKit

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
        private var publishers = [AnyCancellable]()
        
        init() {
            setUpWCSubscribing()
            reloadSession()
            reloadPair()
            
            // try? Sign.instance.cleanup()
        }
        
        func execService<T>(url: URL, method: FCL.ServiceType, request: T?) async throws -> FCL.Response where T : Encodable {
            guard let env = fcl.config.get(.env),
                  let network = WCFlowBlockchain.allCases.first(where: { $0.rawValue == env }),
                    let blockchain = network.blockchain else {
                throw FCLError.invaildNetwork
            }
            
            if method == .authn {
                do {
                    currentProposal = nil
                    try await connectToWallet()
                    let response = try await Sign.instance.sessionSettlePublisher.async()
                    
                    guard let data = try? JSONEncoder().encode(BaseConfigRequest()),
                          let dataString = String(data: data, encoding: .utf8) else {
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
                          let model = try? decoder.decode(FCL.Response.self, from: data) else {
                        throw FCLError.decodeFailure
                    }
                    return model
                } catch {
                    print("authn error ===> \(error)")
                    throw FCLError.failedToConnectWallet
                }
            }
            
            guard let session = self.sessions.first else {
                throw FCLError.unauthenticated
            }
            
            guard let request = request,
                  let data = try? JSONEncoder().encode(request),
                  let dataString = String(data: data, encoding: .utf8) else {
                throw FCLError.encodeFailure
            }
            
            let request1 = Request(topic: session.topic,
                                  method: WCMethod(service: method).rawValue,
                                  params: AnyCodable([dataString]),
                                  chainId: blockchain)
            
            try await Sign.instance.request(params: request1)
            try connectWithExampleWallet()
            
            let authzResponse = try await Sign.instance.sessionResponsePublisher.async()
            
            guard case let .response(value) = authzResponse.result else {
                throw FCLError.generic
            }
            
            let string = try value.asJSONEncodedString()
            let responseData = string.data(using: .utf8)!
            let model = try JSONDecoder().decode(FCL.Response.self, from: responseData)
            return model
        }
        
        private func reloadSessionAndPair() {
            self.pairings = Pair.instance.getPairings()
            self.sessions = Sign.instance.getSessions()
        }
        
        private func reloadSession() {
            self.pairings = Pair.instance.getPairings()
        }
        
        private func reloadPair() {
            self.sessions = Sign.instance.getSessions()
        }
        
        
        private func connectToWallet() async throws {
            reloadSessionAndPair()
            let methods: Set<String> = Set(WCMethod.allCases.map{ $0.rawValue })
            
            guard let env = fcl.config.get(.env),
                  let network = WCFlowBlockchain.allCases.first(where: { $0.rawValue == env }),
                    let blockchain = network.blockchain else {
                throw FCLError.invaildNetwork
            }
            
            guard let endpoint = fcl.config.get(.authn) else {
                throw Flow.FError.urlEmpty
            }
            
            var topic: String? = nil
            if let existingPairing = self.pairings.first(where: { $0.peer?.url == endpoint }) {
                topic = existingPairing.topic
            }
            
            let blockchains: Set<Blockchain> = Set([blockchain])
            let namespaces: [String: ProposalNamespace] = [blockchain.namespace: ProposalNamespace(chains: blockchains, methods: methods, events: [], extensions: nil)]
            
            if let topic {
                try await Sign.instance.connect(requiredNamespaces: namespaces, topic: topic)
                try connectWithExampleWallet(uri: nil)
            } else {
                let uri = try await Pair.instance.create()
                try connectWithExampleWallet(uri: uri)
            }
        }
        
        private func connectWithExampleWallet(uri: WalletConnectURI? = nil) throws{
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
                .sink { [weak self] status in
                    if status == .connected {
//                        self?.onClientConnected?()
                        print("Client connected")
                    }
                }.store(in: &publishers)

            Sign.instance.sessionResponsePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] response in
                    
                    // Response
                    print("Session Response ===> \(response)")
                }.store(in: &publishers)
            
            Sign.instance.sessionProposalPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] sessionProposal in
                    print("[RESPONDER] WC: Did receive session proposal")
                    self?.currentProposal = sessionProposal
//                        self?.showSessionProposal(Proposal(proposal: sessionProposal)) // FIXME: Remove mock
                    self?.reloadSessionAndPair()
                }.store(in: &publishers)

            Sign.instance.sessionSettlePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] response in
//                    self?.reloadActiveSessions()
                    print("Session Settle ===> \(response)")
                    self?.reloadSessionAndPair()
                }.store(in: &publishers)

            Sign.instance.sessionRequestPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] sessionRequest in
                    print("[RESPONDER] WC: Did receive session request")
//                    self?.showSessionRequest(sessionRequest)
                }.store(in: &publishers)
            


            Sign.instance.sessionDeletePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
//                    self?.reloadActiveSessions()
//                    self?.navigationController?.popToRootViewController(animated: true)
                    self?.reloadSessionAndPair()
                }.store(in: &publishers)
        }
        
    }
}
