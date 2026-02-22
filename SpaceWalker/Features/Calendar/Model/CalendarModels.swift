//
//  CalendarModels.swift
//  SpaceWalker
//
//  Created by andev on 2/22/26.
//

import UIKit
import CoreLocation

struct CalendarPendingPhotoMeta {
    let image: UIImage
    let capturedAt: Date
    let width: Int
    let height: Int
    let location: CLLocation?
    let spaceId: Int
    let missionId: Int?
    let missionTitle: String?
    let mimeType: String?
    let deviceName: String?
}

struct CalendarDayPhoto {
    let image: UIImage
    let postId: Int
}

struct CalendarActivitiesResult {
    let missionTitle: String
    let missionId: Int
    let didMission: Bool
    let photos: [Date: CalendarDayPhoto]
}
