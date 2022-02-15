//
import BigInt
//  ViewModel.swift
//  FCLDemo
//
//  Created by lmcmz on 30/8/21.
//
import Combine
import CryptoKit
import FCL
import Flow
import Foundation
import SafariServices
import SwiftPrettyPrint
import SwiftUI

class ViewModel: NSObject, ObservableObject {
    @Published var address: String = ""

    @Published var preAuthz: String = ""

    @Published var provider: Provider = .blocto

    @Published var isShowWeb: Bool = false

    @Published var isPresented: Bool = false

    @Published var accountLookup: String = ""

    @Published var currentObject: String = ""

    @Published var message: String = ""

    @Published var balance: String = ""
    @Published var FUSDBalance: String = ""

    @Published var script: String =
        """
        pub struct SomeStruct {
          pub var x: Int
          pub var y: Int

          init(x: Int, y: Int) {
            self.x = x
            self.y = y
          }
        }

        pub fun main(): [SomeStruct] {
          return [SomeStruct(x: 1, y: 2),
                  SomeStruct(x: 3, y: 4)]
        }
        """

    @Published var transactionScript: String =
        """
           transaction(test: String, testInt: Int) {
               prepare(signer: AuthAccount) {
                    log(signer.address)
                    log(test)
                    log(testInt)
               }
           }
        """

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        fcl.config(appName: "FCLDemo",
                   appIcon: "https://placekitten.com/g/200/200",
                   location: "https://foo.com",
                   walletNode: "https://fcl-http-post.vercel.app/api",
                   accessNode: "https://access-testnet.onflow.org",
                   env: "mainnet",
                   scope: "email",
                   authn: provider.endpoint)

        fcl.config
            .put(key: "0xFungibleToken", value: "0xf233dcee88fe0abe")
            .put(key: "0xFUSD", value: "0x3c5959b568896393")
    }

    func changeWallet() {
        fcl.config.put(key: .authn, value: provider.endpoint)
    }

    func lookupAcount(address: String) {
        fcl.getAccount(address: address)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                }
            } receiveValue: { block in
                self.isPresented = true
                self.currentObject = prettyPrint(block)
            }.store(in: &cancellables)
    }

    func getLastestBlock() {
        fcl.getLastestBlock()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                }
            } receiveValue: { block in
                self.isPresented = true
                self.currentObject = prettyPrint(block)
            }.store(in: &cancellables)
    }

    func queryScript() {
        fcl.query {
            cadence {
                script
            }
        }
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case let .failure(error) = completion {
                print(error)
            }
        } receiveValue: { block in
            self.isPresented = true
            self.currentObject = prettyPrint(block)
        }.store(in: &cancellables)
    }

    func checkBalance(address: String) {
        fcl.getAccount(address: address)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                }
            } receiveValue: { account in
                if let data = account {
                    let (quotient, remainder) = data.balance.quotientAndRemainder(dividingBy: BigInt(10).power(8))
                    let fullRemainder = String(remainder)
                    let fullPaddedRemainder = fullRemainder.leftPadding(toLength: 8, withPad: "0")
                    let remainderPadded = fullPaddedRemainder[0 ..< 2]
                    self.balance = "\(quotient).\(remainderPadded) Flow"
                } else {
                    self.balance = "Empty account"
                }

            }.store(in: &cancellables)
    }

    func queryFUSD(address: String) {
        fcl.query {
            cadence {
                """
                import FungibleToken from 0xFungibleToken
                import FUSD from 0xFUSD

                pub fun main(account: Address): UFix64 {
                  let receiverRef = getAccount(account).getCapability(/public/fusdBalance)!
                    .borrow<&FUSD.Vault{FungibleToken.Balance}>()

                  return receiverRef!.balance
                }
                """
            }

            arguments {
                [.address(Flow.Address(hex: address))]
            }

            gasLimit {
                1000
            }
        }
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case let .failure(error) = completion {
                print(error)
            }
        } receiveValue: { block in
            self.FUSDBalance = "\(String(block.fields?.value.toUFix64() ?? 0.0)) FUSD"
        }.store(in: &cancellables)
    }

    func signMessage() {
        fcl.signUserMessage(message: message)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                }
            } receiveValue: { block in
                self.isPresented = true
                self.currentObject = prettyPrint(block)
            }.store(in: &cancellables)
    }

    func authn() {
        fcl.authenticate()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    self.address = error.localizedDescription
                }
            } receiveValue: { result in
                self.address = result.address ?? ""
            }.store(in: &cancellables)
    }

    func send() {
        fcl.mutate {
            cadence {
                transactionScript
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

    func authz() {
        fcl.send([
            .transaction(
                """
                   transaction(test: String, testInt: Int) {
                       prepare(signer: AuthAccount) {
                            log(signer.address)
                            log(test)
                            log(testInt)
                       }
                   }
                """
            ),
            .args([.string("Test2"), .int(1)]),
            .limit(1000),
        ])
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

func prettyPrint(_ object: Any) -> String {
    return Pretty._prettyPrint(label: nil, [object], separator: "\n", option: Pretty.sharedOption, colored: false)
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
