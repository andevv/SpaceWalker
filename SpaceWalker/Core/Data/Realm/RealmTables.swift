//
//  RealmTables.swift
//  SpaceWalker
//
//  Created by andev on 10/9/25.
//

import Foundation
import RealmSwift

final class PhotoMetadata: Object {
    @Persisted(primaryKey: true) var id: ObjectId

    /// S3에 업로드된 파일의 키
    @Persisted var s3Key: String

    /// 사용자가 사진을 찍은 시각
    @Persisted var capturedAt: Date

    /// 사진 해상도 정보
    @Persisted var width: Int
    @Persisted var height: Int

    /// 위치 정보
    @Persisted var latitude: Double
    @Persisted var longitude: Double

    /// 사용자가 촬영한 스페이스 식별자 (없으면 0)
    @Persisted var spaceId: Int

    /// 오늘의 미션 정보 (선택적)
    @Persisted var missionId: Int?
    @Persisted var missionTitle: String?

    /// 업로드 파일 포맷 (예: image/heic, image/jpeg, image/png)
    @Persisted var mimeType: String?
}
