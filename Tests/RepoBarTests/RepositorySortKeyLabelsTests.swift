@testable import RepoBar
import RepoBarCore
import Testing

struct RepositorySortKeyLabelsTests {
    @Test
    func menuSortSymbolsStayCompact() {
        #expect(RepositorySortKey.menuCases == [.activity, .issues, .pulls, .stars, .name])
        #expect(RepositorySortKey.name.menuSymbolName == "textformat")
        #expect(RepositorySortKey.menuCases.allSatisfy { !$0.menuSymbolName.contains("abc") })
    }
}
