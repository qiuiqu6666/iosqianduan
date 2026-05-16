// Copyright (C) 2026 即时通讯网(52im.net) & Jack Jiang.
// The RainbowChat Project. All rights reserved.

#import <UIKit/UIKit.h>

@class MSSBrowseModel;

@class JSQMessage;

/**
 * 统一的媒体浏览界面，支持图片和视频混合浏览，左右滑动切换
 */
@interface UnifiedMediaBrowserViewController : UIViewController

/**
 * 初始化方法
 * @param mediaDataArray 媒体数据数组，包含图片和视频信息
 * @param currentIndex 当前显示的媒体索引
 * @param browseItems 图片浏览项数组（MSSBrowseModel）
 */
- (instancetype)initWithMediaDataArray:(NSArray<NSDictionary *> *)mediaDataArray
                           currentIndex:(NSInteger)currentIndex
                           browseItems:(NSArray<MSSBrowseModel *> *)browseItems;

/**
 * 显示浏览界面
 */
- (void)showBrowserViewController;

/** 用户点击「转发图片」时回调，参数为在会话中的消息下标（与 getChattingDatasList 一致） */
@property (nonatomic, copy) void (^onForwardBlock)(NSInteger messageIndexInChat);
/** 用户点击「在对话中查看」时回调，参数为在会话中的消息下标 */
@property (nonatomic, copy) void (^onViewInConversationBlock)(NSInteger messageIndexInChat);

/**
 * 打开短视频播放页时使用的导航栈（由聊天页等调用方注入）。
 * 全屏浏览器常由 TabBar 等 present，仅靠 presentingViewController/keyWindow 推断易失败。
 */
@property (nonatomic, weak) UINavigationController *playbackNavigationController;

@end

