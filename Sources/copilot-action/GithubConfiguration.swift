import APIBuilder
import Foundation

struct GithubConfiguration: APIConfiguration {
  let host = URL(string: "https://api.github.com")!

  var requestHeaders: [String : String] {
    [
      "Content-Type": "application/vnd.github.v3+json",
      "Authorization": "Bearer \(token)",
    ]
  }

  let token: String

  init(token: String) {
    self.token = token
  }
}
