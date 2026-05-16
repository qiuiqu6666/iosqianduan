//telegram @wz662
#import <Foundation/Foundation.h>
#import "JSQMessage.h"
#import "MsgBody4Group.h"
#import "GroupMemberEntity.h"

@interface GChatDataHelper : NSObject

/**
 * 往聊天界面中显示一条被世界频道提示信息，以便给用户提供打开世界频道的入口（通知并非服务器发出，而是本地准备好的，仅用UI显示）。
 *
 * @since 10.2
 */
+ (void) addSystenInfo_wordChatPortalForLocalUser;

/**
 * 往聊天界面中显示一条"我"通过扫描二维码加入群聊成功的提示信息（此通知并非服务器发出，而是本地准备好的，仅用UI显示）。
 *
 * @param joinBy 加群方式
 * @param sharedByNickname 二维分享者的昵称
 * @param gid 群id
 * @param gname 群名称
 * @param memberCount 群当前总人数（含本次"我"自已）
 */
+ (void) addSystemInfo_joinGroupSucess:(int)joinBy
                                sharedByNickname:(NSString *)sharedByNickname
                                             gid:(NSString *)gid
                                           gname:(NSString *)gname
                                     memberCount:(int) memberCount;

/**
 * 往聊天界面中显示一条被"我"(我就是群主自已了，不然哪有转让权限)转让群主权限成功的系统通知给"自已"看（此
 * 通知并非服务器发出，而是本地准备好的，仅用UI显示）。
 */
+ (void) addSystenInfo_transferSucessForLocalUser:(NSString *)beTransferNickname
                                              gid:(NSString *)gid
                                            gname:(NSString *)gname;

/**
 * 往聊天界面中显示一条被"我"(我就是群主自已了，不然哪有移除权限)删除群员成功的系统通知给"自已"看（此
 * 通知并非服务器发出，而是本地准备好的，仅用UI显示）。
 */
+ (void) addSystenInfo_removeMembersSucessForLocalUser:(NSArray<GroupMemberEntity *> *)beRemovedMembers
                                                   gid:(NSString *)gid
                                                 gname:(NSString *)gname;

/**
 * 往聊天界面中显示一条被"我"邀请入群成功的系统通知给"自已"看（此通知并非服务器发出，而是本地准备好的，仅用UI显示）。
 */
+ (void) addSystenInfo_inviteMembersSucessForLocalUser:(NSArray<GroupMemberEntity *> *)beInvitedMembers
                                                   gid:(NSString *)gid
                                                 gname:(NSString *)gname;

/**
 * 往聊天界面中显示一条群名被"我"自已修改的系统通知给"自已"看（此通知并非服务器发出，而是本地准备好的，仅用UI显示）。
 *
 * @param gid 群id
 * @param newGroupname 新的群名
 */
+ (void) addSystemInfo_groupNameChangedForLocalUser:(NSString *)gid newGroupname:(NSString *)newGroupname;

/**
 * 添加一条通用群聊系统通知到聊天数据结构中.
 */
+ (void) addSystemInfoData:(NSString *)gid
                     gname:(NSString *)gname
               infoContent:(NSString *)systemInfo
                      date:(NSDate *)time
                showNotify:(BOOL)showNotification
                 playAudio:(BOOL)playPromtAudio;

+ (void) addSystemInfoData:(NSString *)gid
                     gname:(NSString *)gname
               infoContent:(NSString *)systemInfo
               fingerPrint:(NSString *)fingerPrint
                      date:(NSDate *)time
                showNotify:(BOOL)showNotification
                 playAudio:(BOOL)playPromtAudio;

/**
 * 添加一条群聊/频道普通聊天消息到数据结构中.
 */
+ (void) addChatMessageDataIncoming:(NSString *)fingerPrint
                                gid:(NSString *)gid
                              gname:(NSString *)gname
                           withBody:(MsgBody4Group *)msgBody
                               date:(NSDate *)time
                         showNotify:(BOOL)showNotification
                          playAudio:(BOOL)playPromtAudio
                           andQuote:(QuoteMeta *)quoteMeta;

+ (JSQMessage *)addChatMessageData_outgoing:(NSString *)gid withData:(JSQMessage *)entity;

@end
