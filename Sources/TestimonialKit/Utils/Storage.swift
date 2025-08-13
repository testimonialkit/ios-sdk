import Foundation

/// Provides static helper methods for persisting and retrieving small pieces of SDK state
/// using `UserDefaults`. Includes values such as the internal user ID and feature flags
/// for prompting behavior.
final class Storage {
  /// UserDefaults key for storing the generated internal user identifier.
  private static let internalUserIdKey = "testimonialkit_internal_user_id"
  /// UserDefaults key indicating whether to request a comment when the user leaves a positive rating.
  private static let requestCommentOnPositiveRatingKey = "testimonialkit_request_comment_on_positive_rating"

  /// A unique, persistent identifier used internally by the SDK for the current user.
  ///
  /// If no ID is stored, a new UUID is generated, saved to `UserDefaults`, and returned.
  static var internalUserId: String {
    get {
      /// Return the stored ID if it exists, otherwise generate and store a new one.
      if let existingId = UserDefaults.standard.string(forKey: internalUserIdKey) {
          return existingId
      } else {
          let newId = UUID().uuidString
          UserDefaults.standard.setValue(newId, forKey: internalUserIdKey)
          return newId
      }
    }

    set {
      UserDefaults.standard.setValue(newValue, forKey: internalUserIdKey)
    }
  }

  /// Flag that determines whether the SDK should request a comment after a positive rating.
  ///
  /// Defaults to `false` if the key has not been set in `UserDefaults`.
  static var requestCommentOnPositiveRating: Bool {
    get {
      UserDefaults.standard.bool(forKey: requestCommentOnPositiveRatingKey)
    }

    set {
      UserDefaults.standard.setValue(newValue, forKey: requestCommentOnPositiveRatingKey)
    }
  }
}
