@testable import FCL
import XCTest
import Combine
import Flow

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
            //            XCTAssertEqual(.int(13), response.fields?.value)
            expectation.fulfill()
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 10.0)
    }
}
