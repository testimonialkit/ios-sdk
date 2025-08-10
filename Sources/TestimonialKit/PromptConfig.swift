import SwiftUI
import SwiftThemeKit

public struct PromptConfig: @unchecked Sendable {
  public static let defaultConfig: PromptConfig = .init()

  var ratingStrings: RatingStrings
  var commentStrings: CommentStrings
  var storeReviewStrings: StoreReviewStrings
  var thankYouStrings: ThankYouStrings
  var commentField: PromptConfig.TextField
  var submitButton: PromptConfig.Button
  var tintColor: Color
  var tintColorDark: Color

  public init(
    ratingStrings: RatingStrings = .init(),
    commentStrings: CommentStrings = .init(),
    storeReviewStrings: StoreReviewStrings = .init(),
    thankYouStrings: ThankYouStrings = .init(),
    submitButton: PromptConfig.Button = .init(),
    commentField: PromptConfig.TextField = .init(),
    tintColor: Color = .blue,
    tintColorDark: Color = .blue
  ) {
    self.ratingStrings = ratingStrings
    self.commentStrings = commentStrings
    self.storeReviewStrings = storeReviewStrings
    self.thankYouStrings = thankYouStrings
    self.commentField = commentField
    self.submitButton = submitButton
    self.tintColor = tintColor
    self.tintColorDark = tintColorDark
  }

  public func copy(
    ratingStrings: RatingStrings? = nil,
    commentStrings: CommentStrings? = nil,
    submitButton: PromptConfig.Button? = nil,
    commentField: PromptConfig.TextField? = nil,
    tintColor: Color? = nil,
    tintColorDark: Color? = nil,
  ) -> PromptConfig {
    return PromptConfig(
      ratingStrings: ratingStrings ?? self.ratingStrings,
      commentStrings: commentStrings ?? self.commentStrings,
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

  public struct RatingStrings {
    var title: String
    var subtitle: String
    var ratingLabel: String
    var starLabels: [String]
    var submitButtonTitle: String
    var cancelButtonTitle: String

    public init(
      title: String = "Rate this app",
      subtitle: String = "Your feedback is precious to us.",
      ratingLabel: String = "Tap a star to rate",
      starLabels: [String] = ["I hate it", "I don't like it", "It's okay", "I like it", "I love it"],
      submitButtonTitle: String = "Submit",
      cancelButtonTitle: String = "Maybe later"
    ) {
      if starLabels.count != 5 {
        fatalError("Star labels array must contain exactly 5 strings.")
      }

      self.title = title
      self.subtitle = subtitle
      self.ratingLabel = ratingLabel
      self.starLabels = starLabels
      self.submitButtonTitle = submitButtonTitle
      self.cancelButtonTitle = cancelButtonTitle
    }
  }

  public struct CommentStrings {
    var title: String
    var subtitle: String
    var placeholder: String
    var submitButtonTitle: String
    var cancelButtonTitle: String

    public init(
      title: String = "Leave a comment",
      subtitle: String = "We value your honest opinion.",
      placeholder: String = "Type your comment here...",
      submitButtonTitle: String = "Submit",
      cancelButtonTitle: String = "Maybe later"
    ) {
      self.title = title
      self.subtitle = subtitle
      self.placeholder = placeholder
      self.submitButtonTitle = submitButtonTitle
      self.cancelButtonTitle = cancelButtonTitle
    }
  }

  public struct StoreReviewStrings {
    var title: String
    var message: String
    var submitButtonTitle: String
    var cancelButtonTitle: String

    public init(
      title: String = "Thank you!",
      message: String = "What about reviewing us in the App Store?",
      submitButtonTitle: String = "Ok, sure",
      cancelButtonTitle: String = "No thanks"
    ) {
      self.title = title
      self.message = message
      self.submitButtonTitle = submitButtonTitle
      self.cancelButtonTitle = cancelButtonTitle
    }
  }

  public struct ThankYouStrings {
    var title: String
    var message: String
    var closeButtonTitle: String
    
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
