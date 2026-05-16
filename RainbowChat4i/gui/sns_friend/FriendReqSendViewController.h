//telegram @wz662
/**
 * 发送好友请求的功能界面.
 *
 * @author Jack Jiang
 * @version 1.0
 */

#import <UIKit/UIKit.h>
#import "UserEntity.h"

@interface FriendReqSendViewController : UIViewController

// 用户头像
@property (weak, nonatomic) IBOutlet UIImageView *imgAvadar;
// 昵称
@property (weak, nonatomic) IBOutlet UILabel *viewNickname;
// 性别图标（昵称右侧）
@property (weak, nonatomic) IBOutlet UIImageView *imgSex;
// UID
@property (weak, nonatomic) IBOutlet UILabel *viewUid;
// 个性签名（心情/whatsUp）
@property (weak, nonatomic) IBOutlet UILabel *viewSignature;
//// 当前在线状态
//@property (weak, nonatomic) IBOutlet UILabel *viewStatus;
//// 性别
//@property (weak, nonatomic) IBOutlet UIImageView *imgSex;

@property (weak, nonatomic) IBOutlet UIView *viewBzContainer;
// 加好友请求时附加的说明输入框架
@property (weak, nonatomic) IBOutlet UITextView *editContent;

@property (weak, nonatomic) IBOutlet UIView *btnContainer;
@property (weak, nonatomic) IBOutlet UIButton *btnSend;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withDatas:(UserEntity *)userInfo addSource:(NSString *)addSource;

// 处理发送请求按钮事件
- (IBAction)doSendRequest:(UIButton*)sender;

/**
 * 发送添加好友请求的实施方法(前置检查合格后发送真正的IM加好友指令)。
 *
 * @param friendUserUid 对方的uid
 * @param friendUserNickName 对方的昵称
 * @param maxFriend 允许的最大好友数，当<=0时将忽略本参数
 * @param saySomethingToHim 加好友时的验证消息（本消息实际使用时是可能为null的哦，表示可以不输入任何想说的内容就可以加好友）
 * @param addSource 添加来源（如 search_uid, card, group, qrcode 等），可为nil
 * @param complete 在请求成功发出后调用的回调（开发者可在此回调中实现提示信息、请求处理完成后的其它动作），不需要可设为nil
 */
+ (void)sendAddFriendRequest:(NSString *)friendUserUid
                    nickname:(NSString *)friendUserNickName
                   maxFriend:(int)maxFriend
                         say:(NSString *)saySomethingToHim
                   addSource:(NSString *)addSource
                        view:(UIView *)parentView
                    complete:(void (^)(void))complete;

@end
