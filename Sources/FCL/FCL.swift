import AuthenticationServices
import BigInt
import Combine
import Flow

public let fcl = FCL.shared

public final class FCL: NSObject, ObservableObject {
    public static let shared = FCL()

    public var delegate: FCLDelegate?

    public var config = Config()

    private var providers: [FCLProvider] = [.dapper, .blocto]

    private var session: ASWebAuthenticationSession?

    public let version = "@outblock/fcl-swift@0.0.3"

    internal let api = API()

    @Published public var currentUser: User?

    lazy var defaultAddressRegistry = AddressRegistry()

    internal var cancellables = Set<AnyCancellable>()

    // MARK: - Back Channel

    public func config(metadata: FCL.Metadata,
                       env: Flow.ChainID,
                       provider: FCLProvider)
    {
        _ = config
            .put(.title, value: metadata.appName)
            .put(.icon, value: metadata.appIcon)
            .put(.nonce, value: metadata.nonce)
            .put(.appId, value: metadata.appIdentifier)
            .put(.authn, value: provider.endpoint(chainId: env).absoluteString)
            .put(.env, value: env.name)

        // default contracts
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

    public func verifyAccountProof(includeDomainTag: Bool = false) async throws -> Bool {
        guard let currentUser = currentUser, currentUser.loggedIn else {
            throw Flow.FError.unauthenticated
        }

        guard let service = serviceOfType(services: currentUser.services, type: .accountProof),
              let data = service.data,
              let address = data.address,
              let signatures = data.signatures,
              let appIdentifier = config.get(.appId),
              let nonce = config.get(.nonce)
        else {
            throw FCLError.invaildService
        }

        guard let encoded = RLP.encode([appIdentifier.data(using: .utf8), address.hexValue.data, nonce.hexValue.data]) else {
            throw FCLError.encodeFailure
        }

        let encodedTag = includeDomainTag ? Flow.DomainTag.custom("FCL-ACCOUNT-PROOF-V0.0").normalize : Data() + encoded

        return try await fcl.query {
            cadence {
                FCL.Constants.verifyAccountProofSignaturesCadence
            }

            arguments {
                [
                    .address(Flow.Address(hex: data.address ?? "")),
                    .string(encodedTag.hexValue),
                    .array(signatures.compactMap { Flow.Argument(value: .int($0.keyId ?? -1)) }),
                    .array(signatures.compactMap { Flow.Argument(value: .string($0.signature ?? "")) }),
                ]
            }
        }.decode()
    }

    public func verifyUserSignature(message: String, compSigs: [FCLUserSignatureResponse]) async throws -> Bool {
        guard let currentUser = currentUser, currentUser.loggedIn else {
            throw Flow.FError.unauthenticated
        }

        return try await fcl.query {
            cadence {
                FCL.Constants.verifyUserSignaturesCadence
            }

            arguments {
                [
                    .address(Flow.Address(hex: compSigs.first?.addr ?? "")),
                    .string(message.data(using: .utf8)?.hexValue ?? ""),
                    .array(compSigs.compactMap { Flow.Argument(value: .int($0.keyId)) }),
                    .array(compSigs.compactMap { Flow.Argument(value: .string($0.signature)) }),
                ]
            }
        }.decode()
    }

    internal func closeSession() {
        DispatchQueue.main.async {
            self.session?.cancel()
        }
    }

    public func signUserMessage(message: String) async throws -> FCLUserSignatureResponse {
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

        guard let messageData = message.data(using: .utf8),
              let data = try? JSONEncoder().encode(SignableMessage(message: messageData.hexValue))
        else {
            throw FCLError.encodeFailure
        }

        let model = try await api.execHttpPost(url: endpoint, method: .post, params: service.params, data: data)
        guard let data = model.data, let signature = data.signature, let address = data.addr, let keyId = data.keyId else {
            throw FCLError.generic
        }

        return .init(addr: address, keyId: keyId, signature: signature)
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
