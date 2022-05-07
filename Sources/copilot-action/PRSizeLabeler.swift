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
    let githubToken = try getEnv(key: "GITHUB_TOKEN")
    let repo = try getEnv(key: "GITHUB_REPOSITORY")
    let eventPath = try getEnv(key: "GITHUB_EVENT_PATH")

    guard let eventData = try String(contentsOfFile: eventPath).data(using: .utf8) else {
      throw StringError("could not load event data at \(eventPath)")
    }

    print(String(data: eventData, encoding: .utf8)!)

    let provider = APIProvider(configuration: GithubConfiguration(token: githubToken))
    let response = try await provider.request(
      .getPullRequest(repo: repo, pullRequestID: "1550")
    )
    print("The pull has \(response.additions + response.deletions) changed lines")
  }

  private func getEnv(key: String) throws -> String {
    guard let value = ProcessInfo.processInfo.environment[key] else {
      throw StringError("\(key) environment variable not set")
    }

    return value
  }
}
