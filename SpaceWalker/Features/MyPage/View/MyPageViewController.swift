//
//  MyPageViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/30/25.
//

import UIKit
import SafariServices
import SnapKit
import Kingfisher
import PhotosUI
import RxSwift
import RxCocoa
import UniformTypeIdentifiers

final class MyPageViewController: UIViewController {

    // MARK: - Links
    private let termsURLString = "https://an-dev.notion.site/SpaceWalker-289b268a2bd5807591d3feff91059098"
    private let privacyURLString = "https://an-dev.notion.site/SpaceWalker-27eb268a2bd58000865cfb9620685592"
    private let ossURLString = "https://an-dev.notion.site/SpaceWalker-289b268a2bd580ff856fe5f5992fa2fe"

    private let viewModel = MyPageViewModel()
    private let disposeBag = DisposeBag()

    private let viewDidLoadSubject = PublishSubject<Void>()
    private let nicknameUpdateSubject = PublishSubject<String>()
    private let avatarUploadSubject = PublishSubject<MyPageAvatarUploadRequest>()
    private let withdrawalTapSubject = PublishSubject<Void>()
    private let exportLocationMetadataTapSubject = PublishSubject<Void>()
    private let importLocationMetadataURLSubject = PublishSubject<URL>()

    private var pendingNicknameCompletion: ((Bool) -> Void)?
    private var withdrawalLoadingAlert: UIAlertController?

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

    private let settingsTitle: UILabel = {
        let lb = UILabel()
        lb.text = "설정"
        lb.font = .systemFont(ofSize: 17, weight: .semibold)
        lb.textColor = .label
        return lb
    }()
    private lazy var policyButton = makeSettingButton(title: "개인정보 처리방침")
    private lazy var termsButton = makeSettingButton(title: "서비스 이용약관")
    private lazy var ossButton = makeSettingButton(title: "오픈소스 라이센스")
    private lazy var exportLocationButton = makeSettingButton(title: "위치 데이터 내보내기")
    private lazy var importLocationButton = makeSettingButton(title: "위치 데이터 가져오기")

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

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "MyPage"
        view.backgroundColor = .systemBackground
        setupLayout()
        bindActions()
        bindViewModel()
        viewDidLoadSubject.onNext(())
    }

    private func bindViewModel() {
        let input = MyPageViewModel.Input(
            viewDidLoad: viewDidLoadSubject.asObservable(),
            nicknameUpdate: nicknameUpdateSubject.asObservable(),
            avatarUpload: avatarUploadSubject.asObservable(),
            withdrawalTap: withdrawalTapSubject.asObservable(),
            exportLocationMetadataTap: exportLocationMetadataTapSubject.asObservable(),
            importLocationMetadataURL: importLocationMetadataURLSubject.asObservable()
        )

        let output = viewModel.transform(input: input)

        output.user
            .drive(onNext: { [weak self] user in
                self?.updateUI(with: user)
            })
            .disposed(by: disposeBag)

        output.toastMessage
            .emit(onNext: { [weak self] message in
                self?.toast(message)
            })
            .disposed(by: disposeBag)

        output.nicknameChange
            .emit(onNext: { [weak self] event in
                guard let self else { return }
                switch event {
                case .success(let newNickname):
                    self.nicknameLabel.text = newNickname
                    self.showAlert(title: "완료", message: "닉네임이 변경되었습니다.")
                    self.pendingNicknameCompletion?(true)
                case .failure(let message):
                    self.showAlert(title: "변경 실패", message: message)
                    self.pendingNicknameCompletion?(false)
                }
                self.pendingNicknameCompletion = nil
            })
            .disposed(by: disposeBag)

        output.avatarChange
            .emit(onNext: { [weak self] event in
                guard let self else { return }
                switch event {
                case .loading:
                    self.toast("프로필 이미지 업로드 중…")
                case .success(let image):
                    self.applySelectedAvatar(image)
                    self.showAlert(title: "완료", message: "프로필 이미지가 업데이트되었습니다.")
                case .failure(let message):
                    self.showAlert(title: "업로드 실패", message: message)
                }
            })
            .disposed(by: disposeBag)

        output.withdrawal
            .emit(onNext: { [weak self] event in
                guard let self else { return }
                switch event {
                case .started:
                    self.presentWithdrawalLoading()
                case .success:
                    self.dismissWithdrawalLoading { [weak self] in
                        self?.routeToSignUp()
                    }
                case .failure(let message):
                    self.dismissWithdrawalLoading { [weak self] in
                        self?.showAlert(title: "탈퇴 실패", message: message)
                    }
                }
            })
            .disposed(by: disposeBag)

        output.locationTransfer
            .emit(onNext: { [weak self] event in
                guard let self else { return }
                switch event {
                case .exportReady(let fileURL, let itemCount):
                    self.presentExportShareSheet(fileURL: fileURL, itemCount: itemCount)
                case .importCompleted(let result):
                    self.showImportSummary(result)
                case .failure(let message):
                    self.showAlert(title: "위치 데이터 처리 실패", message: message)
                }
            })
            .disposed(by: disposeBag)
    }

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

        contentView.addSubview(titleLabel)
        contentView.addSubview(avatarView)
        avatarView.layer.cornerRadius = 60

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

        contentView.addSubview(settingsTitle)
        settingsTitle.snp.makeConstraints { make in
            make.top.equalTo(nicknameCard.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        let settingsStack = UIStackView(arrangedSubviews: [
            policyButton,
            termsButton,
            ossButton,
            exportLocationButton,
            importLocationButton
        ])
        settingsStack.axis = .vertical
        settingsStack.spacing = 12
        contentView.addSubview(settingsStack)

        settingsStack.snp.makeConstraints { make in
            make.top.equalTo(settingsTitle.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(20)
        }

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

    private func bindActions() {
        editButton.addTarget(self, action: #selector(didTapEditNickname), for: .touchUpInside)
        policyButton.addTarget(self, action: #selector(openPolicy), for: .touchUpInside)
        termsButton.addTarget(self, action: #selector(openTerms), for: .touchUpInside)
        ossButton.addTarget(self, action: #selector(openOSS), for: .touchUpInside)
        exportLocationButton.addTarget(self, action: #selector(didTapExportLocationMetadata), for: .touchUpInside)
        importLocationButton.addTarget(self, action: #selector(didTapImportLocationMetadata), for: .touchUpInside)
        withdrawButton.addTarget(self, action: #selector(didTapWithdraw), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(didTapChangeAvatar), for: .touchUpInside)
    }

    private func updateUI(with user: APIUser) {
        nicknameLabel.text = user.nickname

        if let urlString = user.profileImageUrl, let url = URL(string: urlString) {
            let placeholder = UIImage(systemName: "person.circle")?.withRenderingMode(.alwaysTemplate)
            avatarView.tintColor = .systemBlue
            avatarView.kf.setImage(with: url, placeholder: placeholder)
        } else {
            avatarView.image = UIImage(systemName: "person.circle")?.withRenderingMode(.alwaysTemplate)
            avatarView.tintColor = .systemBlue
            avatarView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        }
    }

    @objc private func didTapEditNickname() {
        let vc = EditNicknameViewController(currentNickname: nicknameLabel.text) { [weak self] newName, completion in
            guard let self else {
                completion(false)
                return
            }
            self.pendingNicknameCompletion = completion
            self.nicknameUpdateSubject.onNext(newName)
        }
        present(vc, animated: true)
    }

    @objc private func openPolicy() {
        guard let url = URL(string: privacyURLString) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    @objc private func openTerms() {
        guard let url = URL(string: termsURLString) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    @objc private func openOSS() {
        guard let url = URL(string: ossURLString) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    @objc private func didTapChangeAvatar() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func applySelectedAvatar(_ image: UIImage) {
        avatarView.image = image
        avatarView.contentMode = .scaleAspectFill
        avatarView.tintColor = nil
        avatarView.backgroundColor = UIColor.systemGray5.withAlphaComponent(0.0)
    }

    @objc private func didTapWithdraw() {
        let alert = UIAlertController(
            title: "회원탈퇴",
            message: "정말로 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "탈퇴", style: .destructive, handler: { [weak self] _ in
            self?.withdrawalTapSubject.onNext(())
        }))
        present(alert, animated: true)
    }

    @objc private func didTapExportLocationMetadata() {
        exportLocationMetadataTapSubject.onNext(())
    }

    @objc private func didTapImportLocationMetadata() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .json], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func presentWithdrawalLoading() {
        guard withdrawalLoadingAlert == nil else { return }
        let loading = UIAlertController(title: nil, message: "탈퇴 처리 중...", preferredStyle: .alert)
        withdrawalLoadingAlert = loading
        present(loading, animated: true)
    }

    private func dismissWithdrawalLoading(completion: (() -> Void)? = nil) {
        guard let loading = withdrawalLoadingAlert else {
            completion?()
            return
        }
        loading.dismiss(animated: true) { [weak self] in
            self?.withdrawalLoadingAlert = nil
            completion?()
        }
    }

    private func routeToSignUp() {
        let signUpVC = SignUpViewController()
        let nav = UINavigationController(rootViewController: signUpVC)
        nav.modalPresentationStyle = .fullScreen

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve, animations: {
                window.rootViewController = nav
            }) { _ in
                window.makeKeyAndVisible()
            }
        } else {
            present(nav, animated: true)
        }
    }

    private func toast(_ message: String) {
        let ac = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(ac, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { ac.dismiss(animated: true) }
    }

    private func showAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "확인", style: .default))
        present(ac, animated: true)
    }

    private func presentExportShareSheet(fileURL: URL, itemCount: Int) {
        let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let pop = activity.popoverPresentationController {
            pop.sourceView = exportLocationButton
            pop.sourceRect = exportLocationButton.bounds
        }
        activity.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: fileURL)
        }
        present(activity, animated: true)
        toast("위치 메타데이터 \(itemCount)건을 내보낼 준비가 완료되었습니다.")
    }

    private func showImportSummary(_ result: LocationMetadataImportResult) {
        let message = """
        전체: \(result.totalCount)건
        신규 추가: \(result.insertedCount)건
        업데이트: \(result.updatedCount)건
        건너뜀: \(result.skippedCount)건
        """
        showAlert(title: "위치 데이터 가져오기 완료", message: message)
    }
}

extension MyPageViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }

        let provider = result.itemProvider
        let detected = viewModel.detectMimeType(from: provider)

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let self, let image = object as? UIImage, error == nil else { return }
            DispatchQueue.main.async {
                self.avatarUploadSubject.onNext(MyPageAvatarUploadRequest(image: image, preferredMime: detected))
            }
        }
    }
}

extension MyPageViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        importLocationMetadataURLSubject.onNext(url)
    }
}
