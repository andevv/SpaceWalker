//
//  SignUpViewController.swift
//  SpaceWalker
//
//  Created by andev on 9/29/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import AuthenticationServices

class SignUpViewController: UIViewController {

    // MARK: - UI Components
    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        // Replace "AppLogo" with your actual asset name
        iv.image = UIImage(named: "AppLogo")
        return iv
    }()

    private let googleButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Google로 계속하기", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = .white
        btn.setTitleColor(.black, for: .normal)
        btn.layer.cornerRadius = 12
        btn.layer.masksToBounds = true
        btn.layer.borderColor = UIColor.separator.cgColor
        btn.layer.borderWidth = 1
        // TODO: Add Google logo image to the left if asset is available
        return btn
    }()

    private let appleButton: ASAuthorizationAppleIDButton = {
        let btn = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        btn.cornerRadius = 12
        return btn
    }()

    private let bottomTextView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.textAlignment = .center
        tv.backgroundColor = .clear
        tv.textColor = .secondaryLabel
        tv.font = .systemFont(ofSize: 13)
        tv.text = "회원가입을 진행하면 서비스 이용약관 및 개인정보 처리방침에 동의한 것으로 간주됩니다."
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        return tv
    }()
    
    private let signupTextButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("계정이 없으신가요? 회원가입", for: .normal)
        btn.setTitleColor(.secondaryLabel, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14)
        btn.contentHorizontalAlignment = .center
        return btn
    }()

    // MARK: - MVVM
    private let viewModel = SignUpViewModel()
    private let disposeBag = DisposeBag()

    // MARK: - Setup
    private func setupViews() {
        view.backgroundColor = .systemBackground
        view.addSubview(logoImageView)
        view.addSubview(googleButton)
        view.addSubview(appleButton)
        view.addSubview(signupTextButton)
        view.addSubview(bottomTextView)
    }

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide

        logoImageView.snp.makeConstraints { make in
            make.top.equalTo(safe).offset(80)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(120)
        }

        googleButton.snp.makeConstraints { make in
            make.top.equalTo(logoImageView.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(52)
        }

        appleButton.snp.makeConstraints { make in
            make.top.equalTo(googleButton.snp.bottom).offset(12)
            make.leading.trailing.equalTo(googleButton)
            make.height.equalTo(52)
        }
        
        signupTextButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(bottomTextView.snp.top).offset(-12)
            make.height.equalTo(24)
        }

        bottomTextView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(safe).inset(12)
        }
    }

    private func bindViewModel() {
        let input = SignUpViewModel.Input(
            googleTap: googleButton.rx.tap.asObservable(),
            appleTap: appleButton.rx.controlEvent(.touchUpInside).asObservable(),
            signupTap: signupTextButton.rx.tap.asObservable()
        )

        let output = viewModel.transform(input: input)

        output.showGoogleLogin
            .emit(onNext: { [weak self] in
                // TODO: Trigger Google OAuth flow
                print("Google OAuth 시작")
            })
            .disposed(by: disposeBag)

        output.showAppleLogin
            .emit(onNext: { [weak self] in
                // TODO: Trigger Apple OAuth flow
                print("Apple OAuth 시작")
            })
            .disposed(by: disposeBag)

        output.showSignUp
            .emit(onNext: { [weak self] in
                // TODO: Navigate to sign up flow
                print("회원가입 플로우로 이동")
            })
            .disposed(by: disposeBag)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupConstraints()
        bindViewModel()
    }
}
