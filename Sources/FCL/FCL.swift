import AuthenticationServices
import BigInt
import Combine
import Flow

public let fcl = FCL.shared

public final class FCL: NSObject {
    public static let shared = FCL()

    public var delegate: FCLDelegate?

    public var config = Config()

    private var providers: [FCLProvider] = [.dapper, .blocto]

    private var session: ASWebAuthenticationSession?

    public let version = "@outblock/fcl-swift@0.0.3"

    internal let api = API()

    @Published public var currentUser: User?

    private lazy var defaultAddressRegistry = AddressRegistry()

    internal var cancellables = Set<AnyCancellable>()
    
    // MARK: - Back Channel

    public func config(metadata: FCL.Metadata,
                       env: Flow.ChainID,
                       provider: FCLProvider)
    {
        _ = config
            .put(.title, value: metadata.appName)
            .put(.icon, value: metadata.appIcon)
            .put(.authn, value: provider.endpoint(chainId: env).absoluteString)
            .put(.env, value: env.name)
    }
    
    public func changeProvider(provider: FCLProvider, env: Flow.ChainID) {
        config.put(.authn, value: provider.endpoint(chainId: env).absoluteString)
            .put(.env, value: env.name)
    }

    public func unauthenticate() {
        // TODO: implement this
        currentUser = nil
    }

    func reauthenticate() async throws -> FCLResponse {
        // TODO: implement this
        unauthenticate()
        return try await authenticate()
    }

    internal func closeSession() {
        DispatchQueue.main.async {
            self.session?.cancel()
        }
    }

    public func signUserMessage(message: String) async throws -> String {
        guard let currentUser = currentUser, currentUser.loggedIn else {
            throw Flow.FError.unauthenticated
        }

        guard let service = serviceOfType(services: currentUser.services, type: .userSignature),
              let endpoint = service.endpoint
        else {
            throw FCLError.invaildService
        }

        struct SignableMessage: Codable {
            let message: String
        }

        // TODO: Fix here, the blocto return html response
        guard let messageData = message.data(using: .utf8),
              let _ = try? JSONEncoder().encode(SignableMessage(message: messageData.hexValue))
        else {
            throw FCLError.encodeFailure
        }

        let model = try await api.execHttpPost(url: endpoint, method: .get, params: service.params)
        return model.data?.signature ?? ""
    }

    func authorization() async throws -> AuthnResponse {
        guard let currentUser = currentUser, currentUser.loggedIn else {
            throw Flow.FError.unauthenticated
        }

        guard let service = serviceOfType(services: currentUser.services, type: .authz),
              let url = service.endpoint
        else {
            throw FCLError.invaildService
        }

        return try await api.execHttpPost(url: url)
    }

    public func authenticate() async throws -> FCLResponse {
        guard let endpoint = config.get(.authn),
              let url = URL(string: endpoint)
        else {
            throw Flow.FError.urlEmpty
        }

        let response = try await api.execHttpPost(url: url)
        currentUser = buildUser(authn: response)
        return FCLResponse(address: response.data?.addr)
    }

    // MARK: - Session

    internal func openAuthenticationSession(service: Service) throws {
        guard let endpoint = service.endpoint,
              let url = api.buildURL(url: endpoint, params: service.params)
        else {
            throw FCLError.invalidSession
        }

        DispatchQueue.main.async {
            self.delegate?.hideLoading()

            if service.type == .authn {
                let session = ASWebAuthenticationSession(url: url,
                                                         callbackURLScheme: nil) { _, _ in
                    fcl.api.canContinue = false
                }
                self.session = session
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            } else {
                SafariWebViewManager.openSafariWebView(url: url)
            }
        }
    }

    // MARK: - Util

    internal func buildUser(authn: AuthnResponse) -> User? {
        guard let address = authn.data?.addr else { return nil }
        return User(addr: Flow.Address(hex: address),
                    loggedIn: true,
                    services: authn.data?.services)
    }

    internal func serviceOfType(services: [Service]?, type: FCLServiceType) -> Service? {
        return services?.first(where: { service in
            service.type == type
        })
    }
}

extension FCL: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let anchor = delegate?.presentationAnchor() {
            return anchor
        }
        return ASPresentationAnchor()
    }
}
