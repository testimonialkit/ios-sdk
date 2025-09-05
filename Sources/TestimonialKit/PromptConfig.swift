import SwiftUI
import SwiftThemeKit

/// Encapsulates all customizable configuration for the in-app feedback prompt.
/// Includes localized strings, component styles, and tint colors for both light and dark mode.
/// Conforms to `@unchecked Sendable` for use across concurrency domains.
public struct PromptConfig: @unchecked Sendable {
  /// A default `PromptConfig` instance with stock strings, styles, and colors.
  public static let defaultConfig: PromptConfig = .init()

  /// Localized strings shown during the comment step.
  var commentStrings: CommentStrings
  /// Localized strings for the App Store review prompt step.
  var storeReviewStrings: StoreReviewStrings
  /// Localized strings for the final thank-you screen.
  var thankYouStrings: ThankYouStrings
  /// Visual style configuration for the comment text field.
  var commentField: PromptConfig.TextField
  /// Visual style configuration for the submit button.
  var submitButton: PromptConfig.Button
  /// Primary accent color for the prompt in light mode.
  var tintColor: Color
  /// Primary accent color for the prompt in dark mode.
  var tintColorDark: Color

  /// Creates a `PromptConfig` with optional overrides for any subset of its configuration values.
  /// - Parameters:
  ///   - ratingStrings: Strings for the rating step.
  ///   - commentStrings: Strings for the comment step.
  ///   - storeReviewStrings: Strings for the store review step.
  ///   - thankYouStrings: Strings for the thank-you step.
  ///   - submitButton: Style for the submit button.
  ///   - commentField: Style for the comment text field.
  ///   - tintColor: Accent color for light mode.
  ///   - tintColorDark: Accent color for dark mode.
  public init(
    commentStrings: CommentStrings = .init(),
    storeReviewStrings: StoreReviewStrings = .init(),
    thankYouStrings: ThankYouStrings = .init(),
    submitButton: PromptConfig.Button = .init(),
    commentField: PromptConfig.TextField = .init(),
    tintColor: Color = .blue,
    tintColorDark: Color = .blue
  ) {
    self.commentStrings = commentStrings
    self.storeReviewStrings = storeReviewStrings
    self.thankYouStrings = thankYouStrings
    self.commentField = commentField
    self.submitButton = submitButton
    self.tintColor = tintColor
    self.tintColorDark = tintColorDark
  }

  /// Returns a copy of this configuration with selectively overridden values.
  /// - Parameters: Same as the stored properties to override.
  /// - Returns: A new `PromptConfig` with updated fields.
  public func copy(
    commentStrings: CommentStrings? = nil,
    submitButton: PromptConfig.Button? = nil,
    commentField: PromptConfig.TextField? = nil,
    tintColor: Color? = nil,
    tintColorDark: Color? = nil
  ) -> PromptConfig {
    return PromptConfig(
      commentStrings: commentStrings ?? self.commentStrings,
      submitButton: submitButton ?? self.submitButton,
      commentField: commentField ?? self.commentField,
      tintColor: tintColor ?? self.tintColor,
      tintColorDark: tintColorDark ?? self.tintColorDark
    )
  }

  /// Configuration for the comment text field's shape, variant, and size.
  public struct TextField {
    /// Shape of the text field (e.g., rounded).
    var shape: TextFieldShape
    /// Visual variant of the text field (e.g., outlined, filled).
    var variant: TextFieldVariant
    /// Size preset for the text field.
    var size: TextFieldSize

    /// Creates a `TextField` style configuration.
    /// - Parameters: Shape, variant, and size to use.
    public init(
      shape: TextFieldShape = .rounded,
      variant: TextFieldVariant = .outlined,
      size: TextFieldSize = .medium
    ) {
      self.shape = shape
      self.variant = variant
      self.size = size
    }
  }

  /// Configuration for the prompt's submit button shape, variant, and size.
  public struct Button {
    /// Shape of the button.
    var shape: ButtonShape
    /// Visual variant of the button (e.g., filled, outlined).
    var variant: ButtonVariant
    /// Size preset for the button.
    var size: ButtonSize
    /// Primary button foreground color in light mode
    var foregroundColor: Color = .white
    /// Primary button foreground color in dark mode
    var foregroundColorDark: Color = .white

    /// Creates a `Button` style configuration.
    /// - Parameters: Shape, variant, size and foreground colors to use.
    public init(
      shape: ButtonShape = .rounded,
      variant: ButtonVariant = .filled,
      size: ButtonSize = .custom(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16), .body),
      foregroundColor: Color = .white,
      foregroundColorDark: Color = .white
    ) {
      self.shape = shape
      self.variant = variant
      self.size = size
      self.foregroundColor = foregroundColor
      self.foregroundColorDark = foregroundColorDark
    }
  }

  /// Localized strings for the comment step of the prompt.
  public struct CommentStrings {
    /// Main title for the comment step.
    var title: String
    /// Subtitle text displayed below the title.
    var subtitle: String
    /// Placeholder text shown in the comment input field.
    var placeholder: String
    /// Title for the submit button in the comment step.
    var submitButtonTitle: String
    /// Title for the cancel button in the comment step.
    var cancelButtonTitle: String

    /// Creates `CommentStrings` with optional custom values.
    /// - Parameters: Titles, subtitles, placeholders, and button titles.
    public init(
      title: String = "Got a moment to share your thoughts?",
      subtitle: String = "We read every message and truly value your input.",
      placeholder: String = "What could we improve or fix?",
      submitButtonTitle: String = "Send Feedback",
      cancelButtonTitle: String = "Skip for now"
    ) {
      self.title = title
      self.subtitle = subtitle
      self.placeholder = placeholder
      self.submitButtonTitle = submitButtonTitle
      self.cancelButtonTitle = cancelButtonTitle
    }
  }

  /// Localized strings for the App Store review prompt step.
  public struct StoreReviewStrings {
    /// Title for the store review prompt.
    var title: String
    /// Message encouraging the user to review in the App Store.
    var message: String
    /// Title for the submit button in the store review step.
    var submitButtonTitle: String
    /// Title for the cancel button in the store review step.
    var cancelButtonTitle: String

    /// Creates `StoreReviewStrings` with optional custom values.
    /// - Parameters: Titles, messages, and button titles.
    public init(
      title: String = "Loving the app so far?",
      message: String = "If you're enjoying it, a quick review would mean the world to us. It helps others discover the app too!",
      submitButtonTitle: String = "Leave a Review",
      cancelButtonTitle: String = "Maybe Later"
    ) {
      self.title = title
      self.message = message
      self.submitButtonTitle = submitButtonTitle
      self.cancelButtonTitle = cancelButtonTitle
    }
  }

  /// Localized strings for the final thank-you screen.
  public struct ThankYouStrings {
    /// Title for the thank-you screen.
    var title: String
    /// Message displayed on the thank-you screen.
    var message: String
    /// Title for the close button on the thank-you screen.
    var closeButtonTitle: String

    /// Creates `ThankYouStrings` with optional custom values.
    /// - Parameters: Titles, messages, and button titles.
    public init(
      title: String = "Thank you!",
      message: String = "Your feedback is precious to us.",
      closeButtonTitle: String = "Close"
    ) {
      self.title = title
      self.message = message
      self.closeButtonTitle = closeButtonTitle
    }
  }
}
