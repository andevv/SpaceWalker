//
//  SpaceActivityResponse.swift
//  SpaceWalker
//
//  Created by andev on 10/9/25.
//

import Foundation

struct SpaceActivityResponse: Decodable {
    let spaceId: Int
    let name: String
    let dailyMission: MissionDTO
    let didMission: Bool
    let activities: [ActivityDTO]
}

struct MissionDTO: Decodable {
    let missionId: Int
    let title: String
}

struct ActivityDTO: Decodable {
    let postId: Int
    let date: String // UTC 문자열
    let photo: String
    let mission: MissionDTO
}

