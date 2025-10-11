import UIKit
import SnapKit
import RxSwift

final class EditNicknameViewController: UIViewController, UIGestureRecognizerDelegate {

    // MARK: - Public API
    init(currentNickname: String?, onSave: @escaping (String, @escaping (Bool) -> Void) -> Void) {
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
        self.textField.text = currentNickname
        self.updateAllValidationStates(for: currentNickname ?? "")
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
            sheet.selectedDetentIdentifier = .medium
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Callbacks
    private let onSave: (String, @escaping (Bool) -> Void) -> Void

    // MARK: - DisposeBag
    private let disposeBag = DisposeBag()

    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let titleLabel: UILabel = {
        let lb = UILabel()
        lb.text = "닉네임 변경"
        lb.font = .systemFont(ofSize: 20, weight: .bold)
        lb.textColor = .label
        return lb
    }()

    private let subtitleLabel: UILabel = {
        let lb = UILabel()
        lb.text = "다음 규칙을 따라 닉네임을 설정해주세요."
        lb.font = .systemFont(ofSize: 13, weight: .regular)
        lb.textColor = .secondaryLabel
        lb.numberOfLines = 0
        return lb
    }()

    private let textField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "새 닉네임"
        tf.borderStyle = .roundedRect
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.clearButtonMode = .whileEditing
        tf.returnKeyType = .done
        return tf
    }()

    private let countLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 12, weight: .regular)
        lb.textColor = .secondaryLabel
        lb.text = "0/20"
        lb.textAlignment = .right
        return lb
    }()

    // Rule rows
    private let lengthRule = RuleRow(text: "길이 2~20자")
    private let charsetRule = RuleRow(text: "영문/한글/숫자/특수문자(-, _)만 사용")
    private let noSpaceRule = RuleRow(text: "공백 금지")
    private let noEmojiRule = RuleRow(text: "이모지 금지")

    private let rulesStack = UIStackView()

    private let saveButton: UIButton = {
        var cfg = UIButton.Configuration.filled()
        cfg.title = "저장"
        cfg.cornerStyle = .large
        cfg.baseBackgroundColor = UIColor(named: "AccentColor_066985") ?? .systemBlue
        cfg.baseForegroundColor = .white
        let b = UIButton(configuration: cfg)
        b.isEnabled = false
        return b
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        bind()
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        tap.delegate = self
        scrollView.keyboardDismissMode = .interactive
        scrollView.delaysContentTouches = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let accent = UIColor(named: "AccentColor_066985") ?? .systemBlue
        navigationController?.navigationBar.tintColor = accent
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Expand to large to avoid detent change overlapping with keyboard presentation
        if let sheet = sheetPresentationController {
            sheet.animateChanges {
                sheet.selectedDetentIdentifier = .large
            }
        }
        // Give the text field focus slightly after layout settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.textField.becomeFirstResponder()
        }
    }

    private func setupLayout() {
        // Base scroll container
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }

        // Add subviews to contentView
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(textField)
        contentView.addSubview(countLabel)

        rulesStack.axis = .vertical
        rulesStack.spacing = 8
        [lengthRule, charsetRule, noSpaceRule, noEmojiRule].forEach { rulesStack.addArrangedSubview($0) }
        contentView.addSubview(rulesStack)

        contentView.addSubview(saveButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(contentView.safeAreaLayoutGuide).inset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        textField.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(44)
        }
        countLabel.snp.makeConstraints { make in
            make.top.equalTo(textField.snp.bottom).offset(6)
            make.trailing.equalTo(textField)
        }
        rulesStack.snp.makeConstraints { make in
            make.top.equalTo(countLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        saveButton.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(rulesStack.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(50)
            make.bottom.equalToSuperview().inset(20)
        }
    }

    private func bind() {
        // Text change handling
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        textField.addTarget(self, action: #selector(didEndOnExit), for: .editingDidEndOnExit)
        saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
    }

    @objc private func textChanged() {
        let text = textField.text ?? ""
        updateAllValidationStates(for: text)
    }

    @objc private func didEndOnExit() {
        if saveButton.isEnabled { didTapSave() }
    }

    @objc private func didTapSave() {
        let newName = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard validateAll(newName) else { return }
        setSaving(true)
        // 상위에서 API 호출을 수행하고 성공 여부를 completion으로 전달
        onSave(newName) { [weak self] success in
            guard let self = self else { return }
            self.setSaving(false)
            if success {
                let ac = UIAlertController(title: "완료", message: "닉네임이 변경되었습니다.", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "확인", style: .default, handler: { [weak self] _ in
                    self?.dismiss(animated: true)
                }))
                self.present(ac, animated: true)
            } else {
                let ac = UIAlertController(title: "변경 실패", message: "닉네임 변경에 실패했습니다. 잠시 후 다시 시도해주세요.", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "확인", style: .default))
                self.present(ac, animated: true)
            }
        }
    }

    private func setSaving(_ saving: Bool) {
        saveButton.isEnabled = !saving
        var cfg = saveButton.configuration ?? .filled()
        cfg.showsActivityIndicator = saving
        saveButton.configuration = cfg
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl { return false }
        if let v = touch.view, v.isDescendant(of: textField) { return false }
        return true
    }

    // MARK: - Validation
    private func updateAllValidationStates(for text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        countLabel.text = "\(trimmed.count)/20"
        lengthRule.isSatisfied = Self.validateLength(trimmed)
        noSpaceRule.isSatisfied = Self.validateNoSpace(trimmed)
        noEmojiRule.isSatisfied = Self.validateNoEmoji(trimmed)
        charsetRule.isSatisfied = Self.validateAllowedCharset(trimmed)
        saveButton.isEnabled = validateAll(trimmed)
    }

    private func validateAll(_ text: String) -> Bool {
        return Self.validateLength(text)
        && Self.validateNoSpace(text)
        && Self.validateNoEmoji(text)
        && Self.validateAllowedCharset(text)
    }

    private static func validateLength(_ text: String) -> Bool {
        return (2...20).contains(text.count)
    }

    private static func validateNoSpace(_ text: String) -> Bool {
        return !text.contains { $0.isWhitespace }
    }

    private static func validateNoEmoji(_ text: String) -> Bool {
        // Approximate emoji detection: any scalar with isEmoji and (presentation or modifier)
        for scalar in text.unicodeScalars {
            if scalar.properties.isEmoji && (scalar.properties.isEmojiPresentation || scalar.value >= 0x238d) {
                return false
            }
        }
        return true
    }

    private static func validateAllowedCharset(_ text: String) -> Bool {
        if text.isEmpty { return false }
        // Allowed: Letters (includes Korean), digits, '-' and '_'
        let allowed = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: "-_"))
        return text.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

// MARK: - Rule Row View
private final class RuleRow: UIView {
    private let iconView = UIImageView()
    private let label = UILabel()

    var isSatisfied: Bool = false {
        didSet { updateAppearance() }
    }

    init(text: String) {
        super.init(frame: .zero)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .secondaryLabel
        iconView.image = UIImage(systemName: "circle")
        iconView.snp.makeConstraints { $0.width.height.equalTo(16) }

        label.text = text
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateAppearance() {
        if isSatisfied {
            iconView.image = UIImage(systemName: "checkmark.circle.fill")
            iconView.tintColor = .systemGreen
            label.textColor = .label
        } else {
            iconView.image = UIImage(systemName: "circle")
            iconView.tintColor = .tertiaryLabel
            label.textColor = .secondaryLabel
        }
    }
}
