import Foundation

class TestimonialKitConfig {
  var apiKey: String
  let bundleId: String
  var userId: String
  let appVersion: String
  let countryCode: String
  let platform: String = "ios"
  let sdkVersion: String = "1.0.0"

  init(apiKey: String,
       bundleId: String,
       userId: String,
       appVersion: String,
       countryCode: String) {
    self.apiKey = apiKey
    self.bundleId = bundleId
    self.userId = userId
    self.appVersion = appVersion
    self.countryCode = countryCode
  }
}
