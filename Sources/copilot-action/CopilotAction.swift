import APIBuilder
import ArgumentParser
import Foundation

@main
struct CopilotAction: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "copilot-action",
    abstract: "Github Action main entry point for copilot-ios",
    subcommands: [
      PRSizeLabeler.self,
      IssueChecker.self,
    ]
  )
}

extension ParsableCommand {
  func getStringEnv(_ key: String, defaultValue: String? = nil) throws -> String {
    guard let value = ProcessInfo.processInfo.environment[key] ?? defaultValue else {
      throw StringError("\(key) environment variable not set")
    }

    return value
  }


  func getIntEnv(_ key: String, defaultValue: Int? = nil) throws -> Int {
    let envValue = ProcessInfo.processInfo.environment[key]
    guard let value = envValue.flatMap({ Int($0) }) ?? defaultValue else {
      throw StringError("\(key) environment variable not set")
    }

    return value
  }
}
