//
//  PlatformView.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2024/6/11.
//

import SwiftUI
import AngelLiveDependencies

struct PlatformView: View {
    let column = Array(repeating: GridItem(.fixed(380), spacing: 50), count: 4)
    @State private var platformViewModel = PlatformViewModel()
    @FocusState private var focusIndex: Int?
    @Environment(AppState.self) private var appViewModel
    @State private var show = false
    @State private var selectedIndex = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if appViewModel.pluginAvailability.hasAvailablePlugins {
                platformGridView
            } else {
                TVShellConfigView()
                    .environment(appViewModel)
            }
        }
        .task {
            await appViewModel.pluginAvailability.checkAvailability()
            platformViewModel.refreshPlatforms(installedPluginIds: appViewModel.pluginAvailability.installedPluginIds)
        }
        .onChange(of: appViewModel.pluginAvailability.installedPluginIds) { _, installedPluginIds in
            platformViewModel.refreshPlatforms(installedPluginIds: installedPluginIds)
            if installedPluginIds.isEmpty {
                show = false
            }
        }
    }

    private var platformGridView: some View {
        ScrollView {
            LazyVGrid(columns: column, alignment: .center, spacing: 50) {
                ForEach(platformViewModel.platformInfo.indices, id: \.self) { index in
                    Button {
                        selectedIndex = index
                        show = true
                    } label: {
                        ZStack {
                            Image("platform-bg")
                                .resizable()
                                .frame(width: 370, height: 222)
                            if let bigImage = TVPlatformIconProvider.bigCardImage(
                                for: platformViewModel.platformInfo[index],
                                isDarkMode: colorScheme == .dark
                            ) {
                                Image(uiImage: bigImage)
                                    .resizable()
                                    .frame(width: 370, height: 222)
                                    .animation(.easeInOut(duration: 0.25), value: focusIndex == index)
                                    .blur(radius: focusIndex == index ? 10 : 0)
                            }

                            if appViewModel.generalSettingsViewModel.generalDisableMaterialBackground {
                                ZStack {
                                    if let smallImage = TVPlatformIconProvider.smallCardImage(
                                        for: platformViewModel.platformInfo[index],
                                        isDarkMode: colorScheme == .dark
                                    ) {
                                        Image(uiImage: smallImage)
                                            .resizable()
                                            .frame(width: 370, height: 222)
                                    }
                                    Text(platformViewModel.platformInfo[index].descripiton)
                                        .font(.body)
                                        .multilineTextAlignment(.leading)
                                        .padding([.leading, .trailing], 15)
                                        .padding(.top, 50)

                                }
                                .background(Color("sl-background", bundle: nil))
                                .opacity(focusIndex == index ? 1 : 0)
                                .animation(.easeInOut(duration: 0.25), value: focusIndex == index)
                            } else {
                                ZStack {
                                    if let smallImage = TVPlatformIconProvider.smallCardImage(
                                        for: platformViewModel.platformInfo[index],
                                        isDarkMode: colorScheme == .dark
                                    ) {
                                        Image(uiImage: smallImage)
                                            .resizable()
                                            .frame(width: 370, height: 222)
                                    }
                                    Text(platformViewModel.platformInfo[index].descripiton)
                                        .font(.body)
                                        .multilineTextAlignment(.leading)
                                        .padding([.leading, .trailing], 15)
                                        .padding(.top, 50)

                                }
                                .background(.thinMaterial)
                                .opacity(focusIndex == index ? 1 : 0)
                                .animation(.easeInOut(duration: 0.25), value: focusIndex == index)
                            }

                        }
                    }
                    .buttonStyle(.card)
                    .background(.clear)
                    .focused($focusIndex, equals: index)
                    .transition(.moveAndOpacity)
                    .animation(.easeInOut(duration: 0.25), value: true)
                    .frame(width: 380, height: 230)
                }

            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 40)
        }
        .fullScreenCover(isPresented: $show, content: {
            if platformViewModel.platformInfo.indices.contains(selectedIndex) {
                if appViewModel.generalSettingsViewModel.generalDisableMaterialBackground {
                    ListMainView(liveType: platformViewModel.platformInfo[selectedIndex].liveType, appViewModel: appViewModel)
                        .background(
                            Color("sl-background", bundle: nil)
                        )
                        .safeAreaPadding(.all)
                        .id(platformViewModel.platformInfo[selectedIndex].liveType)

                } else {
                    ListMainView(liveType: platformViewModel.platformInfo[selectedIndex].liveType, appViewModel: appViewModel)
                        .id(platformViewModel.platformInfo[selectedIndex].liveType)
                }
            } else {
                EmptyView()
            }
        })
    }
}

extension AnyTransition {
    static var moveAndOpacity: AnyTransition {
        AnyTransition.opacity
    }
}

#Preview {
    PlatformView()
}
