//
//  MyPageModels.swift
//  SpaceWalker
//
//  Created by andev on 3/2/26.
//

import Foundation

enum ImageMimeType: String {
    case jpeg = "image/jpeg"
    case png = "image/png"
    case heic = "image/heic"
}

struct APIUser: Decodable {
    let userId: Int64
    let nickname: String
    let profileImageUrl: String?
}

struct UpdateNicknameResponse: Decodable {
    let userId: Int64
    let newNickname: String
}

struct PresignedProfileUpload: Decodable {
    let s3objectKey: String
    let s3Url: String
}

struct ProfileUpdatedResponse: Decodable {
    let success: Bool
}

struct WithdrawResponse: Decodable {
    let success: Bool
}

struct LocationMetadataTransferPack: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let appVersion: String
    let checksum: String?
    let items: [LocationMetadataTransferItem]
}

struct LocationMetadataTransferItem: Codable {
    let s3Key: String
    let capturedAt: Date
    let width: Int
    let height: Int
    let latitude: Double
    let longitude: Double
    let deviceName: String?
    let spaceId: Int
    let missionId: Int?
    let missionTitle: String?
    let mimeType: String?
}

struct LocationMetadataImportResult {
    let insertedCount: Int
    let updatedCount: Int
    let skippedCount: Int
    let totalCount: Int
}
