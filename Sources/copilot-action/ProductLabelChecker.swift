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

    let id: Int
    let labels: [Label]
  }
  let pull_request: PullRequest
}

fileprivate struct ReviewerAddRequest: Codable {
  let assignees: [String]
}

fileprivate struct ReviewResponse: Codable {
  fileprivate struct User: Codable {
    let login: String
  }
  let state: String
  let user: User
}

fileprivate struct IssueResponse: Codable {
  fileprivate struct User: Codable {
    let login: String
  }
  let assignees: [User]
}

// MARK: - Endpoints

extension APIEndpoint {
  static func addReviewer(repo: String, pullRequestID: Int) -> Self {
    APIEndpoint {
      "/repos/\(repo)/issues/\(pullRequestID)/assignees"
      HTTPMethod.post
    }
  }

  static func getReviews(repo: String, pullRequestID: Int) -> Self {
    APIEndpoint {
      "/repos/\(repo)/pulls/\(pullRequestID)/reviews"
      HTTPMethod.get
    }
  }

  static func getIssue(repo: String, pullRequestID: Int) -> Self {
    APIEndpoint {
      "/repos/\(repo)/issues/\(pullRequestID)"
      HTTPMethod.get
    }
  }
}


struct ProductLabelChecker: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "product-label"
  )

  func run() async throws {
    guard try getStringEnv("GITHUB_EVENT_NAME") != "push" else {
      print("Skipping check for event \(try getStringEnv("GITHUB_EVENT_NAME"))")
      return
    }

    let requiredLabels = ["requires_ui_demo", "requires_ui_check", "skip_ui_check"]

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
    } else if try getStringEnv("GITHUB_EVENT_NAME") == "pull_request_review" {
      let pullRequestReviewEvent = try JSONDecoder().decode(PullRequestReviewEvent.self, from: eventData)
      existingLabels = pullRequestReviewEvent.pull_request.labels.map(\.name)
      pullRequestID = pullRequestReviewEvent.pull_request.id
    } else {
      throw StringError("unknown event")
    }

    let uiCheckLabel = existingLabels.first {
      requiredLabels.contains($0)
    }

    guard let uiCheckLabel = uiCheckLabel else {
      throw StringError(
        "requires at least one of these labels: \(requiredLabels.joined(separator: ", "))"
      )
    }

    guard uiCheckLabel == "requires_ui_check" else {
      // For the other 2 labels, we don't need to do anything.
      return
    }

    // At this point, we need to add someone from product for UI check.
    let githubToken = try getStringEnv("GITHUB_TOKEN")
    let repo = try getStringEnv("GITHUB_REPOSITORY")
    let provider = APIProvider(configuration: GithubConfiguration(token: githubToken))

    let issue: IssueResponse = try await provider.request(.getIssue(repo: repo, pullRequestID: pullRequestID))

    let reviewers = issue.assignees.map(\.login)

    if !reviewers.contains("chuga") {
      try await provider.request(
        .addReviewer(repo: repo, pullRequestID: pullRequestID),
        body: ReviewerAddRequest(assignees: ["chuga"])
      )
    }

    let reviews: [ReviewResponse] = try await provider.request(
      .getReviews(repo: repo, pullRequestID: pullRequestID)
    )

    let approvedByProduct = reviews.contains { $0.user.login == "chuga" && $0.state == "APPROVED" }

    guard approvedByProduct else {
      throw StringError("missing product approval")
    }
  }
}
