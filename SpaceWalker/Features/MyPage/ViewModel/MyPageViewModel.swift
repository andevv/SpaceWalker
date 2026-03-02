//
//  MyPageViewModel.swift
//  SpaceWalker
//
//  Created by andev on 3/2/26.
//

import UIKit
import RxSwift
import RxCocoa
import Alamofire
import PhotosUI
import UniformTypeIdentifiers
import ImageIO
import Kingfisher
import RealmSwift

private enum MyPageViewModelError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

struct MyPageAvatarUploadRequest {
    let image: UIImage
    let preferredMime: ImageMimeType
}

enum MyPageNicknameChangeEvent {
    case success(newNickname: String)
    case failure(message: String)
}

enum MyPageAvatarChangeEvent {
    case loading
    case success(image: UIImage)
    case failure(message: String)
}

enum MyPageWithdrawalEvent {
    case started
    case success
    case failure(message: String)
}

final class MyPageViewModel: BaseViewModel {

    struct Input {
        let viewDidLoad: Observable<Void>
        let nicknameUpdate: Observable<String>
        let avatarUpload: Observable<MyPageAvatarUploadRequest>
        let withdrawalTap: Observable<Void>
    }

    struct Output {
        let user: Driver<APIUser>
        let toastMessage: Signal<String>
        let nicknameChange: Signal<MyPageNicknameChangeEvent>
        let avatarChange: Signal<MyPageAvatarChangeEvent>
        let withdrawal: Signal<MyPageWithdrawalEvent>
    }

    private let disposeBag = DisposeBag()

    private let userRelay = PublishRelay<APIUser>()
    private let toastRelay = PublishRelay<String>()
    private let nicknameRelay = PublishRelay<MyPageNicknameChangeEvent>()
    private let avatarRelay = PublishRelay<MyPageAvatarChangeEvent>()
    private let withdrawalRelay = PublishRelay<MyPageWithdrawalEvent>()

    func transform(input: Input) -> Output {
        input.viewDidLoad
            .flatMapLatest { [weak self] _ -> Observable<Event<APIUser>> in
                guard let self else { return .empty() }
                return self.fetchUserSingle().asObservable().materialize()
            }
            .subscribe(onNext: { [weak self] event in
                guard let self else { return }
                switch event {
                case .next(let user):
                    self.userRelay.accept(user)
                case .error(let error):
                    self.toastRelay.accept("사용자 정보 조회 실패: \(error.localizedDescription)")
                case .completed:
                    break
                }
            })
            .disposed(by: disposeBag)

        input.nicknameUpdate
            .flatMapLatest { [weak self] newName -> Observable<MyPageNicknameChangeEvent> in
                guard let self else { return .empty() }
                return self.updateNicknameSingle(newName)
                    .asObservable()
                    .map { .success(newNickname: $0.newNickname) }
                    .catch { error in
                        .just(.failure(message: error.localizedDescription))
                    }
            }
            .bind(to: nicknameRelay)
            .disposed(by: disposeBag)

        input.avatarUpload
            .flatMapLatest { [weak self] request -> Observable<MyPageAvatarChangeEvent> in
                guard let self else { return .empty() }
                return self.uploadProfileImageSingle(image: request.image, preferredMime: request.preferredMime)
                    .asObservable()
                    .map { .success(image: request.image) }
                    .catch { error in
                        .just(.failure(message: error.localizedDescription))
                    }
                    .startWith(.loading)
            }
            .bind(to: avatarRelay)
            .disposed(by: disposeBag)

        input.withdrawalTap
            .flatMapLatest { [weak self] _ -> Observable<MyPageWithdrawalEvent> in
                guard let self else { return .empty() }
                return self.performWithdrawalSingle()
                    .asObservable()
                    .map { .success }
                    .catch { error in
                        .just(.failure(message: error.localizedDescription))
                    }
                    .startWith(.started)
            }
            .bind(to: withdrawalRelay)
            .disposed(by: disposeBag)

        return Output(
            user: userRelay.asDriver(onErrorDriveWith: .empty()),
            toastMessage: toastRelay.asSignal(),
            nicknameChange: nicknameRelay.asSignal(),
            avatarChange: avatarRelay.asSignal(),
            withdrawal: withdrawalRelay.asSignal()
        )
    }

    func detectMimeType(from provider: NSItemProvider) -> ImageMimeType {
        if provider.hasItemConformingToTypeIdentifier(UTType.heic.identifier) {
            return .heic
        } else if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
            return .png
        } else {
            return .jpeg
        }
    }

    private func fetchUserSingle() -> Single<APIUser> {
        NetworkManager.shared
            .request("/api/v1/user", method: .get, parameters: nil, requiresAuth: true)
            .observe(on: MainScheduler.instance)
    }

    private func updateNicknameSingle(_ newName: String) -> Single<UpdateNicknameResponse> {
        NetworkManager.shared
            .request("/api/v1/user/nickname", method: .patch, parameters: ["nickname": newName], requiresAuth: true)
            .observe(on: MainScheduler.instance)
            .catch { [weak self] error in
                let message = self?.parseNicknameErrorMessage(error) ?? error.localizedDescription
                return .error(MyPageViewModelError.message(message))
            }
    }

    private func uploadProfileImageSingle(image: UIImage, preferredMime: ImageMimeType) -> Single<Void> {
        guard let upload = makeUploadData(from: image, preferred: preferredMime) else {
            return .error(MyPageViewModelError.message("이미지 인코딩에 실패했습니다."))
        }

        return requestPresignedProfileURLSingle(mimeType: upload.mime)
            .flatMap { [weak self] presigned -> Single<String> in
                guard let self else { return .error(MyPageViewModelError.message("알 수 없는 오류가 발생했습니다.")) }
                return self.uploadImageDataToS3Single(upload.data, contentType: upload.mime.rawValue, to: presigned.s3Url)
                    .map { presigned.s3objectKey }
            }
            .flatMap { [weak self] objectKey -> Single<Void> in
                guard let self else { return .error(MyPageViewModelError.message("알 수 없는 오류가 발생했습니다.")) }
                return self.notifyProfileUpdatedSingle(objectKey: objectKey)
                    .flatMap { success -> Single<Void> in
                        success
                            ? .just(())
                            : .error(MyPageViewModelError.message("이미지 업데이트 확인에 실패했습니다."))
                    }
            }
            .catch { error in
                .error(MyPageViewModelError.message(error.localizedDescription))
            }
    }

    private func performWithdrawalSingle() -> Single<Void> {
        let req: Single<WithdrawResponse> = NetworkManager.shared
            .request("/api/v1/user/withdraw", method: .delete, parameters: nil, requiresAuth: true)

        return req
            .observe(on: MainScheduler.instance)
            .flatMap { [weak self] response -> Single<Void> in
                guard let self else { return .error(MyPageViewModelError.message("알 수 없는 오류가 발생했습니다.")) }
                guard response.success else {
                    return .error(MyPageViewModelError.message("요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."))
                }
                return self.clearAllAppDataSingle()
            }
            .catch { error in
                .error(MyPageViewModelError.message(error.localizedDescription))
            }
    }

    private func makeUploadData(from image: UIImage, preferred: ImageMimeType) -> (data: Data, mime: ImageMimeType)? {
        switch preferred {
        case .png:
            if let data = image.pngData() { return (data, .png) }
            if let data = image.jpegData(compressionQuality: 0.9) { return (data, .jpeg) }
        case .jpeg:
            if let data = image.jpegData(compressionQuality: 0.9) { return (data, .jpeg) }
            if let data = image.pngData() { return (data, .png) }
        case .heic:
            if let heicData = encodeHEIC(image: image, quality: 0.9) {
                return (heicData, .heic)
            }
            if let data = image.jpegData(compressionQuality: 0.9) { return (data, .jpeg) }
        }
        return nil
    }

    private func encodeHEIC(image: UIImage, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else {
            return nil
        }
        let options: CFDictionary = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(dest, cgImage, options)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private func requestPresignedProfileURLSingle(mimeType: ImageMimeType) -> Single<PresignedProfileUpload> {
        NetworkManager.shared
            .request("/api/v1/user/profile", method: .get, parameters: ["mimeType": mimeType.rawValue], requiresAuth: true)
            .observe(on: MainScheduler.instance)
    }

    private func notifyProfileUpdatedSingle(objectKey: String) -> Single<Bool> {
        NetworkManager.shared
            .request("/api/v1/user/profile-updated", method: .patch, parameters: ["s3objectKey": objectKey], requiresAuth: true)
            .observe(on: MainScheduler.instance)
            .map { (res: ProfileUpdatedResponse) in res.success }
    }

    private func uploadImageDataToS3Single(_ data: Data, contentType: String, to urlString: String) -> Single<Void> {
        Single.create { single in
            guard let url = URL(string: urlString) else {
                single(.failure(MyPageViewModelError.message("유효하지 않은 URL입니다.")))
                return Disposables.create()
            }

            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: contentType)

            let request = AF.upload(data, to: url, method: .put, headers: headers)
                .validate(statusCode: 200..<300)
                .response { response in
                    if let error = response.error {
                        single(.failure(error))
                    } else {
                        single(.success(()))
                    }
                }

            return Disposables.create {
                request.cancel()
            }
        }
    }

    private func clearAllAppDataSingle() -> Single<Void> {
        Single.create { [weak self] single in
            self?.clearAllAppData {
                single(.success(()))
            }
            return Disposables.create()
        }
    }

    private func clearAllAppData(completion: @escaping () -> Void) {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        UserSessionStore.shared.clearSession()
        UserDefaults.standard.removeObject(forKey: "apple_user_id")

        URLCache.shared.removeAllCachedResponses()

        let cache = KingfisherManager.shared.cache
        cache.clearMemoryCache()
        cache.clearDiskCache {
            let fm = FileManager.default

            if let cachesURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
                try? fm.removeItem(at: cachesURL)
            }

            let tmpPath = NSTemporaryDirectory()
            if let tmpURL = URL(string: "file://" + tmpPath) {
                try? fm.removeItem(at: tmpURL)
            }

            do {
                let realm = try Realm()
                try realm.write { realm.deleteAll() }
                if let url = realm.configuration.fileURL {
                    let aux = [
                        url,
                        url.appendingPathExtension("lock"),
                        url.appendingPathExtension("note"),
                        url.deletingPathExtension().appendingPathExtension("management")
                    ]
                    for u in aux { try? fm.removeItem(at: u) }
                }
            } catch {
                print("Realm cleanup error: \(error.localizedDescription)")
            }

            completion()
        }
    }

    private func parseNicknameErrorMessage(_ error: Error) -> String {
        var message = "닉네임 변경에 실패했습니다. 잠시 후 다시 시도해주세요."

        if let afError = error as? AFError, case let .responseValidationFailed(reason) = afError {
            switch reason {
            case .unacceptableStatusCode(let code):
                if code == 409 { message = "이미 사용 중인 닉네임입니다." }
            default:
                break
            }
        }

        if let data = (error as NSError).userInfo["com.alamofire.serialization.response.error.data"] as? Data,
           let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let code = obj["code"] as? String, code.uppercased().contains("DUPLICATE") {
                message = "이미 사용 중인 닉네임입니다."
            } else if let msg = obj["message"] as? String, !msg.isEmpty {
                message = msg
            }
        }

        return message
    }
}
