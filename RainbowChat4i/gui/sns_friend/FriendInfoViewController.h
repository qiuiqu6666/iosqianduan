//telegram @wz662
/**
 * 好友信息查看界面.
 *
 * @author Jack Jiang, 2017-12-01
 * @version 1.0
 */

#import <UIKit/UIKit.h>
#import "UserEntity.h"
#import "GroupMemberEntity.h"

@interface FriendInfoViewController : UIViewController

// 用户头像
@property (nonatomic, strong) UIImageView *imgAvadar;

// 好友的昵称显示（优先显示备注）
@property (nonatomic, strong) UILabel *viewNickname;
// 好友的原始昵称显示
@property (nonatomic, strong) UILabel *viewOriginalNickname;

// 性别
@property (nonatomic, strong) UIImageView *imgSex;
// 标签组件：陌生人标签
@property (nonatomic, strong) UILabel *viewGuestFlag;

// 个人签名
@property (nonatomic, strong) UILabel *viewWhatsup;

// ID号
@property (nonatomic, strong) UILabel *viewUid;
// 注册时间
@property (nonatomic, strong) UILabel *viewRegisterTime;
// 登陆时间
@property (nonatomic, strong) UILabel *viewLatestLoginTime;
// 其它说明
@property (nonatomic, strong) UILabel *viewCaption;

// 照片数量
@property (nonatomic, strong) UILabel *viewPhotosCount;
// 照片预览父布局
@property (nonatomic, strong) UIView *layoutPhotosPreview;
// 照片预览
@property (nonatomic, strong) UIImageView *imgPhotoPreview1;
@property (nonatomic, strong) UIImageView *imgPhotoPreview2;
@property (nonatomic, strong) UIImageView *imgPhotoPreview3;
@property (nonatomic, strong) UIImageView *imgPhotoPreview4;

// 语音介绍数量
@property (nonatomic, strong) UILabel *viewPVoicesCount;

// 底部按钮
@property (nonatomic, strong) UIButton *btnOpenChat;
@property (nonatomic, strong) UIButton *btnSendFriendRequest;

// 好友备注相关
@property (nonatomic, strong) UILabel *viewMobileNum;
@property (nonatomic, strong) UILabel *viewMoreDesc;

/** 添加来源透传（search_uid/search_email/search_phone/card/group/qrcode 等） */
@property (nonatomic, retain) NSString *addSource;

/** 群成员信息（从群聊中跳转时传入，用于显示入群时间和邀请人等） */
@property (nonatomic, retain) GroupMemberEntity *groupMemberInfo;

- (id)initWithDatas:(UserEntity *)userInfo canOpenChat:(BOOL)canOpenChat;

@end
