import SwiftUI

struct PanelIconTile<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.55))
            content
        }
        .frame(width: 34, height: 34)
    }
}

struct PanelStatusBadge: View {
    let title: String
    let tint: Color

    init(_ title: String, tint: Color = .secondary) {
        self.title = title
        self.tint = tint
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

struct PanelNavigationRow: View {
    let title: String
    let subtitle: String?
    let showsChevron: Bool
    private let icon: AnyView
    private let trailingContent: AnyView

    init<Icon: View, Trailing: View>(
        title: String,
        subtitle: String? = nil,
        showsChevron: Bool = true,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsChevron = showsChevron
        self.icon = AnyView(icon())
        self.trailingContent = AnyView(trailing())
    }

    init<Icon: View>(
        title: String,
        subtitle: String? = nil,
        showsChevron: Bool = true,
        @ViewBuilder icon: () -> Icon
    ) {
        self.init(title: title, subtitle: subtitle, showsChevron: showsChevron, icon: icon) {
            EmptyView()
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            PanelIconTile {
                icon
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            trailingContent

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct PanelHintCard: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    init(title: String, message: String, systemImage: String, tint: Color = .accentColor) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PanelIconTile {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
