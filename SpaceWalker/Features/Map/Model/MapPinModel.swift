//
//  MapPinModel.swift
//  SpaceWalker
//
//  Created by andev on 2/11/26.
//

import Foundation

struct MapPinModel: Equatable {
    let latitude: Double
    let longitude: Double
    let title: String
    let subtitle: String
}

struct MapSpaceChipModel: Equatable {
    let id: Int?
    let title: String
    let isSelected: Bool
}
