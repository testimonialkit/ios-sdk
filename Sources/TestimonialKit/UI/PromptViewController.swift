import SwiftUI

/// Delegate for `PromptViewController` lifecycle notifications.
///
/// Notifies when the hosting controller's view appears or disappears,
/// allowing the presenter to react (e.g., start/stop analytics or timers).
@MainActor
protocol PromptViewControllerDelegate: AnyObject {
  /// Called after the prompt sheet becomes visible on screen.
  func promptViewControllerDidAppear()
  /// Called after the prompt sheet is dismissed or otherwise removed from screen.
  func promptViewControllerDidDisappear()
}

/// A `UIHostingController` wrapper that presents SwiftUI content in a sheet with a dynamic detent
/// sized to the content's intrinsic height at the current width.
///
/// On iOS 16 and later it uses a custom `UISheetPresentationController.Detent` that measures the
/// SwiftUI view using `sizeThatFits(in:)`. On iOS 15 it falls back to `.large()`.
/// The controller also forwards basic appear/disappear events to a delegate.
class PromptViewController<Content: View>: UIHostingController<Content> {
  /// Receiver of appear/disappear callbacks for this prompt controller.
  weak var delegate: PromptViewControllerDelegate?

  /// Configures the sheet presentation. On iOS 16+ a custom detent is created that measures the
  /// SwiftUI content height at runtime and clamps it to the system's maximum allowed value.
  /// On iOS 15 the controller falls back to a large detent.
  override func viewDidLoad() {
    super.viewDidLoad()

    guard let sheet = presentationController as? UISheetPresentationController else { return }

    if #available(iOS 16.0, *) {
      /// Create a custom detent that queries the hosting controller for the SwiftUI content height.
      let contentDetent = UISheetPresentationController.Detent.custom(
        identifier: UISheetPresentationController.Detent.Identifier("contentHeight")
      ) { [weak self] context in
        guard let self = self else { return 0 }

        /// Measure the SwiftUI view at the effective width and return its intrinsic height.
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

      /// Apply the custom detent and configure sheet behavior (grabber, scrolling).
      sheet.detents = [contentDetent]
      sheet.selectedDetentIdentifier = contentDetent.identifier
      sheet.prefersGrabberVisible = true
      sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    } else {
      /// iOS 15 fallback: custom detents are unavailable; present as a large sheet.
      sheet.detents = [.large()]
    }
  }

  /// Keeps the detent height in sync when layout or safe-area insets change by invalidating
  /// detents on iOS 16 and later.
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if #available(iOS 16.0, *),
       let sheet = presentationController as? UISheetPresentationController {
      sheet.invalidateDetents()
    }
  }

  /// Handles rotation and size-class changes by invalidating the sheet detents after the transition.
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

  /// Forwards the appearance event to the delegate.
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    delegate?.promptViewControllerDidAppear()
  }

  /// Forwards the disappearance event to the delegate.
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    delegate?.promptViewControllerDidDisappear()
  }
}
