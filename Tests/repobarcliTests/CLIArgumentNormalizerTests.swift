import Commander
@testable import repobarcli
import RepoBarCore
import Testing

struct CLIArgumentNormalizerTests {
    @Test
    func `normalizes binary name to repobar`() {
        let argv = CLIArgumentNormalizer.normalize(["/Applications/RepoBar.app/Contents/MacOS/repobarcli", "status"])
        #expect(argv.first == RepoBarRoot.commandName)
        #expect(argv.dropFirst().first == "status")
    }

    @Test
    @MainActor
    func `normalized args resolve to status command`() throws {
        let argv = CLIArgumentNormalizer.normalize(["/Applications/RepoBar.app/Contents/MacOS/repobarcli", "status"])
        let program = Program(descriptors: [RepoBarRoot.descriptor()])
        let invocation = try program.resolve(argv: argv)
        #expect(invocation.path.last == StatusCommand.commandName)
    }

    @Test
    func `normalizes legacy aliases`() {
        #expect(CLIArgumentNormalizer.normalize(["repobar", "list"]).dropFirst().first == "repos")
        #expect(CLIArgumentNormalizer.normalize(["repobar", "pr"]).dropFirst().first == "pulls")
        #expect(CLIArgumentNormalizer.normalize(["repobar", "prs"]).dropFirst().first == "pulls")
        #expect(CLIArgumentNormalizer.normalize(["repobar", "runs"]).dropFirst().first == "ci")
    }

    @Test
    func `normalizes local subcommands`() {
        let syncArgs = CLIArgumentNormalizer.normalize(["repobar", "local", "sync", "RepoBar"])
        #expect(syncArgs[1] == "local-sync")
        #expect(syncArgs.dropFirst(2).first == "RepoBar")

        let branchesArgs = CLIArgumentNormalizer.normalize(["repobar", "local", "branches", "RepoBar"])
        #expect(branchesArgs[1] == "local-branches")

        let worktreesArgs = CLIArgumentNormalizer.normalize(["repobar", "local", "worktrees", "RepoBar"])
        #expect(worktreesArgs[1] == "worktrees")
    }

    @Test
    func `normalizes settings subcommands`() {
        let showArgs = CLIArgumentNormalizer.normalize(["repobar", "settings", "show"])
        #expect(showArgs[1] == "settings-show")

        let setArgs = CLIArgumentNormalizer.normalize(["repobar", "settings", "set", "refresh-interval", "5m"])
        #expect(setArgs[1] == "settings-set")
    }

    @Test
    func `normalizes open subcommands`() {
        let finderArgs = CLIArgumentNormalizer.normalize(["repobar", "open", "finder", "~/Projects"])
        #expect(finderArgs[1] == "open-finder")

        let terminalArgs = CLIArgumentNormalizer.normalize(["repobar", "open", "terminal", "~/Projects"])
        #expect(terminalArgs[1] == "open-terminal")
    }
}
