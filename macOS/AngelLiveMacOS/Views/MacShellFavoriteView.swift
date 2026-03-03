import SwiftUI
import AngelLiveCore
import AngelLiveDependencies

struct MacShellFavoriteView: View {
    @Environment(StreamBookmarkService.self) private var bookmarkService
    @State private var editingBookmark: StreamBookmark?
    @State private var showDeleteAlert = false
    @State private var bookmarkToDelete: StreamBookmark?
    @State private var playingBookmark: StreamBookmark?

    var body: some View {
        NavigationStack {
            Group {
                if bookmarkService.bookmarks.isEmpty {
                    ContentUnavailableView {
                        Label("暂无收藏", systemImage: "bookmark")
                    } description: {
                        Text("在「配置」页添加网络视频链接后，将在此处显示")
                    }
                } else {
                    List {
                        ForEach(bookmarkService.bookmarks) { bookmark in
                            Button {
                                playBookmark(bookmark)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Text(bookmark.url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)

                                    if let lastPlayed = bookmark.lastPlayedAt {
                                        Text("上次播放: \(lastPlayed.formatted(.relative(presentation: .named)))")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("编辑") {
                                    editingBookmark = bookmark
                                }
                                Button("删除", role: .destructive) {
                                    bookmarkToDelete = bookmark
                                    showDeleteAlert = true
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button("删除", role: .destructive) {
                                    bookmarkToDelete = bookmark
                                    showDeleteAlert = true
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button("编辑") {
                                    editingBookmark = bookmark
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("收藏")
            .task {
                await bookmarkService.syncFromCloud()
            }
            .alert("删除收藏", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    guard let bookmark = bookmarkToDelete else { return }
                    Task {
                        await bookmarkService.remove(bookmark)
                    }
                }
            } message: {
                Text("确定要删除这条收藏吗？")
            }
            .sheet(item: $editingBookmark) { bookmark in
                MacEditBookmarkSheet(bookmark: bookmark, bookmarkService: bookmarkService)
            }
            .sheet(item: $playingBookmark) { bookmark in
                if let url = URL(string: bookmark.url) {
                    MacDirectURLPlayerView(url: url, title: bookmark.title)
                        .frame(minWidth: 900, minHeight: 560)
                }
            }
        }
    }

    private func playBookmark(_ bookmark: StreamBookmark) {
        guard URL(string: bookmark.url) != nil else { return }
        Task { await bookmarkService.updateLastPlayed(bookmark) }
        playingBookmark = bookmark
    }
}

private struct MacEditBookmarkSheet: View {
    let bookmark: StreamBookmark
    let bookmarkService: StreamBookmarkService
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var url: String

    init(bookmark: StreamBookmark, bookmarkService: StreamBookmarkService) {
        self.bookmark = bookmark
        self.bookmarkService = bookmarkService
        _title = State(initialValue: bookmark.title)
        _url = State(initialValue: bookmark.url)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("标题", text: $title)
                TextField("链接", text: $url)
            }
            .navigationTitle("编辑收藏")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var updated = bookmark
                        updated.title = title
                        updated.url = url
                        Task {
                            await bookmarkService.update(updated)
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty || url.isEmpty)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 220)
    }
}

private struct MacDirectURLPlayerView: View {
    let url: URL
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var playerCoordinator = KSVideoPlayer.Coordinator()
    @State private var playerOptions = KSOptions()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            KSVideoPlayer(coordinator: playerCoordinator, url: url, options: playerOptions)
                .ignoresSafeArea()

            HStack {
                Button("关闭") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()
            }
            .padding(16)
        }
        .onAppear {
            playerOptions.userAgent = "libmpv"
            KSOptions.firstPlayerType = KSMEPlayer.self
            KSOptions.secondPlayerType = KSMEPlayer.self
        }
    }
}
