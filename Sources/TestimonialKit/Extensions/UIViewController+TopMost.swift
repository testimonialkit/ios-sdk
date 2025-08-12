import SwiftUI

/// An extension on `UIViewController` that provides a utility to retrieve the top-most view controller.
extension UIViewController {
  /// The top-most view controller currently being displayed in the application.
  ///
  /// This property traverses the view controller hierarchy starting from the root view controller
  /// of the application's key window and follows any presented view controllers until it reaches the top.
  ///
  /// - Returns: The top-most `UIViewController` instance if available, otherwise `nil`.
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
