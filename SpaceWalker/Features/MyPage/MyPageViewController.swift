//
//  MyPageViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import SnapKit

final class MyPageViewController: UIViewController {

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let titleLabel: UILabel = {
        let lb = UILabel()
        lb.text = "내 프로필"
        lb.font = .systemFont(ofSize: 22, weight: .semibold)
        lb.textColor = .label
        return lb
    }()

    private let avatarView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        iv.image = UIImage(systemName: "person.circle")?.withRenderingMode(.alwaysTemplate)
        iv.tintColor = .systemBlue
        return iv
    }()

    // 닉네임 카드
    private let nicknameCard = UIView()
    private let nicknameCaption: UILabel = {
        let lb = UILabel()
        lb.text = "현재 닉네임"
        lb.font = .systemFont(ofSize: 13, weight: .medium)
        lb.textColor = .secondaryLabel
        return lb
    }()
    private let nicknameLabel: UILabel = {
        let lb = UILabel()
        lb.text = "스페이스워커123"
        lb.font = .systemFont(ofSize: 18, weight: .semibold)
        lb.textColor = .label
        return lb
    }()
    private let editButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = "수정"
        config.image = UIImage(systemName: "pencil.line")
        config.imagePadding = 6
        config.baseBackgroundColor = .systemGray6
        config.baseForegroundColor = .label
        config.cornerStyle = .medium
        return UIButton(configuration: config)
    }()

    // 설정 섹션
    private let settingsTitle: UILabel = {
        let lb = UILabel()
        lb.text = "설정"
        lb.font = .systemFont(ofSize: 17, weight: .semibold)
        lb.textColor = .label
        return lb
    }()
    private lazy var policyButton   = makeSettingButton(title: "개인정보 처리방침")
    private lazy var termsButton    = makeSettingButton(title: "서비스 이용약관")
    private lazy var ossButton      = makeSettingButton(title: "오픈소스 라이센스")

    // 회원탈퇴
    private let withdrawButton: UIButton = {
        var config = UIButton.Configuration.bordered()
        config.title = "회원탈퇴"
        config.baseForegroundColor = .systemRed
        config.background.backgroundColor = .clear
        config.cornerStyle = .large
        let b = UIButton(configuration: config)
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.3).cgColor
        b.layer.cornerRadius = 12
        b.clipsToBounds = true
        return b
    }()

    // MARK: - Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "MyPage"
        view.backgroundColor = .systemBackground
        setupLayout()
        bindActions()
    }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }

        // Top
        contentView.addSubview(titleLabel)
        contentView.addSubview(avatarView)
        contentView.addSubview(nicknameCard)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        avatarView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(120)
        }
        avatarView.layer.cornerRadius = 60

        nicknameCard.backgroundColor = .secondarySystemBackground
        nicknameCard.layer.cornerRadius = 16

        let nicknameStack = UIStackView(arrangedSubviews: [nicknameCaption, nicknameLabel])
        nicknameStack.axis = .vertical
        nicknameStack.spacing = 6

        nicknameCard.addSubview(nicknameStack)
        nicknameCard.addSubview(editButton)

        nicknameCard.snp.makeConstraints { make in
            make.top.equalTo(avatarView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        nicknameStack.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview().inset(16)
            make.trailing.lessThanOrEqualTo(editButton.snp.leading).offset(-12)
        }
        editButton.snp.makeConstraints { make in
            make.centerY.equalTo(nicknameStack.snp.centerY)
            make.trailing.equalToSuperview().inset(16)
        }

        // Settings
        contentView.addSubview(settingsTitle)
        settingsTitle.snp.makeConstraints { make in
            make.top.equalTo(nicknameCard.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        let settingsStack = UIStackView(arrangedSubviews: [policyButton, termsButton, ossButton])
        settingsStack.axis = .vertical
        settingsStack.spacing = 12
        contentView.addSubview(settingsStack)

        settingsStack.snp.makeConstraints { make in
            make.top.equalTo(settingsTitle.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        // Withdraw
        contentView.addSubview(withdrawButton)
        withdrawButton.snp.makeConstraints { make in
            make.top.equalTo(settingsStack.snp.bottom).offset(28)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(52)
            make.bottom.equalToSuperview().inset(24)
        }
    }

    private func makeSettingButton(title: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        let b = UIButton(configuration: config)
        b.backgroundColor = .secondarySystemBackground
        b.layer.cornerRadius = 14
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.6).cgColor
        b.contentHorizontalAlignment = .leading
        return b
    }

    // MARK: - Actions
    private func bindActions() {
        editButton.addTarget(self, action: #selector(didTapEditNickname), for: .touchUpInside)
        policyButton.addTarget(self, action: #selector(openPolicy), for: .touchUpInside)
        termsButton.addTarget(self, action: #selector(openTerms), for: .touchUpInside)
        ossButton.addTarget(self, action: #selector(openOSS), for: .touchUpInside)
        withdrawButton.addTarget(self, action: #selector(didTapWithdraw), for: .touchUpInside)
    }

    @objc private func didTapEditNickname() {
        let alert = UIAlertController(title: "닉네임 변경", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "새 닉네임"
            tf.text = self.nicknameLabel.text
        }
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "저장", style: .default, handler: { _ in
            let newName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let newName, !newName.isEmpty {
                self.nicknameLabel.text = newName
            }
        }))
        present(alert, animated: true)
    }

    @objc private func openPolicy() { toast("개인정보 처리방침 화면으로 연결") }
    @objc private func openTerms() { toast("서비스 이용약관 화면으로 연결") }
    @objc private func openOSS() { toast("오픈소스 라이선스 화면으로 연결") }

    // MARK: - 더미 회원탈퇴 로직
    @objc private func didTapWithdraw() {
        let alert = UIAlertController(
            title: "회원탈퇴",
            message: "정말로 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "탈퇴", style: .destructive, handler: { _ in
            self.performDummyWithdrawal()
        }))
        present(alert, animated: true)
    }

    private func performDummyWithdrawal() {
        // 1. 탈퇴 처리 중 로딩 시뮬레이션
        let loading = UIAlertController(title: nil, message: "탈퇴 처리 중...", preferredStyle: .alert)
        present(loading, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            loading.dismiss(animated: true) {
                // 2. 로컬 데이터 초기화 시뮬레이션
                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                UserDefaults.standard.synchronize()

                // 3. 완료 메시지
                let success = UIAlertController(
                    title: "탈퇴 완료",
                    message: "회원탈퇴가 완료되었습니다.",
                    preferredStyle: .alert
                )
                success.addAction(UIAlertAction(title: "확인", style: .default, handler: { _ in
                    // 로그인 화면으로 이동 (root 변경)
                    let signUpVC = SignUpViewController()
                    let nav = UINavigationController(rootViewController: signUpVC)
                    nav.modalPresentationStyle = .fullScreen

                    // ✅ 최신 방식: UIWindowScene → window 접근
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = scene.windows.first {
                        window.rootViewController = nav
                        window.makeKeyAndVisible()
                    } else {
                        // 혹시 모를 예외 (Scene 미사용 시)
                        self.present(nav, animated: true)
                    }
                }))
                self.present(success, animated: true)
            }
        }
    }

    private func toast(_ message: String) {
        let ac = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(ac, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { ac.dismiss(animated: true) }
    }
}
