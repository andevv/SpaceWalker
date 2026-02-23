//
//  FeedViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class FeedViewController: UIViewController {

    private let accent = UIColor(named: "AccentColor_066985") ?? .systemBlue

    // MARK: - UI
    private let chipStack = UIStackView()
    private let chipScrollView = UIScrollView()
    private let collectionView: UICollectionView

    // MARK: - Dependencies
    private let viewModel = FeedViewModel()
    private let disposeBag = DisposeBag()

    // MARK: - Init
    init() {
        let layout = MasonryLayout()
        layout.numberOfColumns = 2
        layout.columnSpacing = 12
        layout.rowSpacing = 12
        layout.contentInsets = .zero

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)

        layout.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Feed"
        view.backgroundColor = .systemBackground

        setupChips()
        setupCollectionView()
        bindViewModel()
        viewModel.loadInitial()
    }

    // MARK: - Setup
    private func setupChips() {
        view.addSubview(chipScrollView)
        chipScrollView.showsHorizontalScrollIndicator = false
        chipScrollView.alwaysBounceHorizontal = true
        chipScrollView.alwaysBounceVertical = false

        chipScrollView.addSubview(chipStack)
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.alignment = .fill
        chipStack.distribution = .fill

        chipScrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).inset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(36)
        }

        chipStack.snp.makeConstraints { make in
            make.edges.equalTo(chipScrollView.contentLayoutGuide).inset(0)
            make.height.equalTo(chipScrollView.frameLayoutGuide)
        }
    }

    private func setupCollectionView() {
        view.addSubview(collectionView)
        collectionView.backgroundColor = .systemBackground
        collectionView.register(FeedCell.self, forCellWithReuseIdentifier: FeedCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(chipScrollView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func bindViewModel() {
        viewModel.chipsUpdated
            .asSignal()
            .emit(onNext: { [weak self] in
                self?.reloadChips()
            })
            .disposed(by: disposeBag)

        viewModel.feedUpdated
            .asSignal()
            .emit(onNext: { [weak self] in
                self?.collectionView.reloadData()
            })
            .disposed(by: disposeBag)

        viewModel.errorMessage
            .asSignal()
            .emit(onNext: { [weak self] message in
                self?.presentErrorAlert(message: message)
            })
            .disposed(by: disposeBag)

        viewModel.reportSuccess
            .asSignal()
            .emit(onNext: { [weak self] in
                guard let self else { return }
                let ok = UIAlertController(title: "신고 완료",
                                           message: "신고가 접수되었습니다. 검토 후 조치하겠습니다.",
                                           preferredStyle: .alert)
                ok.addAction(UIAlertAction(title: "확인", style: .default))
                self.present(ok, animated: true)
            })
            .disposed(by: disposeBag)
    }

    private func reloadChips() {
        for sub in chipStack.arrangedSubviews {
            chipStack.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }

        let allButton = makeChipButton(title: "전체", selected: viewModel.selectedChipIndex == 0)
        allButton.tag = 0
        allButton.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        chipStack.addArrangedSubview(allButton)

        for (idx, space) in viewModel.spaces.enumerated() {
            let tag = idx + 1
            let b = makeChipButton(title: space.name, selected: viewModel.selectedChipIndex == tag)
            b.tag = tag
            b.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            chipStack.addArrangedSubview(b)
        }
    }

    private func presentErrorAlert(message: String) {
        let ac = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "확인", style: .default))
        present(ac, animated: true)
    }

    // MARK: - Actions
    @objc private func chipTapped(_ sender: UIButton) {
        let selectedIndex = sender.tag
        viewModel.selectChip(index: selectedIndex)

        for case let btn as UIButton in chipStack.arrangedSubviews {
            styleChip(btn, selected: btn.tag == selectedIndex)
        }

        collectionView.setContentOffset(.zero, animated: false)
    }

    private func makeChipButton(title: String, selected: Bool) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        b.layer.cornerRadius = 16
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.systemGray4.cgColor
        styleChip(b, selected: selected)
        return b
    }

    private func styleChip(_ b: UIButton, selected: Bool) {
        if selected {
            b.backgroundColor = accent
            b.setTitleColor(.white, for: .normal)
            b.layer.borderColor = accent.cgColor
        } else {
            b.backgroundColor = .systemGray6
            b.setTitleColor(.label, for: .normal)
            b.layer.borderColor = UIColor.systemGray4.cgColor
        }
    }
}

// MARK: - DataSource
extension FeedViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.numberOfItems()
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FeedCell.reuseID,
            for: indexPath
        ) as! FeedCell

        guard let item = viewModel.item(at: indexPath) else { return cell }

        let placeholder = UIImage(systemName: "photo")?.withTintColor(.secondarySystemBackground, renderingMode: .alwaysOriginal)
        cell.configure(url: item.photoURL, liked: item.isLiked, placeholder: placeholder)

        cell.onImageLoaded = { [weak self] size in
            guard let self else { return }
            if self.viewModel.updateMeasuredSize(size, at: indexPath) {
                self.collectionView.collectionViewLayout.invalidateLayout()
            }
        }

        cell.onLikeTapped = { [weak self, weak cell] in
            guard let self else { return }
            self.viewModel.toggleLike(at: indexPath, onStateChange: { updatedItem in
                if let c = cell {
                    let placeholder = UIImage(systemName: "photo")?.withTintColor(.secondarySystemBackground, renderingMode: .alwaysOriginal)
                    c.configure(url: updatedItem.photoURL, liked: updatedItem.isLiked, placeholder: placeholder)
                } else {
                    self.collectionView.reloadItems(at: [indexPath])
                }
            })
        }

        cell.onReportTapped = { [weak self] in
            guard let self else { return }
            let ac = UIAlertController(title: "신고하기",
                                       message: "이 사진을 신고할까요?",
                                       preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "취소", style: .cancel))
            ac.addAction(UIAlertAction(title: "신고", style: .destructive, handler: { [weak self] _ in
                self?.viewModel.report(at: indexPath)
            }))
            self.present(ac, animated: true)
        }

        return cell
    }
}

// MARK: - MasonryLayoutDelegate
extension FeedViewController: MasonryLayoutDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        heightForItemAt indexPath: IndexPath,
                        with width: CGFloat) -> CGFloat {
        viewModel.heightForItem(at: indexPath, width: width)
    }
}

// MARK: - Navigation
extension FeedViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = viewModel.item(at: indexPath) else { return }
        let detail = FeedDetailViewController(postId: item.postId)
        navigationController?.pushViewController(detail, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        if viewModel.shouldLoadNextPage(for: indexPath) {
            viewModel.loadNextPage()
        }
    }
}
