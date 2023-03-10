//
//  TDD_Async_Combine_And_TimersTests.swift
//  TDD-Async-Combine-And-TimersTests
//
//  Created by Egor Mikhailov on 21/01/2023.
//

import Combine
import CombineExt
import CombineSchedulers
import XCTest
@testable import TDD_Async_Combine_And_Timers

struct NowDateProvidingMock: NowDateProviding {
    static var _now: Date!
    static var now: Date { _now }
}

class ApiRequestPerformerMock: ApiRequestPerformer {
    func request() -> AnyPublisher<Int, Never> {
        .create { [weak self] in
            guard let slf = self else { return AnyCancellable { } }
            $0.send(slf.response)
            $0.send(completion: .finished)

            return AnyCancellable { }
        }
    }

    var response: Int!
}

final class TDD_Async_Combine_And_TimersTests: XCTestCase {
    func testTimerFires6TimesAnHour() throws {
        var firingCount = 0
        nowDateProviding._now = Date(timeIntervalSince1970: 0.0)
        apiRequestPerformer.response = 0

        let canc = dataProvider.freshData()
            .map { _ in }
            .sink { firingCount += 1 }

        XCTAssertEqual(firingCount, 1)
        apiRequestPerformer.response = 1
        scheduler.advance(by: 600)
        XCTAssertEqual(firingCount, 2)
        apiRequestPerformer.response = 2
        scheduler.advance(by: 600)
        XCTAssertEqual(firingCount, 3)
        apiRequestPerformer.response = 3
        scheduler.advance(by: 600)
        XCTAssertEqual(firingCount, 4)
        apiRequestPerformer.response = 4
        scheduler.advance(by: 600)
        XCTAssertEqual(firingCount, 5)
        apiRequestPerformer.response = 5
        scheduler.advance(by: 600)
        XCTAssertEqual(firingCount, 6)
        apiRequestPerformer.response = 6
        scheduler.advance(by: 600)
        XCTAssertEqual(firingCount, 7)
    }

    func testTimerNotFiringSomewhereInTheMiddleOfSegment() throws {
        var firingCount = 0
        nowDateProviding._now = Date(timeIntervalSince1970: 0.0)
        apiRequestPerformer.response = 0

        let canc = dataProvider.freshData()
            .map { _ in }
            .sink { firingCount += 1 }

        XCTAssertEqual(firingCount, 1)
        scheduler.advance(by: 300)
        XCTAssertEqual(firingCount, 1)
        apiRequestPerformer.response = 1
        scheduler.advance(by: 600)
        XCTAssertEqual(firingCount, 2)
    }

    func testTimerFiringAccuratelyIfNowIsntAlignedWithTheBorderOfSegment() throws {
        var firingCount = 0
        let shift = 355.55
        nowDateProviding._now = Date(timeIntervalSince1970: shift)
        apiRequestPerformer.response = 0

        let canc = dataProvider.freshData()
            .map { _ in }
            .sink { firingCount += 1 }

        let toNextSegment = 600 - Int(shift)

        XCTAssertEqual(firingCount, 1)
        apiRequestPerformer.response = 1
        scheduler.advance(by: .seconds(toNextSegment))
        XCTAssertEqual(firingCount, 2)
        apiRequestPerformer.response = 2
        scheduler.advance(by: 600)
        XCTAssertEqual(firingCount, 3)
    }

    func testResponseIsReceived() throws {
        nowDateProviding._now = Date(timeIntervalSince1970: 0.0)
        apiRequestPerformer.response = 10
        var response: Int?

        let canc = dataProvider.freshData()
            .sink { response = $0 }

        XCTAssertEqual(response, apiRequestPerformer.response)
    }

    func testCorrectResponseIfServiceHasDelayWithANewData() throws {
        nowDateProviding._now = Date(timeIntervalSince1970: 0.0)
        apiRequestPerformer.response = 0
        var response: Int?

        let canc = dataProvider.freshData()
            .sink { response = $0 }

        XCTAssertEqual(response, apiRequestPerformer.response)
        nowDateProviding._now = Date(timeIntervalSince1970: 600.0)
        scheduler.advance(by: 600)
        XCTAssertEqual(response, apiRequestPerformer.response)
        scheduler.advance(by: 30)
        XCTAssertEqual(response, apiRequestPerformer.response)
        apiRequestPerformer.response = 1
        scheduler.advance(by: 30)
        XCTAssertEqual(response, apiRequestPerformer.response)
    }

    private lazy var dataProvider = FreshDataProviderImpl(
        apiRequestPerformer: apiRequestPerformer,
        timerScheduler: scheduler.eraseToAnyScheduler(),
        nowDateProviding: nowDateProviding
    )

    private let nowDateProviding = NowDateProvidingMock.self
    private let apiRequestPerformer = ApiRequestPerformerMock()
    private let scheduler = DispatchQueue.test
}
