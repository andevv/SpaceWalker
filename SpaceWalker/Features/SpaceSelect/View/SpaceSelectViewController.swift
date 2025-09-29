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
    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .systemBackground
        tv.separatorStyle = .none
        tv.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        tv.register(SpaceCell.self, forCellReuseIdentifier: SpaceCell.reuseID)
        tv.estimatedRowHeight = 88
        tv.rowHeight = 88
        return tv
    }()

    private let bottomBar = UIView()
    private let proceedButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Space로 이동하기"
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        let btn = UIButton(configuration: config)
        btn.isEnabled = false
        btn.alpha = 0.5 // 비활성화 시 시각적 구분
        return btn
    }()

    // MARK: - Properties
    private let viewModel = SpaceSelectViewModel()
    private let disposeBag = DisposeBag()

    /// 현재 표시 중인 아이템 캐시 (선택 상태 재적용용)
    private var itemsCache: [SpaceUIModel] = []

    // 외부로 선택 결과 전달하고 싶다면 사용
    let proceedSelectedSpaces = PublishRelay<[Space]>()

    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Choose Your Space"
        view.backgroundColor = .systemBackground
        setupLayout()
        bind()
    }

    private func setupLayout() {
        view.addSubview(tableView)
        view.addSubview(bottomBar)
        bottomBar.addSubview(proceedButton)

        // bottom bar 스타일
        bottomBar.backgroundColor = .systemBackground
        bottomBar.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        bottomBar.layer.shadowOpacity = 1
        bottomBar.layer.shadowRadius = 8
        bottomBar.layer.shadowOffset = CGSize(width: 0, height: -2)

        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        proceedButton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(12)
            make.height.equalTo(52)
        }

        tableView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(bottomBar.snp.top)
        }
    }

    private func bind() {
        let input = SpaceSelectViewModel.Input(
            viewWillAppear: self.rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:)))
                .map { _ in () },
            itemSelected: tableView.rx.itemSelected.asObservable()
        )

        let output = viewModel.transform(input: input)

        // 1) 아이템 목록은 ID 배열이 바뀔 때만 테이블에 바인딩 (전량 재구성 최소화)
        output.items
            .distinctUntilChanged { a, b in a.map(\.id) == b.map(\.id) }
            .do(onNext: { [weak self] items in
                self?.itemsCache = items
            })
            .drive(tableView.rx.items(
                cellIdentifier: SpaceCell.reuseID,
                cellType: SpaceCell.self
            )) { _, model, cell in
                // 초기 구성은 선택 상태 없이 렌더링 (선택 상태는 아래에서 재적용)
                cell.configure(with: model, selected: false)
            }
            .disposed(by: disposeBag)

        // 2) 선택 상태 변경 시, 보이는 셀만 부분 업데이트
        let selectedIDsDriver = output.selectedSpaces
            .map { Set($0.map { $0.id }) }
            .distinctUntilChanged()
            .asDriver()

        selectedIDsDriver
            .drive(with: self) { owner, selectedIDs in
                guard let visible = owner.tableView.indexPathsForVisibleRows else { return }
                UIView.performWithoutAnimation {
                    for indexPath in visible {
                        guard indexPath.row < owner.itemsCache.count,
                              let cell = owner.tableView.cellForRow(at: indexPath) as? SpaceCell else { continue }
                        let model = owner.itemsCache[indexPath.row]
                        cell.configure(with: model, selected: selectedIDs.contains(model.id))
                    }
                }
            }
            .disposed(by: disposeBag)

        // 3) 버튼 활성/비활성 제어 + 카운터 표시
        output.selectedSpaces
            .map { $0.count }
            .distinctUntilChanged()
            .drive(with: self) { owner, count in
                owner.navigationItem.rightBarButtonItem = {
                    let btn = UIBarButtonItem(title: "\(count)/3", style: .plain, target: nil, action: nil)
                    btn.isEnabled = count > 0
                    return btn
                }()

                let enabled = count > 0
                owner.proceedButton.isEnabled = enabled
                owner.proceedButton.alpha = enabled ? 1.0 : 0.5
            }
            .disposed(by: disposeBag)

        // 4) 버튼 탭 → 메인 탭바로 전환 (선택이 1개 이상일 때만)
        proceedButton.rx.tap
            .withLatestFrom(output.selectedSpaces.map { !$0.isEmpty }) // true면 가능
            .filter { $0 }
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, _ in
                owner.switchToMainTabBar()
            }
            .disposed(by: disposeBag)

        // 5) 기본 선택 하이라이트 즉시 제거
        tableView.rx.itemSelected
            .subscribe(with: self) { owner, indexPath in
                owner.tableView.deselectRow(at: indexPath, animated: false)
            }
            .disposed(by: disposeBag)
    }
    
    private func switchToMainTabBar() {
        let tab = MainTabBarController() // 준비된 메인 탭바 컨트롤러

        // 현재 윈도우를 안전하게 찾아서 root 교체 (크로스 디졸브 애니메이션)
        if let windowScene = view.window?.windowScene
            ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = tab
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
            window.makeKeyAndVisible()
        }
    }
}
