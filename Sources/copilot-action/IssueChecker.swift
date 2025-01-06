import APIBuilder
import ArgumentParser
import Foundation

// MARK: - API Types

fileprivate struct PullRequestEvent: Codable {
  fileprivate struct PullRequest: Codable {
    fileprivate struct Head: Codable {
      let ref: String
    }
    let body: String?
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
    guard try getStringEnv("GITHUB_EVENT_NAME") == "pull_request" else {
      print("Skipping check for event \(try getStringEnv("GITHUB_EVENT_NAME"))")
      return
    }

    let eventPath = try getStringEnv("GITHUB_EVENT_PATH")

    guard let eventData = try String(contentsOfFile: eventPath).data(using: .utf8) else {
      throw StringError("could not load event data at \(eventPath)")
    }

    let pullRequestEvent = try JSONDecoder().decode(PullRequestEvent.self, from: eventData)

    print(pullRequestEvent.pull_request.body ?? "_no body_")
    print(pullRequestEvent.pull_request.title)
    print(pullRequestEvent.pull_request.head.ref)

    let issuePrefixes = try getStringEnv("ISSUE_CHECKER_PREFIX").split(separator: ",")
    for issuePrefix in issuePrefixes {
      let inputsToCheck = [
        pullRequestEvent.pull_request.body,
        pullRequestEvent.pull_request.title,
        pullRequestEvent.pull_request.head.ref,
      ].compactMap { $0 }

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
    }

    let path = try getStringEnv("GITHUB_STEP_SUMMARY")
    print(path, FileHandle(forWritingAtPath: path))
    guard let summaryHandle = FileHandle(forWritingAtPath: path) else {
      throw StringError("Could not find issue in the PR")
    }

    try summaryHandle.write(contentsOf: """
      In copilot-ios, all PRs must be associated with a Linear issue, and we couldn't find one.
      
      The easiest way is adding the APL-1234 identifier in the description of the PR, but you can
      also use the issue's generated branch, or adding the issue ID in the PR's title. Once an issue
      is associated, this check will pass.
    """.data(using: .utf8)!)

    try summaryHandle.seekToEnd()
    try summaryHandle.close()
  }
}
