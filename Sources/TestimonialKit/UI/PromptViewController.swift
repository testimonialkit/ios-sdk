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

#if canImport(UIKit)
import UIKit

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
#endif

#if canImport(AppKit)
import AppKit

@MainActor
/// A `NSHostingController` wrapper that presents SwiftUI content in a macOS sheet sized
/// to the content’s intrinsic height at the current window width. The controller forwards
/// appear/disappear events to a delegate.
class PromptViewController<Content: View>: NSHostingController<Content> {
  /// Receiver of appear/disappear callbacks for this prompt controller.
  weak var delegate: PromptViewControllerDelegate?

  /// Tracks the most recently applied preferred content size to avoid resize loops.
  private var lastAppliedSize: CGSize = .zero
  /// Guard to prevent re-entrant sizing during a layout pass.
  private var isApplyingSize: Bool = false
  /// Coalesces pending size applications to avoid rapid re-entrant layout.
  private var pendingSizeWork: DispatchWorkItem?
  /// Observer token for window resize notifications.
  private var resizeObserver: NSObjectProtocol?

  /// Updates the preferred content size to match the SwiftUI view’s fitting size at the
  /// current window width. Debounces and guards against re-entrant layout to avoid
  /// “needs another Update Constraints in Window pass” loops.
  private func updatePreferredSize() {
    // If we're mid-application, let the pending work finish first
    if isApplyingSize { return }

    // Ensure layout is up-to-date to get a correct fitting size.
    view.layoutSubtreeIfNeeded()

    let insets = view.safeAreaInsets
    let measuredViewWidth = self.view.bounds.width - (insets.left + insets.right)
    // Use a fallback width if no reasonable width is available yet
    let fallbackWidth: CGFloat = 400
    let width = measuredViewWidth > 0 ? measuredViewWidth : (view.window?.contentLayoutRect.width ?? max(view.bounds.width, fallbackWidth))

    // Ask the hosting controller to size the SwiftUI content at this width
    let fitting = CGSize(width: width, height: .greatestFiniteMagnitude)
    let measuredHeight = self.sizeThatFits(in: fitting).height

    // Ask SwiftUI for its fitting size at this width.
    var size = view.fittingSize
    size.width = max(width, size.width) // Respect the content's fitting width if larger
    size.height = measuredHeight
    if !size.height.isFinite || size.height <= 0 { size.height = 200 }

    // If the size hasn't changed meaningfully, bail early.
    let epsilon: CGFloat = 0.5
    let approximatelyEqual = { (a: CGSize, b: CGSize) -> Bool in
      abs(a.width - b.width) < epsilon && abs(a.height - b.height) < epsilon
    }
    if approximatelyEqual(size, lastAppliedSize) { return }

    // Coalesce updates onto the next runloop tick and avoid resizing during layout.
    isApplyingSize = true
    pendingSizeWork?.cancel()

//    let work = DispatchWorkItem { [weak self] in
//      guard let self = self else { return }
//      if let window = self.view.window {
//        let currentContentRect = window.contentRect(forFrameRect: window.frame)
//        var newContentRect = currentContentRect
//        newContentRect.size = size
//        let newFrame = window.frameRect(forContentRect: newContentRect)
//        window.setFrame(newFrame, display: true, animate: true)
//      } else {
//        self.preferredContentSize = size
//      }
//      self.lastAppliedSize = size
//      self.isApplyingSize = false
//    }

//    pendingSizeWork = work
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if let window = self.view.window {
        let currentContentRect = window.contentRect(forFrameRect: window.frame)
        var newContentRect = currentContentRect
        newContentRect.size = size
        let newFrame = window.frameRect(forContentRect: newContentRect)
        window.setFrame(newFrame, display: true, animate: true)
      } else {
        self.preferredContentSize = size
      }
      self.lastAppliedSize = size
      self.isApplyingSize = false
    }
  }

  /// Coalesces size updates to avoid rapid re-entrant layout while the window is resizing.
  private func scheduleSizeUpdate(after delay: TimeInterval = 0.06) {
    pendingSizeWork?.cancel()
    let work = DispatchWorkItem { [weak self] in
      self?.updatePreferredSize()
    }
    pendingSizeWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    updatePreferredSize()
  }

  override func viewDidAppear() {
    super.viewDidAppear()

    // Register for window resize events to update the preferred size after the resize settles.
    if let window = view.window {
      resizeObserver = NotificationCenter.default.addObserver(
        forName: NSWindow.didResizeNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        // While resizing, avoid tight loops; coalesce updates slightly.
        Task { @MainActor in
          self?.scheduleSizeUpdate(after: 0.08)
        }
      }
    }

    // Initial sizing once visible
    scheduleSizeUpdate(after: 0.0)

    delegate?.promptViewControllerDidAppear()
  }

  override func viewWillDisappear() {
    super.viewWillDisappear()
    if let token = resizeObserver {
      NotificationCenter.default.removeObserver(token)
      resizeObserver = nil
    }
    pendingSizeWork?.cancel()
  }

  override func viewDidDisappear() {
    super.viewDidDisappear()
    delegate?.promptViewControllerDidDisappear()
  }
}
#endif
