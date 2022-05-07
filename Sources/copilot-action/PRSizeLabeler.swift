import ArgumentParser
import APIBuilder
import Foundation

// MARK: - API Types

fileprivate struct PullRequestEvent: Codable {
  fileprivate struct PullRequest: Codable {
    let additions: Int
    let deletions: Int
  }

  let pull_request: PullRequest
  let number: Int
}

struct LabelsChangeRequest: Codable {
  let labels: [String]
}

// MARK: - Endpoints

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
    let githubToken = try getEnv("GITHUB_TOKEN")
    let repo = try getEnv("GITHUB_REPOSITORY")
    let eventPath = try getEnv("GITHUB_EVENT_PATH")

    guard let eventData = try String(contentsOfFile: eventPath).data(using: .utf8) else {
      throw StringError("could not load event data at \(eventPath)")
    }

    let pullRequestEvent = try JSONDecoder().decode(PullRequestEvent.self, from: eventData)

    let totalLinesChanged = pullRequestEvent.pull_request.additions +
        pullRequestEvent.pull_request.deletions

    print("The pull request has \(totalLinesChanged) changed lines")

    let label: String
    if try totalLinesChanged < getInputEnv("PR_SIZE_XS_LIMIT", defaultValue: 10) {
      label = try getInputEnv("PR_SIZE_XS_LABEL", defaultValue: "XS")
    } else if try totalLinesChanged < getInputEnv("PR_SIZE_S_LIMIT", defaultValue: 100) {
      label = try getInputEnv("PR_SIZE_S_LABEL", defaultValue: "S")
    } else if try totalLinesChanged < getInputEnv("PR_SIZE_M_LIMIT", defaultValue: 500) {
      label = try getInputEnv("PR_SIZE_M_LABEL", defaultValue: "M")
    } else if try totalLinesChanged < getInputEnv("PR_SIZE_L_LIMIT", defaultValue: 1000) {
      label = try getInputEnv("PR_SIZE_L_LABEL", defaultValue: "L")
    } else {
      label = try getInputEnv("PR_SIZE_XL_LABEL", defaultValue: "XL")
    }

    print("Assigning the \(label) label to pull request #\(pullRequestEvent.number)")

    let provider = APIProvider(configuration: GithubConfiguration(token: githubToken))

    try await provider.request(
      .setLabels(repo: repo, pullRequestID: pullRequestEvent.number),
      body: LabelsChangeRequest(labels: [label])
    )
  }
}
