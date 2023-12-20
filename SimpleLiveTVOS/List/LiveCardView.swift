//
//  LiveCardView.swift
//  SimpleLiveTVOS
//
//  Created by pangchong on 2023/10/9.
//

import SwiftUI
import Kingfisher
import KSPlayer
import LiveParse

struct LiveCardView: View {
    @EnvironmentObject var liveListViewModel: LiveListViewModel
    @State var index: Int
//    @Binding var liveModel: LiveModel
//    @FocusState var mainContentfocusState: Int?
//    @State var isFavoritePage = false
    @State private var showAlert = false
    @State private var isCellVisible: Bool = false
    @State private var favorited: Bool = false
    @State private var isLive: Bool = false
    var showLoading: (String) -> Void = { _ in }
    var showToast: (Bool, Bool, String) -> Void = { _,_,_   in }
    @FocusState var focusState: FocusableField?
    
    var body: some View {
        Button {
            
            Task {
                do {
                    if try await self.liveListViewModel.getCurrentRoomLiveState() == .live {
                        try await self.liveListViewModel.getPlayArgs()
                        DispatchQueue.main.async {
                            isLive = true
                        }
                    }else {
                        DispatchQueue.main.async {
                            isLive = false
                        }
                    }
                }catch {
                    DispatchQueue.main.async {
                        isLive = false
                    }
                }
            }
//            if isFavoritePage == true && (liveModel.liveState == "正在直播" || liveModel.liveState == "视频轮播" || liveModel.liveState == "轮播中") {
//
//            }else if isFavoritePage == false {
//                isLive = true
//            }else {
//                self.showToast(false, false, "该主播正在休息哦")
//                isLive = false
//            }
        } label: {
            VStack(spacing: 10, content: {
                ZStack(alignment: Alignment(horizontal: .leading, vertical: .top), content: {
                    if isCellVisible {
                        KFImage(URL(string: liveListViewModel.roomList[index].roomCover))
                            .resizable()
                            .frame(width: 360, height: 180)
                            
                    }
//                    if isFavoritePage {
//                        HStack{
//                            Image(uiImage: .init(named: getImage())!)
//                                .resizable()
//                                .frame(width: 40, height: 40)
//                                .cornerRadius(5)
//                                .padding(.top, 5)
//                                .padding(.leading, 5)
//                            Spacer()
//                            HStack(spacing: 5) {
//                                
//                                if liveModel.liveState ?? "" == "" {
//                                    ProgressView()
//                                        .scaleEffect(0.5)
//                                }else {
//                                    HStack(spacing: 5) {
//                                        Circle()
//                                            .fill((liveModel.liveState == "正在直播" || liveModel.liveState == "视频轮播" || liveModel.liveState == "轮播中") ? Color.green : Color.gray)
//                                            .frame(width: 10, height: 10)
//                                            .padding(.leading, 5)
//                                        Text(liveModel.liveState ?? "")
//                                            .font(.system(size: 18))
//                                            .foregroundColor(Color.white)
//                                            .padding(.trailing, 5)
//                                            .padding(.top, 5)
//                                            .padding(.bottom, 5)
//                                    }
//                                    .background(Color("favorite_right_hint"))
//                                    .clipShape(RoundedRectangle(cornerRadius: 5))
//                                    
//                                }
//                            }
//                            .padding(.trailing, 5)
//                        }
//                        .task {
//                            do {
//                                if self.isFavoritePage == true {
//                                    if liveModel == nil {
//                                        return
//                                    }
////                                    try await liveModel.getLiveState()
//                                }
//                            }catch {
//                                
//                            }
//                        }
//                    }
                })
                HStack {
                    if isCellVisible {
                        KFImage(URL(string: liveListViewModel.roomList[index].userHeadImg))
                                .resizable()
                                .frame(width: 40, height: 40)
                                .cornerRadius(20)
                    }
                    VStack (alignment: .leading, spacing: 10) {
                        Text(liveListViewModel.roomList[index].userName)
                            .font(.system(size: liveListViewModel.roomList[index].userName.count > 5 ? 19 : 24))
                            .padding(.top, 10)
                            .frame(width: 200, height: liveListViewModel.roomList[index].userName.count > 5 ? 19 : 24, alignment: .leading)
                        Text(liveListViewModel.roomList[index].roomTitle)
                            .font(.system(size: 15))
                            .frame(width: 200, height: 15 ,alignment: .leading)
                    }
                    .padding(.trailing, 0)
                    .padding(.leading, -35)
                   
                }
                Spacer(minLength: 0)
            })
            
        }
        .buttonStyle(.card)
//        .focused($mainContentfocusState, equals: index)
        .focused($focusState, equals: .mainContent(index))
        .onChange(of: focusState, perform: { value in
            liveListViewModel.currentRoom = liveListViewModel.roomList[index]
    
            if focusState == .mainContent(0) {
                liveListViewModel.showOverlay = false
            }else {
                liveListViewModel.showOverlay = true
                focusState = .leftMenu(0)
            }

        })
        .alert("提示", isPresented: $showAlert) {
            Button("取消收藏", role: .destructive, action: {
                Task {
                    await cancelFavoriteAction()
                }
            })
            Button("再想想",role: .cancel) {
                showAlert = false
            }
        } message: {
            Text("确认取消收藏吗")
        }
        .contextMenu(menuItems: {
            if favorited {
                Button(action: {
                    showAlert = true
                }, label: {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("取消收藏")
                    }
                })
                
            }else {
                Button(action: {
                    Task {
                        await favoriteAction()
                    }
                }, label: {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("收藏")
                    }
                })
            }
        })
        .onAppear {
            self.isCellVisible = true
        }
        .onDisappear {
            self.isCellVisible = false
//            ImageCache.default.clearMemoryCache()
        }
        .task {
            do {
                await getFavoriteState()
            }catch {
                
            }
        }
        .fullScreenCover(isPresented: $isLive, content: {
////            KSAudioView(roomModel: liveModel) { needShowHint, hintString in
////                isLive = false
////                if needShowHint {
////                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
////                        self.showToast(false, false, hintString)
////                    }
////                }
////            }
            DetailPlayerView(url: liveListViewModel.currentPlayURL!.absoluteString, didExitView: { isLive, hint in
                self.isLive = isLive
            })
                .environmentObject(liveListViewModel)
                .edgesIgnoringSafeArea(.all)
        })
    }
    
    func favoriteAction() async {
        do {
            self.showLoading("正在收藏")
//            try await CloudSQLManager.saveRecord(liveModel: liveListViewModel.roomList[index])
            self.showToast(true, false, "收藏成功")
        }catch {
            print(error)
            self.showToast(false, false, "收藏失败，错误码：\(error.localizedDescription)")
        }
       
    }
    
    func getFavoriteState() async {
        do {
//            favorited = try await CloudSQLManager.searchRecord(roomId: liveModel.roomId).count > 0
        }catch {
//            favorited = false
        }
    }
    
    func cancelFavoriteAction() async {
//        if SQLiteManager.manager.delete(roomId: liveModel.roomId) {
//            self.showToast(true, true, "取消收藏成功")
//        }else {
//            self.showToast(false, true, "取消收藏失败")
//        }
        do {
            self.showLoading("正在取消收藏")
//            try await CloudSQLManager.deleteRecord(liveModel: liveModel)
            self.showToast(true, true, "取消收藏成功")
        }catch {
            self.showToast(false, true, "取消收藏失败")
        }
    }
    
//    func getImage() -> String {
//        switch liveModel.liveType {
//            case .bilibili:
//                return "bilibili_2"
//            case .douyu:
//                return "douyu"
//            case .huya:
//                return "huya"
//            default:
//                return "douyin"
//        }
//    }
}
