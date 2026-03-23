//
//  iOS17Compatibility.swift
//  AngelLive
//
//  iOS 17 兼容性修饰符
//

import SwiftUI
import UIKit

/// iOS 版本兼容的 zoom 过渡修饰符
struct ZoomTransitionModifier: ViewModifier {
    let sourceID: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            content
        }
    }
}

/// iOS 版本兼容的 matchedTransitionSource 修饰符
struct MatchedTransitionSourceModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

/// iOS 版本兼容的 presentationSizing 修饰符
struct WelcomePresentationModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.presentationSizing(.page.fitted(horizontal: true, vertical: false))
        } else {
            content
        }
    }
}

private struct InteractivePopGestureConfigurator: UIViewControllerRepresentable {
    let isEnabled: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.isGestureEnabled = isEnabled
        uiViewController.applyInteractivePopConfiguration()
    }

    final class Controller: UIViewController {
        var isGestureEnabled = false
        private weak var trackedGestureRecognizer: UIGestureRecognizer?
        private weak var originalDelegate: UIGestureRecognizerDelegate?
        private var originalIsEnabled = true

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyInteractivePopConfiguration()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            restoreInteractivePopConfiguration()
        }

        func applyInteractivePopConfiguration() {
            guard let gestureRecognizer = navigationController?.interactivePopGestureRecognizer else {
                return
            }

            if trackedGestureRecognizer !== gestureRecognizer {
                trackedGestureRecognizer = gestureRecognizer
                originalDelegate = gestureRecognizer.delegate
                originalIsEnabled = gestureRecognizer.isEnabled
            }

            if isGestureEnabled {
                gestureRecognizer.delegate = nil
                gestureRecognizer.isEnabled = true
            } else {
                restoreInteractivePopConfiguration()
            }
        }

        private func restoreInteractivePopConfiguration() {
            guard let gestureRecognizer = trackedGestureRecognizer else {
                return
            }
            gestureRecognizer.delegate = originalDelegate
            gestureRecognizer.isEnabled = originalIsEnabled
        }
    }
}

extension View {
    func interactivePopGestureEnabled(_ isEnabled: Bool) -> some View {
        background(
            InteractivePopGestureConfigurator(isEnabled: isEnabled)
                .frame(width: 0, height: 0)
        )
    }
}
