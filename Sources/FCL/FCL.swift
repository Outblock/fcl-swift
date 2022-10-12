import AuthenticationServices
import BigInt
import Combine
import Flow
import Starscream
import WalletConnectRelay
import WalletConnectSign

extension WebSocket: WebSocketConnecting {}

struct SocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        return WebSocket(url: url)
    }
}

public let fcl = FCL.shared

public final class FCL: NSObject, ObservableObject {
    public static let shared = FCL()

    public var delegate: FCLDelegate?

    public var config = Config()

    private var providers: [FCL.Provider] = [.dapper, .lilico, .blocto]

    public let version = "@outblock/fcl-swift@0.0.3"

    @Published public var currentUser: User?

    lazy var defaultAddressRegistry = AddressRegistry()

    internal var httpProvider = FCL.HTTPProvider()
    internal var wcProvider: FCL.WalletConnectProvider?
    
    internal var preAuthz: FCL.Response?
    
    // MARK: - Back Channel

    public func config(metadata: FCL.Metadata,
                       env: Flow.ChainID,
                       provider: FCL.Provider)
    {
        _ = config
            .put(.title, value: metadata.appName)
            .put(.description, value: metadata.appDescription)
            .put(.icon, value: metadata.appIcon.absoluteString)
            .put(.location, value: metadata.location.absoluteString)
            .put(.authn, value: provider.endpoint(chainId: env).absoluteString)
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
    }

    private func setupWalletConnect() {
        guard let name = config.get(.title),
              let description = config.get(.description),
              let icon = config.get(.icon),
//              let location = config.get(.location),
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

        Sign.configure(metadata: metadata)
        Relay.configure(projectId: projectID, socketFactory: SocketFactory())
        wcProvider = FCL.WalletConnectProvider()
    }

    public func changeProvider(provider: FCL.Provider, env: Flow.ChainID) {
        config
            .put(.authn, value: provider.endpoint(chainId: env).absoluteString)
            .put(.providerMethod, value: provider.provider(chainId: env).method.rawValue)
            .put(.env, value: env.name)
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

internal func buildUser(authn: FCL.Response) -> FCL.User? {
    guard let address = authn.data?.addr else { return nil }
    return FCL.User(addr: Flow.Address(hex: address),
                loggedIn: true,
                services: authn.data?.services)
}

internal func serviceOfType(services: [FCL.Service]?, type: FCL.ServiceType) -> FCL.Service? {
    return services?.first(where: { service in
        service.type == type
    })
}
