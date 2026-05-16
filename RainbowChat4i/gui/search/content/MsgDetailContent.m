//telegram @wz662
//
//  MsgDetailContent.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/23.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "MsgDetailContent.h"
#import "MsgDetailContentDTO.h"
#import "MessageTableViewCell.h"
#import "AlarmType.h"
#import "MsgSummaryContent.h"
#import "RBAvatarView.h"
#import "TimeTool.h"
#import "IMClientManager.h"
#import "BasicTool.h"

@implementation MsgDetailContent

static NSString *RBSearchReadableMessageText(MsgDetailContentDTO *dto)
{
    if (dto == nil) return @"";
    switch (dto.msgType) {
        case TM_TYPE_RED_PACKET:
            return @"「红包」";
        case TM_TYPE_TRANSFER:
            return @"「转账」";
        case TM_TYPE_IMAGE:
            return @"[图片]";
        case TM_TYPE_VOICE:
            return @"[语音]";
        case TM_TYPE_FILE:
            return @"[文件]";
        case TM_TYPE_SHORTVIDEO:
            return @"[视频]";
        case TM_TYPE_LOCATION:
            return @"[位置]";
        case TM_TYPE_CONTACT:
            return @"[名片]";
        case TM_TYPE_GIFT_SEND:
        case TM_TYPE_GIFT_GET:
            return @"[礼物]";
        case TM_TYPE_SYSTEAM_INFO:
            return @"[系统消息]";
        case TM_TYPE_REVOKE:
            return @"[已撤回]";
        default:
            return dto.text ?: @"";
    }
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 用于SearchViewController中的tableView:cellForRowAtIndexPath:方法调用，从而实现不同搜索内容的表格cell内容显示。
 *
 * @param vc 对应的搜索主界面对象应用
 * @param dto 表格单元对应的数据对象
 * @return 返回对应的表格ceell对象
 */
- (UITableViewCell *) onTableViewCell:(SearchViewController *)vc contentDTO:(MsgDetailContentDTO *)dto {
    UITableViewCell *cell = [vc tableCell:vc.tableView withIdenfity:@"msgCell" xibName:@"MessageTableViewCell" c:[MessageTableViewCell class]];
    if(cell != nil) {
        MessageTableViewCell *theCell = (MessageTableViewCell *)cell;
        // 基本设置
        [theCell baseSetup];
        
        MsgDetailContentDTO *m = dto;
        
        theCell.viewDate.text = [TimeTool getTimeStringAutoShort2:m.date mustIncludeTime:NO timeWithSegment:NO];
        
        // 关键字高亮
        NSString *displayText = RBSearchReadableMessageText(m);
        NSMutableAttributedString *ssb = [BasicTool coloredStringForSearch:displayText keyword:self.currentKeyword keywordColor:UI_DEFAULT_SEARCH_KEYWORD_COLOR];
        if(ssb != nil) {
            [theCell.viewDesc setAttributedText:ssb];
        } else {
            theCell.viewDesc.text = displayText;// keyword = self.currentKeyword
        }
        
        // 设置默认占位图
        [theCell.viewAvadar setImage:[UIImage imageNamed:@"default_avatar_for_chattingui_40"]];
        
        NSString *senderUid = m.senderId;
        NSString *nickname = m.senderDisplayName;

        UserEntity *localUserInfo = [IMClientManager sharedInstance].localUserInfo;
        // 发消息的人是"我"
        BOOL isMe = [[IMClientManager sharedInstance] isLocalUser:senderUid];
        
        BOOL dontDiskCache = false;
        // 用户的头像文件名（这个文件名目前仅用于缓存图片时使用，确保文件名不一样时能及时更新图片）
        NSString *fileNameForUserAvatar = nil;
        
        if (senderUid != nil) {
            if(isMe){
                if(localUserInfo != nil){
                    fileNameForUserAvatar = localUserInfo.userAvatarFileName;
                    nickname = localUserInfo.nickname;
                }
            } else {
                // 尝试从好友数据中读取对方信息
                UserEntity *friendRee = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:senderUid];
                // 好友信息不为空，表示对方是好友
                if (friendRee != nil) {
                    fileNameForUserAvatar = friendRee.userAvatarFileName;
                    nickname = [friendRee getNickNameWithRemark];
                    
                    // 该字段为空可能是该用户没有设置头像，也可能是有可能是对方已把"我"删除，因而对方不在我
                    // 的好友列表里了，所以好友数据不存在，头像文件名也就取不到了，这种情况取头像时，就把它当陌生人聊
                    // 天模式去取头像，即dontDiskCache为true——确保相同url情况下至少app重启后能强行拉取一次最新头像
                    if ([BasicTool isStringEmpty:[BasicTool trim:fileNameForUserAvatar]]) {
                        dontDiskCache = YES;
                    }
                }
                // 对方不是好友（陌生人聊天）
                else {
                    // 因陌生人没有好友信息缓存，所以尝试从首页"消息"列表中查找缓存
                    AlarmDto *d = [[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmDto:AMT_guestChatMessage dataId:senderUid];
                    // 对于陌生人来说，extra1String中，存放的就是可能最新头像文件名（在查看最新用户资料时设置进来的）
                    fileNameForUserAvatar = (d != nil?d.extraString1:nil);
                    
                    // 陌生人昵称（对于聊天详情搜索结果来说，当不存在首页消息item时优化用消息记录中存的昵称，兜底才是用uid显示）
                    nickname = [MsgSummaryContent tryGetGustNickname:senderUid defaultNick:nickname];
                    
                    dontDiskCache = YES;
                }
            }
            
            // 加载用户头像（支持视频头像播放）
            [RBAvatarView setAvatarWithFileName:fileNameForUserAvatar uid:senderUid onImageView:theCell.viewAvadar placeholder:nil];
        }

        // 显示昵称
        theCell.viewName.text = nickname;
    }
    
    return cell;
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 点击事件真正的实施方法。子类可重写本方法实现自已的逻辑。
 *
 * @param vc 对应的搜索主界面对象应用
 * @param cell   表格单元对象引用
 * @param dto 表格单元对应的数据对象
 */
- (void)doClickImpl:(SearchViewController *)vc cell:(UITableViewCell *)cell contentDTO:(MsgDetailContentDTO *)dto {
    [MsgSummaryContent toChattingPage:vc.navigationController hudParentView:vc.view parentContentDto:self.msgSummaryContentDTO highlightOnceMsgFingerprint:dto.fp anchorMessageDate:dto.date];
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 点击"查看更多"事件真正的实施方法。子类可重写本方法实现自已的逻辑。
 *
 * @param vc 对应的搜索主界面对象应用
 */
- (void)doClickMoreImpl:(SearchViewController *)fragment {
    //
}

/**
 * 搜索消息记录的实施方法。
 *
 * @param keyword 要搜索的关键词
 * @param searchAll YES表示显示所有结果，NO表示只显示限定数据的结果（多余部分用“查看更多”这样的cell由用户点进去进一步查看）
 * @return 返回的搜索结果集 (List<R>)
 */
- (NSMutableArray *)doSearchImpl:(NSString *)keyword searchAll:(BOOL)searchAll db:(FMDatabase *)db {
    (void)keyword;
    (void)searchAll;
    (void)db;
    return [NSMutableArray array];
}

- (BOOL)rb_messageSearchUsesServer
{
    return NO;
}

- (void)rb_doServerMessageSearch:(NSString *)keyword searchAll:(BOOL)searchAll complete:(void (^)(NSMutableArray * _Nullable results))complete
{
    self.currentKeyword = keyword;
    if (complete) {
        complete([NSMutableArray array]);
    }
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 返回本搜索内容显示在结果列表界面中时的对应的搜索内容类型常量。
 *
 * @return 搜索内容类型常量
 */
- (int)getContentType {
    return SEARCH_CONTENT_TYPE_MSG_DETAIL;
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 返回对应搜索内容的文字描述。
 *
 * @return 对应搜索内容的文字描述
 */
- (NSString *)getContentDescription {
    return @"本地聊天记录";// (详)
}

@end
