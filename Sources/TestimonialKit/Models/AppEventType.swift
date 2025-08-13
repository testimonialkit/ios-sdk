import Foundation

/// Represents the sentiment type of an application event.
///
/// Used to categorize events as either positive or negative interactions,
/// which can help in analytics, scoring systems, or feedback evaluation.
/// Conforms to `Codable` for JSON encoding/decoding.
public enum AppEventType: String, Codable {
  /// Indicates a positive event or interaction, such as a favorable action or feedback.
  case positive
  /// Indicates a negative event or interaction, such as an unfavorable action or feedback.
  case negative
}
