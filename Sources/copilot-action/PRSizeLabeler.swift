import ArgumentParser
import APIBuilder
import Foundation

struct PullRequest: Codable {
  let additions: Int
  let deletions: Int
}

struct GithubConfiguration: APIConfiguration {
  let token: String

  let host = URL(string: "https://api.github.com")!

  var requestHeaders: [String : String] {
    [
      "Content-Type": "application/vnd.github.v3+json",
      "Authorization": "Bearer \(token)",
    ]
  }

  init(token: String) {
    self.token = token
  }
}

extension APIEndpoint where T == PullRequest {
  static func getPullRequest(repo: String, pullRequestID: String) -> Self {
    APIEndpoint { "/repos/\(repo)/pulls/\(pullRequestID)" }
  }
}

struct PRSizeLabeler: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "pr-size-labeler"
  )

  func run() async throws {
    guard let githubToken = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] else {
      throw StringError("GITHUB_TOKEN environment variable not set")
    }

    let provider = APIProvider(configuration: GithubConfiguration(token: githubToken))
    let response = try await provider.request(
      .getPullRequest(repo: "copilotmoney/copilot-ios", pullRequestID: "1550")
    )
    print("The pull has \(response.additions + response.deletions) changed lines")
  }
}
