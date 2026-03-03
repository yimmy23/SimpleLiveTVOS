//
//  PlayerOptions.swift
//  AngelLive
//
//  播放器选项：壳 UI 和完整 UI 共用。
//

import Foundation
import CoreMedia
import AngelLiveDependencies

public class PlayerOptions: KSOptions, @unchecked Sendable {
    public var syncSystemRate: Bool = false

    nonisolated required public init() {
        super.init()
    }

    override public func updateVideo(refreshRate: Float, isDovi: Bool, formatDescription: CMFormatDescription) {
        guard syncSystemRate else { return }
        super.updateVideo(refreshRate: refreshRate, isDovi: isDovi, formatDescription: formatDescription)
    }
}
