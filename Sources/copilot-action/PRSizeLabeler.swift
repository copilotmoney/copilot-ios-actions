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

extension APIEndpoint {
  static func setLabels(repo: String, pullRequestID: Int) -> Self {
    APIEndpoint {
      "/repos/\(repo)/issues/\(pullRequestID)/labels"
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

    let pullRequestEvent = try JSONDecoder().decode(PullRequestEvent.self, from: eventData)

    let totalLinesChanged = pullRequestEvent.pull_request.additions + pullRequestEvent.pull_request.deletions
    print("The pull has \(totalLinesChanged) changed lines")

    let label: String
    if totalLinesChanged < 10 {
      label = "XS"
    } else if totalLinesChanged < 100 {
      label = "S"
    } else if totalLinesChanged < 500 {
      label = "M"
    } else if totalLinesChanged < 1000 {
      label = "L"
    } else {
      label = "XL"
    }

    print("Assigning the \(label) label")

    let provider = APIProvider(configuration: GithubConfiguration(token: githubToken))

    let body = LabelsChangeRequest(labels: [label])
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
