import AuthenticationServices
import Combine
import Flow
import SafariServices

public let fcl = FCL.shared

public final class FCL: NSObject {
    public static let shared = FCL()

    public var delegate: FCLDelegate?

    public var config = Config()

    private var providers: [FCLProvider] = [.dapper, .blocto]

    private var session: ASWebAuthenticationSession?

    private let api = API()

    @Published var currentUser: User? = nil

    private lazy var defaultAddressRegistry = AddressRegistry()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Back Channel

    public func config(appName: String,
                       appIcon: String,
                       location: String,
                       walletNode: String,
                       accessNode: String,
                       scope: String,
                       authn: String) {
        _ = config.put(key: .wallet, value: walletNode)
            .put(key: .accessNode, value: accessNode)
            .put(key: .title, value: appName)
            .put(key: .icon, value: appIcon)
            .put(key: .icon, value: appIcon)
            .put(key: .scope, value: scope)
            .put(key: .authn, value: authn)
            .put(key: .location, value: location)
    }

    public func unauthenticate() {
        // TODO: implement this
        currentUser = nil
    }

    func reauthenticate() -> Future<FCLResponse, Error> {
        // TODO: implement this
        unauthenticate()
        return authn()
    }

    internal func closeSession() {
        DispatchQueue.main.async {
            self.session?.cancel()
        }
    }

    public func preauthz() -> Future<FCLResponse, Error> {
        return Future { [weak self] promise in
            guard let self = self, let currentUser = self.currentUser, currentUser.loggedIn else {
                promise(.failure(Flow.FError.unauthenticated))
                return
            }

            guard let service = self.serviceOfType(services: currentUser.services, type: .preAuthz),
                let endpoint = service.endpoint else {
                return
            }

            let call = flow.accessAPI.getLatestBlock(sealed: true)

            call.whenSuccess { block in
                let blockId = block.id.hex

                let preSignable = PreSignable(fType: "PreSignable",
                                              fVsn: "1.0.1",
                                              roles: Role(proposer: true, authorizer: false, payer: true, param: false),
                                              cadence: "transaction {\n  execute {\n    log(\"A transaction happened\")\n  }\n}\n",
                                              args: [],
                                              interaction: Interaction(tag: "TRANSACTION",
                                                                       assigns: [String: String](),
                                                                       status: "OK",
                                                                       reason: nil,
                                                                       accounts: Accounts(currentUser: CurrentUser(kind: "ACCOUNT",
                                                                                                                   tempID: "CURRENT_USER",
                                                                                                                   addr: nil,
                                                                                                                   signature: nil,
                                                                                                                   keyID: nil,
                                                                                                                   sequenceNum: nil,
                                                                                                                   signingFunction: nil,
                                                                                                                   role: Role(proposer: true,
                                                                                                                              authorizer: false,
                                                                                                                              payer: true,
                                                                                                                              param: false))),
                                                                       params: [String: String](),
                                                                       arguments: [String: String](),
                                                                       message: Message(cadence: "transaction {\n  execute {\n    log(\"A transaction happened\")\n  }\n}\n",
                                                                                        refBlock: blockId,
                                                                                        computeLimit: 10,
                                                                                        proposer: nil,
                                                                                        payer: nil,
                                                                                        authorizations: [],
                                                                                        params: [],
                                                                                        arguments: []),
                                                                       proposer: "CURRENT_USER",
                                                                       authorizations: [],
                                                                       payer: "CURRENT_USER",
                                                                       events: Events(eventType: nil,
                                                                                      start: nil,
                                                                                      end: nil,
                                                                                      blockIDS: []),
                                                                       transaction: Id(id: nil),
                                                                       block: Block(id: nil, height: nil, isSealed: nil),
                                                                       account: Account(addr: nil),
                                                                       collection: Id(id: nil)),
                                              voucher: Voucher(cadence: "transaction {\n  execute {\n    log(\"A transaction happened\")\n  }\n}\n",
                                                               refBlock: blockId,
                                                               computeLimit: 10,
                                                               arguments: [],
                                                               proposalKey: ProposalKey(address: nil, keyID: nil, sequenceNum: nil),
                                                               payer: nil,
                                                               authorizers: [],
                                                               payloadSigs: []))

                let data = try! JSONEncoder().encode(preSignable)

                self.api.execHttpPost(url: endpoint, params: service.params, data: data)
                    .map { response -> FCLResponse in
                        FCLResponse(address: response.data?.addr)
                    }
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
    }

    func resolvePreAuthz(reponse: AuthnResponse) -> Future<AuthnResponse, Error> {
        return Future { _ in
            var axs: [(role: String, az: Service)] = []
            if let proposer = reponse.data?.proposer {
                axs.append(("PROPOSER", proposer))
            }

            if let payers = reponse.data?.payer {
                payers.forEach { payer in
                    axs.append(("PAYER", payer))
                }
            }

            if let authorizations = reponse.data?.authorization {
                authorizations.forEach { authorization in
                    axs.append(("AUTHORIZER", authorization))
                }
            }

            axs.map { _, az in
                let tempId = ([az.identity?.address, "\(az.identity?.keyId)"] as [String?]).compactMap { $0 }.joined(separator: "|")
                let addr = az.identity?.address
                let keyId = az.identity?.keyId
            }
        }
    }

    func authorization() -> Future<AuthnResponse, Error> {
        return Future { [weak self] promise in
            guard let self = self, let currentUser = self.currentUser, currentUser.loggedIn else {
                promise(.failure(Flow.FError.unauthenticated))
                return
            }

            guard let service = self.serviceOfType(services: currentUser.services, type: .authz),
                let url = service.endpoint else {
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

    public func authn() -> Future<FCLResponse, Error> {
        return Future { promise in
            guard let endpoint = self.config.get(key: .authn),
                let url = URL(string: endpoint) else {
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
            let url = buildURL(url: endpoint, params: service.params) else {
            throw FCLError.invalidSession
        }

        DispatchQueue.main.async {
            self.delegate?.hideLoading()
            let session = ASWebAuthenticationSession(url: url,
                                                     callbackURLScheme: nil) { _, _ in
                fcl.api.canContinue = false
            }
            self.session = session
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    // MARK: - Util

    private func buildUser(authn: AuthnResponse) -> User? {
        guard let address = authn.data?.addr else { return nil }
        return User(addr: Flow.Address(hex: address),
                    loggedIn: true,
                    services: authn.data?.services)
    }

    private func serviceOfType(services: [Service]?, type: FCLServiceType) -> Service? {
        return services?.first(where: { service in
            service.type == type
        })
    }
}

extension FCL: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let anchor = self.delegate?.presentationAnchor() {
            return anchor
        }
        return ASPresentationAnchor()
    }
}
