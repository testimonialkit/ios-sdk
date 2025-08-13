#if canImport(UIKit)
import UIKit

/// An extension on `UIViewController` that provides a utility to retrieve the top-most view controller (iOS).
extension UIViewController {
  /// The top-most view controller currently being displayed in the application.
  ///
  /// Traverses from the key window’s root view controller through any presented view controllers.
  static var topMost: UIViewController? {
    guard let keyWindow = UIApplication.shared.connectedScenes
      .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return nil }

    var top = keyWindow.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
#endif

#if canImport(AppKit)
import AppKit

/// An extension on `NSViewController` that provides a utility to retrieve the top-most view controller (macOS).
extension NSViewController {
  /// The top-most view controller currently being displayed in the application.
  ///
  /// Starts from the key or main window’s `contentViewController` and follows
  /// any presented controllers (sheets/popovers) and attached window sheets.
  ///
  /// - Returns: The top-most `NSViewController` if available, otherwise `nil`.
  static var topMost: NSViewController? {
    // Prefer keyWindow, then mainWindow, then any visible window
    let window = NSApp.keyWindow
      ?? NSApp.mainWindow
      ?? NSApplication.shared.windows.first(where: { $0.isVisible })

    guard let startVC = window?.contentViewController else { return nil }

    var topVC: NSViewController? = startVC
    var topWindow: NSWindow? = window

    while true {
      // 1) Follow presented view controllers (popover, sheet, custom presentations)
      if let presented = topVC?.presentedViewControllers?.last {
        topVC = presented
        continue
      }

      // 2) If the window has an attached sheet, follow it to its contentViewController
      if let sheet = topWindow?.attachedSheet, let sheetVC = sheet.contentViewController {
        topVC = sheetVC
        topWindow = sheet
        continue
      }

      // Nothing more to traverse
      break
    }

    return topVC
  }
}
#endif
