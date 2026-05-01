import SwiftUI
import MarkdownUI

struct MarkdownResponseView: View {
    let text: String

    var body: some View {
        if text.isEmpty {
            EmptyView()
        } else {
            Markdown(text)
                .markdownTheme(.gitHub)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
