//
//  ViewModel.swift
//  FCLDemo
//
//  Created by lmcmz on 30/8/21.
//
import BigInt
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

    @Published var provider: FCL.Provider = fcl.currentProvider ?? .lilico

    @Published var env: Flow.ChainID = fcl.currentEnv

    @Published var walletList = FCL.Provider.getEnvCases()

    @MainActor
    @Published var isShowWeb: Bool = false

    @Published var isPresented: Bool = false

    @Published var isAccountProof: Bool?

    @Published var isUserMessageProof: Bool?

    @Published var accountLookup: String = ""

    @Published var currentObject: String = ""

    @Published var message: String = "foo bar"

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

        let accountProof = FCL.Metadata.AccountProofConfig(appIdentifier: "Awesome App (v0.0)")
        let walletConnect = FCL.Metadata.WalletConnectConfig(urlScheme: "fclDemo://", projectID: "c284f5a3346da817aeca9a4e6bc7f935")

        let metadata = FCL.Metadata(appName: "FCLDemo",
                                    appDescription: "Demo App for fcl",
                                    appIcon: URL(string: "https://placekitten.com/g/200/200")!,
                                    location: URL(string: "https://flow.org")!,
                                    accountProof: accountProof,
                                    walletConnectConfig: walletConnect)

        fcl.config(metadata: metadata,
                   env: env,
                   provider: provider)

        fcl.config
            .put("0xFungibleToken", value: "0xf233dcee88fe0abe")
            .put("0xFUSD", value: "0x3c5959b568896393")

        fcl.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { user in
                self.address = user?.addr.hex ?? ""
                if let user = user {
                    print("<==== Current User =====>")
                    print(user)
                    self.verifyAccountProof()
                } else {
                    print("<==== No User =====>")
                }
            }.store(in: &cancellables)

        fcl.$currentEnv
            .receive(on: DispatchQueue.main)
            .sink { env in
                self.env = env
                self.walletList = FCL.Provider.getEnvCases(env: env)
            }.store(in: &cancellables)

        fcl.$currentProvider
            .receive(on: DispatchQueue.main)
            .sink { provider in
                if let provider {
                    self.provider = provider
                }
            }.store(in: &cancellables)

        fcl.delegate = self
    }

    func changeWallet() {
        do {
            try fcl.changeProvider(provider: provider, env: env)
        } catch {
            // Handle unspport network
        }
    }

    func lookupAcount(address: String) async {
        do {
            let account = try await fcl.getAccount(address: address)
            await MainActor.run {
                self.isPresented = true
                self.currentObject = prettyPrint(account)
            }
        } catch {
            print(error)
        }
    }

    func getLastestBlock() async {
        do {
            let block = try await fcl.getLatestBlock()
            await MainActor.run {
                self.isPresented = true
                self.currentObject = prettyPrint(block)
            }
        } catch {
            print(error)
        }
    }

    func queryScript() async {
        do {
            let block = try await fcl.query {
                cadence {
                    script
                }
            }.decode()
            await MainActor.run {
                self.isPresented = true
                self.currentObject = prettyPrint(block)
            }
        } catch {
            print(error)
        }
    }

    func checkBalance(address: String) async {
        do {
            let account = try await fcl.getAccount(address: address)
            await MainActor.run {
                let (quotient, remainder) = account.balance.quotientAndRemainder(dividingBy: BigInt(10).power(8))
                let fullRemainder = String(remainder)
                let fullPaddedRemainder = fullRemainder.leftPadding(toLength: 8, withPad: "0")
                let remainderPadded = fullPaddedRemainder[0 ..< 2]
                self.balance = "\(quotient).\(remainderPadded) Flow"
            }
        } catch {
            print(error)
        }
    }

    func verifyAccountProof() {
        Task {
            do {
                let result = try await fcl.verifyAccountProof()
                print("verifyAccountProof ==> \(result)")
                await MainActor.run {
                    isAccountProof = result
                }
            } catch {
                print(error)
                await MainActor.run {
                    isAccountProof = false
                }
            }
        }
    }

    func verifyUserMessage(message: String, compSigs: FCLUserSignatureResponse) async {
        do {
            let result = try await fcl.verifyUserSignature(message: message, compSigs: [compSigs])
            print("verifyUserMessage ==> \(result)")
            await MainActor.run {
                isUserMessageProof = result
            }
        } catch {
            print(error)
            await MainActor.run {
                isUserMessageProof = false
            }
        }
    }

    func queryFUSD(address: String) async {
        do {
            let block = try await fcl.query {
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
            }.decode(Decimal.self)
            await MainActor.run {
                self.FUSDBalance = "\(block.toTokenFormat()) FUSD"
            }
        } catch {
            print(error)
        }
    }

    func signMessage() async {
        do {
            let block = try await fcl.signUserMessage(message: message)
            await MainActor.run {
                self.isPresented = true
                self.currentObject = prettyPrint(block)
            }
            await verifyUserMessage(message: message, compSigs: block)
        } catch {
            print(error)
        }
    }

    func authn() async {
        do {
            _ = try await fcl.reauthenticate()
        } catch {
            print(error)
        }
    }

    func send() async {
        do {
            let txId = try await fcl.mutate(cadence: transactionScript,
                                            args: [.string("Test2"), .int(1)])

            await MainActor.run {
                self.preAuthz = txId.hex
            }

        } catch {
            print(error)
        }
    }

    func authz() async {
        do {
            let txId = try await fcl.send([
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

            await MainActor.run {
                self.preAuthz = txId.hex
            }

            _ = try await txId.onceSealed()
        } catch {
            print(error)
        }
    }
}

func prettyPrint(_ object: Any) -> String {
    return Pretty._prettyPrint(label: nil, [object], separator: "\n", option: Pretty.sharedOption, colored: false)
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context _: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_: SFSafariViewController, context _: UIViewControllerRepresentableContext<SafariView>) {}
}

extension ViewModel: FCLDelegate {
    func showLoading() {
        ProgressHUD.show("Loading...")
    }

    func hideLoading() {
        ProgressHUD.dismiss()
    }
}
