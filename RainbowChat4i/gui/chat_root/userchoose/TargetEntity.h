//telegram @wz662
/**
 * 一个 RosterElementEntity的子类，目的是增加是否选中标识，方便用于用户选择UI界面列表中作为item数据对象。
 */

#import <Foundation/Foundation.h>
#import "UserEntity.h"

/**  专用于群成员选择时，实现"@所有人"选项的item类型 */
// TODO: 目前 TargetSourceGroupMember 暂时是专用于"@"功能时选择被"@"的成员时，暂时为了简化代码，
//       "@所有人"这个选项只能在 TargetChooseViewController 另用代码写死，暂时就不考虑"@"功能之外使用了，特此说明！
#define TARGET_CHAT_TYPE_FOR_AT_ALL 991

/**
 * 目选选择列表item的数据对象。
 *
 * @author JackJiang
 * @since 8.0
 */
@interface TargetEntity : NSObject

/** 目标id（可能是uid、群id） */
@property (nonatomic, retain) NSString *targetId;
/** 目标名（可能是昵称、群名称）*/
@property (nonatomic, retain) NSString *targetName;
/** 目标其它信息 */
@property (nonatomic, retain) NSString *targetOtherInfo;
/**
 * 目标的聊天类型
 * @see com.x52im.rainbowchat.im.dto.ChatType */
@property (nonatomic, assign) int targetChatType;

/**
 * 本字段仅用于好友数据时，存放好友的最新头像文件名，用于提升图片缓存准确性和性能之用，别无它用。
 */
@property (nonatomic, retain) NSString *userAvatarFileName;

/**
 * 本字段仅用于客户端UI界面使用。表示UI界面上的选中情况。
 */
@property (nonatomic, assign) BOOL selected;

@end


