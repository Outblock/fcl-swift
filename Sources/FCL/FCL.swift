import AuthenticationServices
import BigInt
import Combine
import Flow
import Starscream
import WalletConnectRelay
import WalletConnectSign
import WalletConnectNetworking
import WalletConnectPairing
import WalletConnectKMS
import SwiftUI
import UIKit

extension WebSocket: WebSocketConnecting {}

private class SocketFactory: WebSocketFactory {
    var socket: WebSocket?
    func create(with url: URL) -> WebSocketConnecting {
        let socket = WebSocket(url: url)
        self.socket = socket
        return socket
    }
}

public let fcl = FCL.shared

public final class FCL: NSObject, ObservableObject {
    public static let shared = FCL()

    public var delegate: FCLDelegate?

    public var config = Config()

    private var providers: [FCL.Provider] = [.dapper, .lilico, .blocto]

    public let version = "@outblock/fcl-swift@0.0.5"

    @Published
    public var currentUser: User?
    
    lazy var defaultAddressRegistry = AddressRegistry()
    
    public var currentEnv: Flow.ChainID?
    public var currentProvider: FCL.Provider?
    
    internal var httpProvider = FCL.HTTPProvider()
    internal var wcProvider: FCL.WalletConnectProvider?
    internal var preAuthz: FCL.Response?
    internal var keychain = KeychainStorage(serviceIdentifier: "@outblock/fcl-swift")
    internal var perferenceStorage = UserDefaults.standard
    
    // MARK: - Back Channel

    public override init() {
        super.init()
        
        if let providerId = perferenceStorage.string(forKey: .PreferenceKey.provider.rawValue),
           let provider = FCL.Provider(id: providerId),
           provider.supportAutoConnect {
            currentProvider = provider
            
            if let data = try? keychain.readData(key: .StorageKey.currentUser.rawValue),
               let user = try? JSONDecoder().decode(FCL.User.self, from: data) {
                currentUser = user
            }
            
            if let env = perferenceStorage.string(forKey: .PreferenceKey.env.rawValue) {
                try? changeProvider(provider: provider, env: Flow.ChainID(name: env))
            }
        }
    }
    
    public func config(metadata: FCL.Metadata,
                       env: Flow.ChainID,
                       provider: FCL.Provider) {
        _ = config
            .put(.title, value: metadata.appName)
            .put(.description, value: metadata.appDescription)
            .put(.icon, value: metadata.appIcon.absoluteString)
            .put(.location, value: metadata.location.absoluteString)
            .put(.authn, value: provider.endpoint(chainId: env))
            .put(.env, value: env.name)
            .put(.providerMethod, value: provider.provider(chainId: env).method.rawValue)

        if let accountProof = metadata.accountProof {
            _ = config
                .put(.nonce, value: accountProof.nonce)
                .put(.appId, value: accountProof.appIdentifier)
        }

        if let walletConnect = metadata.walletConnectConfig {
            _ = config
                .put(.projectID, value: walletConnect.projectID)
                .put(.urlSheme, value: walletConnect.urlScheme)
            
            setupWalletConnect()
        }
        
        if !metadata.autoConnect && provider.supportAutoConnect {
            currentProvider = provider
            perferenceStorage.set(provider.id, forKey: .PreferenceKey.provider.rawValue)
            perferenceStorage.set(env.name, forKey: .PreferenceKey.env.rawValue)
        } else {
            guard let providerId = perferenceStorage.string(forKey: .PreferenceKey.provider.rawValue),
                  let provider = FCL.Provider(id: providerId),
                  provider.supportAutoConnect else {
                      return
            }
            _ = config.put(.authn, value: provider.endpoint(chainId: env))
        }
    }

    private func setupWalletConnect() {
        guard let name = config.get(.title),
              let description = config.get(.description),
              let icon = config.get(.icon),
              let projectID = config.get(.projectID),
              let urlScheme = config.get(.urlSheme)
        else {
            return
        }

        let metadata = AppMetadata(
            name: name,
            description: description,
            url: urlScheme,
            icons: [icon]
        )

        Pair.configure(metadata: metadata)
        Networking.configure(projectId: projectID, socketFactory: SocketFactory())
        wcProvider = FCL.WalletConnectProvider()
    }

    public func changeProvider(provider: FCL.Provider, env: Flow.ChainID) throws {
        if !provider.supportNetwork.contains(env) {
            throw FCLError.unsupportNetwork
        }
        
        config
            .put(.authn, value: provider.endpoint(chainId: env))
            .put(.providerMethod, value: provider.provider(chainId: env).method.rawValue)
            .put(.env, value: env.name)
        
        if provider.supportAutoConnect {
            currentProvider = provider
            perferenceStorage.set(provider.id, forKey: .PreferenceKey.provider.rawValue)
            perferenceStorage.set(env.name, forKey: .PreferenceKey.env.rawValue)
        }
    }
    
    public func openDiscovery() {
        let discoveryVC = UIHostingController(rootView: DiscoveryView())
        discoveryVC.view.backgroundColor = .clear
        discoveryVC.modalPresentationStyle = .overFullScreen
        UIApplication.shared.topMostViewController?.present(discoveryVC, animated: true)
    }
    
    public func closeDiscoveryIfNeed(completion: (() -> Void)? = nil ) {
        guard let vc = UIApplication.shared.topMostViewController as? UIHostingController<DiscoveryView> else {
            return
        }
        vc.dismiss(animated: true, completion: completion)
    }
    
    public func generateNonce() -> String {
        let letters = "0123456789abcdef"
        return String((0..<64).map{ _ in letters.randomElement()! })
    }
    
    internal func getStategy() throws -> FCLStrategy {
        guard let methodString = config.get(.providerMethod),
              let method = FCL.ServiceMethod(rawValue: methodString) else {
            throw FCLError.invalidWalletProvider
        }
        return method.provider
    }
}

// MARK: - Util

internal func serviceOfType(services: [FCL.Service]?, type: FCL.ServiceType) -> FCL.Service? {
    return services?.first(where: { service in
        service.type == type
    })
}
