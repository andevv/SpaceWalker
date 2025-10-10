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
}
