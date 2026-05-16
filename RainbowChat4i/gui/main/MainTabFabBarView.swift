//
//  MainTabFabBarView.swift
//  使用 FabBar 的自定义底部导航条（iOS 26+ Liquid Glass 风格），供 MainTabsViewController 嵌入
//
import SwiftUI
import UIKit

/// 5 个 Tab：消息、群聊、通讯录、钱包、我的（与系统 Tab 一致）；中间 FAB 支持由 ObjC 侧处理长按菜单
@available(iOS 26.0, *)
struct MainTabFabBarView: View {
    let initialSelection: Int
    let titles: [String]   // 5 个：消息、群聊、通讯录、钱包、我的
    let imageNames: [String]
    let selectedImageNames: [String]
    let onSelectionChange: (Int) -> Void
    let onAddLongPress: () -> Void

    @State private var selection: Int

    init(
        initialSelection: Int,
        titles: [String],
        imageNames: [String],
        selectedImageNames: [String],
        onSelectionChange: @escaping (Int) -> Void,
        onAddLongPress: @escaping () -> Void
    ) {
        let safe = min(max(initialSelection, 0), 4)
        self.initialSelection = safe
        self.titles = titles
        self.imageNames = imageNames
        self.selectedImageNames = selectedImageNames
        self.onSelectionChange = onSelectionChange
        self.onAddLongPress = onAddLongPress
        _selection = State(initialValue: safe)
    }

    private static let barCount = 5
    /// 与 `MainTabsViewController` 中 `host.view.tintColor = HexColor(0xc1342d)` 一致，避免首帧仅靠继承 tint 仍为系统蓝
    private static let selectedAccentColor = UIColor(red: 193 / 255, green: 52 / 255, blue: 45 / 255, alpha: 1)

    private var tabs: [FabBarTab<Int>] {
        (0..<min(Self.barCount, titles.count)).map { idx in
            FabBarTab(
                value: idx,
                title: titles[idx],
                image: imageNames.count > idx ? imageNames[idx] : "circle",
                imageBundle: .main,
                selectedImage: selectedImageNames.count > idx ? selectedImageNames[idx] : nil,
                selectedImageBundle: .main,
                onReselect: nil
            )
        }
    }

    private var action: FabBarAction {
        FabBarAction(systemImage: "plus", accessibilityLabel: "Add", action: onAddLongPress, longPressAction: onAddLongPress)
    }

    var body: some View {
        FabBar(selection: $selection, tabs: tabs, action: action, selectedTabAccentColor: Self.selectedAccentColor)
            .background(Color.clear)
            .onChange(of: selection) { _, newValue in
                onSelectionChange(newValue)
            }
    }
}

/// 供 ObjC 调用的工厂：创建包含 FabBar 的 UIHostingController（仅 iOS 26+）
/// 返回 UIViewController 以便 @objc 可暴露给 Objective-C（泛型 UIHostingController 不能）
@available(iOS 26.0, *)
@objc public final class MainTabFabBarFactory: NSObject {
    @objc public static func makeHostingController(
        initialSelection: Int,
        titles: [String],
        imageNames: [String],
        selectedImageNames: [String],
        onSelectionChange: @escaping (Int) -> Void,
        onAddLongPress: @escaping () -> Void
    ) -> UIViewController {
        let view = MainTabFabBarView(
            initialSelection: initialSelection,
            titles: titles,
            imageNames: imageNames,
            selectedImageNames: selectedImageNames,
            onSelectionChange: onSelectionChange,
            onAddLongPress: onAddLongPress
        )
        return UIHostingController(rootView: view)
    }
}
