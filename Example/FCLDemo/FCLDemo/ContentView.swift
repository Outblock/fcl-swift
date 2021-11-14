//
//  ContentView.swift
//  FCLDemo
//
//  Created by lmcmz on 30/8/21.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()

    var signIn: some View {
        return Section {
            HStack {
                Button {
                    viewModel.authn()
                } label: {
                    Label("Sign In", systemImage: "person")
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
                }

                Picker("iFrame", selection: $viewModel.provider, content: {
                    Text("Dapper").tag(Provider.dapper)
                    Text("Blocoto").tag(Provider.blocto)
                }).onChange(of: viewModel.provider, perform: { _ in
                    viewModel.changeWallet()
                })
                    .pickerStyle(SegmentedPickerStyle())
            }
            Text(verbatim: viewModel.address)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                signIn

                Section {
                    Button {
                        viewModel.checkBalance(address: viewModel.address)
                        viewModel.queryFUSD(address: viewModel.address)
                    } label: {
                        Label("Get Balance", systemImage: "dollarsign.circle")
                    }

                    Text(viewModel.balance)
                    Text(viewModel.FUSDBalance)
                }

                Section {
                    Button {
                        viewModel.getLastestBlock()
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
                        viewModel.lookupAcount(address: viewModel.accountLookup)
                    } label: {
                        Label("Lookup account", systemImage: "eyes")
                    }
                }

                Section {
                    TextEditor(text: $viewModel.script)
                        .textFieldStyle(.roundedBorder)
                        .font(.footnote)

                    Button {
                        viewModel.queryScript()
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
                            SafariView(url: URL(string: "https://flowscan.org/transaction/\(viewModel.preAuthz)")!)
                        }
                    }

                    Button {
                        viewModel.authz()
                    } label: {
                        Label("Send Transaction", systemImage: "doc.plaintext")
                    }
                }

                Section {
                    TextField("Message", text: $viewModel.message)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        viewModel.signMessage()
                    } label: {
                        Label("Sign message (Unavailable)", systemImage: "pencil")
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
