import Foundation

class Storage {
  private static let internalUserIdKey = "testimonialkit_internal_user_id"
  private static let requestCommentOnPositiveRatingKey = "testimonialkit_request_comment_on_positive_rating"

  static var internalUserId: String {
    get {
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

  static var requestCommentOnPositiveRating: Bool {
    get {
      UserDefaults.standard.bool(forKey: requestCommentOnPositiveRatingKey)
    }

    set {
      UserDefaults.standard.setValue(newValue, forKey: requestCommentOnPositiveRatingKey)
    }
  }
}
