//
//  ContentView.swift
//  FCLDemo
//
//  Created by lmcmz on 30/8/21.
//

import FCL
import Flow
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()

    var signIn: some View {
        return Section {
            Button {
                Task {
                    await viewModel.authn()
                }
            } label: {
                Label("Sign In", systemImage: "person")
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
            }

            Text(verbatim: viewModel.address)

            if let isAccountProof = viewModel.isAccountProof {
                Label("Account Proof", systemImage: isAccountProof ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isAccountProof ? .green : .red)
            }

            if fcl.currentUser?.loggedIn ?? false {
                Button {
                    Task {
                        do {
                            try await fcl.unauthenticate()
                        } catch {
                            print(error)
                        }
                    }
                } label: {
                    Label("Sign out", systemImage: "person.badge.minus")
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
                }
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("iFrame", selection: $viewModel.env, content: {
                        Text("mainnet").tag(Flow.ChainID.mainnet)
                        Text("testnet").tag(Flow.ChainID.testnet)
                    }).onChange(of: viewModel.env, perform: { _ in
                        viewModel.changeWallet()
                    })
                    .pickerStyle(SegmentedPickerStyle())
                } header: {
                    Text("Network")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Open Discovery") {
                        fcl.openDiscovery()
                    }
                } header: {
                    Text("Wallet Discovery")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section {
                    Picker("iFrame", selection: $viewModel.provider, content: {
                        ForEach(viewModel.walletList, id: \.hashValue) { provider in
                            Text(provider.name).tag(provider)
                        }
                    }).onChange(of: viewModel.provider, perform: { _ in
                        viewModel.changeWallet()
                    })
                    .pickerStyle(SegmentedPickerStyle())
                } header: {
                    Text("Wallet Provider")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                signIn

                Section {
                    Button {
                        Task {
                            await viewModel.checkBalance(address: viewModel.address)
                            await viewModel.queryFUSD(address: viewModel.address)
                        }
                    } label: {
                        Label("Get Balance", systemImage: "dollarsign.circle")
                    }

                    Text(viewModel.balance)
                    Text(viewModel.FUSDBalance)
                }

                Section {
                    Button {
                        Task {
                            await viewModel.getLastestBlock()
                        }
                    } label: {
                        Label("Get lastest block", systemImage: "cube")
                    }.sheet(isPresented: $viewModel.isPresented) {
                        viewModel.isPresented = false
                    } content: {
                        DetaiView(text: viewModel.currentObject)
                    }
                }

                Section {
                    TextField("Enter flow address", text: $viewModel.accountLookup)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            await viewModel.lookupAcount(address: viewModel.accountLookup)
                        }
                    } label: {
                        Label("Lookup account", systemImage: "eyes")
                    }
                }

                Section {
                    TextEditor(text: $viewModel.script)
                        .textFieldStyle(.roundedBorder)
                        .font(.footnote)

                    Button {
                        Task {
                            await viewModel.queryScript()
                        }
                    } label: {
                        Label("Run script", systemImage: "ellipsis.curlybraces")
                    }
                }

                Section {
                    TextEditor(text: $viewModel.transactionScript)
                        .textFieldStyle(.roundedBorder)
                        .font(.footnote)

                    Text(verbatim: viewModel.preAuthz)

                    if !viewModel.preAuthz.isEmpty {
                        Button("View on flow scan") {
                            viewModel.isShowWeb.toggle()
                        }.sheet(isPresented: $viewModel.isShowWeb, onDismiss: nil) {
                            SafariView(url: URL(string: "https://\(viewModel.env == .testnet ? "testnet." : "")flowscan.org/transaction/\(viewModel.preAuthz)")!)
                        }
                    }

                    Button {
                        Task {
                            await viewModel.authz()
                        }
                    } label: {
                        Label("Send Transaction", systemImage: "doc.plaintext")
                    }
                }

                Section {
                    TextField("Message", text: $viewModel.message)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task {
                            await viewModel.signMessage()
                        }
                    } label: {
                        Label("Sign message", systemImage: "pencil")
                    }

                    if let isAccountProof = viewModel.isUserMessageProof {
                        Label("User Message Proof", systemImage: isAccountProof ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isAccountProof ? .green : .red)
                    }
                }
            }
            .navigationTitle("FCL-Swift Demo")
            //            .keyboardAware()
            //            .dismissingKeyboard()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
