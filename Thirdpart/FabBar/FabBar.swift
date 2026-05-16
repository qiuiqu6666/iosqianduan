import SwiftUI
import UIKit

/// A customizable iOS 26 glass tab bar with a floating action button.
///
/// FabBar provides a native-looking iOS 26 tab bar where you control what goes in it,
/// including a FAB that morphs with the glass effect.
///
/// ## Usage
///
/// The recommended way to use FabBar is with the `.fabBar()` modifier:
///
/// ```swift
/// TabView(selection: $selectedTab) {
///     Tab(value: .home) {
///         HomeView()
///             .fabBarSafeAreaPadding()
///             .toolbarVisibility(.hidden, for: .tabBar)
///     }
///     // more tabs...
/// }
/// .fabBar(
///     selection: $selectedTab,
///     tabs: [
///         FabBarTab(value: .home, title: "Home", systemImage: "house.fill"),
///         FabBarTab(value: .explore, title: "Explore", systemImage: "compass"),
///         FabBarTab(value: .profile, title: "Profile", systemImage: "person.fill"),
///     ],
///     action: FabBarAction(systemImage: "plus", accessibilityLabel: "Add Item") {
///         // Handle tap
///     }
/// )
/// ```
///
/// For more control over positioning, you can use the `FabBar` view directly.

@available(iOS 26.0, *)
public struct FabBar<Value: Hashable>: View {
    /// The currently selected tab.
    @Binding public var selection: Value

    /// The tabs to display.
    public let tabs: [FabBarTab<Value>]

    /// The floating action button configuration.
    public var action: FabBarAction

    /// 选中 Tab 的强调色。非 nil 时首帧即写入 `TabBarSegmentedControl.activeTintColor`，不依赖外层 `tintColor` 晚一拍同步。
    public var selectedTabAccentColor: UIColor?

    /// Creates a FabBar with the specified configuration.
    ///
    /// - Parameters:
    ///   - selection: A binding to the currently selected tab.
    ///   - tabs: The tabs to display.
    ///   - action: The floating action button configuration.
    ///   - selectedTabAccentColor: 选中态颜色；`nil` 时仍从父视图 `tintColor` 继承。
    public init(
        selection: Binding<Value>,
        tabs: [FabBarTab<Value>],
        action: FabBarAction,
        selectedTabAccentColor: UIColor? = nil
    ) {
        self._selection = selection
        self.tabs = tabs
        self.action = action
        self.selectedTabAccentColor = selectedTabAccentColor
    }

    public var body: some View {
        if tabs.isEmpty {
            Color.clear
                .frame(height: Constants.barHeight)
                .onAppear {
                    fabBarLogger.warning("FabBar initialized with empty tabs array - nothing will be displayed")
                }
        } else {
            FabBarRepresentable(
                tabs: tabs,
                action: action,
                activeTab: $selection,
                selectedTabAccentColor: selectedTabAccentColor
            )
            .frame(height: Constants.barHeight)
        }
    }
}
