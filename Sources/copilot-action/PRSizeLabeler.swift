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

fileprivate struct LabelsChangeRequest: Codable {
  let labels: [String]
}

fileprivate struct LabelsResponse: Codable {
  fileprivate struct Label: Codable {
    let name: String
  }
  let labels: [Label]
}

// MARK: - Endpoints

extension APIEndpoint {
  static func setLabels(repo: String, pullRequestID: Int) -> Self {
    APIEndpoint {
      "/repos/\(repo)/issues/\(pullRequestID)/labels"
      HTTPMethod.put
    }
  }

  static func getLabels(repo: String, pullRequestID: Int) -> Self {
    APIEndpoint {
      "/repos/\(repo)/issues/\(pullRequestID)/labels"
      HTTPMethod.get
    }
  }
}

struct PRSizeLabeler: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "pr-size-labeler"
  )

  func run() async throws {
    guard try getStringEnv("GITHUB_EVENT_NAME") == "pull_request" else {
      print("Skipping check for event \(try getStringEnv("GITHUB_EVENT_NAME"))")
      return
    }

    let githubToken = try getStringEnv("GITHUB_TOKEN")
    let repo = try getStringEnv("GITHUB_REPOSITORY")
    let eventPath = try getStringEnv("GITHUB_EVENT_PATH")

    guard let eventData = try String(contentsOfFile: eventPath).data(using: .utf8) else {
      throw StringError("could not load event data at \(eventPath)")
    }

    let pullRequestEvent = try JSONDecoder().decode(PullRequestEvent.self, from: eventData)

    let totalLinesChanged = pullRequestEvent.pull_request.additions +
        pullRequestEvent.pull_request.deletions

    print("The pull request has \(totalLinesChanged) changed lines")

    let availableLabelIDs = try [
      "PR_SIZE_XS_LABEL": "XS",
      "PR_SIZE_S_LABEL": "S",
      "PR_SIZE_M_LABEL": "M",
      "PR_SIZE_L_LABEL": "L",
      "PR_SIZE_XL_LABEL": "XL",
    ].reduce(into: [:]) {
      $0[$1.key] = try getStringEnv($1.key, defaultValue: $1.value)
    }

    let label: String
    if try totalLinesChanged < getIntEnv("PR_SIZE_XS_LIMIT", defaultValue: 10) {
      label = availableLabelIDs["PR_SIZE_XS_LABEL"]!
    } else if try totalLinesChanged < getIntEnv("PR_SIZE_S_LIMIT", defaultValue: 100) {
      label = availableLabelIDs["PR_SIZE_S_LABEL"]!
    } else if try totalLinesChanged < getIntEnv("PR_SIZE_M_LIMIT", defaultValue: 500) {
      label = availableLabelIDs["PR_SIZE_M_LABEL"]!
    } else if try totalLinesChanged < getIntEnv("PR_SIZE_L_LIMIT", defaultValue: 1000) {
      label = availableLabelIDs["PR_SIZE_L_LABEL"]!
    } else {
      label = availableLabelIDs["PR_SIZE_XL_LABEL"]!
    }

    print("Assigning the \(label) label to pull request #\(pullRequestEvent.number)")

    let provider = APIProvider(configuration: GithubConfiguration(token: githubToken))

    let labelsResponse: LabelsResponse = try await provider.request(
      .getLabels(repo: repo, pullRequestID: pullRequestEvent.number)
    )

    let presentLabels = labelsResponse.labels.map(\.name)

    let keptLabels = presentLabels.filter { !availableLabelIDs.values.contains($0) }

    try await provider.request(
      .setLabels(repo: repo, pullRequestID: pullRequestEvent.number),
      body: LabelsChangeRequest(labels: keptLabels + [label])
    )
  }
}
