//
//  SpaceSelectViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/29/25.
//

import UIKit
import RxSwift
import RxCocoa
import SnapKit

final class SpaceSelectViewController: UIViewController {

    // MARK: - UI
    private let titleLabel: UILabel = {
        let lb = UILabel()
        lb.text = "당신의 Space를 선택하세요."
        lb.font = .systemFont(ofSize: 28, weight: .bold)
        lb.textColor = .label
        lb.numberOfLines = 0
        return lb
    }()

    private let subtitleLabel: UILabel = {
        let lb = UILabel()
        lb.text = "최대 3개까지 선택 가능합니다."
        lb.font = .systemFont(ofSize: 14, weight: .medium)
        lb.textColor = .secondaryLabel
        lb.numberOfLines = 1
        return lb
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .systemBackground
        tv.separatorStyle = .none
        tv.register(SpaceCell.self, forCellReuseIdentifier: SpaceCell.reuseID)
        tv.estimatedRowHeight = 80
        tv.rowHeight = 80
        return tv
    }()

    private let countLabel: UILabel = {
        let lb = UILabel()
        lb.textAlignment = .center
        lb.font = .systemFont(ofSize: 14, weight: .semibold)
        lb.textColor = .secondaryLabel
        lb.text = "선택됨: 0 / 3"
        return lb
    }()

    private let bottomBar = UIView()
    private let proceedButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Space 선택"
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        let btn = UIButton(configuration: config)
        btn.isEnabled = false
        btn.alpha = 0.5
        return btn
    }()

    // MARK: - Properties
    private let viewModel = SpaceSelectViewModel()
    private let disposeBag = DisposeBag()
    private var itemsCache: [SpaceUIModel] = []

    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        bind()
    }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(tableView)
        view.addSubview(countLabel)
        view.addSubview(bottomBar)
        bottomBar.addSubview(proceedButton)

        // Bottom bar style
        bottomBar.backgroundColor = .systemBackground
        //bottomBar.layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        //bottomBar.layer.shadowOpacity = 1
        //bottomBar.layer.shadowRadius = 8
        //bottomBar.layer.shadowOffset = CGSize(width: 0, height: -2)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).inset(24)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(titleLabel)
        }

        countLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(bottomBar.snp.top).offset(-12)
        }

        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        proceedButton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(12)
            make.height.equalTo(52)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(countLabel.snp.top).offset(-12)
        }
    }

    // MARK: - Bind
    private func bind() {
        let input = SpaceSelectViewModel.Input(
            viewWillAppear: self.rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:)))
                .map { _ in () },
            itemSelected: tableView.rx.itemSelected.asObservable()
        )

        let output = viewModel.transform(input: input)

        // 아이템은 ID 배열이 바뀔 때만 전체 바인딩
        output.items
            .distinctUntilChanged { a, b in a.map(\.id) == b.map(\.id) }
            .do(onNext: { [weak self] items in
                self?.itemsCache = items
            })
            .drive(tableView.rx.items(
                cellIdentifier: SpaceCell.reuseID,
                cellType: SpaceCell.self
            )) { _, model, cell in
                cell.configure(with: model, selected: false)
            }
            .disposed(by: disposeBag)

        // 선택 상태 → 보이는 셀만 부분 업데이트, 카운트/버튼 반영
        output.selectedSpaces
            .map { ($0, Set($0.map { $0.id })) }
            .distinctUntilChanged { lhs, rhs in lhs.1 == rhs.1 }
            .drive(with: self) { owner, pair in
                let (spaces, selectedIDs) = pair

                // visible cells만 업데이트 (잔상 최소화)
                if let visible = owner.tableView.indexPathsForVisibleRows {
                    UIView.performWithoutAnimation {
                        for indexPath in visible {
                            guard indexPath.row < owner.itemsCache.count,
                                  let cell = owner.tableView.cellForRow(at: indexPath) as? SpaceCell else { continue }
                            let model = owner.itemsCache[indexPath.row]
                            cell.configure(with: model, selected: selectedIDs.contains(model.id))
                        }
                    }
                }

                // 선택 개수 & 버튼 상태
                owner.countLabel.text = "선택됨: \(spaces.count) / 3"
                let enabled = !spaces.isEmpty
                owner.proceedButton.isEnabled = enabled
                owner.proceedButton.alpha = enabled ? 1.0 : 0.5
            }
            .disposed(by: disposeBag)

        // 기본 하이라이트 즉시 제거
        tableView.rx.itemSelected
            .subscribe(with: self) { owner, indexPath in
                owner.tableView.deselectRow(at: indexPath, animated: false)
            }
            .disposed(by: disposeBag)

        // 버튼 탭 → root를 MainTabBarController로 교체
        proceedButton.rx.tap
            .withLatestFrom(output.selectedSpaces.map { !$0.isEmpty })
            .filter { $0 }
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, _ in
                owner.switchToMainTabBar()
            }
            .disposed(by: disposeBag)
    }

    // MARK: - Root switch
    private func switchToMainTabBar() {
        let tab = MainTabBarController()
        if let windowScene = view.window?.windowScene
            ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = tab
            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: nil)
            window.makeKeyAndVisible()
        }
    }
}
