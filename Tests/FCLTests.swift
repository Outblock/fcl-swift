import Combine
@testable import FCL
import Flow
import XCTest

final class FCLTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    func testQuery() {
        let expectation = XCTestExpectation(description: "Query got executed!")
        fcl.query {
            cadence {
                """
                pub fun main(a: Int, b: Int, addr: Address): Int {
                  log(addr)
                  return a + b
                }
                """
            }

            arguments {
                [.int(7), .int(6), .address(Flow.Address(hex: "0x4b7f74fdd447640a"))]
            }
        }.sink { completion in
            if case let .failure(error) = completion {
                XCTFail(error.localizedDescription)
            }
        } receiveValue: { response in
            print(response)
            XCTAssertEqual(13, response.fields?.value.toInt())
            expectation.fulfill()
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 10.0)
    }

    func testGetAccount() {
        let expectation = XCTestExpectation(description: "Query got executed!")

        fcl.getAccount(address: "0x19efd5b9b60bd82e")
            .sink { completion in
                if case let .failure(error) = completion {
                    XCTFail(error.localizedDescription)
                }
            } receiveValue: { response in
                XCTAssertNotNil(response)
                expectation.fulfill()
            }.store(in: &cancellables)

        wait(for: [expectation], timeout: 10.0)
    }

    func testGetBlock() {
        let expectation = XCTestExpectation(description: "Query got executed!")

        fcl.getBlock(blockId: "c768c8c39de928e422f9185f1668befd661e15be8822d030a03f060629bc0f87")
            .sink { completion in
                if case let .failure(error) = completion {
                    XCTFail(error.localizedDescription)
                }
            } receiveValue: { response in
                XCTAssertNotNil(response)
                expectation.fulfill()
            }.store(in: &cancellables)

        wait(for: [expectation], timeout: 20.0)
    }

    func testGetLastestBlock() {
        let expectation = XCTestExpectation(description: "Query got executed!")

        fcl.getLastestBlock()
            .sink { completion in
                if case let .failure(error) = completion {
                    XCTFail(error.localizedDescription)
                }
            } receiveValue: { response in
                XCTAssertNotNil(response)
                expectation.fulfill()
            }.store(in: &cancellables)

        wait(for: [expectation], timeout: 10.0)
    }
}
