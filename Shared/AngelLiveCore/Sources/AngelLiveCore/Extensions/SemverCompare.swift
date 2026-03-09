//
//  SemverCompare.swift
//  AngelLiveCore
//
//  语义化版本比较工具，统一各处重复实现。
//

import Foundation

/// 比较两个语义化版本号字符串（如 "1.2.3"）。
/// - Returns: 负数表示 lhs < rhs，0 表示相等，正数表示 lhs > rhs。
public func semverCompare(_ lhs: String, _ rhs: String) -> Int {
    func parts(_ text: String) -> [Int] {
        text.split(separator: ".").map { Int($0) ?? 0 } + [0, 0, 0]
    }

    let left = parts(lhs)
    let right = parts(rhs)
    for index in 0..<3 where left[index] != right[index] {
        return left[index] < right[index] ? -1 : 1
    }
    return 0
}
