import ArgumentParser
import APIBuilder
import Foundation

struct PullRequest: Codable {
  let additions: Int
  let deletions: Int
}
struct PullRequestEvent: Codable {

  let pull_request: PullRequest
  let number: Int
}

struct LabelsChangeRequest: Codable {
  let labels: [String]
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

extension APIEndpoint {
  static func setLabels(repo: String, pullRequestID: Int) -> Self {
    APIEndpoint {
      "/repos/\(repo)/issues/\(pullRequestID)"
      HTTPMethod.put
    }
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

    let pullRequestEvent = try JSONDecoder().decode(PullRequestEvent.self, from: eventData)

    print("The pull has \(pullRequestEvent.pull_request.additions + pullRequestEvent.pull_request.deletions) changed lines")

    let provider = APIProvider(configuration: GithubConfiguration(token: githubToken))
    let body = LabelsChangeRequest(labels: ["XS"])
    try await provider.request(
      .setLabels(repo: repo, pullRequestID: pullRequestEvent.number),
      body: body
    )
  }

  private func getEnv(key: String) throws -> String {
    guard let value = ProcessInfo.processInfo.environment[key] else {
      throw StringError("\(key) environment variable not set")
    }

    return value
  }
}
