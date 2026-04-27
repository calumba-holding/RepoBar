import Foundation
import Swiftdansi

struct MarkdownRenderRequest {
    var width: Int?
    var wrap: Bool?
    var color: Bool?
    var plain: Bool
}

func renderMarkdown(_ markdown: String, request: MarkdownRenderRequest) -> String {
    let options = RenderOptions(
        wrap: request.wrap,
        width: request.width,
        color: request.color
    )

    if request.plain {
        return strip(markdown, options: options)
    }

    return render(markdown, options: options)
}
