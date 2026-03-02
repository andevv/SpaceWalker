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
