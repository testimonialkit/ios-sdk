import SwiftUI

extension UIViewController {
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
