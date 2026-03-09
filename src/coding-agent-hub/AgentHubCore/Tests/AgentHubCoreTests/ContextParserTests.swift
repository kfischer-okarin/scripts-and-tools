import Testing
@testable import AgentHubCore

struct ContextParserTests {
    let parser = ContextParser()

    @Test func extractsLinesAboveInputAreaWhenIdle() {
        let output = """
            This line should not appear
            Some earlier stuff
            Read the file
            Edited src/main.swift
            Ran the tests
            All 15 tests passed

            ────────────────────
            ❯
            ────────────────────
            """

        #expect(parser.parse(output) == [
            "Some earlier stuff",
            "Read the file",
            "Edited src/main.swift",
            "Ran the tests",
            "All 15 tests passed",
        ])
    }

    @Test func extractsLinesAboveThinkingWhenWorking() {
        let output = """
            This line should not appear
            Some earlier stuff
            Read the file
            Edited src/main.swift
            Ran the tests
            All 15 tests passed

            ✻ Thinking… (5s)

            ────────────────────
            ❯
            ────────────────────
            """

        #expect(parser.parse(output) == [
            "Some earlier stuff",
            "Read the file",
            "Edited src/main.swift",
            "Ran the tests",
            "All 15 tests passed",
        ])
    }

    @Test func extractsLinesFromPermissionPromptForBashCommand() {
        let output = """
            Some previous output

            ────────────────────────────────────────────────
             Bash command

               cd /tmp && pwd
               Change to /tmp directory and print working directory

             Do you want to proceed?
             ❯ 1. Yes
               2. Yes, allow reading from tmp/ from this project
               3. No

             Esc to cancel · Tab to amend · ctrl+e to explain
            """

        #expect(parser.parse(output) == [
            " Bash command",
            "",
            "   cd /tmp && pwd",
            "   Change to /tmp directory and print working directory",
            "",
        ])
    }

    @Test func extractsLinesFromQuestionPrompt() {
        let output = """
            Some previous output

            ────────────────────────────────────────────────
             ☐ Next test

            What tool do you want to test next, Okarin?

            ❯ 1. Bash
                 Run another shell command
              2. File edit
                 Try editing a file again
              3. Agent
                 Spin up a subagent to explore something
              4. We're done
                 Wrap up the testing session
              5. Type something.
            ────────────────────────────────────────────────
              6. Chat about this
              7. Skip interview and plan immediately

            Enter to select · ↑/↓ to navigate · Esc to cancel
            """

        #expect(parser.parse(output) == [
            " ☐ Next test",
            "",
            "What tool do you want to test next, Okarin?",
            "",
            "❯ 1. Bash",
        ])
    }

    @Test func ignoresOldScrollbackBordersWhenFindingPrompt() {
        let output = """
            Old output from earlier session

            ────────────────────────────────────────────────
             Here is Claude's plan:
            ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
             Old Plan Title

             This is stale content from scrollback

            More output happened after that

            ────────────────────────────────────────────────
             Bash command

               rm -rf /tmp/test
               Remove test directory

             Do you want to proceed?
             ❯ 1. Yes
               2. No
            """

        #expect(parser.parse(output) == [
            " Bash command",
            "",
            "   rm -rf /tmp/test",
            "   Remove test directory",
            "",
        ])
    }

    @Test func extractsLinesFromPlanPrompt() {
        let output = """
            Some previous output

            ────────────────────────────────────────────────
             Ready to code?

             Here is Claude's plan:
            ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
             Tool Interaction Test Plan

             Context

             Okarin is testing Claude Code's various tool interactions.

             ❯ 1. Yes, clear context
               2. Yes, auto-accept edits
               3. Yes, manually approve edits
               4. Type here to tell Claude what to change
            """

        #expect(parser.parse(output) == [
            " Tool Interaction Test Plan",
            "",
            " Context",
            "",
            " Okarin is testing Claude Code's various tool interactions.",
        ])
    }
}
