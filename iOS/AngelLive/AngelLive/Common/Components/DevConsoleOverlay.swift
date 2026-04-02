//
//  DevConsoleOverlay.swift
//  AngelLive
//
//  Created by pangchong on 2026/4/2.
//

import SwiftUI
import AngelLiveCore

// MARK: - 管理器：直接添加到 keyWindow 上

@MainActor
final class DevConsoleWindowManager {

    static let shared = DevConsoleWindowManager()

    private var overlayWindow: DevConsolePassthroughWindow?

    private init() {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.syncVisibility() }
        }
    }

    func setup() {
        syncVisibility()
    }

    private func syncVisibility() {
        let enabled = UserDefaults.shared.bool(forKey: GeneralSettingModel.globalDeveloperMode)
        if enabled {
            show()
        } else {
            hide()
        }
    }

    private func show() {
        guard overlayWindow == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        let window = DevConsolePassthroughWindow(windowScene: scene)
        window.windowLevel = .alert + 100
        window.backgroundColor = .clear
        window.isHidden = false

        let container = DevConsoleContainerView(frame: window.bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let rootVC = DevConsolePassthroughViewController()
        rootVC.view.addSubview(container)
        window.rootViewController = rootVC

        overlayWindow = window
    }

    private func hide() {
        guard let window = overlayWindow else { return }
        if let container = window.rootViewController?.view.subviews.first as? DevConsoleContainerView {
            container.dismissPanel()
        }
        window.isHidden = true
        window.rootViewController = nil
        overlayWindow = nil
    }
}

// MARK: - 透传触摸的 Window 和 ViewController

/// 独立窗口：不在触摸区域内的事件透传到下层窗口
private class DevConsolePassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        // 如果命中的是 rootVC 的 view 本身，说明没有子视图响应，透传
        return hit === rootViewController?.view ? nil : hit
    }
}

/// 根控制器：透明背景，不影响状态栏
private class DevConsolePassthroughViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    // 不影响下层的状态栏样式
    override var prefersStatusBarHidden: Bool { false }
    override var preferredStatusBarStyle: UIStatusBarStyle { .default }
}

// MARK: - 容器视图（透传触摸 + 管理按钮和面板）

private class DevConsoleContainerView: UIView {

    private let floatingButton = UIButton(type: .custom)
    private var buttonCenter: CGPoint = .zero
    private var isPanelOpen = false

    private var dimmingView: UIView?
    private var panelHosting: UIHostingController<AnyView>?

    // iOS 26 Liquid Glass 效果层
    private var glassBackgroundView: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
        setupFloatingButton()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        if buttonCenter == .zero {
            buttonCenter = CGPoint(
                x: 28 + 4,
                y: bounds.height - safeAreaInsets.bottom - 80
            )
            floatingButton.center = buttonCenter
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in subviews.reversed() where !subview.isHidden && subview.alpha > 0.01 {
            let converted = subview.convert(point, from: self)
            if let hit = subview.hitTest(converted, with: event) {
                return hit
            }
        }
        return nil
    }

    // MARK: - 浮动按钮

    private func setupFloatingButton() {
        let size: CGFloat = 52
        floatingButton.frame = CGRect(x: 0, y: 0, width: size, height: size)
        floatingButton.clipsToBounds = false

        if #available(iOS 26.0, *) {
            // iOS 26: 使用系统风格，让 Liquid Glass 自动生效
            floatingButton.configuration = {
                var config = UIButton.Configuration.plain()
                config.image = UIImage(
                    systemName: "ladybug.fill",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
                )
                config.baseForegroundColor = .white
                config.background.backgroundColor = .systemRed
                config.cornerStyle = .capsule
                return config
            }()
            floatingButton.layer.cornerRadius = size / 2
            // 阴影
            floatingButton.layer.shadowColor = UIColor.black.cgColor
            floatingButton.layer.shadowOpacity = 0.25
            floatingButton.layer.shadowOffset = CGSize(width: 0, height: 3)
            floatingButton.layer.shadowRadius = 10
        } else {
            // iOS 17-25: 手动渐变 + 阴影
            floatingButton.layer.cornerRadius = size / 2

            let gradient = CAGradientLayer()
            gradient.frame = CGRect(x: 0, y: 0, width: size, height: size)
            gradient.cornerRadius = size / 2
            gradient.colors = [
                UIColor.systemRed.cgColor,
                UIColor.systemRed.withAlphaComponent(0.8).cgColor
            ]
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            floatingButton.layer.insertSublayer(gradient, at: 0)

            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
            floatingButton.setImage(UIImage(systemName: "ladybug.fill", withConfiguration: config), for: .normal)
            floatingButton.tintColor = .white

            floatingButton.layer.shadowColor = UIColor.black.cgColor
            floatingButton.layer.shadowOpacity = 0.3
            floatingButton.layer.shadowOffset = CGSize(width: 0, height: 4)
            floatingButton.layer.shadowRadius = 8
        }

        floatingButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        floatingButton.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))

        addSubview(floatingButton)
    }

    // MARK: - 按钮交互

    @objc private func buttonTapped() {
        isPanelOpen ? dismissPanel() : showPanel()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)

        switch gesture.state {
        case .began:
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
                self.floatingButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
        case .changed:
            floatingButton.center = CGPoint(
                x: buttonCenter.x + translation.x,
                y: buttonCenter.y + translation.y
            )
        case .ended, .cancelled:
            let raw = CGPoint(
                x: buttonCenter.x + translation.x,
                y: buttonCenter.y + translation.y
            )
            let snapped = snapToEdge(raw)
            buttonCenter = snapped
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.8) {
                self.floatingButton.center = snapped
                self.floatingButton.transform = .identity
            }
        default: break
        }
    }

    private func snapToEdge(_ center: CGPoint) -> CGPoint {
        let half: CGFloat = 28
        let pad: CGFloat = 4
        let minX = half + pad
        let maxX = bounds.width - half - pad
        let minY = safeAreaInsets.top + half + pad
        let maxY = bounds.height - safeAreaInsets.bottom - half - pad

        return CGPoint(
            x: center.x < bounds.width / 2 ? minX : maxX,
            y: min(max(center.y, minY), maxY)
        )
    }

    // MARK: - 面板

    func showPanel() {
        guard !isPanelOpen else { return }
        isPanelOpen = true

        UIView.animate(withDuration: 0.2) {
            self.floatingButton.alpha = 0
            self.floatingButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }

        // 遮罩
        let dimming = UIView(frame: bounds)
        dimming.backgroundColor = .black.withAlphaComponent(0.35)
        dimming.alpha = 0
        dimming.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimming.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleDismiss)))
        insertSubview(dimming, belowSubview: floatingButton)
        self.dimmingView = dimming

        // SwiftUI 面板
        let panel = ConsolePanel(
            consoleService: PluginConsoleService.shared,
            onDismiss: { [weak self] in self?.dismissPanel() }
        )
        let hosting = UIHostingController(rootView: AnyView(panel))
        hosting.view.backgroundColor = .clear

        let parentVC = findViewController()
        parentVC?.addChild(hosting)
        addSubview(hosting.view)
        hosting.didMove(toParent: parentVC)

        let panelHeight = bounds.height * 0.5
        hosting.view.frame = CGRect(
            x: 6, y: bounds.height,
            width: bounds.width - 12, height: panelHeight
        )
        self.panelHosting = hosting

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5) {
            dimming.alpha = 1
            hosting.view.frame.origin.y = self.bounds.height - panelHeight - self.safeAreaInsets.bottom
        }
    }

    @objc private func handleDismiss() {
        dismissPanel()
    }

    func dismissPanel() {
        guard isPanelOpen else { return }
        isPanelOpen = false

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            self.dimmingView?.alpha = 0
            self.panelHosting?.view.frame.origin.y = self.bounds.height
        } completion: { _ in
            self.dimmingView?.removeFromSuperview()
            self.dimmingView = nil
            self.panelHosting?.willMove(toParent: nil)
            self.panelHosting?.view.removeFromSuperview()
            self.panelHosting?.removeFromParent()
            self.panelHosting = nil
        }

        UIView.animate(withDuration: 0.35, delay: 0.1, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.8) {
            self.floatingButton.alpha = 1
            self.floatingButton.transform = .identity
        }
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }
}

// MARK: - SwiftUI 控制台面板

private struct ConsolePanel: View {
    let consoleService: PluginConsoleService
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // 顶部把手（可拖拽关闭）
            panelHandle

            // 标题栏
            panelHeader

            // 日志列表
            if consoleService.entries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .modifier(PanelBackgroundModifier())
        .offset(y: max(0, dragOffset))
    }

    private var panelHandle: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(.secondary.opacity(0.5))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        if value.translation.height > 100 || value.predictedEndTranslation.height > 200 {
                            onDismiss()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
            )
    }

    private var panelHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "ladybug.fill")
                .font(.system(size: 16))
                .foregroundStyle(.red)

            Text("插件控制台")
                .font(.system(.headline, design: .rounded))

            Spacer()

            if !consoleService.entries.isEmpty {
                headerButton(icon: "trash", action: {
                    withAnimation { consoleService.clear() }
                })
            }

            headerButton(icon: "xmark", action: onDismiss)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func headerButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: icon == "xmark" ? 10 : 13, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
        .modifier(HeaderButtonStyleModifier())
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            Text("暂无插件调用记录")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            Text("插件运行时日志将在此显示")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var entryList: some View {
        List {
            ForEach(consoleService.entries) { entry in
                ConsoleEntryRow(entry: entry)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(.secondary.opacity(0.15))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - iOS 26 适配 Modifier

/// 面板背景：iOS 26 使用 glassEffect，低版本使用 ultraThinMaterial
private struct PanelBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 24, y: -6)
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
        }
    }
}

/// 头部按钮样式：iOS 26 使用 glass circle，低版本使用 ultraThinMaterial
private struct HeaderButtonStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(.ultraThinMaterial, in: Circle())
                .glassEffect(in: Circle())
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}

// MARK: - 共享时间格式

private let consoleTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()

// MARK: - 日志条目行

private struct ConsoleEntryRow: View {
    let entry: PluginConsoleEntry
    @State private var showDetail = false

    var body: some View {
        Button {
            if entry.status != .loading {
                showDetail = true
            }
        } label: {
            HStack(spacing: 10) {
                // 左侧状态指示条
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(statusColor)
                    .frame(width: 3, height: 36)

                // 标题区域
                VStack(alignment: .leading, spacing: 4) {
                    // 标题：[tag] 插件名 · 方法名
                    HStack(spacing: 6) {
                        Text(entry.tag)
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(statusColor.opacity(0.85), in: Capsule())

                        Text(entry.method)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    // 副标题：时间 + 耗时
                    HStack(spacing: 6) {
                        Text(consoleTimeFormatter.string(from: entry.timestamp))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)

                        if let duration = entry.duration {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(String(format: "%.0fms", duration * 1000))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                // 右侧：状态标签 + 详情箭头
                HStack(spacing: 8) {
                    statusBadge

                    if entry.status != .loading {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            ConsoleEntryDetailView(entry: entry)
        }
    }

    private var statusColor: Color {
        switch entry.status {
        case .loading: .orange
        case .success: .green
        case .error: .red
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch entry.status {
        case .loading:
            ProgressView().controlSize(.small)
        case .success:
            Text("成功")
                .font(.system(.caption2, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.green.opacity(0.12), in: Capsule())
        case .error:
            Text("失败")
                .font(.system(.caption2, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.red.opacity(0.12), in: Capsule())
        }
    }
}

// MARK: - 条目详情页

private struct ConsoleEntryDetailView: View {
    let entry: PluginConsoleEntry
    @Environment(\.dismiss) private var dismiss
    @State private var copiedIndex: Int? = nil

    var body: some View {
        NavigationStack {
            List {
                // 基本信息
                Section("基本信息") {
                    row("插件", entry.tag)
                    row("方法", entry.method)
                    row("时间", consoleTimeFormatter.string(from: entry.timestamp))
                    if let duration = entry.duration {
                        row("耗时", String(format: "%.1fms", duration * 1000))
                    }
                    HStack {
                        Text("状态")
                            .foregroundStyle(.secondary)
                        Spacer()
                        statusLabel
                    }
                }

                // 插件调用参数
                if let body = entry.requestBody, !body.isEmpty, body != "{}" {
                    Section("调用参数") {
                        Text(prettyJSON(body))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                // 插件返回结果 / 错误
                if let response = entry.responseBody {
                    Section("返回数据") {
                        Text(prettyJSON(response))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(50)
                    }
                }

                if let error = entry.errorMessage {
                    Section("错误信息") {
                        Text(error)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }

                // HTTP 请求记录
                ForEach(Array(entry.httpRecords.enumerated()), id: \.element.id) { index, record in
                    httpRecordSection(record, index: index)
                }
            }
            .navigationTitle("\(entry.tag).\(entry.method)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: - HTTP 请求段

    @ViewBuilder
    private func httpRecordSection(_ record: PluginConsoleHTTPRecord, index: Int) -> some View {
        let isCopied = copiedIndex == index

        Section {
            // URL + Method
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(record.method)
                        .font(.system(.caption2, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(.blue.opacity(0.8), in: Capsule())

                    if let code = record.statusCode {
                        Text("\(code)")
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(httpStatusColor(code).opacity(0.8), in: Capsule())
                    }

                    if let duration = record.duration {
                        Text(String(format: "%.0fms", duration * 1000))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(record.url)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(3)
            }

            // 请求头
            DisclosureGroup("请求头") {
                ForEach(record.headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(key)
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                }
            }
            .font(.system(.caption, design: .rounded))

            // 请求体
            if let body = record.body, !body.isEmpty {
                DisclosureGroup("请求体") {
                    Text(prettyJSON(body))
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }
                .font(.system(.caption, design: .rounded))
            }

            // 响应头
            if let respHeaders = record.responseHeaders, !respHeaders.isEmpty {
                DisclosureGroup("响应头") {
                    ForEach(respHeaders.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(key)
                                .font(.system(.caption2, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(value)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(2)
                        }
                    }
                }
                .font(.system(.caption, design: .rounded))
            }

            // 响应体
            if let respBody = record.responseBody {
                DisclosureGroup("响应体") {
                    Text(prettyJSON(respBody))
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(30)
                }
                .font(.system(.caption, design: .rounded))
            }

            // 错误
            if let error = record.error {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.red)
            }

            // 复制 cURL
            Button {
                UIPasteboard.general.string = buildCurl(for: record)
                copiedIndex = index
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedIndex == index { copiedIndex = nil }
                }
            } label: {
                HStack {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    Text(isCopied ? "已复制" : "复制 cURL")
                }
                .font(.system(.caption))
                .foregroundStyle(isCopied ? .green : .accentColor)
                .frame(maxWidth: .infinity)
            }
        } header: {
            Text("HTTP 请求 #\(index + 1)")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var statusLabel: some View {
        switch entry.status {
        case .loading:
            Label("加载中", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.orange)
        case .success:
            Label("成功", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .error:
            Label("失败", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
        }
    }

    private func httpStatusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: .green
        case 300..<400: .orange
        default: .red
        }
    }

    private func prettyJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            return raw
        }
        return str
    }

    /// 从真实 HTTP 请求构造 cURL（含 Cookie、所有请求头）
    private func buildCurl(for record: PluginConsoleHTTPRecord) -> String {
        let escaped = { (s: String) in s.replacingOccurrences(of: "'", with: "'\\''") }
        var parts = ["curl -X \(record.method) '\(escaped(record.url))'"]

        for (key, value) in record.headers.sorted(by: { $0.key < $1.key }) {
            parts.append("  -H '\(key): \(escaped(value))'")
        }

        if let body = record.body, !body.isEmpty {
            parts.append("  -d '\(escaped(body))'")
        }

        return parts.joined(separator: " \\\n")
    }
}

// MARK: - SwiftUI 入口

struct DevConsoleOverlay: View {
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { DevConsoleWindowManager.shared.setup() }
    }
}
