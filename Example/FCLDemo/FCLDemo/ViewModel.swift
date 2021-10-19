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
import SafariServices
import SwiftUI
import Flow

class ViewModel: NSObject, ObservableObject {
    @Published var address: String = ""

    @Published var preAuthz: String = ""

    @Published var provider: Provider = .blocto

    @Published var isShowWeb: Bool = false

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
    }

    func changeWallet() {
        _ = fcl.config.put(key: .authn, value: provider.endpoint)
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

    func authz() {
        fcl.mutate {
            cadence {
                """
                           transaction(test: String, testInt: Int) {
                               prepare(signer: AuthAccount) {
                                    log(signer.address)
                                    log(test)
                                    log(testInt)
                               }
                           }
                """
            }
            
            arguments {
                [.string("Test2"), .int(1)]
            }
            
            gasLimit {
                1000
            }
        }
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case let .failure(error) = completion {
                self.preAuthz = error.localizedDescription
            }
        } receiveValue: { txId in
            self.preAuthz = txId
        }.store(in: &cancellables)
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

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context _: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_: SFSafariViewController, context _: UIViewControllerRepresentableContext<SafariView>) {}
}
