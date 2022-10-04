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
import UIKit

extension FCL {
    
    enum WCMethod: String, CaseIterable {
        case authn = "flow_authn"
        case authz = "flow_authz"
        case userSignature = "flow_user_sign"
        case unknow
        
        static func convertFrom(service: ServiceType) -> Self {
            switch service {
            case .authn:
                return .authn
            case .authz:
                return .authz
            case .userSignature:
                return .userSignature
            default:
                return .unknow
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
        }
        
        func execService<T>(url: URL, method: FCL.ServiceType, request: T?) async throws -> FCL.Response where T : Codable {
            guard let session = self.sessions.first else {
                throw FCLError.unauthenticated
            }
            
            
            guard let env = fcl.config.get(.env),
                  let network = WCFlowBlockchain.allCases.first(where: { $0.rawValue == env }),
                    let blockchain = network.blockchain else {
                throw FCLError.invaildNetwork
            }
            
            guard let data = try? JSONEncoder().encode(request),
                  let dataString = String(data: data, encoding: .utf8) else {
                throw FCLError.encodeFailure
            }
            
            let request = Request(topic: session.topic, method: WCMethod.convertFrom(service: method).rawValue,
                                  params: AnyCodable([dataString]), chainId: blockchain )
            try await Sign.instance.request(params: request)
            
            let response = try await Sign.instance.sessionResponsePublisher.async()
            guard let paramStr = try? request.params.get([String].self),
                  let deocdeStr = paramStr.first, let data = deocdeStr.data(using: .utf8),
                  let decode = try? JSONDecoder().decode(FCL.Response.self, from: data) else {
                throw FCLError.decodeFailure
            }
            
            return decode
        }
        
        private func reloadSessionAndPair() {
            self.pairings = Sign.instance.getPairings()
            self.sessions = Sign.instance.getSessions()
        }
        
        private func reloadSession() {
            self.pairings = Sign.instance.getPairings()
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
            
            let blockchains: Set<Blockchain> = Set([blockchain])
            let namespaces: [String: ProposalNamespace] = [blockchain.namespace: ProposalNamespace(chains: blockchains, methods: methods, events: [], extensions: nil)]
            
            guard let uri = try await Sign.instance.connect(requiredNamespaces: namespaces, topic: self.sessions.first?.topic) else {
                throw FCLError.generateURIFailed
            }
            try connectWithExampleWallet(uri: uri)
        }
        
        private func connectWithExampleWallet(uri: WalletConnectURI) throws{
            
            guard let endpoint = fcl.config.get(.authn) else {
                throw Flow.FError.urlEmpty
            }
            
            let url = URL(string: "\(endpoint)/wc?uri=\(uri.absoluteString)")!
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:])
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
                .sink { [weak self] _ in
//                    self?.reloadActiveSessions()
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
