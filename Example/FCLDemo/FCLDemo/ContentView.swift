//
//  ContentView.swift
//  FCLDemo
//
//  Created by lmcmz on 30/8/21.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Picker("iFrame", selection: $viewModel.provider, content: {
                            Text("Dapper").tag(Provider.dapper)
                            Text("Blocoto").tag(Provider.blocto)
                        }).onChange(of: viewModel.provider, perform: { _ in
                            viewModel.changeWallet()
                        })
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                    }

                    Button("Auth") {
                        viewModel.authn()
                    }

                    Text(verbatim: viewModel.address)
                }

                Section {
                    Button("Authz") {
                        viewModel.authz()
                    }

                    Text(verbatim: viewModel.preAuthz)

                    if !viewModel.preAuthz.isEmpty {
                        Button("View on flow scan") {
                            viewModel.isShowWeb.toggle()
                        }.sheet(isPresented: $viewModel.isShowWeb, onDismiss: nil) {
                            SafariView(url: URL(string: "https://flowscan.org/transaction/\(viewModel.preAuthz)")!)
                        }
                    }
                }
            }.navigationTitle("FCL-Swift Demo")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
