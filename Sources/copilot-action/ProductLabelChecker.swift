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

fileprivate struct PullRequestReviewEvent: Codable {
  fileprivate struct PullRequest: Codable {
    fileprivate struct Label: Codable {
      let name: String
    }

    let number: Int
    let labels: [Label]
  }
  let pull_request: PullRequest
}

fileprivate struct ReviewerAddRequest: Codable {
  let reviewers: [String]
}

fileprivate struct ReviewResponse: Codable {
  fileprivate struct User: Codable {
    let login: String
  }
  let state: String
  let user: User
}

fileprivate struct ReviewersResponse: Codable {
  fileprivate struct User: Codable {
    let login: String
  }
  let users: [User]
}

// MARK: - Endpoints

extension APIEndpoint {
  static func addReviewer(repo: String, pullRequestID: Int) -> Self {
    APIEndpoint {
      "/repos/\(repo)/pulls/\(pullRequestID)/requested_reviewers"
      HTTPMethod.post
    }
  }

  static func getReviews(repo: String, pullRequestID: Int) -> Self {
    APIEndpoint {
      "/repos/\(repo)/pulls/\(pullRequestID)/reviews"
      HTTPMethod.get
    }
  }

  static func getReviewers(repo: String, pullRequestID: Int) -> Self {
    APIEndpoint {
      "/repos/\(repo)/pulls/\(pullRequestID)/requested_reviewers"
      HTTPMethod.get
    }
  }

  static func updatePullRequest(repo: String, pullRequestID: Int) -> Self {
    APIEndpoint {
      "/repos/\(repo)/pulls/\(pullRequestID)"
      HTTPMethod.patch
    }
  }
}

struct ProductLabelChecker: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "product-label"
  )

  func run() async throws {
    let productApprovers = try getStringEnv("COPILOT_PRODUCT_APPROVER")

    guard try getStringEnv("GITHUB_EVENT_NAME") != "push" else {
      print("Skipping check for event \(try getStringEnv("GITHUB_EVENT_NAME"))")
      return
    }

    let requiredLabels = ["requires_ui_demo", "requires_ui_check", "skip_ui_check"]
    let uiReviewedLabel = "ui_reviewed"

    let eventPath = try getStringEnv("GITHUB_EVENT_PATH")
    guard let eventData = try String(contentsOfFile: eventPath).data(using: .utf8) else {
      throw StringError("could not load event data at \(eventPath)")
    }

    let existingLabels: [String]
    let pullRequestID: Int

    if try getStringEnv("GITHUB_EVENT_NAME") == "pull_request" {
      let pullRequestEvent = try JSONDecoder().decode(PullRequestEvent.self, from: eventData)
      existingLabels = pullRequestEvent.pull_request.labels.map(\.name)
      pullRequestID = pullRequestEvent.number
    } else {
      throw StringError("unknown event")
    }

    // At this point, we need to add someone from product for UI check.
    let githubToken = try getStringEnv("GITHUB_TOKEN")
    let repo = try getStringEnv("GITHUB_REPOSITORY")
    let provider = APIProvider(configuration: GithubConfiguration(token: githubToken))

    if existingLabels.contains(uiReviewedLabel) {
      // PR has been approved for UI
      return
    }

    let uiCheckLabel = existingLabels.first {
      requiredLabels.contains($0)
    }

    guard uiCheckLabel != nil else {
      throw StringError(
        "requires at least one of these labels: \(requiredLabels.joined(separator: ", "))"
      )
    }

    // Return success if the label is not requires_ui_check, as that one needs more checks
    guard uiCheckLabel == "requires_ui_check" else {
      return
    }

    let issue: ReviewersResponse = try await provider.request(
      .getReviewers(repo: repo, pullRequestID: pullRequestID)
    )

    let reviewers = Set(issue.users.map(\.login))
    let approvers = Set(productApprovers.components(separatedBy: ","))

    let missing = approvers.subtracting(reviewers)

    if !missing.isEmpty {
      try await provider.request(
        .addReviewer(repo: repo, pullRequestID: pullRequestID),
        body: ReviewerAddRequest(reviewers: Array(missing))
      )
    }

    if !existingLabels.contains(uiReviewedLabel) {
      throw StringError("missing product approval")
    }
  }
}
