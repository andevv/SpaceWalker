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
