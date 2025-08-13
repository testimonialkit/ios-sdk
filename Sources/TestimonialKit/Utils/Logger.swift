import Foundation
import os.log  // For using OSLog, which is efficient for iOS logging

/// Defines the various log levels supported by the SDK, ordered by verbosity.
///
/// Conforms to `Comparable` so levels can be compared to determine if a message
/// should be logged given the current logging threshold.
public enum LogLevel: Int, Comparable {
  /// Verbose = most detailed logs, Debug = developer-focused info, Info = general info,
  /// Warning = non-fatal issues, Error = serious problems, None = disables logging.
  case verbose = 0
  case debug = 1
  case info = 2
  case warning = 3
  case error = 4
  case none = 5  // Effectively disables logging

  /// Compares two log levels by their raw value to determine ordering.
  /// - Parameters:
  ///   - lhs: The left-hand side log level.
  ///   - rhs: The right-hand side log level.
  /// - Returns: `true` if `lhs` is less verbose than `rhs`.
  public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
    return lhs.rawValue < rhs.rawValue
  }

  /// An emoji representing the log level, used to visually distinguish logs in the console.
  var emoji: String {
    switch self {
    case .verbose: return "💬"  // Grayish for verbose
    case .debug: return "🐞"    // Blue-ish bug for debug
    case .info: return "ℹ️"     // Blue info
    case .warning: return "⚠️"  // Yellow warning
    case .error: return "❌"     // Red error
    case .none: return ""
    }
  }
}

/// Singleton logger utility for the SDK.
///
/// Wraps `OSLog` for efficient and privacy-aware logging on iOS.
/// Provides convenience methods for each log level.
/// Marked `@unchecked Sendable` for concurrency, though access to `currentLevel` should be managed safely.
final class Logger: @unchecked Sendable {
  /// Shared global instance of the logger.
  static let shared = Logger()

  /// The minimum log level that will be output. Defaults to `.info`.
  /// Messages below this level will be ignored.
  var currentLevel: LogLevel = .info

  /// Internal `OSLog` configured with the SDK's subsystem and category.
  private let osLogger = OSLog(subsystem: "dev.testimonialkit.ios-sdk", category: "TestimonialKit")

  /// Private initializer to enforce singleton usage.
  private init() {}

  /// Logs a message at the specified level with optional file, line, and function context.
  /// - Parameters:
  ///   - level: The severity level of the log.
  ///   - message: The message to log.
  ///   - file: The file name from which the log is called (default: `#file`).
  ///   - line: The line number from which the log is called (default: `#line`).
  ///   - function: The function name from which the log is called (default: `#function`).
  func log(_ level: LogLevel, _ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    // Only log if the message level is at or above the current level
    guard level >= currentLevel else { return }

    // Format the message with level, file, line, and function for better debugging
    //    let formattedMessage = "[\(level)] \(file.components(separatedBy: "/").last ?? ""):\(line) \(function) - \(message)"
    let formattedMessage = "\(level.emoji) [\(level)] TestimonialKit - \(message)"

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

  /// Logs a verbose message.
  /// - Parameters:
  ///   - message: The message to log.
  ///   - file: The file name from which the log is called (default: `#file`).
  ///   - line: The line number from which the log is called (default: `#line`).
  ///   - function: The function name from which the log is called (default: `#function`).
  func verbose(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.verbose, message, file: file, line: line, function: function)
  }

  /// Logs a debug message.
  /// - Parameters:
  ///   - message: The message to log.
  ///   - file: The file name from which the log is called (default: `#file`).
  ///   - line: The line number from which the log is called (default: `#line`).
  ///   - function: The function name from which the log is called (default: `#function`).
  func debug(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.debug, message, file: file, line: line, function: function)
  }

  /// Logs an info message.
  /// - Parameters:
  ///   - message: The message to log.
  ///   - file: The file name from which the log is called (default: `#file`).
  ///   - line: The line number from which the log is called (default: `#line`).
  ///   - function: The function name from which the log is called (default: `#function`).
  func info(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.info, message, file: file, line: line, function: function)
  }

  /// Logs a warning message.
  /// - Parameters:
  ///   - message: The message to log.
  ///   - file: The file name from which the log is called (default: `#file`).
  ///   - line: The line number from which the log is called (default: `#line`).
  ///   - function: The function name from which the log is called (default: `#function`).
  func warning(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.warning, message, file: file, line: line, function: function)
  }

  /// Logs an error message.
  /// - Parameters:
  ///   - message: The message to log.
  ///   - file: The file name from which the log is called (default: `#file`).
  ///   - line: The line number from which the log is called (default: `#line`).
  ///   - function: The function name from which the log is called (default: `#function`).
  func error(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    log(.error, message, file: file, line: line, function: function)
  }
}
