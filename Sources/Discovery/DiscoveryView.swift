//
//  SwiftUIView.swift
//  
//
//  Created by Hao Fu on 9/11/2022.
//

import SwiftUI

public struct DiscoveryView: View {
    
    @Environment(\.presentationMode)
    var presentationMode
    
    @State
    var isShown: Bool = false
    
    public var body: some View {
        
        VStack(spacing: 0) {
            Spacer()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack(spacing: 0) {
                
                HStack {
                    Text("Connect Wallet")
                    Spacer()
                    
                    Button {
                        isShown = false
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                    
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 18)
                
                Divider()
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal) {
                    HStack(alignment: .center, spacing: 18) {
                        ForEach(FCL.Provider.allCases.filter {
                            $0.supportNetwork.contains(.testnet)
                        },
                                id: \.hashValue) { provider in
                            
                            let info = provider.provider(chainId: .testnet)
                            Button {
                                isShown = false
                                fcl.closeDiscoveryIfNeed {
                                    Task {
                                        do {
                                            try fcl.changeProvider(provider: provider, env: .testnet)
                                            let _ = try await fcl.authenticate()
                                        } catch {
                                            print(error)
                                        }
                                    }
                                }
                                   
                            } label: {
                                VStack {
                                    ImageView(url: info.logo)
                                        .frame(maxWidth: 70, maxHeight: 70)
                                        .cornerRadius(10)
                                    
                                    Text(info.name)
                                        .font(.footnote)
                                        .foregroundColor(.primary)
                                }
                                
                            }
                        }
                    }
                    .padding(18)
                    .padding(.bottom, UIApplication.shared.topMostViewController?.view.safeAreaInsets.bottom ?? .zero)
                }
                .background(Color(UIColor.secondarySystemBackground).edgesIgnoringSafeArea(.bottom))
            }
            .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.bottom))
            .cornerRadius(8, corners: [.topLeft, .topRight])
        }
        .edgesIgnoringSafeArea(.all)
        .background(Color.black.opacity( isShown ? 0.1 : 0).edgesIgnoringSafeArea(.top))
        .animation(isShown ? .easeInOut.delay(0.15) : .none, value: isShown)
        .onAppear {
            isShown = true
        }
        .onTapGesture {
            presentationMode.wrappedValue.dismiss()
            isShown = false
        }
        .onDisappear {
            isShown = false
        }
    }
}

struct DiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            DiscoveryView()
        }
        .background(Color(UIColor.systemBlue))
    }
}

