//
//  DouyinMainView.swift
//  SimpleLiveTVOS
//
//  Created by pangchong on 2023/9/14.
//

import SwiftUI
import Kingfisher

struct DouyinMainView: View {
    
    @State private var mainList = [DouyinCategoryData]()
    @State private var size: CGFloat = leftMenuNormalStateWidth
    @State private var leftMenuCurrentSelectIndex = -1
    @State private var leftMenuShowSubList = false
    @FocusState var focusState: FocusAreas?
    @FocusState var mainContentfocusState: Int?
    @State private var roomContentArray: Array<LiveModel> = []
    @State private var page = 1
    @State private var currentCategoryModel: DouyinCategoryData?
    
    var body: some View {
        HStack {
            LeftMenu(liveType: .douyin, size: $size, currentIndex: $leftMenuCurrentSelectIndex, isShowSubList: $leftMenuShowSubList, leftMenuDidClick: { _, _, categoryModel in
                page = 1
                currentCategoryModel = categoryModel as? DouyinCategoryData
                getRoomList()
            })
                .cornerRadius(20)
                .focused($focusState, equals: .leftMenu)
            ScrollView {
                LazyVGrid(columns: [GridItem(.fixed(360)), GridItem(.fixed(360)), GridItem(.fixed(360)), GridItem(.fixed(360))], spacing: 35) {
                    ForEach(roomContentArray.indices, id: \.self) { index in
                        LiveCardView(liveModel: $roomContentArray[index], mainContentfocusState: _mainContentfocusState, index: index)
                    }
                }
            }
        }
        .onChange(of: focusState, perform: { newFocus in
            if newFocus == .leftMenu {
                withAnimation {
                    size = leftMenuHighLightStateWidth
                }
            }else {
                withAnimation {
                    size = leftMenuNormalStateWidth
                    leftMenuCurrentSelectIndex = -1
                    leftMenuShowSubList = false
                }
            }
        })
        .onChange(of: mainContentfocusState, perform: { newValue in
            if newValue ?? 0 > self.roomContentArray.count - 6 {
                page += 1
                getRoomList()
            }
        })
        .onAppear {
            Task {
                do {
                   
                    self.mainList = try await Douyin.getDouyinList()
                }catch {
                    print(error)
                }
            }
        }
    }
    
    func getRoomList() {
        Task {
            do {
               
            }catch {
                print("-----error:\(error)")
            }
        }
    }
}

struct DouyinMainView_Previews: PreviewProvider {
    static var previews: some View {
        DouyinMainView()
    }
}
