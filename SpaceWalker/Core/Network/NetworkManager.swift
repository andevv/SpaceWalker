//
//  NetworkManager.swift
//  SpaceWalker
//
//  Created by andev on 10/5/25.
//

import Foundation
import Alamofire
import RxSwift

final class NetworkManager {
    static let shared = NetworkManager()
    private init() {}

    // MARK: - Base Configuration
    private let baseURL = "https://example.spacewalker.com"

    // MARK: - Request Method
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) -> Single<T> {

        return Single.create { single in
            let url = self.baseURL + endpoint

            var headers: HTTPHeaders = [
                "Content-Type": "application/json"
            ]

            // Authorization 헤더 자동 추가
            if requiresAuth, let token = UserSessionStore.shared.accessToken {
                headers.add(name: "Authorization", value: "Bearer \(token)")
            }

            // 요청 실행
            let request = AF.request(
                url,
                method: method,
                parameters: parameters,
                encoding: method == .get ? URLEncoding.default : JSONEncoding.default,
                headers: headers
            )
            .validate()
            .responseDecodable(of: T.self) { response in
                switch response.result {
                case .success(let result):
                    single(.success(result))
                case .failure(let error):
                    print("[NetworkManager] \(endpoint) 실패:", error.localizedDescription)
                    single(.failure(error))
                }
            }

            return Disposables.create {
                request.cancel()
            }
        }
    }
}
