//
//  SignUpViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/29/25.
//

import UIKit
import SafariServices
import SnapKit
import AuthenticationServices
import CryptoKit
import RxSwift
import RxCocoa

final class SignUpViewController: UIViewController {

    // MARK: - Links
    private let termsURLString = "https://an-dev.notion.site/SpaceWalker-289b268a2bd5807591d3feff91059098"
    private let privacyURLString = "https://an-dev.notion.site/SpaceWalker-27eb268a2bd58000865cfb9620685592"

    // MARK: - ViewModel
    private let viewModel = SignUpViewModel()
    private let disposeBag = DisposeBag()
    private let appleLoginSuccessRelay = PublishRelay<SignUpAppleLoginPayload>()
    private let appleLoginFailureRelay = PublishRelay<String>()

    // MARK: - UI Components
    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "Logo_Wordmark3"))
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.tintColor = .label
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let appleButton: ASAuthorizationAppleIDButton = {
        let btn = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
        btn.cornerRadius = 12
        return btn
    }()

    private let linksStack = UIStackView()
    private let termsButton = UIButton(type: .system)
    private let privacyButton = UIButton(type: .system)
    private let dotLabel: UILabel = {
        let lb = UILabel()
        lb.text = " · "
        lb.textColor = .systemGray
        lb.textAlignment = .center
        lb.font = .systemFont(ofSize: 14, weight: .regular)
        return lb
    }()

    private let bottomTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textAlignment = .center
        tv.backgroundColor = .clear
        tv.textColor = .systemGray
        tv.font = .systemFont(ofSize: 10)
        tv.text = "로그인을 진행하면 서비스 이용약관 및 개인정보 처리방침에 동의한 것으로 간주됩니다."
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        return tv
    }()

    // MARK: - Apple Sign In Properties
    private var currentNonce: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 1.0/255.0, alpha: 1.0)
        setupLayout()
        setupLinks()
        bindViewModel()
        appleButton.addTarget(self, action: #selector(startAppleLogin), for: .touchUpInside)
    }

    private func bindViewModel() {
        let input = SignUpViewModel.Input(
            appleLoginSuccess: appleLoginSuccessRelay.asObservable(),
            appleLoginFailure: appleLoginFailureRelay.asObservable()
        )

        let output = viewModel.transform(input: input)

        output.route
            .emit(onNext: { [weak self] route in
                self?.routeToNext(route)
            })
            .disposed(by: disposeBag)

        output.alertMessage
            .emit(onNext: { [weak self] message in
                self?.showLoginFailAlert(message: message)
            })
            .disposed(by: disposeBag)

        output.isLoading
            .drive(onNext: { [weak self] isLoading in
                self?.appleButton.isEnabled = !isLoading
                self?.appleButton.alpha = isLoading ? 0.7 : 1.0
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(logoImageView)
        view.addSubview(appleButton)
        view.addSubview(linksStack)
        view.addSubview(bottomTextView)

        logoImageView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(100)
            make.centerX.equalToSuperview()
            make.width.equalTo(appleButton)
            make.height.equalTo(150)
        }

        appleButton.snp.makeConstraints { make in
            make.top.equalTo(logoImageView.snp.bottom).offset(60)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(52)
        }

        bottomTextView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
        }

        linksStack.snp.makeConstraints { make in
            make.bottom.equalTo(bottomTextView.snp.top).offset(-16)
            make.centerX.equalToSuperview()
        }
    }

    private func setupLinks() {
        linksStack.axis = .horizontal
        linksStack.spacing = 8
        linksStack.alignment = .firstBaseline
        linksStack.distribution = .equalCentering

        func styleLinkButton(_ b: UIButton, title: String) {
            var config = UIButton.Configuration.plain()
            config.title = title
            config.baseForegroundColor = .systemGray
            config.contentInsets = .zero
            b.configuration = config
            b.titleLabel?.font = .systemFont(ofSize: 12, weight: .regular)

            let attr = NSAttributedString(
                string: title,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: UIColor.systemGray,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            )
            b.setAttributedTitle(attr, for: .normal)
        }

        styleLinkButton(termsButton, title: "서비스 이용약관")
        styleLinkButton(privacyButton, title: "개인정보 처리방침")

        termsButton.addTarget(self, action: #selector(openTerms), for: .touchUpInside)
        privacyButton.addTarget(self, action: #selector(openPrivacy), for: .touchUpInside)

        dotLabel.setContentHuggingPriority(.required, for: .horizontal)
        dotLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        linksStack.addArrangedSubview(termsButton)
        linksStack.addArrangedSubview(dotLabel)
        linksStack.addArrangedSubview(privacyButton)
    }

    // MARK: - Apple Login Flow
    @objc private func startAppleLogin() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = []
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Terms / Privacy
    @objc private func openTerms() {
        guard let url = URL(string: termsURLString) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    @objc private func openPrivacy() {
        guard let url = URL(string: privacyURLString) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    // MARK: - Nonce Helpers
    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms = (0 ..< 16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random) % charset.count])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func routeToNext(_ route: SignUpRoute) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let delegate = scene.delegate as? SceneDelegate,
              let window = delegate.window else { return }

        let nextVC: UIViewController
        switch route {
        case .spaceSelect:
            nextVC = SpaceSelectViewController()
        case .mainTab:
            nextVC = MainTabBarController()
        }

        UIView.transition(
            with: window,
            duration: 0.4,
            options: .transitionCrossDissolve,
            animations: {
                window.rootViewController = nextVC
            },
            completion: nil
        )
    }

    private func showLoginFailAlert(message: String) {
        let alert = UIAlertController(
            title: "로그인 실패",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension SignUpViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            LogAuth("ID Token 없음")
            appleLoginFailureRelay.accept("ID Token을 가져오지 못했습니다.")
            return
        }

        guard let authCodeData = credential.authorizationCode,
              let authCode = String(data: authCodeData, encoding: .utf8) else {
            LogAuth("Authorization Code 없음")
            appleLoginFailureRelay.accept("Authorization Code를 가져오지 못했습니다.")
            return
        }

        let userIdentifier = credential.user
        UserDefaults.standard.set(userIdentifier, forKey: "apple_user_id")
        LogAuth("Apple 로그인 성공")
        LogAuth("userIdentifier: \(userIdentifier)")
        LogAuth("idToken (JWT): \(idToken)")
        LogAuth("authCode (raw): \(authCode)")

        appleLoginSuccessRelay.accept(
            SignUpAppleLoginPayload(userIdentifier: userIdentifier, idToken: idToken, authCode: authCode)
        )
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        LogAuth("Apple 로그인 실패: \(error.localizedDescription)")
        appleLoginFailureRelay.accept(error.localizedDescription)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension SignUpViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window!
    }
}
