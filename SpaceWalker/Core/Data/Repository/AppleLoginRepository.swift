//
//  AppleLoginRepository.swift
//  SpaceWalker
//
//  Created by andev on 10/7/25.
//

import Foundation
import RxSwift
import Alamofire

enum AppleLoginError: Error {
    case invalidAuthCode(message: String)
    case unknown(message: String)
}

final class AppleLoginRepository {

    func loginWithApple(idToken: String) -> Single<AppleLoginResponse> {
        let params: [String: Any] = ["idToken": idToken]

        // API 요청
        let req: Single<Data> = NetworkManager.shared.requestRawData(
            "/api/v1/user/login/apple",
            method: .post,
            parameters: params,
            requiresAuth: false
        )

        // 성공/실패 분기 처리
        return req.flatMap { data -> Single<AppleLoginResponse> in
            do {
                let success = try JSONDecoder().decode(AppleLoginResponse.self, from: data)
                return .just(success)
            } catch {
                if let apiErr = try? JSONDecoder().decode(AppleLoginErrorResponse.self, from: data),
                   apiErr.code == "INVALID_AUTH_CODE" {
                    return .error(AppleLoginError.invalidAuthCode(message: apiErr.message))
                } else if let apiErr = try? JSONDecoder().decode(AppleLoginErrorResponse.self, from: data) {
                    return .error(AppleLoginError.unknown(message: apiErr.message))
                } else {
                    return .error(error)
                }
            }
        }
    }
}
