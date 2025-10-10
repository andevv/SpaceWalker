import Foundation
import RxSwift
import Alamofire

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
}
