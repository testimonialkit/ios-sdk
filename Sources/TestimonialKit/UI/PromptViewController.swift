import SwiftUI

@MainActor
protocol PromptViewControllerDelegate: AnyObject {
  func promptViewControllerDidAppear()
  func promptViewControllerDidDisappear()
}

class PromptViewController<Content: View>: UIHostingController<Content> {
  weak var delegate: PromptViewControllerDelegate?

  override func viewDidLoad() {
    super.viewDidLoad()

    guard let sheet = presentationController as? UISheetPresentationController else { return }

    if #available(iOS 16.0, *) {
      let contentDetent = UISheetPresentationController.Detent.custom(
        identifier: UISheetPresentationController.Detent.Identifier("contentHeight")
      ) { [weak self] context in
        guard let self = self else { return 0 }

        // Determine the width to measure against:
        // - Prefer current view width minus safe area insets
        // - Fallback to the screen width if the view hasn't laid out yet
        let insets = self.view.safeAreaInsets
        let measuredViewWidth = self.view.bounds.width - (insets.left + insets.right)
        let width = measuredViewWidth > 0 ? measuredViewWidth : UIScreen.main.bounds.width

        // Ask the hosting controller to size the SwiftUI content at this width
        let fitting = CGSize(width: width, height: .greatestFiniteMagnitude)
        let measuredHeight = self.sizeThatFits(in: fitting).height

        // Clamp to system-allowed maximum
        return min(max(0, measuredHeight), context.maximumDetentValue)
      }

      sheet.detents = [contentDetent]
      sheet.selectedDetentIdentifier = contentDetent.identifier
      sheet.prefersGrabberVisible = true
      sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    } else {
      // iOS 15 fallback: custom detents are unavailable.
      sheet.detents = [.large()]
    }
  }

  // Keep the detent in sync when layout/safe areas/content change.
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if #available(iOS 16.0, *),
       let sheet = presentationController as? UISheetPresentationController {
      sheet.invalidateDetents()
    }
  }

  // Handle rotations/size changes without rebuilding the detents.
  override func viewWillTransition(to size: CGSize,
                                   with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    coordinator.animate(alongsideTransition: nil) { [weak self] _ in
      if #available(iOS 16.0, *),
         let sheet = self?.presentationController as? UISheetPresentationController {
        sheet.invalidateDetents()
      }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    delegate?.promptViewControllerDidAppear()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    delegate?.promptViewControllerDidDisappear()
  }
}
