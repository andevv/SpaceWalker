//
//  SpacesResponse.swift
//  SpaceWalker
//
//  Created by andev on 10/5/25.
//

import Foundation

// MARK: - /api/v1/space/all
struct SpacesResponse: Decodable {
    let spaces: [SpaceDTO]
    let total: Int
}

struct SpaceDTO: Decodable {
    let id: Int
    let name: String
}

// MARK: - /api/v1/space/join (성공)
struct JoinSpacesSuccessResponse: Decodable {
    let joinedSpaces: [JoinedSpaceDTO]
}

struct JoinedSpaceDTO: Decodable {
    let spaceId: Int
    let name: String
    let joinedAt: String // ISO8601 (Zulu)
}

// MARK: - /api/v1/space/join (실패)
struct JoinSpacesErrorResponse: Decodable, Error {
    let code: String
    let message: String
    let invalidIds: [Int]?
}

// MARK: - /api/v1/space/my-space
struct MySpacesResponse: Decodable {
    let spaces: [MySpaceDTO]
    let total: Int
}

struct MySpaceDTO: Decodable {
    let spaceId: Int
    let name: String
    let joinedAt: String // ISO8601
}

// MARK: - Domain Error
enum JoinSpacesDomainError: Error {
    case invalidSpaceIds(invalidIds: [Int], message: String)
    case unknown(message: String)
}
