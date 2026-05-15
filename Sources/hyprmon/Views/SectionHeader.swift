import SwiftUI
import HyprmonCore

struct SectionHeader: View {
    let title: String
    let theme: Theme

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1)
            .foregroundStyle(theme.accent)
    }
}
