//
//  MyPageRepository.swift
//  SpaceWalker
//
//  Created by andev on 3/31/26.
//

import Foundation
import RxSwift
import Alamofire

final class MyPageRepository {

    func fetchUser() -> Single<APIUser> {
        NetworkManager.shared
            .request("/api/v1/user", method: .get, parameters: nil, requiresAuth: true)
    }

    func updateNickname(_ newName: String) -> Single<UpdateNicknameResponse> {
        NetworkManager.shared
            .request("/api/v1/user/nickname", method: .patch, parameters: ["nickname": newName], requiresAuth: true)
    }

    func requestPresignedProfileURL(mimeTypeRawValue: String) -> Single<PresignedProfileUpload> {
        NetworkManager.shared
            .request("/api/v1/user/profile", method: .get, parameters: ["mimeType": mimeTypeRawValue], requiresAuth: true)
    }

    func notifyProfileUpdated(objectKey: String) -> Single<ProfileUpdatedResponse> {
        NetworkManager.shared
            .request("/api/v1/user/profile-updated", method: .patch, parameters: ["s3objectKey": objectKey], requiresAuth: true)
    }

    func withdraw() -> Single<WithdrawResponse> {
        NetworkManager.shared
            .request("/api/v1/user/withdraw", method: .delete, parameters: nil, requiresAuth: true)
    }

    func uploadImageDataToS3(_ data: Data, contentType: String, to urlString: String) -> Single<Void> {
        Single.create { single in
            guard let url = URL(string: urlString) else {
                single(.failure(NSError(domain: "InvalidURL", code: -1)))
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
}
