//
//  ContentView.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2023/6/26.
//

import SwiftUI
import Kingfisher
import GameController
import LiveParse
import Network
import UDPBroadcast
import Foundation
import Darwin

struct ContentView: View {
    
    var appViewModel = SimpleLiveViewModel()
    var searchLiveViewModel: LiveViewModel
    var favoriteLiveViewModel: LiveViewModel

    init() {
        searchLiveViewModel = LiveViewModel(roomListType: .search, liveType: .bilibili, favoriteModel: appViewModel.favoriteModel, danmuSettingModel: appViewModel.danmuSettingModel)
        favoriteLiveViewModel = LiveViewModel(roomListType: .favorite, liveType: .bilibili, favoriteModel: appViewModel.favoriteModel, danmuSettingModel: appViewModel.danmuSettingModel)
    }
    
    var body: some View {
        
        @Bindable var contentVM = appViewModel
        
        NavigationView {
            TabView(selection:$contentVM.selection) {
                FavoriteMainView()
                    .tabItem {
                        if appViewModel.favoriteModel.isLoading == true || appViewModel.favoriteModel.cloudKitReady == false {
                            Label(
                                title: {  },
                                icon: {
                                    Image(systemName: appViewModel.favoriteModel.isLoading == true ? "arrow.triangle.2.circlepath.icloud" : appViewModel.favoriteModel.cloudKitReady == true ? "checkmark.icloud" : "exclamationmark.icloud" )
                                }
                            )
                            .contentTransition(.symbolEffect(.replace))
                        }else {
                            Text("收藏")
                        }
                    }
                    .tag(0)
                    .environment(favoriteLiveViewModel)
                
//                PlatformView()
//                    .tabItem {
//                        Text("平台")
//                    }
//                    .tag(1)
                    
                
//                SearchRoomView()
//                    .tabItem {
//                        Text("搜索")
//                    }
//                    .tag(2)
//                    .environment(searchLiveViewModel)

                
//                SettingView()
//                    .tabItem {
//                        Text("设置")
//                    }
//                .tag(3)

            }
        }
        .onAppear {
            Task {
                try await Douyin.getRequestHeaders()
            }
        }
        .simpleToast(isPresented: $contentVM.showToast, options: appViewModel.toastOptions) {
            VStack(alignment: .leading) {
                Label("提示", systemImage: appViewModel.toastTypeIsSuccess ? "checkmark.circle" : "xmark.circle")
                    .font(.headline.bold())
                Text(appViewModel.toastTitle)
            }
            .padding()
            .background(.black.opacity(0.6))
            .foregroundColor(Color.white)
            .cornerRadius(10)
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


