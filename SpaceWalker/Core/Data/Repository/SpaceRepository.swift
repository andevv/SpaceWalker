//
//  SpaceRepository.swift
//  SpaceWalker
//
//  Created by andev on 10/5/25.
//

import Foundation
import RxSwift
import Alamofire

enum JoinSpacesDomainError: Error {
    case invalidSpaceIds(invalidIds: [Int], message: String)
    case unknown(message: String)
}

final class SpaceRepository {

    // MARK: - 실제 API 버전 (서버 완성 후 교체)
    func fetchSpaces() -> Single<[Space]> {
        let single: Single<SpacesResponse> = NetworkManager.shared.request(
            "/api/v1/space/all",
            method: .get,
            parameters: nil,
            requiresAuth: true
        )
        return single.map { $0.spaces.map { Space(id: $0.id, name: $0.name) } }
    }

    // MARK: - 더미 버전
    func fetchDummySpaces() -> Single<[Space]> {
        let single: Single<SpacesResponse> = NetworkManager.shared.requestDummy(
            "/api/v1/space/all",
            method: .get
        )
        return single.map { $0.spaces.map { Space(id: $0.id, name: $0.name) } }
    }

    // MARK: - Space Join (실제)
    func joinSpaces(spaceIds: [Int]) -> Single<[JoinedSpace]> {
        let params: [String: Any] = ["spaceIds": spaceIds]
        let req: Single<Data> = NetworkManager.shared.requestRawData(
            "/api/v1/space/join",
            method: .post,
            parameters: params,
            requiresAuth: true
        )
        return parseJoinResponse(req)
    }

    // MARK: - Space Join (더미)
    func joinSpacesDummy(spaceIds: [Int]) -> Single<[JoinedSpace]> {
        let params: [String: Any] = ["spaceIds": spaceIds]
        let req: Single<Data> = NetworkManager.shared.requestRawDataDummy(
            "/api/v1/space/join",
            method: .post,
            parameters: params
        )
        return parseJoinResponse(req)
    }

    // MARK: - 공통 파서
    private func parseJoinResponse(_ req: Single<Data>) -> Single<[JoinedSpace]> {
        return req.flatMap { data -> Single<[JoinedSpace]> in
            do {
                let success = try JSONDecoder().decode(JoinSpacesSuccessResponse.self, from: data)
                let mapped = success.joinedSpaces.compactMap { dto -> JoinedSpace? in
                    guard let date = ISO8601DateFormatter().date(from: dto.joinedAt) else { return nil }
                    return JoinedSpace(id: dto.spaceId, name: dto.name, joinedAt: date)
                }
                return .just(mapped)
            } catch {
                if let apiErr = try? JSONDecoder().decode(JoinSpacesErrorResponse.self, from: data),
                   apiErr.code == "INVALID_SPACE_IDS" {
                    return .error(
                        JoinSpacesDomainError.invalidSpaceIds(
                            invalidIds: apiErr.invalidIds ?? [],
                            message: apiErr.message
                        )
                    )
                } else if let apiErr = try? JSONDecoder().decode(JoinSpacesErrorResponse.self, from: data) {
                    return .error(JoinSpacesDomainError.unknown(message: apiErr.message))
                } else {
                    return .error(error)
                }
            }
        }
    }
}
