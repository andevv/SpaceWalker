//
//  NetworkManager.swift
//  SpaceWalker
//
//  Created by andev on 10/5/25.
//

import Foundation
import Alamofire
import RxSwift
import OSLog

final class NetworkManager {
    static let shared = NetworkManager()
    private init() {}

    // Unified logging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SpaceWalker", category: "NetworkManager")

    // MARK: - Base Configuration
    private let baseURL = Secrets.baseURL

    // UI routing hook set by SceneDelegate/AppRouter
    var onRequireReauthentication: (() -> Void)?

    /// Refresh access token using stored refresh token
    private func refreshAccessToken() -> Single<Bool> {
        guard let refreshToken = UserSessionStore.shared.refreshToken else {
            logger.warning("[Auth] No refresh token available. Skipping refresh.")
            return .just(false)
        }

        return Single.create { single in
            self.logger.info("[Auth] Start token refresh -> POST /api/v1/user/refresh")
            let url = self.baseURL + "/api/v1/user/refresh"
            let params: [String: Any] = ["refreshToken": refreshToken]
            let headers: HTTPHeaders = ["Content-Type": "application/json"]

            let req = AF.request(
                url,
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                headers: headers
            ).responseData { response in
                let status = response.response?.statusCode ?? -1
                self.logger.debug("[Auth] Refresh response status: \(status)")
                switch response.result {
                case .success(let data):
                    if status == 200 {
                        self.logger.info("[Auth] Token refresh succeeded (200)")
                        if let refreshed = try? JSONDecoder().decode(RefreshResponse.self, from: data) {
                            UserSessionStore.shared.accessToken = refreshed.accessToken
                            UserSessionStore.shared.refreshToken = refreshed.refreshToken
                            single(.success(true))
                        } else {
                            self.logger.error("[Auth] Failed to decode refresh response")
                            single(.success(false))
                        }
                    } else if status == 401 {
                        self.logger.warning("[Auth] Refresh rejected with 401. Tokens expired or invalid.")
                        single(.success(false)) // explicit expired
                    } else {
                        self.logger.error("[Auth] Refresh failed with status: \(status)")
                        single(.success(false))
                    }
                case .failure:
                    self.logger.error("[Auth] Network error during refresh: \(response.error?.localizedDescription ?? "unknown error")")
                    single(.success(false))
                }
            }
            return Disposables.create { req.cancel() }
        }
    }

    // MARK: - Request (실제 API용)
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) -> Single<T> {

        return Single.create { single in
            self.logger.debug("[Request] Start \(method.rawValue) \(endpoint) auth=\(requiresAuth) params=\(parameters != nil)")

            var refreshDisposable: Disposable? = nil

            let performRequest: () -> DataRequest = { [baseURL = self.baseURL] in
                let url = baseURL + endpoint
                var headers: HTTPHeaders = ["Content-Type": "application/json"]
                if requiresAuth, let token = UserSessionStore.shared.accessToken {
                    headers.add(name: "Authorization", value: "Bearer \(token)")
                }
                let req = AF.request(
                    url,
                    method: method,
                    parameters: parameters,
                    encoding: method == .get ? URLEncoding.default : JSONEncoding.default,
                    headers: headers
                )
                self.logger.debug("[Request] Performing: \(method.rawValue) \(url), headersAuth=\(requiresAuth && UserSessionStore.shared.accessToken != nil)")
                return req
            }

            var currentRequest: DataRequest? = nil

            var handleResponse: ((AFDataResponse<T>, Bool) -> Void)!
            handleResponse = { [weak self] response, didRetry in
                guard let self = self else { return }
                let status = response.response?.statusCode ?? -1
                self.logger.debug("[Response] \(method.rawValue) \(endpoint) status=\(status) didRetry=\(didRetry)")
                switch response.result {
                case .success(let result):
                    self.logger.info("[Response] Success for \(endpoint) didRetry=\(didRetry)")
                    single(.success(result))
                case .failure(let error):
                    self.logger.error("[Response] Failure for \(endpoint): \(error.localizedDescription)")
                    if status == 401, requiresAuth, !didRetry {
                        self.logger.notice("[Auth] 401 received for \(endpoint). Attempting token refresh...")
                        refreshDisposable = self.refreshAccessToken()
                            .subscribe(onSuccess: { [weak self] ok in
                                guard let self = self else { return }
                                self.logger.debug("[Auth] Refresh result ok=\(ok)")
                                if ok {
                                    self.logger.info("[Auth] Refresh succeeded. Retrying request: \(method.rawValue) \(endpoint)")
                                    let retryReq = performRequest()
                                    currentRequest = retryReq
                                    retryReq.validate().responseDecodable(of: T.self) { retryRes in
                                        handleResponse(retryRes, true)
                                    }
                                } else {
                                    self.logger.warning("[Auth] Refresh failed. Reauthentication required.")
                                    self.onRequireReauthentication?()
                                    single(.failure(error))
                                }
                            }, onFailure: { [weak self] _ in
                                self?.logger.error("[Auth] Refresh request errored. Reauthentication required.")
                                self?.onRequireReauthentication?()
                                single(.failure(error))
                            })
                    } else {
                        self.logger.error("[Response] Non-retriable failure for \(endpoint): \(error.localizedDescription)")
                        single(.failure(error))
                    }
                }
            }

            let initial = performRequest()
            currentRequest = initial
            self.logger.debug("[Request] Initial request fired: \(method.rawValue) \(endpoint)")
            initial.validate().responseDecodable(of: T.self) { response in
                handleResponse(response, false)
            }

            return Disposables.create { currentRequest?.cancel(); refreshDisposable?.dispose() }
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
            self.logger.debug("[RequestRaw] Start \(method.rawValue) \(path) auth=\(requiresAuth) params=\(parameters != nil)")
            let performRequest: () -> DataRequest = { [baseURL = self.baseURL] in
                var headers: HTTPHeaders = ["Content-Type": "application/json"]
                if requiresAuth, let token = UserSessionStore.shared.accessToken {
                    headers.add(name: "Authorization", value: "Bearer \(token)")
                }
                let req = AF.request(
                    baseURL + path,
                    method: method,
                    parameters: parameters,
                    encoding: JSONEncoding.default,
                    headers: headers
                )
                self.logger.debug("[RequestRaw] Performing: \(method.rawValue) \(baseURL + path), headersAuth=\(requiresAuth && UserSessionStore.shared.accessToken != nil)")
                return req
            }

            var currentRequest: DataRequest? = nil
            var refreshDisposable: Disposable? = nil

            var handleResponse: ((AFDataResponse<Data>, Bool) -> Void)!
            handleResponse = { [weak self] res, didRetry in
                guard let self = self else { return }
                let status = res.response?.statusCode ?? -1
                self.logger.debug("[ResponseRaw] \(method.rawValue) \(path) status=\(status) didRetry=\(didRetry)")
                switch res.result {
                case .success(let data):
                    if status == 401, requiresAuth, !didRetry {
                        self.logger.notice("[Auth] 401 received for raw request \(path). Attempting token refresh...")
                        refreshDisposable = self.refreshAccessToken()
                            .subscribe(onSuccess: { [weak self] ok in
                                guard let self = self else { return }
                                self.logger.debug("[Auth] Refresh result ok=\(ok)")
                                if ok {
                                    self.logger.info("[Auth] Refresh succeeded. Retrying raw request: \(method.rawValue) \(path)")
                                    let retryReq = performRequest()
                                    currentRequest = retryReq
                                    retryReq.validate(statusCode: 200..<600).responseData { retryRes in
                                        handleResponse(retryRes, true)
                                    }
                                } else {
                                    self.logger.warning("[Auth] Refresh failed. Reauthentication required (raw request). Returning original data.")
                                    self.onRequireReauthentication?()
                                    single(.success(data))
                                }
                            }, onFailure: { [weak self] _ in
                                self?.logger.error("[Auth] Refresh request errored (raw). Reauthentication required. Returning original data if available.")
                                self?.onRequireReauthentication?()
                                single(.success(res.data ?? Data()))
                            })
                    } else {
                        single(.success(data))
                    }
                case .failure(let err):
                    if status == 401, requiresAuth, !didRetry {
                        self.logger.notice("[Auth] 401 failure for raw request \(path). Attempting token refresh...")
                        refreshDisposable = self.refreshAccessToken()
                            .subscribe(onSuccess: { [weak self] ok in
                                guard let self = self else { return }
                                self.logger.debug("[Auth] Refresh result ok=\(ok)")
                                if ok {
                                    self.logger.info("[Auth] Refresh succeeded. Retrying raw request after failure: \(method.rawValue) \(path)")
                                    let retryReq = performRequest()
                                    currentRequest = retryReq
                                    retryReq.validate(statusCode: 200..<600).responseData { retryRes in
                                        handleResponse(retryRes, true)
                                    }
                                } else {
                                    self.logger.warning("[Auth] Refresh failed (raw failure). Reauthentication required.")
                                    self.onRequireReauthentication?()
                                    if let data = res.data { single(.success(data)) }
                                    else { single(.failure(err)) }
                                }
                            }, onFailure: { [weak self] _ in
                                self?.logger.error("[Auth] Refresh request errored (raw failure). Reauthentication required.")
                                self?.onRequireReauthentication?()
                                if let data = res.data { single(.success(data)) }
                                else { single(.failure(err)) }
                            })
                    } else {
                        self.logger.error("[ResponseRaw] Failure for \(path): \(err.localizedDescription)")
                        if let data = res.data { single(.success(data)) }
                        else { single(.failure(err)) }
                    }
                }
            }

            let initial = performRequest()
            currentRequest = initial
            self.logger.debug("[RequestRaw] Initial request fired: \(method.rawValue) \(path)")
            initial.validate(statusCode: 200..<600).responseData { res in
                handleResponse(res, false)
            }

            return Disposables.create { currentRequest?.cancel(); refreshDisposable?.dispose() }
        }
    }
}

//MARK: - Dummy 테스트용 확장
extension NetworkManager {

    enum DummyRoute: Equatable {
        case getSpaces                // GET /api/v1/space/all
        case joinSpaces([Int])        // POST /api/v1/space/join
        case getMySpaces              // GET /api/v1/space/my-space

        init?(endpoint: String, method: HTTPMethod, parameters: [String: Any]?) {
            switch (endpoint, method) {
            case ("/api/v1/space/all", .get):
                self = .getSpaces
            case ("/api/v1/space/join", .post):
                let ids = (parameters?["spaceIds"] as? [Int]) ?? []
                self = .joinSpaces(ids)
            case ("/api/v1/space/my-space", .get):
                self = .getMySpaces
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

        case .getMySpaces:
            let json = """
            {
              "spaces": [
                { "spaceId": 1, "name": "Study", "joinedAt": "2025-09-20T00:10:00Z" },
                { "spaceId": 2, "name": "Travel", "joinedAt": "2025-09-20T00:10:00Z" },
                { "spaceId": 3, "name": "Color", "joinedAt": "2025-09-21T00:10:00Z" }
              ],
              "total": 3
            }
            """
            return Data(json.utf8)
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

