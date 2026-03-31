//
//  CalendarViewModel.swift
//  SpaceWalker
//
//  Created by andev on 2/22/26.
//

import Foundation
import UIKit
import RxSwift

struct MissionSubmissionRequest {
    let spaceId: Int
    let imageData: Data
    let mimeType: String
    let missionId: Int
    let missionTitle: String
    let timezone: String
    let isPublic: Bool
}

struct MissionSubmissionResult {
    let s3objectKey: String
    let response: SpaceRepository.SubmitMissionResponse
}

final class CalendarViewModel {
    private let repository = SpaceRepository()
    private let calendarRepository = CalendarRepository()
    private let metadataRepository = CalendarMetadataRepository()
    private let imageCache = NSCache<NSString, UIImage>()
    private let disposeBag = DisposeBag()
    private let missionStateLock = NSLock()
    private var isMissionSubmitting = false

    init() {
        imageCache.countLimit = 150
    }

    func fetchMySpaces() -> Single<[JoinedSpace]> {
        repository.fetchMySpaces()
    }

    func beginMissionSubmission() -> Bool {
        missionStateLock.lock()
        defer { missionStateLock.unlock() }
        guard isMissionSubmitting == false else { return false }
        isMissionSubmitting = true
        return true
    }

    func endMissionSubmission() {
        missionStateLock.lock()
        isMissionSubmitting = false
        missionStateLock.unlock()
    }

    func savePhotoMetadata(pending: CalendarPendingPhotoMeta, s3Key: String) {
        do {
            _ = try metadataRepository.savePhotoMetadata(pending: pending, s3Key: s3Key)
        } catch {
            LogGeneral("Realm write failed: \(error.localizedDescription)")
        }
    }

    func missionServerErrorMessage(from error: Error) -> String? {
        let nsErr = error as NSError
        let alamofireDataKey = "com.alamofire.serialization.response.error.data"
        if let data = nsErr.userInfo[alamofireDataKey] as? Data, let text = String(data: data, encoding: .utf8) {
            return text
        }
        let altKeys = ["AFNetworkingOperationFailingURLResponseDataErrorKey", NSLocalizedDescriptionKey]
        for key in altKeys {
            if let data = nsErr.userInfo[key] as? Data, let text = String(data: data, encoding: .utf8) {
                return text
            }
            if let text = nsErr.userInfo[key] as? String, !text.isEmpty { return text }
        }
        return nsErr.userInfo[NSLocalizedDescriptionKey] as? String
    }

    func missionErrorMessage(from error: Error) -> String {
        missionServerErrorMessage(from: error) ?? error.localizedDescription
    }

    func submitMission(
        request: MissionSubmissionRequest,
        progress: ((Double) -> Void)? = nil,
        onUploaded: ((String) -> Void)? = nil
    ) -> Single<MissionSubmissionResult> {
        repository.requestPresignedUpload(
            spaceId: request.spaceId,
            mimeType: request.mimeType,
            timezone: request.timezone
        )
        .flatMap { [weak self] presigned -> Single<MissionSubmissionResult> in
            guard let self else {
                return .error(NSError(domain: "CalendarViewModel", code: -1))
            }

            return self.calendarRepository.uploadImageDataToS3(
                request.imageData,
                contentType: request.mimeType,
                to: presigned.mainImageUrl,
                progress: progress
            )
            .flatMap { [weak self] _ -> Single<MissionSubmissionResult> in
                guard let self else {
                    return .error(NSError(domain: "CalendarViewModel", code: -1))
                }
                onUploaded?(presigned.mainImageKey)

                let daily = SpaceRepository.DailyMissionSubmit(
                    missionId: request.missionId,
                    title: request.missionTitle
                )

                return self.repository.submitMission(
                    spaceId: request.spaceId,
                    s3objectKey: presigned.mainImageKey,
                    dailyMission: daily,
                    isPublic: request.isPublic,
                    timezone: request.timezone
                )
                .map { resp in
                    MissionSubmissionResult(s3objectKey: presigned.mainImageKey, response: resp)
                }
            }
        }
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
    private func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        calendarRepository.fetchImage(url: url)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { image in
                completion(image)
            }, onFailure: { _ in
                completion(nil)
            })
            .disposed(by: disposeBag)
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
