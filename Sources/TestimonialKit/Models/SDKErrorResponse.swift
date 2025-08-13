import Foundation

/// Represents an error response returned by the SDK's backend.
///
/// Contains a descriptive error message and an optional error code for programmatic handling.
/// Conforms to `Decodable` for JSON parsing.
struct SDKErrorResponse: Decodable {
  /// A descriptive error message returned by the backend.
  let message: String
  /// An optional error code string that can be used to identify the specific error type.
  /// May be `nil` if no code is provided.
  let errorCode: String?
}
