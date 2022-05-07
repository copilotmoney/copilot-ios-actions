import ArgumentParser

@main
struct CopilotAction: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "copilot-action",
    abstract: "Github Action main entry point for copilot-ios",
    subcommands: [
      PRSizeLabeler.self,
    ],
    defaultSubcommand: PRSizeLabeler.self
  )

  func run() async throws {
    print("hello world!")
  }
}
