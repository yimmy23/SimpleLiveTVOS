//
//  LiveRoomCollectionViewCell.swift
//  AngelLive
//
//  Created by pangchong on 10/21/25.
//

import UIKit
import SwiftUI
import AngelLiveCore
import AngelLiveDependencies

class LiveRoomCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "LiveRoomCollectionViewCell"

    private var hostingController: UIHostingController<AnyView>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear
    }

    func configure(with room: LiveModel, liveCheckMode: LiveCheckMode = .local, showsCoverBadge: Bool = false) {
        let roomCard = LiveRoomCard(room: room, liveCheckMode: liveCheckMode, showsCoverBadge: showsCoverBadge)
        applyRootView(AnyView(roomCard))
    }

    /// 配置 cell（带外部导航状态和命名空间，用于解决 PiP 导航状态丢失问题）
    func configure(with room: LiveModel, navigationState: LiveRoomNavigationState, namespace: Namespace.ID, liveCheckMode: LiveCheckMode = .local, onDelete: (() -> Void)? = nil, showsCoverBadge: Bool = false) {
        var roomCard = LiveRoomCard(room: room, liveCheckMode: liveCheckMode, showsCoverBadge: showsCoverBadge)
        roomCard.onDelete = onDelete
        let cardView = roomCard
            .environment(\.liveRoomNavigationState, navigationState)
            .environment(\.roomTransitionNamespace, namespace)
        applyRootView(AnyView(cardView))
    }

    /// 复用已有 UIHostingController，避免滚动时反复创建/销毁的开销
    private func applyRootView(_ rootView: AnyView) {
        if let hosting = hostingController {
            hosting.rootView = rootView
        } else {
            let hosting = UIHostingController(rootView: rootView)
            hosting.view.backgroundColor = .clear
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
            hostingController = hosting
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 不销毁 hostingController，复用时直接更新 rootView
    }
}
