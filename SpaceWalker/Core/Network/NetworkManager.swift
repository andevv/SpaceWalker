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

    // MARK: - Request (실제 API용)
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

            // Authorization 헤더 추가
            if requiresAuth, let token = UserSessionStore.shared.accessToken {
                headers.add(name: "Authorization", value: "Bearer \(token)")
            }

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

            return Disposables.create { request.cancel() }
        }
    }

    // MARK: - Raw Data 요청 (성공/실패 바디 모두 받기)
    func requestRawData(
        _ path: String,
        method: HTTPMethod,
        parameters: [String: Any]?,
        requiresAuth: Bool
    ) -> Single<Data> {
        return Single.create { single in
            var headers: HTTPHeaders = ["Content-Type": "application/json"]
            if requiresAuth, let token = UserSessionStore.shared.accessToken {
                headers.add(name: "Authorization", value: "Bearer \(token)")
            }

            let req = AF.request(
                self.baseURL + path,
                method: method,
                parameters: parameters,
                encoding: JSONEncoding.default,
                headers: headers
            )
            .validate(statusCode: 200..<600)
            .responseData { res in
                switch res.result {
                case .success(let data):
                    single(.success(data))
                case .failure(let err):
                    if let data = res.data { single(.success(data)) }
                    else { single(.failure(err)) }
                }
            }

            return Disposables.create { req.cancel() }
        }
    }
}

//MARK: - Dummy 테스트용 확장
extension NetworkManager {

    enum DummyRoute: Equatable {
        case getSpaces
        case joinSpaces([Int])

        init?(endpoint: String, method: HTTPMethod, parameters: [String: Any]?) {
            switch (endpoint, method) {
            case ("/api/v1/space/all", .get):
                self = .getSpaces
            case ("/api/v1/space/join", .post):
                let ids = (parameters?["spaceIds"] as? [Int]) ?? []
                self = .joinSpaces(ids)
            default:
                return nil
            }
        }
    }

    private var dummyDelay: TimeInterval { 0.6 }

    // MARK: - Decodable 타입으로 더미 응답 반환
    func requestDummy<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil
    ) -> Single<T> {
        guard let route = DummyRoute(endpoint: endpoint, method: method, parameters: parameters) else {
            return .error(NSError(domain: "Dummy", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Dummy route not implemented for \(endpoint)"]))
        }

        return Single.create { single in
            DispatchQueue.main.asyncAfter(deadline: .now() + self.dummyDelay) {
                do {
                    let data = try self.makeDummyData(for: route)
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    single(.success(decoded))
                } catch {
                    single(.failure(error))
                }
            }
            return Disposables.create()
        }
    }

    // MARK: - 원시 Data로 더미 응답 반환 (성공/실패 바디)
    func requestRawDataDummy(
        _ endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil
    ) -> Single<Data> {
        guard let route = DummyRoute(endpoint: endpoint, method: method, parameters: parameters) else {
            return .error(NSError(domain: "Dummy", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Dummy route not implemented for \(endpoint)"]))
        }

        return Single.create { single in
            DispatchQueue.main.asyncAfter(deadline: .now() + self.dummyDelay) {
                do {
                    let data = try self.makeDummyData(for: route)
                    single(.success(data))
                } catch {
                    single(.failure(error))
                }
            }
            return Disposables.create()
        }
    }

    // MARK: - 라우트별 더미 JSON 생성
    private func makeDummyData(for route: DummyRoute) throws -> Data {
        switch route {

        case .getSpaces:
            let json = """
            {
              "spaces": [
                { "id": 1, "name": "Study" },
                { "id": 2, "name": "Color" },
                { "id": 3, "name": "Work" },
                { "id": 4, "name": "Rest" }
              ],
              "total": 4
            }
            """
            return Data(json.utf8)

        case .joinSpaces(let ids):
            if ids.contains(99) {
                let err = """
                {
                  "code": "INVALID_SPACE_IDS",
                  "message": "유효하지 않은 Space ID가 포함되어 있습니다.",
                  "invalidIds": [99]
                }
                """
                return Data(err.utf8)
            }

            let now = ISO8601DateFormatter().string(from: Date())
            let payload = [
                "joinedSpaces": ids.map { id in
                    [
                        "spaceId": id,
                        "name": self.nameForSpaceId(id),
                        "joinedAt": now
                    ]
                }
            ]
            return try JSONSerialization.data(withJSONObject: payload, options: [])
        }
    }

    private func nameForSpaceId(_ id: Int) -> String {
        switch id {
        case 1: return "Study"
        case 2: return "Color"
        case 3: return "Work"
        case 4: return "Rest"
        default: return "Unknown \(id)"
        }
    }
}
