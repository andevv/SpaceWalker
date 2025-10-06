//
//  SpacesResponse.swift
//  SpaceWalker
//
//  Created by andev on 10/5/25.
//

import Foundation

struct SpacesResponse: Decodable {
    let spaces: [SpaceDTO]
    let total: Int
}

struct SpaceDTO: Decodable {
    let id: Int
    let name: String
}

// Joined result
struct JoinSpacesSuccessResponse: Decodable {
    let joinedSpaces: [JoinedSpaceDTO]
}

struct JoinedSpaceDTO: Decodable {
    let spaceId: Int
    let name: String
    let joinedAt: String // ISO8601 Zulu
}

// Error body
struct JoinSpacesErrorResponse: Decodable, Error {
    let code: String
    let message: String
    let invalidIds: [Int]?
}

// /api/v1/space/my-space 응답
struct MySpaceDTO: Decodable {
    let spaceId: Int
    let name: String
    let joinedAt: String // ISO8601
}

struct MySpacesResponse: Decodable {
    let spaces: [MySpaceDTO]
    let total: Int
}
