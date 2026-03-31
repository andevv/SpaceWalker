//
//  CalendarMetadataRepository.swift
//  SpaceWalker
//
//  Created by andev on 3/31/26.
//

import Foundation
import CoreLocation
import RealmSwift

final class CalendarMetadataRepository {
    func savePhotoMetadata(pending: CalendarPendingPhotoMeta, s3Key: String) throws -> ObjectId {
        let meta = PhotoMetadata()
        meta.s3Key = s3Key
        meta.capturedAt = pending.capturedAt
        meta.width = pending.width
        meta.height = pending.height
        meta.latitude = pending.location?.coordinate.latitude ?? 0.0
        meta.longitude = pending.location?.coordinate.longitude ?? 0.0
        meta.spaceId = pending.spaceId
        meta.missionId = pending.missionId
        meta.missionTitle = pending.missionTitle
        meta.mimeType = pending.mimeType
        meta.deviceName = pending.deviceName

        let realm = try Realm()
        try realm.write {
            realm.add(meta)
        }
        return meta.id
    }
}
