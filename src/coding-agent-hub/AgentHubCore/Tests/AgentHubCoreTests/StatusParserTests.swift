import Testing
@testable import AgentHubCore

struct StatusParserTests {
    let parser = StatusParser()

    @Test func detectsWorking() {
        let output = """
            Some previous output
            ✻ Thinking… (27s, 200 tokens)
            ────────────────────
            ❯
            """

        #expect(parser.parse(output) == .working)
    }

    @Test func detectsAwaitingUserInput() {
        let output = """
            Some output here
            ────────────────────
            ❯
            """

        #expect(parser.parse(output) == .awaitingUserInput)
    }

    @Test func detectsAwaitingPermission() {
        let output = """
            ───────────────────────────────────────────────
             Bash command
               echo "Hello" | rev
             Do you want to proceed?
             ❯ 1. Yes
               2. Yes, and don't ask again for: rev
               3. No
            """

        #expect(parser.parse(output) == .awaitingPermission)
    }

    @Test func doesNotFalsePositiveOnDoYouWantInOutput() {
        let output = """
            Do you want to know how this works? Let me explain.
            Here is the answer.
            ────────────────────
            ❯
            """

        #expect(parser.parse(output) == .awaitingUserInput)
    }

    @Test func workingTakesPriorityOverInputPrompt() {
        let output = """
            ✻ Thinking… (5s)
            ────────────────────
            ❯
            """

        #expect(parser.parse(output) == .working)
    }

    @Test func unknownWhenNoPatternMatches() {
        #expect(parser.parse("just some random text") == .unknown)
    }
}
