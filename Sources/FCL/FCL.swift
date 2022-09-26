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

    private var providers: [FCLProvider] = [.dapper, .lilico, .blocto]

    public let version = "@outblock/fcl-swift@0.0.3"

    @Published public var currentUser: User?

    lazy var defaultAddressRegistry = AddressRegistry()

    // MARK: - Back Channel

    public func config(metadata: FCL.Metadata,
                       env: Flow.ChainID,
                       provider: FCLProvider)
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
              let location = config.get(.location),
              let projectID = config.get(.projectID)
        else {
            return
        }

        let metadata = AppMetadata(
            name: name,
            description: description,
            url: location,
            icons: [icon]
        )

        Sign.configure(metadata: metadata)

        Relay.configure(projectId: projectID, socketFactory: SocketFactory())
    }

    public func changeProvider(provider: FCLProvider, env: Flow.ChainID) {
        config
            .put(.authn, value: provider.endpoint(chainId: env).absoluteString)
            .put(.env, value: env.name)
    }
    
    internal func getStategy() throws -> FCLStrategy {
        guard let methodString = config.get(.providerMethod),
              let method = FCLServiceMethod(rawValue: methodString) else {
            throw FCLError.invalidWalletProvider
        }
        
        return method.provider
    }
}

// MARK: - Util

internal func buildUser(authn: FCL.Response) -> User? {
    guard let address = authn.data?.addr else { return nil }
    return User(addr: Flow.Address(hex: address),
                loggedIn: true,
                services: authn.data?.services)
}

internal func serviceOfType(services: [FCL.Service]?, type: FCL.ServiceType) -> FCL.Service? {
    return services?.first(where: { service in
        service.type == type
    })
}
