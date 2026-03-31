//
//  CalendarDetailRepository.swift
//  SpaceWalker
//
//  Created by andev on 3/31/26.
//

import Foundation
import UIKit

struct CalendarDetailImagePayload {
    let image: UIImage?
    let byteCount: Int
}

final class CalendarDetailRepository {
    func fetchImagePayload(from urlString: String) async -> CalendarDetailImagePayload? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return CalendarDetailImagePayload(image: UIImage(data: data), byteCount: data.count)
        } catch {
            return nil
        }
    }

    func fetchImage(from urlString: String) async -> UIImage? {
        await fetchImagePayload(from: urlString)?.image
    }
}
