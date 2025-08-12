import Foundation
import os.log  // For using OSLog, which is efficient for iOS logging

// Define log levels as an enum for clarity and type safety
public enum LogLevel: Int, Comparable {
  case verbose = 0
  case debug = 1
  case info = 2
  case warning = 3
  case error = 4
  case none = 5  // Effectively disables logging

  // Allow comparison for checking if a log should be printed
  public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
    return lhs.rawValue < rhs.rawValue
  }
}

// Singleton Logger class for easy access throughout the SDK
final class Logger: @unchecked Sendable {
  // Shared instance
  static let shared = Logger()

  // Current log level, default to info. This can be set by the developer
  var currentLevel: LogLevel = .info

  // Private OSLog instance for subsystem and category (customize as needed)
  private let osLogger = OSLog(subsystem: "dev.testimonialkit.ios-sdk", category: "TestimonialKit")

  // Private init to enforce singleton
  private init() {}

  // General log method that takes a level, message, and optional file/line/function for context
  func log(_ level: LogLevel, _ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    // Only log if the message level is at or above the current level
    guard level >= currentLevel else { return }

    // Format the message with level, file, line, and function for better debugging
//    let formattedMessage = "[\(level)] \(file.components(separatedBy: "/").last ?? ""):\(line) \(function) - \(message)"
    let formattedMessage = "[\(level)] TestimonialKit - \(message)"

    // Use OSLog for efficient logging (privacy-preserving and performant on iOS)
    switch level {
    case .verbose:
      os_log("%{public}s", log: osLogger, type: .debug, formattedMessage)  // Verbose as debug in OSLog
    case .debug:
      os_log("%{public}s", log: osLogger, type: .debug, formattedMessage)
    case .info:
      os_log("%{public}s", log: osLogger, type: .info, formattedMessage)
    case .warning:
      os_log("%{public}s", log: osLogger, type: .default, formattedMessage)  // Warning as default
    case .error:
      os_log("%{public}s", log: osLogger, type: .error, formattedMessage)
    default:
      break
    }
  }

  // Convenience methods for each log level
  func verbose(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.verbose, message, file: file, line: line, function: function)
  }

  func debug(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.debug, message, file: file, line: line, function: function)
  }

  func info(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.info, message, file: file, line: line, function: function)
  }

  func warning(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.warning, message, file: file, line: line, function: function)
  }

  func error(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.error, message, file: file, line: line, function: function)
  }
}
