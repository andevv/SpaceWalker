//
//  Date+.swift
//  SpaceWalker
//
//  Created by andev on 10/9/25.
//

import Foundation

extension Date {
    func convertToLocal() -> Date {
        let timezoneOffset = TimeInterval(TimeZone.current.secondsFromGMT(for: self))
        return addingTimeInterval(timezoneOffset)
    }
}
