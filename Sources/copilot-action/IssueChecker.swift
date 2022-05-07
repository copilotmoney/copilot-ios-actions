import APIBuilder
import ArgumentParser
import Foundation

// MARK: - API Types

fileprivate struct PullRequestEvent: Codable {
  fileprivate struct PullRequest: Codable {
    fileprivate struct Head: Codable {
      let ref: String
    }
    let body: String
    let title: String
    let head: Head
  }
  let pull_request: PullRequest
}

struct IssueChecker: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "issue-checker"
  )

  func run() async throws {
    let eventPath = try getStringEnv("GITHUB_EVENT_PATH") as String

    guard let eventData = try String(contentsOfFile: eventPath).data(using: .utf8) else {
      throw StringError("could not load event data at \(eventPath)")
    }

    let pullRequestEvent = try JSONDecoder().decode(PullRequestEvent.self, from: eventData)

    print(pullRequestEvent.pull_request.body)
    print(pullRequestEvent.pull_request.title)
    print(pullRequestEvent.pull_request.head.ref)

    let issuePrefix = try getStringEnv("ISSUE_CHECKER_PREFIX") as String

    let inputsToCheck = [
      pullRequestEvent.pull_request.body,
      pullRequestEvent.pull_request.title,
      pullRequestEvent.pull_request.head.ref,
    ]

    for input in inputsToCheck {
      let range = input
        .lowercased()
        .range(
          of: "\(issuePrefix.lowercased())\\d{1,}",
          options: .regularExpression
        )

      if let range = range {
        print("Found \(input[range])")
        return
      }
    }

    throw StringError("Could not find issue in the PR")
  }
}
