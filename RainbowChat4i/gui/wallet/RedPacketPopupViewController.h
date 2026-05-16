#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 点击聊天中红包时弹出的「拆红包」浮层，展示背景图，用户点击后关闭并回调
@interface RedPacketPopupViewController : UIViewController

- (instancetype)initWithPacketId:(NSString *)packetId;

@property (nonatomic, copy) NSString *packetId;
/// 用户点击「查看领取详情」后执行，可在此 block 内 push 到红包详情页（modal 方式时使用）
@property (nonatomic, copy, nullable) void (^onOpenBlock)(NSString *packetId);
/// 嵌入为子视图时使用：关闭时调用，openDetail==YES 表示要点「查看领取详情」进入详情页
@property (nonatomic, copy, nullable) void (^onDismissBlock)(BOOL openDetail);

@end

NS_ASSUME_NONNULL_END
