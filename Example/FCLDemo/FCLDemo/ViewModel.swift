//
//  ViewModel.swift
//  FCLDemo
//
//  Created by lmcmz on 30/8/21.
//
import Combine
import CryptoKit
import FCL
import Foundation

class ViewModel: NSObject, ObservableObject {
    @Published var address: String = ""

    @Published var preAuthz: String = ""

    @Published var authz: String = ""

    @Published var provider: Provider = .dapper

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        fcl.config(appName: "FCLDemo",
                   appIcon: "https://placekitten.com/g/200/200",
                   location: "https://foo.com",
                   walletNode: "https://fcl-http-post.vercel.app/api",
                   accessNode: "https://access-testnet.onflow.org",
                   scope: "email",
                   authn: provider.endpoint)
//                   authn: "https://flow-wallet.blocto.app/api/flow/authn")
    }

    func changeWallet() {
        fcl.config.put(key: .authn, value: provider.endpoint)
    }

    func authn() {
        fcl.authn()
            .sink { completion in
                if case let .failure(error) = completion {
                    self.address = error.localizedDescription
                }
            } receiveValue: { result in
                self.address = result.address ?? ""
            }.store(in: &cancellables)
    }

    func preauthz() {
        fcl.preauthz()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    self.preAuthz = error.localizedDescription
                }
            } receiveValue: { _ in
//                guard let payer = result.data?.payer?.first,
//                    let proposer = result.data?.proposer else {
//                    self.preAuthz = "Empty payer, proposer or authorization"
//                    return
//                }
//
//                self.preAuthz = """
//                payer: \(payer.identity?.address ?? "")
//                proposer: \(proposer.identity?.address ?? "")
//                """

            }.store(in: &cancellables)
    }

    func authenz() {
//        Flow.shared.authorization()
//            .receive(on: DispatchQueue.main)
//            .sink { completion in
//                if case let .failure(error) = completion {
//                    self.authz = error.localizedDescription
//                }
//            } receiveValue: { result in
//                self.authz = "signature: \(result.data?.signature ?? "")"
//            }.store(in: &cancellables)
    }
}

enum Provider: Int {
    case dapper
    case blocto

    var endpoint: String {
        switch self {
        case .dapper:
            return "https://dapper-http-post.vercel.app/api/authn"
        case .blocto:
            return "https://flow-wallet.blocto.app/api/flow/authn"
        }
    }
}
