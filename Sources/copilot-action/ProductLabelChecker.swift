import APIBuilder
import ArgumentParser
import Foundation

// MARK: - API Types

fileprivate struct PullRequestEvent: Codable {
  fileprivate struct PullRequest: Codable {
    fileprivate struct Label: Codable {
      let name: String
    }
    let labels: [Label]
  }
  let pull_request: PullRequest
  let number: Int
}

struct ReviewerAddRequest: Codable {
  let assignees: [String]
}

// MARK: - Endpoints

extension APIEndpoint {
  static func addReviewer(repo: String, pullRequestID: Int) -> Self {
    APIEndpoint {
      "/repos/\(repo)/issues/\(pullRequestID)/assignees"
      HTTPMethod.post
    }
  }
}


struct ProductLabelChecker: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "product-label"
  )

  func run() async throws {
    guard try getStringEnv("GITHUB_EVENT_NAME") == "pull_request" else {
      print("Skipping check for event \(try getStringEnv("GITHUB_EVENT_NAME"))")
      return
    }

    let eventPath = try getStringEnv("GITHUB_EVENT_PATH")

    guard let eventData = try String(contentsOfFile: eventPath).data(using: .utf8) else {
      throw StringError("could not load event data at \(eventPath)")
    }

    let pullRequestEvent = try JSONDecoder().decode(PullRequestEvent.self, from: eventData)

    let requiredLabels = ["requires_ui_demo", "requires_ui_check", "skip_ui_check"]

    let uiCheckLabel = pullRequestEvent.pull_request.labels.first {
      requiredLabels.contains($0.name)
    }

    guard let uiCheckLabel = uiCheckLabel else {
      throw StringError(
        "requires at least one of these labels: \(requiredLabels.joined(separator: ", "))"
      )
    }

    guard uiCheckLabel.name == "requires_ui_check" else {
      // For the other 2 labels, we don't need to do anything.
      return
    }

    // At this point, we need to add someone from product for UI check.

    let githubToken = try getStringEnv("GITHUB_TOKEN")
    let repo = try getStringEnv("GITHUB_REPOSITORY")
    let provider = APIProvider(configuration: GithubConfiguration(token: githubToken))

    try await provider.request(
      .addReviewer(repo: repo, pullRequestID: pullRequestEvent.number),
      body: ReviewerAddRequest(assignees: ["chuga"])
    )
  }
}
