import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct PluginSourceErrorCard: View {
    private let title: String
    private let rawMessage: String
    private let parsedMessage: ParsedPluginSourceErrorMessage

    @State private var isResponseExpanded = false
    @State private var didCopy = false

    public init(title: String = "插件源异常", message: String) {
        self.title = title
        self.rawMessage = message
        self.parsedMessage = ParsedPluginSourceErrorMessage(message: message)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            headerSection

            if !parsedMessage.details.isEmpty {
                separator

                VStack(alignment: .leading, spacing: detailSpacing) {
                    ForEach(parsedMessage.details) { detail in
                        detailSection(detail)
                    }
                }
            }
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.24), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var headerSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: headerSpacing) {
                headerContent
                Spacer(minLength: headerSpacing)
                copyButton
            }

            VStack(alignment: .leading, spacing: sectionSpacing) {
                headerContent
                copyButton
            }
        }
    }

    private var headerContent: some View {
        HStack(alignment: .top, spacing: headerSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(iconFont)
                .foregroundStyle(.orange)
                .frame(width: iconFrameSize, height: iconFrameSize)
                .background(Color.orange.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: textSpacing) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(.primary)

                Text(parsedMessage.summary)
                    .font(summaryFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var copyButton: some View {
        Button(action: copyFullMessage) {
            Label(didCopy ? "已复制" : "复制完整错误", systemImage: didCopy ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .controlSize(controlSize)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }

    @ViewBuilder
    private func detailSection(_ detail: PluginSourceErrorDetail) -> some View {
        VStack(alignment: .leading, spacing: detailTextSpacing) {
            Text(detail.label)
                .font(detailLabelFont)
                .foregroundStyle(.secondary)

            if detail.isURL, let url = URL(string: detail.value) {
                Link(destination: url) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(detail.value)
                            .font(detailValueFont)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Image(systemName: "arrow.up.right.square")
                            .font(linkIconFont)
                    }
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if detail.isResponsePreview {
                VStack(alignment: .leading, spacing: detailTextSpacing) {
                    detailValueText(responseText(for: detail.value))

                    if detail.canExpand {
                        Button(isResponseExpanded ? "收起响应片段" : "展开响应片段") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isResponseExpanded.toggle()
                            }
                        }
                        .buttonStyle(.plain)
                        .font(expandButtonFont)
                        .foregroundStyle(.tint)
                    }
                }
            } else {
                detailValueText(detail.value)
            }
        }
    }

    @ViewBuilder
    private func detailValueText(_ value: String) -> some View {
        let text = Text(value)
            .font(detailValueFont)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)

        #if os(tvOS)
        text
        #else
        text.textSelection(.enabled)
        #endif
    }

    private var cardBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    #if os(tvOS)
    private var iconFont: Font { .title3.weight(.semibold) }
    private var titleFont: Font { .title3.weight(.semibold) }
    private var summaryFont: Font { .body }
    private var detailLabelFont: Font { .callout.weight(.semibold) }
    private var detailValueFont: Font { .system(.body, design: .monospaced) }
    private var expandButtonFont: Font { .callout.weight(.semibold) }
    private var linkIconFont: Font { .callout.weight(.semibold) }
    private var iconFrameSize: CGFloat { 52 }
    private var cardPadding: CGFloat { 24 }
    private var cornerRadius: CGFloat { 20 }
    private var headerSpacing: CGFloat { 16 }
    private var sectionSpacing: CGFloat { 16 }
    private var detailSpacing: CGFloat { 14 }
    private var detailTextSpacing: CGFloat { 6 }
    private var textSpacing: CGFloat { 6 }
    private var controlSize: ControlSize { .large }
    #else
    private var iconFont: Font { .title3.weight(.semibold) }
    private var titleFont: Font { .headline }
    private var summaryFont: Font { .subheadline }
    private var detailLabelFont: Font { .caption.weight(.semibold) }
    private var detailValueFont: Font { .system(.footnote, design: .monospaced) }
    private var expandButtonFont: Font { .footnote.weight(.semibold) }
    private var linkIconFont: Font { .caption.weight(.semibold) }
    private var iconFrameSize: CGFloat { 40 }
    private var cardPadding: CGFloat { 16 }
    private var cornerRadius: CGFloat { 16 }
    private var headerSpacing: CGFloat { 12 }
    private var sectionSpacing: CGFloat { 12 }
    private var detailSpacing: CGFloat { 10 }
    private var detailTextSpacing: CGFloat { 4 }
    private var textSpacing: CGFloat { 4 }
    private var controlSize: ControlSize { .small }
    #endif

    private func responseText(for value: String) -> String {
        guard !isResponseExpanded, value.count > PluginSourceErrorDetail.collapsedResponseLimit else {
            return value
        }
        return String(value.prefix(PluginSourceErrorDetail.collapsedResponseLimit)) + "..."
    }

    private func copyFullMessage() {
        Self.copyToPasteboard(rawMessage)
        withAnimation(.easeInOut(duration: 0.2)) {
            didCopy = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 0.2)) {
                didCopy = false
            }
        }
    }

    private static func copyToPasteboard(_ value: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        #else
        UIPasteboard.general.string = value
        #endif
    }
}

struct ParsedPluginSourceErrorMessage {
    let summary: String
    let details: [PluginSourceErrorDetail]

    init(message: String) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let diagnosticsRange = trimmedMessage.range(of: "URL ") else {
            self.summary = trimmedMessage
            self.details = []
            return
        }

        let summaryText = String(trimmedMessage[..<diagnosticsRange.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: "。 ").union(.whitespacesAndNewlines))
        let diagnosticsText = String(trimmedMessage[diagnosticsRange.lowerBound...])

        self.summary = summaryText.isEmpty ? trimmedMessage : summaryText
        self.details = Self.parseDetails(from: diagnosticsText)
    }

    private static func parseDetails(from diagnosticsText: String) -> [PluginSourceErrorDetail] {
        let orderedKeys: [(label: String, start: String, end: String?)] = [
            ("URL", "URL ", ", HTTP "),
            ("HTTP", "HTTP ", ", Content-Type "),
            ("Content-Type", "Content-Type ", ", 响应片段 "),
            ("响应片段", "响应片段 ", nil)
        ]

        return orderedKeys.compactMap { item in
            guard let startRange = diagnosticsText.range(of: item.start) else { return nil }
            let valueStart = startRange.upperBound
            let valueEnd = item.end.flatMap { marker in
                diagnosticsText.range(of: marker, range: valueStart..<diagnosticsText.endIndex)?.lowerBound
            } ?? diagnosticsText.endIndex
            let value = diagnosticsText[valueStart..<valueEnd].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return PluginSourceErrorDetail(label: item.label, value: value)
        }
    }
}

struct PluginSourceErrorDetail: Identifiable {
    static let collapsedResponseLimit = 120

    let label: String
    let value: String

    var id: String { label }
    var isURL: Bool { label == "URL" }
    var isResponsePreview: Bool { label == "响应片段" }
    var canExpand: Bool { isResponsePreview && value.count > Self.collapsedResponseLimit }
}
