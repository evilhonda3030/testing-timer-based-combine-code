//
//  FreshDataProvider.swift
//  TDD-Async-Combine-And-Timers
//
//  Created by Egor Mikhailov on 21/01/2023.
//

import Combine
import CombineSchedulers
import Foundation

protocol FreshDataProvider: AnyObject {
    func freshData() -> AnyPublisher<Int, Never>
}

protocol ApiRequestPerformer: AnyObject {
    func request() -> AnyPublisher<Int, Error>
}

/// What do we know on how we can determine whether the data received from served is up to date?
/// Imagine we have a service run on server that obtains a new data that is used to make some trasformations necessary to provide a client with a value
///
/// For the sake of simplicity let's say that service has 2 endpoints:
/// - The first endpoint provides a client with the piece of information allowing a client to understand if other data obtained via this service is up-to-date
/// - The second endpoint provides models that are built using the most recent data, the relevance of which we judge using the first endpoint.
///
/// Let's come with an agreement of how we judge about data relevance
/// 1. We know that the service requests a new data every ten minutes of an hour, otherwise 6 times an hour
/// 2. However, since nothing is perfect a new shipment might be delayed and, for example, occurs at 20:11 instead of 20:10.
/// 3. To understand on a client side whether it needs to update other cilent's components dependent on the service the client takes current time and examines it on which 10-minutes segment
///   of an hour it hits. If a previously received segment is
///

protocol NowDateProviding {
    static var now: Date { get }
}

extension Date: NowDateProviding { }

final class FreshDataProviderImpl: FreshDataProvider {
    // MARK: - Initializers

    init(
        apiRequestPerformer: ApiRequestPerformer,
        timerScheduler: AnySchedulerOf<DispatchQueue> = .main,
        nowDateProviding: NowDateProviding.Type = Date.self
    ) {
        self.apiRequestPerformer = apiRequestPerformer
        self.timerScheduler = timerScheduler
        self.nowDateProviding = nowDateProviding
    }

    // MARK: - Public methods

    func freshData() -> AnyPublisher<Int, Never> {
        Publishers
            .firingEveryTenMinutesOfHourTimer(
                scheduler: timerScheduler,
                nowDateProviding: nowDateProviding
            )
            .flatMap { [apiRequestPerformer] in
                apiRequestPerformer.request()
                    .replaceError(with: 0)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Private properties

    private let apiRequestPerformer: ApiRequestPerformer
    private let timerScheduler: AnySchedulerOf<DispatchQueue>
    private let nowDateProviding: NowDateProviding.Type
}

private extension Publishers {
    static func firingEveryTenMinutesOfHourTimer(
        scheduler: AnySchedulerOf<DispatchQueue>,
        nowDateProviding: NowDateProviding.Type
    ) -> AnyPublisher<Void, Never> {
        let now = nowDateProviding.now
        let nowTimestamp = TimeInterval(Int(now.timeIntervalSince1970)) // extract seconds only

        let hours = TimeInterval(Int(nowTimestamp / .hour))
        let elapsedSeconds = nowTimestamp - (hours * .hour)
        let currentSegment = TimeInterval(Int(elapsedSeconds / 10.0 * .minute))

        let secondsToNextSegment = elapsedSeconds - currentSegment * 10.0 * .minute

        return Just(())
            .delay(for: .seconds(secondsToNextSegment), scheduler: scheduler)
            .flatMap {
                Publishers.Timer(every: .seconds(10.0 * .minute), scheduler: scheduler)
                    .autoconnect()
                    .map { _ in }
                    .prepend(())
                    .eraseToAnyPublisher()
            }
            .prepend(())
            .eraseToAnyPublisher()
    }
}

private extension TimeInterval {
    static let minute: TimeInterval = 60.0
    static let hour = TimeInterval(Int(60.0 * minute))
}