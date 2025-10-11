import Foundation
import RxSwift
import Alamofire

public struct FeedDetailDTO: Decodable {
    public struct DailyMission: Decodable { let missionId: Int; let title: String }
    public struct Author: Decodable { let nickname: String; let profileImageUrl: String }

    let postId: Int
    let spaceId: Int
    let spaceName: String
    let dailyMission: DailyMission
    let photoUrl: String
    let author: Author
    let likeCount: Int
    let createdAt: String
    let liked: Bool
}

public struct FeedResponse: Decodable {
    let page: Int
    let size: Int
    let totalPages: Int
    let posts: [FeedPostDTO]
}

public struct FeedPostDTO: Decodable {
    let postId: Int
    let photoUrl: String
    let liked: Bool
}

final class FeedRepository {
    func fetchFeed(spaceId: Int?, page: Int = 1, size: Int = 20) -> Single<FeedResponse> {
        var params: [String: Any] = [
            "page": page,
            "size": size,
            "sort": "LATEST"
        ]
        if let spaceId {
            params["spaceId"] = spaceId
        }
        return NetworkManager.shared.request(
            "/api/v1/feed",
            method: .get,
            parameters: params,
            requiresAuth: true
        )
    }

    func fetchFeedDetail(postId: Int) -> Single<FeedDetailDTO> {
        let endpoint = "/api/v1/feed/\(postId)"
        return NetworkManager.shared.request(
            endpoint,
            method: .get,
            parameters: nil,
            requiresAuth: true
        )
    }

    struct LikeResponse: Codable {
        let postId: Int
        let success: Bool
    }

    func updateLike(postId: Int, liked: Bool) -> Single<LikeResponse> {
        let endpoint = "/api/v1/feed/\(postId)/like"
        let params: [String: Any] = [
            "liked": liked
        ]
        let req: Single<Data> = NetworkManager.shared.requestRawData(
            endpoint,
            method: .patch,
            parameters: params,
            requiresAuth: true
        )
        return req.flatMap { data -> Single<LikeResponse> in
            // Log raw JSON (or text) response body for debugging (e.g., 500 errors)
            if let text = String(data: data, encoding: .utf8) {
                print("[FeedRepository] Like raw response (postId=\(postId)): \(text)")
            } else {
                print("[FeedRepository] Like raw response (postId=\(postId)): <non-utf8 data size=\(data.count)>")
            }
            do {
                let decoded = try JSONDecoder().decode(LikeResponse.self, from: data)
                return .just(decoded)
            } catch {
                return .error(error)
            }
        }
    }

    struct ReportResponse: Codable {
        let postId: Int
        let success: Bool
    }

    func report(postId: Int, reason: String = "REVIEW_REQUIRED") -> Single<ReportResponse> {
        let endpoint = "/api/v1/feed/\(postId)/report"
        let params: [String: Any] = [
            "reason": reason
        ]
        let req: Single<Data> = NetworkManager.shared.requestRawData(
            endpoint,
            method: .post,
            parameters: params,
            requiresAuth: true
        )
        return req.flatMap { data -> Single<ReportResponse> in
            // Debug: log raw response body for troubleshooting
            if let text = String(data: data, encoding: .utf8) {
                print("[FeedRepository] Report raw response (postId=\(postId)): \(text)")
            } else {
                print("[FeedRepository] Report raw response (postId=\(postId)): <non-utf8 data size=\(data.count)>")
            }
            do {
                let decoded = try JSONDecoder().decode(ReportResponse.self, from: data)
                return .just(decoded)
            } catch {
                return .error(error)
            }
        }
    }
}
