//
//  CalendarDetailViewModel.swift
//  SpaceWalker
//
//  Created by andev on 2/16/26.
//

import Foundation
import UIKit
import RealmSwift
import RxSwift
import RxCocoa

enum CalendarDetailAlert {
    case visibilityUpdated(isPublic: Bool)
    case visibilityUpdateFailed
    case deleteFailed
}

final class CalendarDetailViewModel: BaseViewModel {

    struct Input {
        let viewDidLoad: Observable<Void>
        let visibilityToggle: Observable<Bool>
        let deleteConfirmed: Observable<Void>
    }

    struct Output {
        let detail: Driver<SpacePhotoDetailModel>
        let isDeleting: Driver<Bool>
        let alert: Signal<CalendarDetailAlert>
        let deleteSuccess: Signal<Void>
    }

    private let identifier: SpacePostIdentifier
    private let repository = SpaceRepository()
    private let calendarDetailRepository = CalendarDetailRepository()

    private let detailRelay: BehaviorRelay<SpacePhotoDetailModel>
    private let deletingRelay = BehaviorRelay<Bool>(value: false)
    private let alertRelay = PublishRelay<CalendarDetailAlert>()
    private let deleteSuccessRelay = PublishRelay<Void>()

    private let disposeBag = DisposeBag()
    private var s3objectKey: String?

    init(identifier: SpacePostIdentifier, placeholderModel: SpacePhotoDetailModel) {
        self.identifier = identifier
        self.detailRelay = BehaviorRelay(value: placeholderModel)
    }

    func transform(input: Input) -> Output {
        input.viewDidLoad
            .subscribe(onNext: { [weak self] in
                guard let self else { return }
                Task { await self.fetchAndBindDetail() }
            })
            .disposed(by: disposeBag)

        input.visibilityToggle
            .subscribe(onNext: { [weak self] newValue in
                guard let self else { return }
                Task { await self.updateVisibility(to: newValue) }
            })
            .disposed(by: disposeBag)

        input.deleteConfirmed
            .subscribe(onNext: { [weak self] in
                guard let self else { return }
                Task { await self.performDelete() }
            })
            .disposed(by: disposeBag)

        return Output(
            detail: detailRelay.asDriver(),
            isDeleting: deletingRelay.asDriver(),
            alert: alertRelay.asSignal(),
            deleteSuccess: deleteSuccessRelay.asSignal()
        )
    }

    private func fetchAndBindDetail() async {
        LogNetwork("Fetching detail for spaceId=\(identifier.spaceId), postId=\(identifier.postId)")

        do {
            let response = try await repository.fetchPostDetail(spaceId: identifier.spaceId, postId: identifier.postId).value
            LogNetwork("Response received: \(response)")
            s3objectKey = response.s3objectKey

            let localMeta = await fetchLocalMetadata(for: response.s3objectKey)
            let hasLocalMeta = (localMeta != nil)

            var detail = detailRelay.value
            detail.isPublic = response.isPublic
            detail.likeCount = response.likeCount
            detail.missionTitle = response.dailyMission.title
            detail.date = Self.parseServerDate(response.createdAt)
            detail.authorName = response.author.nickname

            detail.resolutionText = " - "
            detail.fileSizeText = " - "
            detail.shotTimeText = " - "
            detail.deviceName = " - "

            if let meta = localMeta {
                detail.resolutionText = "\(meta.width) × \(meta.height)"

                let timeDF = DateFormatter()
                timeDF.locale = Locale(identifier: "ko_KR")
                timeDF.dateFormat = "a h:mm"
                detail.shotTimeText = timeDF.string(from: meta.capturedAt)
                detail.deviceName = meta.deviceName ?? UIDevice.current.model

                if meta.latitude != 0 || meta.longitude != 0 {
                    detail.latitude = meta.latitude
                    detail.longitude = meta.longitude
                    detail.locationName = String(format: "%.5f, %.5f", meta.latitude, meta.longitude)
                }
            }

            await MainActor.run {
                self.detailRelay.accept(detail)
            }

            if let imageResult = await calendarDetailRepository.fetchImagePayload(from: response.photoUrl) {
                detail.image = imageResult.image

                if hasLocalMeta {
                    let formatter = ByteCountFormatter()
                    formatter.allowedUnits = [.useMB, .useKB]
                    formatter.countStyle = .file
                    detail.fileSizeText = formatter.string(fromByteCount: Int64(imageResult.byteCount))
                }

                await MainActor.run {
                    self.detailRelay.accept(detail)
                }
            }

            if let profileURL = response.author.profileImageUrl,
               let profileImage = await calendarDetailRepository.fetchImage(from: profileURL) {
                detail.authorProfileImage = profileImage
                await MainActor.run {
                    self.detailRelay.accept(detail)
                }
            }

        } catch {
            LogNetwork("Failed to fetch post detail: \(error.localizedDescription)")
        }
    }

    private func updateVisibility(to newValue: Bool) async {
        var current = detailRelay.value
        let oldValue = current.isPublic

        current.isPublic = newValue
        await MainActor.run {
            self.detailRelay.accept(current)
        }

        do {
            let resp = try await repository
                .updatePostVisibility(spaceId: identifier.spaceId, postId: identifier.postId, isPublic: newValue)
                .value

            if resp.success {
                await MainActor.run {
                    self.alertRelay.accept(.visibilityUpdated(isPublic: newValue))
                }
            } else {
                current.isPublic = oldValue
                await MainActor.run {
                    self.detailRelay.accept(current)
                    self.alertRelay.accept(.visibilityUpdateFailed)
                }
            }
        } catch {
            current.isPublic = oldValue
            await MainActor.run {
                self.detailRelay.accept(current)
                self.alertRelay.accept(.visibilityUpdateFailed)
            }
        }
    }

    private func performDelete() async {
        await MainActor.run {
            self.deletingRelay.accept(true)
        }

        do {
            let resp = try await repository
                .deletePost(spaceId: identifier.spaceId, postId: identifier.postId)
                .value

            if resp.success {
                if let key = s3objectKey {
                    await deleteLocalMetadata(for: key)
                }
                await MainActor.run {
                    self.deleteSuccessRelay.accept(())
                }
            } else {
                await MainActor.run {
                    self.deletingRelay.accept(false)
                    self.alertRelay.accept(.deleteFailed)
                }
            }
        } catch {
            await MainActor.run {
                self.deletingRelay.accept(false)
                self.alertRelay.accept(.deleteFailed)
            }
        }
    }

    private func fetchLocalMetadata(for s3Key: String) async -> PhotoMetadata? {
        do {
            let realm = try await Realm()
            return realm.objects(PhotoMetadata.self).filter("s3Key == %@", s3Key).first
        } catch {
            LogGeneral("Realm open failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func deleteLocalMetadata(for s3Key: String) async {
        do {
            let realm = try await Realm()
            let objects = realm.objects(PhotoMetadata.self).filter("s3Key == %@", s3Key)
            if !objects.isEmpty {
                try realm.write {
                    realm.delete(objects)
                }
            }
        } catch {
            LogGeneral("Realm delete failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Date Parsing Helpers
    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let microsecondsNoTZ: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return f
    }()

    private static let millisecondsNoTZ: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return f
    }()

    private static let secondsNoTZ: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    private static func parseServerDate(_ string: String) -> Date {
        if let d = iso8601WithFractional.date(from: string) { return d }
        if let d = iso8601Basic.date(from: string) { return d }
        if let d = microsecondsNoTZ.date(from: string) { return d }
        if let d = millisecondsNoTZ.date(from: string) { return d }
        if let d = secondsNoTZ.date(from: string) { return d }
        return Date()
    }
}
