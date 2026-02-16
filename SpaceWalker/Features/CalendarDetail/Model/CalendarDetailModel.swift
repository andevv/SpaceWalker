//
//  CalendarDetailModel.swift
//  SpaceWalker
//
//  Created by andev on 2/16/26.
//

import UIKit
import Foundation

struct SpacePhotoDetailModel {
    var image: UIImage?
    var date: Date
    var missionTitle: String
    var isPublic: Bool
    var likeCount: Int
    var authorName: String
    var authorProfileImage: UIImage? = nil
    var locationName: String?
    var latitude: Double? = nil
    var longitude: Double? = nil
    var deviceName: String
    var resolutionText: String
    var fileSizeText: String
    var shotTimeText: String
}

struct SpacePostIdentifier {
    let spaceId: Int
    let postId: Int
}
