//
//  SearchStore.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2024/1/12.
//

import Foundation
import LiveParse
import SimpleToast
import Observation

@Observable
class SearchViewModel {
    var searchTypeArray = ["关键词", "链接/分享口令/房间号", "Youtube链接/VideoId"]
    var searchTypeIndex = 0
    var page = 0
    var searchText: String = "8- #在抖音，记录美好生活#【女流66】正在直播，来和我一起支持Ta吧。复制下方链接，打开【抖音】，直接观看直播！ https://v.douyin.com/irK1UcdD/ 7@1.com :8pm"
}
