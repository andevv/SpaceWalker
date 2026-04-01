//
//  LocationMetadataTransferRepository.swift
//  SpaceWalker
//
//  Created by andev on 4/1/26.
//

import Foundation
import RealmSwift

private enum LocationMetadataTransferError: LocalizedError {
    case emptyData
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .emptyData:
            return "내보낼 위치 메타데이터가 없습니다."
        case .invalidFile:
            return "가져오기 파일 형식이 올바르지 않습니다."
        }
    }
}

final class LocationMetadataTransferRepository {
    private let schemaVersion = 1

    func exportLocationMetadataPack() throws -> (fileURL: URL, itemCount: Int) {
        let realm = try Realm()
        let rows = realm.objects(PhotoMetadata.self).sorted(byKeyPath: "capturedAt", ascending: true)

        let items = rows.map { row in
            LocationMetadataTransferItem(
                s3Key: row.s3Key,
                capturedAt: row.capturedAt,
                width: row.width,
                height: row.height,
                latitude: row.latitude,
                longitude: row.longitude,
                deviceName: row.deviceName,
                spaceId: row.spaceId,
                missionId: row.missionId,
                missionTitle: row.missionTitle,
                mimeType: row.mimeType
            )
        }

        guard items.isEmpty == false else {
            throw LocationMetadataTransferError.emptyData
        }

        let pack = LocationMetadataTransferPack(
            schemaVersion: schemaVersion,
            exportedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            items: Array(items)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(pack)

        let fileName = "spacewalker-location-metadata-\(Self.timestamp()).swlocpack"
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: destination, options: .atomic)
        return (destination, items.count)
    }

    func importLocationMetadataPack(from fileURL: URL) throws -> LocationMetadataImportResult {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let pack = try? decoder.decode(LocationMetadataTransferPack.self, from: data) else {
            throw LocationMetadataTransferError.invalidFile
        }

        let realm = try Realm()
        var inserted = 0
        var updated = 0
        var skipped = 0

        try realm.write {
            for item in pack.items {
                guard item.s3Key.isEmpty == false else {
                    skipped += 1
                    continue
                }
                guard (-90.0...90.0).contains(item.latitude), (-180.0...180.0).contains(item.longitude) else {
                    skipped += 1
                    continue
                }

                if let existing = realm.objects(PhotoMetadata.self).filter("s3Key == %@", item.s3Key).first {
                    existing.capturedAt = item.capturedAt
                    existing.width = item.width
                    existing.height = item.height
                    existing.latitude = item.latitude
                    existing.longitude = item.longitude
                    existing.deviceName = item.deviceName
                    existing.spaceId = item.spaceId
                    existing.missionId = item.missionId
                    existing.missionTitle = item.missionTitle
                    existing.mimeType = item.mimeType
                    updated += 1
                } else {
                    let row = PhotoMetadata()
                    row.s3Key = item.s3Key
                    row.capturedAt = item.capturedAt
                    row.width = item.width
                    row.height = item.height
                    row.latitude = item.latitude
                    row.longitude = item.longitude
                    row.deviceName = item.deviceName
                    row.spaceId = item.spaceId
                    row.missionId = item.missionId
                    row.missionTitle = item.missionTitle
                    row.mimeType = item.mimeType
                    realm.add(row)
                    inserted += 1
                }
            }
        }

        return LocationMetadataImportResult(
            insertedCount: inserted,
            updatedCount: updated,
            skippedCount: skipped,
            totalCount: pack.items.count
        )
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
