import Combine
@testable import FCL
import Flow
import XCTest

final class FCLTests: XCTestCase {
    func testEncodeMessageForAuthn() {
        let timestamp = Date().timeIntervalSince1970
        let result1 = FCL.WalletUtil.encodeMessageForProvableAuthnSigning(address: .init(hex: "0x6704b72eb8c51187"),
                                                                          timestamp: timestamp)

        let result2 = FCL.WalletUtil.encodeMessageForProvableAuthnSigning(address: .init(hex: "0x6704b72eb8c51187"),
                                                                          timestamp: timestamp,
                                                                          appDomainTag: "AWESOME-APP-V0.0-user")

        fcl.config.put(.domainTag, value: "AWESOME-APP-V0.0-user")
        let result3 = FCL.WalletUtil.encodeMessageForProvableAuthnSigning(address: .init(hex: "0x6704b72eb8c51187"),
                                                                          timestamp: timestamp)
        XCTAssertNotEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
        XCTAssertEqual(result2, result3)
    }

    func testRegexInConfig() {
        let metadata = FCL.Metadata(appName: "FCLDemo",
                                    appDescription: "Demo app of FCL",
                                    appIcon: URL(string: "https://placekitten.com/g/200/200")!,
                                    location: URL(string: "https://foo.com")!,
                                    accountProof: nil,
                                    walletConnectConfig: nil)

        fcl.config(metadata: metadata, env: .mainnet, provider: .flowWallet)

        let dict = fcl.config.configLens("^app\\.detail\\.")
        XCTAssertNotNil(dict)
        XCTAssertNotEqual(dict.keys.count, 0)
        XCTAssertEqual(dict["icon"], "https://placekitten.com/g/200/200")
        XCTAssertEqual(dict["title"], "FCLDemo")
    }

    func testQuery() async throws {
        let response: Int = try await fcl.query {
            cadence {
                """
                access(all) fun main(a: Int, b: Int, addr: Address): Int {
                  log(addr)
                  return a + b
                }
                """
            }

            arguments {
                [.int(7), .int(6), .address(Flow.Address(hex: "0x4b7f74fdd447640a"))]
            }
        }.decode()

        XCTAssertEqual(13, response)
    }

    func testGetAccount() async throws {
        _ = try await fcl.getAccount(address: "0x19efd5b9b60bd82e")
    }

    func testGetBlock() async throws {
        _ = try await fcl.getBlock(blockId: "4722fcaa0c7939453b4886a7cccb364977372b5b6c103ea4264e75dafbf10ffa")
    }

    func testGetLastestBlock() async throws {
        _ = try await fcl.getLastestBlock()
    }
}
