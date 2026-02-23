//
//  MasonryLayout.swift
//  SpaceWalker
//
//  Created by andev on 10/4/25.
//

import UIKit

protocol MasonryLayoutDelegate: AnyObject {
    func collectionView(_ collectionView: UICollectionView,
                        heightForItemAt indexPath: IndexPath,
                        with width: CGFloat) -> CGFloat
}

final class MasonryLayout: UICollectionViewLayout {

    weak var delegate: MasonryLayoutDelegate?

    var numberOfColumns: Int = 2
    var columnSpacing: CGFloat = 12   // 컬럼 간 간격
    var rowSpacing: CGFloat = 12      // 아이템 간 세로 간격
    var contentInsets: UIEdgeInsets = .zero

    private var cache: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0

    private var contentWidth: CGFloat {
        guard let cv = collectionView else { return 0 }
        let insets = cv.adjustedContentInset
        return cv.bounds.width - insets.left - insets.right - contentInsets.left - contentInsets.right
    }

    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight + contentInsets.top + contentInsets.bottom)
    }

    override func prepare() {
        super.prepare()
        guard let cv = collectionView, cache.isEmpty else { return }

        let columnWidth = (contentWidth - CGFloat(numberOfColumns - 1) * columnSpacing) / CGFloat(numberOfColumns)
        var xOffsets: [CGFloat] = []
        for column in 0..<numberOfColumns {
            let x = contentInsets.left + CGFloat(column) * (columnWidth + columnSpacing)
            xOffsets.append(x)
        }

        var yOffsets = Array(repeating: contentInsets.top, count: numberOfColumns)
        var column = 0

        for section in 0..<cv.numberOfSections {
            for item in 0..<cv.numberOfItems(inSection: section) {
                let indexPath = IndexPath(item: item, section: section)

                // 요청: 이 width로 높이를 계산해 달라
                let width = columnWidth
                let height = delegate?.collectionView(cv, heightForItemAt: indexPath, with: width) ?? 100

                let frame = CGRect(x: xOffsets[column],
                                   y: yOffsets[column],
                                   width: width,
                                   height: height)

                let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attributes.frame = frame
                cache.append(attributes)

                contentHeight = max(contentHeight, frame.maxY)

                yOffsets[column] = yOffsets[column] + height + rowSpacing

                // 다음 아이템은 현재 높이가 가장 낮은 컬럼에 배치
                if let minColumn = yOffsets.enumerated().min(by: { $0.element < $1.element })?.offset {
                    column = minColumn
                }
            }
        }
        contentHeight -= rowSpacing // 마지막 간격 보정
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        // 보이는 영역만 반환
        return cache.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache.first { $0.indexPath == indexPath }
    }

    override func invalidateLayout() {
        super.invalidateLayout()
        cache.removeAll()
        contentHeight = 0
    }
}
