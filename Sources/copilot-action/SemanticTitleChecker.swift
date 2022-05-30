import APIBuilder
import ArgumentParser
import Foundation

// MARK: - API Types

fileprivate struct PullRequestEvent: Codable {
  fileprivate struct PullRequest: Codable {
    let title: String
  }
  let pull_request: PullRequest
}

private let validTypes = [
  "feat",
  "fix",
  "docs",
  "style",
  "refactor",
  "perf",
  "test",
  "build",
  "ci",
  "chore",
  "revert",
]

struct SemanticTitleChecker: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "semantic-title-checker"
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

    print("Checking semantics for: ", pullRequestEvent.pull_request.title)

    let checker = try SemanticChecker()
    let result = try checker.check(pullRequestEvent.pull_request.title)
  }
}

public struct SemanticChecker {
  private let regex: NSRegularExpression

  public init() throws {
    regex = try NSRegularExpression(pattern: #"^(\w+)(\([\w_-]+\))?(!)?: (.*)$"#)
  }

  @discardableResult
  public func check(
    _ input: String
  ) throws -> (type: String, scope: String?, message: String, force: Bool) {
    guard let match = regex.firstMatch(
      in: input,
      range: NSRange(location: 0, length: input.utf8.count)
    ) else {
      throw StringError("invalid input: \(input)")
    }

    guard let typeRange = Range(match.range(at: 1), in: input) else {
      throw StringError("missing type from input: \(input)")
    }
    guard let messageRange = Range(match.range(at: 4), in: input) else {
      throw StringError("missing message from input: \(input)")
    }

    let type = String(input[typeRange])
    let message = String(input[messageRange])

    let scope: String?
    if let scopeRange = Range(match.range(at: 2), in: input) {
      let rawScope = String(input[scopeRange])
      scope = String(rawScope.suffix(rawScope.count - 1).prefix(rawScope.count - 2))
    } else {
      scope = nil
    }

    let force: Bool
    if let forceRange = Range(match.range(at: 3), in: input) {
      force = input[forceRange] == "!"
    } else {
      force = false
    }

    guard validTypes.contains(type) else {
      throw StringError(
        "invalid type \(type), valid types are \(validTypes.joined(separator: ","))"
      )
    }

    if type == "feat", scope == nil {
      throw StringError("feat pull requests require scope")
    }

    return (type, scope, message, force)
  }
}
