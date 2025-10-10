//
//  SpaceRepository.swift
//  SpaceWalker
//
//  Created by andev on 10/5/25.
//

import Foundation
import RxSwift
import Alamofire

// MARK: - Post Detail DTOs
struct DailyMissionDTO: Decodable {
    let missionId: Int
    let title: String
}

struct AuthorDTO: Decodable {
    let userId: Int
    let nickname: String
    let profileImageUrl: String
}

struct SpacePostDetailResponse: Decodable {
    let postId: Int
    let spaceId: Int
    let spaceName: String
    let dailyMission: DailyMissionDTO
    let photoUrl: String
    let s3objectKey: String
    let author: AuthorDTO
    let likeCount: Int
    let isPublic: Bool
    let createdAt: String
    let liked: Bool
}

final class SpaceRepository {
    
    // MARK: - 게시글 상세 조회
    func fetchPostDetail(spaceId: Int, postId: Int) -> Single<SpacePostDetailResponse> {
        let endpoint = "/api/v1/space/\(spaceId)/\(postId)"
        return NetworkManager.shared.request(
            endpoint,
            method: .get,
            parameters: nil,
            requiresAuth: true
        )
    }
    
    // MARK: - 사용자의 특정 Space 상태 상세조회
    func fetchSpaceActivities(spaceId: Int, year: Int, month: Int, timezone: String) -> Single<SpaceActivityResponse> {
        let endpoint = "/api/v1/space/\(spaceId)/activities"
        let params: [String: Any] = [
            "year": year,
            "month": month,
            "timezone": timezone
        ]

        return NetworkManager.shared.request(
            endpoint,
            method: .get,
            parameters: params,
            requiresAuth: true
        )
    }

    // MARK: - ISO8601 Date Parsing (supports fractional seconds)
    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    // Supports timestamps without timezone (assumed UTC)
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

    private static func parseISO8601(_ s: String) -> Date? {
        // 1) ISO8601 with fractional seconds (e.g., 2025-10-07T18:33:56.241Z)
        if let d = iso8601WithFractional.date(from: s) { return d }
        // 2) ISO8601 basic (e.g., 2025-10-07T18:33:56Z)
        if let d = iso8601Basic.date(from: s) { return d }
        // 3) No timezone, microseconds (e.g., 2025-10-07T18:33:56.241536)
        if let d = microsecondsNoTZ.date(from: s) { return d }
        // 4) No timezone, milliseconds (e.g., 2025-10-07T18:33:56.241)
        if let d = millisecondsNoTZ.date(from: s) { return d }
        // 5) No timezone, seconds only (e.g., 2025-10-07T18:33:56)
        if let d = secondsNoTZ.date(from: s) { return d }
        return nil
    }

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

            return req.flatMap { data -> Single<[JoinedSpace]> in
                do {
                    // 성공 케이스
                    let success = try JSONDecoder().decode(JoinSpacesSuccessResponse.self, from: data)
                    let joined = success.joinedSpaces.compactMap { dto -> JoinedSpace? in
                        guard let date = Self.parseISO8601(dto.joinedAt) else { return nil }
                        return JoinedSpace(id: dto.spaceId, name: dto.name, joinedAt: date)
                    }
                    return .just(joined)

                } catch {
                    // 실패 케이스 (INVALID_SPACE_IDS 등)
                    if let apiErr = try? JSONDecoder().decode(JoinSpacesErrorResponse.self, from: data),
                       apiErr.code == "INVALID_SPACE_IDS" {
                        return .error(JoinSpacesDomainError.invalidSpaceIds(
                            invalidIds: apiErr.invalidIds ?? [],
                            message: apiErr.message
                        ))
                    } else if let apiErr = try? JSONDecoder().decode(JoinSpacesErrorResponse.self, from: data) {
                        return .error(JoinSpacesDomainError.unknown(message: apiErr.message))
                    } else {
                        return .error(error)
                    }
                }
            }
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
    
    // MARK: - Fetch MySpace (더미)
    func fetchMySpacesDummy() -> Single<[JoinedSpace]> {
        let single: Single<MySpacesResponse> = NetworkManager.shared.requestDummy(
            "/api/v1/space/my-space",
            method: .get
        )
        return single.map { resp in
            resp.spaces.compactMap { dto in
                guard let date = Self.parseISO8601(dto.joinedAt) else { return nil }
                return JoinedSpace(id: dto.spaceId, name: dto.name, joinedAt: date)
            }
        }
    }
    
    // MARK: - Fetch MySpace (실제)
    func fetchMySpaces() -> Single<[JoinedSpace]> {
        let single: Single<MySpacesResponse> = NetworkManager.shared.request(
            "/api/v1/space/my-space",
            method: .get,
            requiresAuth: true
        )
        return single.map { response in
            response.spaces.compactMap { dto in
                guard let date = Self.parseISO8601(dto.joinedAt) else { return nil }
                return JoinedSpace(id: dto.spaceId, name: dto.name, joinedAt: date)
            }
        }
    }

    // MARK: - 공통 파서
    private func parseJoinResponse(_ req: Single<Data>) -> Single<[JoinedSpace]> {
        return req.flatMap { data -> Single<[JoinedSpace]> in
            do {
                let success = try JSONDecoder().decode(JoinSpacesSuccessResponse.self, from: data)
                let mapped = success.joinedSpaces.compactMap { dto -> JoinedSpace? in
                    guard let date = Self.parseISO8601(dto.joinedAt) else { return nil }
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

    // MARK: - Presigned Upload DTOs
    struct PresignedUploadResponse: Decodable {
        let mainImageKey: String
        let mainImageUrl: String
    }

    struct DailyMissionSubmit: Encodable {
        let missionId: Int
        let title: String
    }

    struct SubmitMissionRequestBody: Encodable {
        let s3objectKey: String
        let dailyMission: DailyMissionSubmit
        let isPublic: Bool
    }

    struct SubmitMissionResponse: Decodable {
        let success: Bool
    }

    struct UpdateVisibilityResponse: Decodable {
        let postId: Int
        let success: Bool
    }
    
    struct DeletePostResponse: Decodable {
        let success: Bool
    }

    // MARK: - Presigned URL 발급
    func requestPresignedUpload(spaceId: Int, mimeType: String, timezone: String) -> Single<PresignedUploadResponse> {
        let endpoint = "/api/v1/space/\(spaceId)/upload"
        let params: [String: Any] = [
            "mimeType": mimeType,
            "timezone": timezone
        ]
        return NetworkManager.shared.request(
            endpoint,
            method: .get,
            parameters: params,
            requiresAuth: true
        )
    }

    // MARK: - 미션 제출
    func submitMission(spaceId: Int, s3objectKey: String, dailyMission: DailyMissionSubmit, isPublic: Bool = true, timezone: String) -> Single<SubmitMissionResponse> {
        let endpoint = "/api/v1/space/\(spaceId)/submit"
        let params: [String: Any] = [
            "s3objectKey": s3objectKey,
            "dailyMission": [
                "missionId": dailyMission.missionId,
                "title": dailyMission.title
            ],
            "isPublic": isPublic,
            "timezone": timezone
        ]
        return NetworkManager.shared.request(
            endpoint,
            method: .post,
            parameters: params,
            requiresAuth: true
        )
    }

    // MARK: - 게시글 공개여부 수정
    func updatePostVisibility(spaceId: Int, postId: Int, isPublic: Bool) -> Single<UpdateVisibilityResponse> {
        let endpoint = "/api/v1/space/\(spaceId)/\(postId)"
        let params: [String: Any] = [
            "isPublic": isPublic
        ]
        return NetworkManager.shared.request(
            endpoint,
            method: .patch,
            parameters: params,
            requiresAuth: true
        )
    }
    
    // MARK: - 게시글 삭제
    func deletePost(spaceId: Int, postId: Int) -> Single<DeletePostResponse> {
        let endpoint = "/api/v1/space/\(spaceId)/\(postId)"
        return NetworkManager.shared.request(
            endpoint,
            method: .delete,
            parameters: nil,
            requiresAuth: true
        )
    }
}

