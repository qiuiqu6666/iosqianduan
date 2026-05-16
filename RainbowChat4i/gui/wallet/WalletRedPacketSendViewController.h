#import <UIKit/UIKit.h>
@interface WalletRedPacketSendViewController : UIViewController
@property (nonatomic, strong) NSString *receiverUid;  // 单聊时使用
@property (nonatomic, strong) NSString *groupId;      // 群聊时使用
@property (nonatomic, assign) int receiverType;       // 1=单聊, 2=群聊
/** 进入发送页时预选的红包类型：0=未设置（默认拼手气）, 1=普通, 2=拼手气, 3=专属 */
@property (nonatomic, assign) int initialPacketType;
/** 预设专属领取人 uid（与 initialPacketType=3 配合，从群聊头像长按「发送专属红包」进入时传入） */
@property (nonatomic, copy, nullable) NSString *initialExclusiveReceiverUid;
/** 预设专属领取人显示名 */
@property (nonatomic, copy, nullable) NSString *initialExclusiveReceiverDisplayName;
/** 可选：预设币种（当前仅前端界面与本地消息展示使用） */
@property (nonatomic, copy, nullable) NSString *presetAssetType;
@end
