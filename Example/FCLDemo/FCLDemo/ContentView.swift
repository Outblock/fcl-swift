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
                    Button("PreAuthz") {
                        viewModel.preauthz()
                    }

                    Text(verbatim: viewModel.preAuthz)
                }

                Section {
                    Button("Authz") {
                        viewModel.authenz()
                    }

                    Text(verbatim: viewModel.authz)
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
