import copilot_action
import XCTest

final class SemanticCheckerTests: XCTestCase {
  func testRegularExpressions() throws {
    let checker = try SemanticChecker()

    do {
      let result = try checker.check("fix: Hello, world!")
      XCTAssertEqual(result.type, "fix")
      XCTAssertNil(result.scope)
      XCTAssertEqual(result.force, false)
      XCTAssertEqual(result.message, "Hello, world!")
    }

    do {
      let result = try checker.check("fix(scope): Hello, world!")
      XCTAssertEqual(result.type, "fix")
      XCTAssertEqual(result.scope, "scope")
      XCTAssertEqual(result.force, false)
      XCTAssertEqual(result.message, "Hello, world!")
    }

    do {
      let result = try checker.check("fix!: Hello, world!")
      XCTAssertEqual(result.type, "fix")
      XCTAssertNil(result.scope)
      XCTAssertEqual(result.force, true)
      XCTAssertEqual(result.message, "Hello, world!")
    }

    do {
      let result = try checker.check("fix(scope)!: Hello, world!")
      XCTAssertEqual(result.type, "fix")
      XCTAssertEqual(result.scope, "scope")
      XCTAssertEqual(result.force, true)
      XCTAssertEqual(result.message, "Hello, world!")
    }

    do {
      let result = try checker.check("fix(scope_underscore): Hello, world!")
      XCTAssertEqual(result.type, "fix")
      XCTAssertEqual(result.scope, "scope_underscore")
      XCTAssertEqual(result.force, false)
      XCTAssertEqual(result.message, "Hello, world!")
    }

    do {
      let result = try checker.check("feat(real-estate): Address location search")
      XCTAssertEqual(result.type, "feat")
      XCTAssertEqual(result.scope, "real-estate")
      XCTAssertEqual(result.force, false)
      XCTAssertEqual(result.message, "Address location search")
    }
    XCTAssertThrowsError(try checker.check("feat: Hello, world!"))

    XCTAssertThrowsError(try checker.check("Hello, world!"))
    XCTAssertThrowsError(try checker.check(": Hello, world!"))
    XCTAssertThrowsError(try checker.check("(scope_underscore): Hello, world!"))
    XCTAssertThrowsError(try checker.check("fix Hello, world!"))
    XCTAssertThrowsError(try checker.check(":Hello, world!"))

    XCTAssertThrowsError(try checker.check("feat(scope): [WIP] Hello, world!"))
    XCTAssertThrowsError(try checker.check("feat(scope): /WIP/ Hello, world!"))
    XCTAssertThrowsError(try checker.check("feat(scope): wip Hello, world!"))
  }
}
