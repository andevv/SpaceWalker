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

}
