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

    internal let api = API()

    @Published var currentUser: User?

    private lazy var defaultAddressRegistry = AddressRegistry()

    internal var cancellables = Set<AnyCancellable>()

    // MARK: - Back Channel

    public func config(appName: String,
                       appIcon: String,
                       location: String,
                       walletNode: String,
                       accessNode: String,
                       env: String,
                       scope: String,
                       authn: String)
    {
        _ = config.put(.wallet, value: walletNode)
            .put(.accessNode, value: accessNode)
            .put(.title, value: appName)
            .put(.icon, value: appIcon)
            .put(.scope, value: scope)
            .put(.authn, value: authn)
            .put(.location, value: location)
            .put(.env, value: env)
    }

    public func unauthenticate() {
        // TODO: implement this
        currentUser = nil
    }

    func reauthenticate() -> Future<FCLResponse, Error> {
        // TODO: implement this
        unauthenticate()
        return authenticate()
    }

    internal func closeSession() {
        DispatchQueue.main.async {
            self.session?.cancel()
        }
    }

    public func signUserMessage(message: String) -> Future<String, Error> {
        return Future { [weak self] promise in
            guard let self = self, let currentUser = self.currentUser, currentUser.loggedIn else {
                promise(.failure(Flow.FError.unauthenticated))
                return
            }

            guard let service = self.serviceOfType(services: currentUser.services, type: .userSignature),
                  let endpoint = service.endpoint
            else {
                promise(.failure(FCLError.invaildService))
                return
            }

            struct SignableMessage: Codable {
                let message: String
            }

            // TODO: Fix here, the blocto return html response
            guard let messageData = message.data(using: .utf8),
                  let data = try? JSONEncoder().encode(SignableMessage(message: messageData.hexValue))
            else {
                promise(.failure(FCLError.encodeFailure))
                return
            }

            self.api.execHttpPost(url: endpoint, method: .get, params: service.params)
                .sink { completion in
                    if case let .failure(error) = completion {
                        print(error)
                    }
                } receiveValue: { response in
                    print(response)
                }.store(in: &self.cancellables)
        }
    }

    func authorization() -> Future<AuthnResponse, Error> {
        return Future { [weak self] promise in
            guard let self = self, let currentUser = self.currentUser, currentUser.loggedIn else {
                promise(.failure(Flow.FError.unauthenticated))
                return
            }

            guard let service = self.serviceOfType(services: currentUser.services, type: .authz),
                  let url = service.endpoint
            else {
                return
            }

            self.api.execHttpPost(url: url)
                .sink { completion in
                    if case let .failure(error) = completion {
                        promise(.failure(error))
                    }
                } receiveValue: { model in
                    promise(.success(model))
                }
                .store(in: &self.cancellables)
        }
    }

    public func authenticate() -> Future<FCLResponse, Error> {
        return Future { promise in
            guard let endpoint = self.config.get(.authn),
                  let url = URL(string: endpoint)
            else {
                return promise(.failure(Flow.FError.urlEmpty))
            }
            self.api.execHttpPost(url: url)
                .map { response -> FCLResponse in
                    self.currentUser = self.buildUser(authn: response)
                    return FCLResponse(address: response.data?.addr)
                }
                .receive(on: DispatchQueue.main)
                .sink { _ in
                    self.closeSession()
                } receiveValue: { model in
                    promise(.success(model))
                }.store(in: &self.cancellables)
        }
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
                SafariWebViewManager.openSafariWebView(url: url) {
                    fcl.api.canContinue = false
                }
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
