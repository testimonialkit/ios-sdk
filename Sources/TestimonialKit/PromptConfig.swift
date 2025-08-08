import SwiftUI
import SwiftThemeKit

public struct PromptConfig {
  @MainActor
  public static let defaultConfig: PromptConfig = .init()

  var strings: Strings
  var commentField: PromptConfig.TextField
  var submitButton: PromptConfig.Button
  var tintColor: Color
  var tintColorDark: Color

  public init(
    strings: Strings = .init(),
    submitButton: PromptConfig.Button = .init(),
    commentField: PromptConfig.TextField = .init(),
    tintColor: Color = .blue,
    tintColorDark: Color = .blue
  ) {
    self.strings = strings
    self.commentField = commentField
    self.submitButton = submitButton
    self.tintColor = tintColor
    self.tintColorDark = tintColorDark
  }

  public func copy(
    strings: Strings? = nil,
    submitButton: PromptConfig.Button? = nil,
    commentField: PromptConfig.TextField? = nil,
    tintColor: Color? = nil,
    tintColorDark: Color? = nil,
  ) -> PromptConfig {
    return PromptConfig(
      strings: strings ?? self.strings,
      submitButton: submitButton ?? self.submitButton,
      commentField: commentField ?? self.commentField,
      tintColor: tintColor ?? self.tintColor,
      tintColorDark: tintColorDark ?? self.tintColorDark,
    )
  }

  public struct TextField {
    var shape: TextFieldShape
    var variant: TextFieldVariant
    var size: TextFieldSize

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

  public struct Button {
    var shape: ButtonShape
    var variant: ButtonVariant
    var size: ButtonSize

    public init(
      shape: ButtonShape = .rounded,
      variant: ButtonVariant = .filled,
      size: ButtonSize = .custom(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16), .body)
    ) {
      self.shape = shape
      self.variant = variant
      self.size = size
    }
  }

  public struct Strings {
    var ratingTitle: String = "Rate this app"
    var ratingSubtitle: String = "Your feedback is precious to us."
    var ratingSubmitButtonTitle: String = "Submit"
    var ratingCancelButtonTitle: String = "Maybe later"

    var commentTitle: String = "Leave a comment"
    var commentSubtitle: String = "We value your honest opinion."
    var commentPlaceholder: String = "Type your comment here..."
    var commentSubmitButtonTitle: String = "Submit"
    var commentCancelButtonTitle: String = "Maybe later"

    public init(
      ratingTitle: String = "Rate this app",
      ratingSubtitle: String = "Your feedback is precious to us.",
      ratingSubmitButtonTitle: String = "Submit",
      ratingCancelButtonTitle: String = "Maybe later",
      commentTitle: String = "Leave a comment",
      commentSubtitle: String = "We value your honest opinion.",
      commentPlaceholder: String = "Type your comment here...",
      commentSubmitButtonTitle: String = "Submit",
      commentCancelButtonTitle: String = "Maybe later"
    ) {
      self.ratingTitle = ratingTitle
      self.ratingSubtitle = ratingSubtitle
      self.ratingSubmitButtonTitle = ratingSubmitButtonTitle
      self.ratingCancelButtonTitle = ratingCancelButtonTitle
      self.commentTitle = commentTitle
      self.commentSubtitle = commentSubtitle
      self.commentPlaceholder = commentPlaceholder
      self.commentSubmitButtonTitle = commentSubmitButtonTitle
      self.commentCancelButtonTitle = commentCancelButtonTitle
    }
  }
}
