//
//  SpaceUIModel.swift
//  SpaceWalker
//
//  Created by andev on 9/29/25.
//

import Foundation

// dummy
struct SpaceUIModel: Hashable {
    let id: UUID
    let title: String

    init(space: Space) {
        self.id = space.id
        self.title = space.name
    }
}
