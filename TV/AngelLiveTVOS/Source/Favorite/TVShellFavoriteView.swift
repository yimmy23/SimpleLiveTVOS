import SwiftUI
import AngelLiveCore
import AngelLiveDependencies

struct TVShellFavoriteView: View {
    @Environment(AppState.self) private var appViewModel
    @State private var editingBookmark: StreamBookmark?
    @State private var showDeleteDialog = false
    @State private var bookmarkToDelete: StreamBookmark?
    @State private var playingBookmark: StreamBookmark?

    var body: some View {
        NavigationStack {
            Group {
                if appViewModel.bookmarkService.bookmarks.isEmpty {
                    ContentUnavailableView {
                        Label("暂无收藏", systemImage: "bookmark")
                    } description: {
                        Text("在「配置」页添加网络视频链接后，将在此处显示")
                    }
                } else {
                    List {
                        ForEach(appViewModel.bookmarkService.bookmarks) { bookmark in
                            Button {
                                playBookmark(bookmark)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(bookmark.title)
                                        .font(.title3)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Text(bookmark.url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)

                                    if let lastPlayed = bookmark.lastPlayedAt {
                                        Text("上次播放: \(lastPlayed.formatted(.relative(presentation: .named)))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .contextMenu {
                                Button("编辑") {
                                    editingBookmark = bookmark
                                }
                                Button("删除", role: .destructive) {
                                    bookmarkToDelete = bookmark
                                    showDeleteDialog = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("收藏")
            .task {
                await appViewModel.bookmarkService.syncFromCloud()
            }
            .overlay(alignment: .bottom) {
                if !appViewModel.bookmarkService.bookmarks.isEmpty {
                    Text("长按条目可编辑或删除")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 24)
                }
            }
            .confirmationDialog("删除收藏", isPresented: $showDeleteDialog) {
                Button("删除", role: .destructive) {
                    guard let bookmark = bookmarkToDelete else { return }
                    Task {
                        await appViewModel.bookmarkService.remove(bookmark)
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .sheet(item: $editingBookmark) { bookmark in
                TVEditBookmarkSheet(bookmark: bookmark, bookmarkService: appViewModel.bookmarkService)
            }
            .fullScreenCover(item: $playingBookmark) { bookmark in
                if let url = URL(string: bookmark.url) {
                    TVDirectURLPlayerView(url: url, title: bookmark.title)
                }
            }
        }
    }

    private func playBookmark(_ bookmark: StreamBookmark) {
        guard URL(string: bookmark.url) != nil else { return }
        Task { await appViewModel.bookmarkService.updateLastPlayed(bookmark) }
        playingBookmark = bookmark
    }
}

private struct TVEditBookmarkSheet: View {
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
    }
}

private struct TVDirectURLPlayerView: View {
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

            HStack(spacing: 16) {
                Button("返回") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            playerOptions.userAgent = "libmpv"
            KSOptions.firstPlayerType = KSMEPlayer.self
            KSOptions.secondPlayerType = KSMEPlayer.self
        }
        .onExitCommand {
            dismiss()
        }
    }
}
