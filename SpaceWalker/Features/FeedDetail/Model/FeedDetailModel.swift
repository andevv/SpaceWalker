//
//  FeedDetailModel.swift
//  SpaceWalker
//
//  Created by andev on 2/25/26.
//

import UIKit

struct FeedDetailModel {
    var image: UIImage?
    var imageURL: URL?
    var likeCount: Int
    var liked: Bool
    var authorName: String
    var missionTitle: String
    var authorProfileURL: URL?

    init(
        image: UIImage?,
        likeCount: Int,
        liked: Bool,
        authorName: String,
        missionTitle: String,
        imageURL: URL? = nil,
        authorProfileURL: URL? = nil
    ) {
        self.image = image
        self.likeCount = likeCount
        self.liked = liked
        self.authorName = authorName
        self.missionTitle = missionTitle
        self.imageURL = imageURL
        self.authorProfileURL = authorProfileURL
    }
}
