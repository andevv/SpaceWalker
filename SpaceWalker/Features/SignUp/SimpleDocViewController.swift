//
//  SimpleDocViewController.swift
//  SpaceWalker
//
//  Created by andev on 10/4/25.
//

import UIKit
import SnapKit

final class SimpleDocViewController: UIViewController {
    private let titleText: String
    private let bodyText: String

    private let titleLabel = UILabel()
    private let textView = UITextView()

    init(titleText: String, bodyText: String) {
        self.titleText = titleText
        self.bodyText = bodyText
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        view.addSubview(titleLabel)
        view.addSubview(textView)

        titleLabel.text = titleText
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center

        textView.isEditable = false
        textView.text = bodyText
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .label
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).inset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        textView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }
}
