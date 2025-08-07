import UIKit

class PromptViewController: UIViewController {
  private let promptText: String

  init(promptText: String) {
    self.promptText = promptText
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .formSheet
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    let label = UILabel()
    label.text = promptText
    label.textAlignment = .center
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
    ])
  }
}

protocol PromptViewControllerDelegate: AnyObject {
  func promptDidDismiss()
  func didSubmitFeedback(rating: Int, comment: String?)
}
