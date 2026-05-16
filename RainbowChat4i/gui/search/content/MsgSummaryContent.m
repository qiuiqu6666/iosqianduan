//telegram @wz662
//
//  MsgSummaryContent.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/24.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "MsgSummaryContent.h"
#import "AlarmType.h"
#import "MessageTableViewCell.h"
#import "IMClientManager.h"
#import "AlarmsViewController.h"
#import "ViewControllerFactory.h"
#import "MBProgressHUD.h"
#import "BasicTool.h"
#import "RBAvatarView.h"
#import "TimeTool.h"
#import "MessagesProvider.h"
#import "FriendsListProvider.h"
#import "JSQMessage.h"

static NSString *RBChatSearchSummaryCellStr(id v)
{
    if (v == nil || v == [NSNull null]) {
        return @"";
    }
    if ([v isKindOfClass:[NSString class]]) {
        return (NSString *)v;
    }
    if ([v isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)v stringValue];
    }
    return [v description];
}

@implementation MsgSummaryContent

/**
 * @Override - 此方法实现了父类中的空方法！
 * 用于SearchViewController中的tableView:cellForRowAtIndexPath:方法调用，从而实现不同搜索内容的表格cell内容显示。
 *
 * @param vc 对应的搜索主界面对象应用
 * @param dto 表格单元对应的数据对象
 * @return 返回对应的表格ceell对象
 */
- (UITableViewCell *) onTableViewCell:(SearchViewController *)vc contentDTO:(MsgSummaryContentDTO *)dto {
    UITableViewCell *holder =  [vc tableCell:vc.tableView withIdenfity:@"msgCell" xibName:@"MessageTableViewCell" c:[MessageTableViewCell class]];
    if(holder != nil) {
        MessageTableViewCell *theCell = (MessageTableViewCell *)holder;
        // 基本设置
        [theCell baseSetup];
        
        MsgSummaryContentDTO *m = dto;
        
        // 查询结果只有一条时，就直接显示该消息记录内容
        if(m.resultCount == 1){
            theCell.viewDate.hidden = NO;
            theCell.viewDate.text = [TimeTool getTimeStringAutoShort2:m.date mustIncludeTime:NO timeWithSegment:NO];
            
            NSString *moreDesc = m.text;
            // 关键字高亮
            NSMutableAttributedString *ssb = [BasicTool coloredStringForSearch:moreDesc keyword:self.currentKeyword keywordColor:UI_DEFAULT_SEARCH_KEYWORD_COLOR];
            if(ssb != nil) {
                [theCell.viewDesc setAttributedText:ssb];
            } else {
                theCell.viewDesc.text = moreDesc;// keyword = self.currentKeyword
            }
        }
        // 否则显示一个聚合信息（可以点击查看详细的消息列表）
        else{
            theCell.viewDate.hidden = YES;
            theCell.viewDate.text = nil;
            theCell.viewDesc.text = [NSString stringWithFormat:@"%d条相关的聊天记录", m.resultCount ];
        }
        
        // 如果搜索结果是单聊消息
        if(m.chatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SINGLE){
            // 先设置默认头像
            [theCell.viewAvadar setImage:[UIImage imageNamed:@"default_avatar_for_chattingui_40"]];
            
            BOOL dontDiskCache = NO;
            NSString *friendUid = m.dataId;
            NSString *nickname = friendUid;
            // 用户的头像文件名（这个文件名目前仅用于缓存图片时作为key的一部分使用）
            NSString *fileNameForUserAvatar = nil;
            if (friendUid != nil) {
                
                // 尝试从好友数据中读取对方信息
                UserEntity *friendRee = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:friendUid];
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
                else{
                    // 因陌生人没有好友信息缓存，所以尝试从首页"消息"列表中查找缓存
                    AlarmDto *d = [[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmDto:AMT_guestChatMessage dataId:friendUid];
                    // 对于陌生人来说，extra1String中，存放的就是可能最新头像文件名（在查看最新用户资料时设置进来的）
                    fileNameForUserAvatar = (d != nil?d.extraString1:nil);
                    
                    // 陌生人昵称（对于Summary聊天搜索结果来说，当不存在首页消息item时兜底直接用uid显示（sqlite查询时读senderDiaplayNick对群聊来说数据聚合逻辑上不合理，所以没法读取））
                    nickname = [MsgSummaryContent tryGetGustNickname:friendUid defaultNick:nil];
                    
                    dontDiskCache = true;
                }
                
                // 加载用户头像（支持视频头像播放）
                [RBAvatarView setAvatarWithFileName:fileNameForUserAvatar uid:friendUid onImageView:theCell.viewAvadar placeholder:nil];
                
            }
            
            // 显示昵称
            theCell.viewName.text = nickname;
        }
        // 如果搜索结果是群聊消息记录
        else {
            // 设置默认占位图
            [theCell.viewAvadar setImage:[UIImage imageNamed:@"groupchat_groups_icon_default"]];
            
            NSString *gid = m.dataId;
            NSString *gname = gid;
            if(gid != nil) {
                GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:gid];
                if(ge != nil){
                    gname = ge.g_name;
                }
                
                // 加载群头像
                [FileDownloadHelper loadGroupAvatar:gid logTag:@"MsgSummaryContent"
                                           complete:^(BOOL sucess, UIImage *img) {
                                                if(sucess && img != nil)
                                                    [theCell.viewAvadar setImage:img];
                                            }];
            }
            
            // 显示群名
            theCell.viewName.text = gname;
        }
    }
    
    return holder;
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 点击事件真正的实施方法。子类可重写本方法实现自已的逻辑。
 *
 * @param vc 对应的搜索主界面对象应用
 * @param cell   表格单元对象引用
 * @param dto 表格单元对应的数据对象
 */
- (void)doClickImpl:(SearchViewController *)vc cell:(UITableViewCell *)cell contentDTO:(MsgSummaryContentDTO *)dto {
    
    if(dto != nil) {
        // 只查到了一条结果（那就直接进入聊天界面）
        if(dto.resultCount == 1){
            [MsgSummaryContent toChattingPage:vc.navigationController hudParentView:vc.view parentContentDto:dto highlightOnceMsgFingerprint:dto.fp anchorMessageDate:dto.date];
        }
        // 查到的是多条结果（显示的内容诸如："10条相关聊天记录"），此时就进入聊天详情搜索界面中
        else{
            [MsgSummaryContent toSearchMsgDetail:vc.navigationController keyword:self.currentKeyword summaryContent:dto];
        }
    }
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 点击"查看更多"事件真正的实施方法。子类可重写本方法实现自已的逻辑。
 *
 * @param vc 对应的搜索主界面对象应用
 */
- (void)doClickMoreImpl:(SearchViewController *)vc {
    [ViewControllerFactory goSearchViewController:vc.navigationController supportedSearchableContens:@[[[MsgSummaryContent alloc] init]] keyword:self.currentKeyword showAllResult:YES];
}

/**
 * 搜索消息记录的实施方法。
 *
 * @param keyword 要搜索的关键词
 * @param searchAll YES表示显示所有结果，NO表示只显示限定数据的结果（多余部分用"查看更多"这样的cell由用户点进去进一步查看）
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
    return SEARCH_CONTENT_TYPE_MSG_SUMMARY;
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 返回对应搜索内容的文字描述。
 *
 * @return 对应搜索内容的文字描述
 */
- (NSString *)getContentDescription {
    return @"本地聊天记录";// (概要)
}


#pragma mark - 实用静态类方法

// 尝试读取了陌生人的昵称（因陌生人信息没有本地缓存，所以只能从间接渠道尝试读取）
+ (NSString *)tryGetGustNickname:(NSString *)guestUid defaultNick:(NSString *)defaultGuestNickname {
    // 因陌生人没有好友信息缓存，所以尝试从首页"消息"列表中查找缓存
    AlarmDto *d = [[[IMClientManager sharedInstance] getAlarmsProvider] getAlarmDto:AMT_guestChatMessage dataId:guestUid];
    // 陌生人昵称
    return (d != nil? d.title : ([BasicTool isStringEmpty:defaultGuestNickname]? [NSString stringWithFormat:@"陌生人（UID: %@）", guestUid] : defaultGuestNickname  ));
}

// 进入聊天界面
+ (void)toChattingPage:(UINavigationController *)nc hudParentView:(UIView *)view parentContentDto:(MsgSummaryContentDTO *)m highlightOnceMsgFingerprint:(NSString *)highlightOnceMsgFingerprint {
    [self toChattingPage:nc hudParentView:view parentContentDto:m highlightOnceMsgFingerprint:highlightOnceMsgFingerprint anchorMessageDate:nil];
}

+ (void)toChattingPage:(UINavigationController *)nc hudParentView:(UIView *)view parentContentDto:(MsgSummaryContentDTO *)m highlightOnceMsgFingerprint:(NSString *)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *)anchorMessageDate {
    NSLog(@"【RB-SEARCH-JUMP】toChattingPage BEGIN dataId=%@ fp=%@", m.dataId ?: @"-", highlightOnceMsgFingerprint ?: @"");
    
    if(m.chatType == MSSR_SEARCH_RESULT_CHAT_TYPE_SINGLE){
        NSString *uid = m.dataId;
        NSString *nickname = nil;
        
        if(![[[IMClientManager sharedInstance] getFriendsListProvider] isUserInRoster2:uid]){
            nickname = [MsgSummaryContent tryGetGustNickname:uid defaultNick:nil];
        } else {
            UserEntity *friendInfo = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:uid];
            nickname = (friendInfo != nil? [friendInfo getNickNameWithRemark] : uid);
        }
        
        [AlarmsViewController gotoSingleChattingViewController:nc
                                                       fromUid:uid
                                                  fromNickname:nickname
                                                     highlight:highlightOnceMsgFingerprint
                                             anchorMessageDate:anchorMessageDate];
    } else{
        [AlarmsViewController gotoGroupChattingViewController:nc
                                                          gid:m.dataId
                                                           ge:nil
                                                    highlight:highlightOnceMsgFingerprint
                                            anchorMessageDate:anchorMessageDate];
    }
}

// 从聊天概要（多天聊天消息合并的列表项，形如"共N条相关聊天记录"）继续进入到聊天详情（不合并同类聊天消息，有多少列多少）
+ (void)toSearchMsgDetail:(UINavigationController *)nc keyword:(NSString *)currentKeyword summaryContent:(MsgSummaryContentDTO *) currentSummaryContentDTO {
    MsgDetailContent *c = [[MsgDetailContent alloc] init];
    // 注意此参数，它将决定子级页面里搜索的消息范围为该item指定的聊天对象范围内的消息记录
    c.msgSummaryContentDTO = currentSummaryContentDTO;
    
    [ViewControllerFactory goSearchViewController:nc supportedSearchableContens:@[c] keyword:currentKeyword showAllResult:YES];
}

// 看看需要被高亮的消息，是否已在被加载到内存中了（因为当前的聊天消息是分页懒加载的）
+ (BOOL)messageLoaded:(NSString *)highlightOnceMsgFingerprint chatType:(int)chatType toId:(NSString *)toId {
    MessagesProvider *mp = [MessagesProvider getMessageProiderInstance:chatType];
    return [mp findMessageByFingerPrint:toId fp:highlightOnceMsgFingerprint] != nil;
}

@end
