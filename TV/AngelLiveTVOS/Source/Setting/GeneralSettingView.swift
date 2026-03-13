//
//  PlaySettingView.swift
//  SimpleLiveTVOS
//
//  Created by pangchong on 2024/9/21.
//

import SwiftUI
import AngelLiveCore
import AngelLiveDependencies

struct GeneralSettingView: View {
    
    @Environment(AppState.self) var appViewModel
    @FocusState var focused: Bool
    @StateObject var settingStore = SettingStore()
    
    var body: some View {

        @Bindable var playerSettingModel = appViewModel.playerSettingsViewModel
        @Bindable var generalSettingModel = appViewModel.generalSettingsViewModel

        VStack(spacing: 50) {
            Spacer()

            Toggle(isOn: $playerSettingModel.openExitPlayerViewWhenLiveEnd) {
                Text("直播结束后自动退出直播间（不推荐）")
                    .foregroundColor(.primary)
            }
                .frame(height: 45)
                .focused($focused)

            if playerSettingModel.openExitPlayerViewWhenLiveEnd {
                HStack {
                    Text("自动退出直播间时间：")
                        .foregroundColor(.primary)
                    Spacer()
                    Menu(content: {
                        ForEach(PlayerSettingModel.timeArray.indices, id: \.self) { index in
                            Button(PlayerSettingModel.timeArray[index]) {
                                playerSettingModel.getTimeSecond(index: index)
                            }
                        }
                    }, label: {
                        Text("\(PlayerSettingModel.timeArray[playerSettingModel.openExitPlayerViewWhenLiveEndSecondIndex])")
                            .foregroundColor(.primary)
                            .frame(width: 250, alignment: .center)
                    })
                }
                .frame(height: 45)
            }

            Toggle(isOn: $settingStore.syncSystemRate) {
                Text("匹配系统帧率")
                    .foregroundColor(.primary)
            }
                .frame(height: 45)

            Toggle(isOn: $generalSettingModel.generalDisableMaterialBackground) {
                Text("禁用渐变背景")
                    .foregroundColor(.primary)
            }
                .frame(height: 45)

            Text("如果您的页面部分背景不正常（如页面背景透明）,请尝试打开这个选项。")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(height: 45)

            Spacer()
        }
    }
}
