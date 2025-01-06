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
    do {
      try checker.check(pullRequestEvent.pull_request.title)
    } catch {
      try printError(error)
      throw error
    }
  }

  private func printError(_ error: SemanticChecker.SemanticCheckerError) throws {
    let errorTitle = switch error {
    case .invalidInput(_):
      "The PR's title does not conform to the expected format."
    case .invalidType(let type):
      "`\(type)` is not a valid semantic type."
    case .missingFeatScope(_):
      "`feat` PRs are required to have a scope"
    case .wip:
      "The PR is marked as a Work in Progress"
    case .missingMessage(_):
      "The PR's title does not have a description."
    case .missingType(_):
      "The PR's title does not have a semantic type"
    }

    let path = try getStringEnv("GITHUB_STEP_SUMMARY")
    guard let summaryHandle = FileHandle(forWritingAtPath: path) else {
      throw StringError("Could not find issue in the PR")
    }

    try summaryHandle.write(contentsOf: """
      > [!CAUTION]
      > \(errorTitle)
    
      In `copilot-ios`, all PRs require titles are required to be written with semantic markers, in
      the following format:
    
      `<type>(<scope>): PR title message`
      
      e.g.: 
      
      * `feat(finance-goals): Adds new transaction selection list`
      * `build: Fix build and release script`
    
      `type` can be one of the following:
    
      \(validTypes.map { "* `\($0)`\n" }.joined(separator: ""))
      
      `feat` PRs also are required to have the `scope` value.
    
      Finally, PRs with `WIP` in them will fail as it is an indicator that the PR is not ready.
    """.data(using: .utf8)!)

    try summaryHandle.seekToEnd()
    try summaryHandle.close()
  }
}

public struct SemanticChecker {
  public enum SemanticCheckerError: Error {
    case wip
    case invalidType(String)
    case missingType(String)
    case missingFeatScope(String)
    case missingMessage(String)
    case invalidInput(String)
  }

  private let regex: NSRegularExpression
  private let wipRegex: NSRegularExpression

  public init() throws {
    regex = try NSRegularExpression(pattern: #"^(\w+)(\([\w_-]+\))?(!)?: (.*)$"#)
    wipRegex = try NSRegularExpression(pattern: #"\bwip\b"#, options: .caseInsensitive)
  }

  @discardableResult
  public func check(
    _ input: String
  ) throws(SemanticCheckerError) -> (type: String, scope: String?, message: String, force: Bool) {
    guard let match = regex.firstMatch(
      in: input,
      range: NSRange(location: 0, length: input.utf8.count)
    ) else {
      throw SemanticCheckerError.invalidInput(input)
    }

    guard let typeRange = Range(match.range(at: 1), in: input) else {
      throw SemanticCheckerError.missingType(input)
    }
    guard let messageRange = Range(match.range(at: 4), in: input) else {
      throw SemanticCheckerError.missingMessage(input)
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
      throw SemanticCheckerError.invalidType(type)
    }

    if type == "feat", scope == nil {
      throw SemanticCheckerError.missingFeatScope(input)
    }

    if wipRegex.numberOfMatches(
      in: input,
      range: NSRange(location: 0, length: input.utf8.count)
    ) > 0 {
      throw SemanticCheckerError.wip
    }

    return (type, scope, message, force)
  }
}
