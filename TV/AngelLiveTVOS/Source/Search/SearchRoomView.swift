 //
//  SearchRoomView.swift
//  SimpleLiveTVOS
//
//  Created by pangchong on 2023/11/30.
//

import SwiftUI
import AngelLiveDependencies

struct SearchRoomView: View {
    
    @FocusState var focusState: Int?
    @Environment(LiveViewModel.self) var liveViewModel
    @Environment(AppState.self) var appViewModel
    
    var body: some View {
        
        @Bindable var appModel = appViewModel
        @Bindable var liveModel = liveViewModel

        HStack(alignment: .top, spacing: 0) {
            // 左侧：搜索主体
            VStack {
            Text("请输入要搜索的主播名或平台链接/分享口令/房间号")
            HStack {
                Picker(selection: $appModel.searchViewModel.searchTypeIndex) {
                    ForEach(liveViewModel.searchTypeArray.indices, id: \.self) { index in
                        // 需要有一个变量text。不然会自动帮忙加很多0
                        let text = liveViewModel.searchTypeArray[index]
                        Text(text)
                    }
                } label: {
                    Text("字体大小")
                }
            }
            TextField("搜索", text: $appModel.searchViewModel.searchText)
            .onSubmit {
                Task {
                    await MainActor.run {
                        liveViewModel.roomPage = 1
                    }

                    if appModel.searchViewModel.searchTypeIndex == 1 {
                        // 关键词搜索
                        await liveViewModel.searchRoomWithText(text: appModel.searchViewModel.searchText)
                    } else {
                        // 链接/口令搜索
                        await liveViewModel.searchRoomWithShareCode(text: appModel.searchViewModel.searchText)
                    }
                }
            }
            Spacer()
            if liveViewModel.hasError, let error = liveViewModel.currentError {
                    ErrorView(
                        title: error.isBilibiliAuthRequired ? "搜索失败-请登录B站账号并检查官方页面" : "搜索失败",
                        message: error.liveParseMessage,
                        detailMessage: error.liveParseDetail,
                        curlCommand: error.liveParseCurl,
                        showRetry: true,
                        showLoginButton: error.isBilibiliAuthRequired,
                        onDismiss: {
                            liveViewModel.hasError = false
                            liveViewModel.currentError = nil
                        },
                        onRetry: {
                            liveViewModel.hasError = false
                            liveViewModel.currentError = nil
                            Task {
                                if appModel.searchViewModel.searchTypeIndex == 1 {
                                    // 关键词搜索
                                    await liveViewModel.searchRoomWithText(text: appModel.searchViewModel.searchText)
                                } else {
                                    // 链接/口令搜索
                                    await liveViewModel.searchRoomWithShareCode(text: appModel.searchViewModel.searchText)
                                }
                            }
                        }
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.fixed(370), spacing: 50), GridItem(.fixed(370), spacing: 50), GridItem(.fixed(370), spacing: 50), GridItem(.fixed(370), spacing: 50)], alignment: .center, spacing: 50) {
                        ForEach(liveViewModel.roomList.indices, id: \.self) { index in
                            LiveCardView(index: index)
                                .environment(liveViewModel)
                                .frame(width: 370, height: 280)
                        }
                        if liveViewModel.isLoading {
                            LoadingView()
                                .frame(width: 370, height: 280)
                                .cornerRadius(5)
                                .shimmering(active: true)
                                .redacted(reason: .placeholder)
                        }
                    }
                    .safeAreaPadding(.top, 50)
                    }
                }
            } // 左侧 VStack 结束

            // 右侧：扫码输入面板
            searchQRPanel
        } // HStack 结束
        .simpleToast(isPresented: $liveModel.showToast, options: liveModel.toastOptions) {
            VStack(alignment: .leading) {
                Label("提示", systemImage: liveModel.toastTypeIsSuccess ? "checkmark.circle" : "xmark.circle")
                    .font(.headline.bold())
                Text(liveModel.toastTitle)
            }
            .padding()
            .background(.black.opacity(0.6))
            .foregroundColor(Color.white)
            .cornerRadius(10)
        }
        .onPlayPauseCommand(perform: {
            liveViewModel.getRoomList(index: 1)
        })
        .onChange(of: appViewModel.remoteInputService.lastEvent?.value) {
            guard let event = appViewModel.remoteInputService.lastEvent,
                  event.field == .search else { return }
            appModel.searchViewModel.searchText = event.value
        }
    }

    // MARK: - 搜索页远程输入二维码面板

    private var searchQRPanel: some View {
        let service = appViewModel.remoteInputService
        let url = "http://\(service.localIPAddress):\(service.port)/search"
        return VStack(spacing: 16) {
            Spacer()
            if service.isRunning && !service.localIPAddress.isEmpty {
                Image(uiImage: Common.generateQRCode(from: url))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 14)
                Text("扫码用手机输入")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(url)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            } else {
                ProgressView()
                Text("正在启动远程输入...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(width: 320)
        .padding(.trailing, 40)
    }
}
