//
//  MyPageViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import SnapKit
import RxSwift
import Kingfisher
import Alamofire
import PhotosUI

final class MyPageViewController: UIViewController {

    // MARK: - API Models
    private struct APIUser: Decodable {
        let userId: Int64
        let nickname: String
        let profileImageUrl: String
    }
    private struct UpdateNicknameResponse: Decodable {
        let userId: Int64
        let newNickname: String
    }
    private let disposeBag = DisposeBag()

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
    
    private let cameraButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = .systemBackground
        b.tintColor = .label
        b.layer.cornerRadius = 18
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.12
        b.layer.shadowRadius = 4
        b.layer.shadowOffset = CGSize(width: 0, height: 2)
        let image = UIImage(systemName: "camera.fill")
        b.setImage(image, for: .normal)
        b.imageView?.contentMode = .scaleAspectFit
        b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        return b
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
        fetchUser()
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
        avatarView.layer.cornerRadius = 60

        // Camera button overlay on avatar
        contentView.addSubview(cameraButton)
        cameraButton.snp.makeConstraints { make in
            make.width.height.equalTo(36)
            make.trailing.equalTo(avatarView.snp.trailing).offset(6)
            make.bottom.equalTo(avatarView.snp.bottom).offset(6)
        }
        
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

    // MARK: - Networking
    private func fetchUser() {
        NetworkManager.shared
            .request("/api/v1/user", method: .get, parameters: nil, requiresAuth: true)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] (user: APIUser) in
                self?.updateUI(with: user)
            }, onFailure: { [weak self] error in
                self?.toast("사용자 정보 조회 실패: \(error.localizedDescription)")
            })
            .disposed(by: disposeBag)
    }

    private func updateUI(with user: APIUser) {
        // 닉네임 업데이트
        self.nicknameLabel.text = user.nickname

        // 프로필 이미지 로드 (Kingfisher 사용)
        if let url = URL(string: user.profileImageUrl) {
            let placeholder = UIImage(systemName: "person.circle")?.withRenderingMode(.alwaysTemplate)
            self.avatarView.tintColor = .systemBlue
            self.avatarView.kf.setImage(with: url, placeholder: placeholder)
        }
    }

    private func updateNickname(_ newName: String, completion: @escaping (Bool) -> Void) {
        NetworkManager.shared
            .request("/api/v1/user/nickname", method: .patch, parameters: ["nickname": newName], requiresAuth: true)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] (res: UpdateNicknameResponse) in
                guard let self = self else { return }
                self.nicknameLabel.text = res.newNickname
                let ac = UIAlertController(title: "완료", message: "닉네임이 변경되었습니다.", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "확인", style: .default))
                self.present(ac, animated: true)
                completion(true)
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                var message = "닉네임 변경에 실패했습니다. 잠시 후 다시 시도해주세요."
                if let afError = error as? AFError, case let .responseValidationFailed(reason) = afError {
                    switch reason {
                    case .unacceptableStatusCode(let code):
                        if code == 409 { message = "이미 사용 중인 닉네임입니다." }
                    default: break
                    }
                }
                if let data = (error as NSError).userInfo["com.alamofire.serialization.response.error.data"] as? Data,
                   let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let code = obj["code"] as? String, code.uppercased().contains("DUPLICATE") {
                        message = "이미 사용 중인 닉네임입니다."
                    } else if let msg = obj["message"] as? String, !msg.isEmpty {
                        message = msg
                    }
                }
                let ac = UIAlertController(title: "변경 실패", message: message, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "확인", style: .default))
                self.present(ac, animated: true)
                completion(false)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Actions
    private func bindActions() {
        editButton.addTarget(self, action: #selector(didTapEditNickname), for: .touchUpInside)
        policyButton.addTarget(self, action: #selector(openPolicy), for: .touchUpInside)
        termsButton.addTarget(self, action: #selector(openTerms), for: .touchUpInside)
        ossButton.addTarget(self, action: #selector(openOSS), for: .touchUpInside)
        withdrawButton.addTarget(self, action: #selector(didTapWithdraw), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(didTapChangeAvatar), for: .touchUpInside)
    }

    @objc private func didTapEditNickname() {
        let vc = EditNicknameViewController(currentNickname: self.nicknameLabel.text) { [weak self] newName, completion in
            self?.updateNickname(newName) { success in
                completion(success)
            }
        }
        present(vc, animated: true)
    }

    @objc private func openPolicy() { toast("개인정보 처리방침 화면으로 연결") }
    @objc private func openTerms() { toast("서비스 이용약관 화면으로 연결") }
    @objc private func openOSS() { toast("오픈소스 라이선스 화면으로 연결") }
    
    // MARK: - Avatar change
    @objc private func didTapChangeAvatar() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func applySelectedAvatar(_ image: UIImage) {
        // Update avatar view with the selected image
        self.avatarView.image = image
        self.avatarView.contentMode = .scaleAspectFill
        self.avatarView.tintColor = nil
        self.avatarView.backgroundColor = UIColor.systemGray5.withAlphaComponent(0.0)
        // TODO: Upload API integration will be added later
    }

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

                    // 최신 방식: UIWindowScene → window 접근
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

extension MyPageViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let itemProvider = results.first?.itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let self = self, let image = object as? UIImage, error == nil else { return }
            DispatchQueue.main.async {
                self.applySelectedAvatar(image)
            }
        }
    }
}

