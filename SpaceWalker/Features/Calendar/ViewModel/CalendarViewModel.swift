//
//  CalendarViewModel.swift
//  SpaceWalker
//
//  Created by andev on 2/22/26.
//

import Foundation
import UIKit
import Alamofire
import RxSwift

final class CalendarViewModel {
    private let repository = SpaceRepository()
    private let imageCache = NSCache<NSString, UIImage>()

    init() {
        imageCache.countLimit = 150
    }

    func fetchMySpaces() -> Single<[JoinedSpace]> {
        repository.fetchMySpaces()
    }

    func fetchSpaceActivities(spaceId: Int, year: Int, month: Int, timezone: String) -> Single<CalendarActivitiesResult> {
        repository.fetchSpaceActivities(spaceId: spaceId, year: year, month: month, timezone: timezone)
            .flatMap { [weak self] response in
                guard let self else { return .just(CalendarActivitiesResult(missionTitle: response.dailyMission.title, missionId: response.dailyMission.missionId, didMission: response.didMission, photos: [:])) }

                return Single<CalendarActivitiesResult>.create { single in
                    let group = DispatchGroup()
                    var resultMap: [Date: CalendarDayPhoto] = [:]
                    let resultQueue = DispatchQueue(label: "calendar.photos.result.serial")

                    for activity in response.activities {
                        guard let utcDate = self.parseActivityUTCDate(activity.date) else { continue }
                        let localDay = Calendar.current.startOfDay(for: utcDate)
                        let dayKeyString = "space:\(spaceId)|day:\(self.dayString(for: localDay))"

                        if let cached = self.imageCache.object(forKey: dayKeyString as NSString) {
                            resultQueue.sync {
                                resultMap[localDay] = CalendarDayPhoto(image: cached, postId: activity.postId)
                            }
                            continue
                        }

                        guard let url = URL(string: activity.photo) else { continue }

                        group.enter()
                        self.loadImage(from: url) { image in
                            defer { group.leave() }
                            guard let image else { return }
                            self.imageCache.setObject(image, forKey: dayKeyString as NSString)
                            resultQueue.sync {
                                resultMap[localDay] = CalendarDayPhoto(image: image, postId: activity.postId)
                            }
                        }
                    }

                    group.notify(queue: .global(qos: .userInitiated)) {
                        let snapshot = resultQueue.sync { resultMap }
                        single(.success(
                            CalendarActivitiesResult(
                                missionTitle: response.dailyMission.title,
                                missionId: response.dailyMission.missionId,
                                didMission: response.didMission,
                                photos: snapshot
                            )
                        ))
                    }

                    return Disposables.create()
                }
            }
    }

    // MARK: - Image Loading
    private static let afSession: Session = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "calendar.image.cache"
        )
        return Session(configuration: config)
    }()

    private func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        CalendarViewModel.afSession.request(request)
            .validate(statusCode: 200..<400)
            .responseData(queue: .global(qos: .userInitiated)) { response in
                switch response.result {
                case .success(let data):
                    let image = UIImage(data: data)
                    DispatchQueue.main.async { completion(image) }
                case .failure(let error):
                    LogNetwork("[AF] image request failed — url=\(url.absoluteString), error=\(error.localizedDescription)")
                    DispatchQueue.main.async { completion(nil) }
                }
            }
    }

    // MARK: - Date Helpers
    private func parseActivityUTCDate(_ string: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = iso.date(from: string) { return d }

        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        iso2.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = iso2.date(from: string) { return d }

        let fmts = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        for f in fmts {
            df.dateFormat = f
            if let d = df.date(from: string) { return d }
        }

        if let d = iso.date(from: string + "Z") { return d }

        LogGeneral("[DateParse] failed to parse UTC date — string=\(string)")
        return nil
    }

    private func dayString(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
}
