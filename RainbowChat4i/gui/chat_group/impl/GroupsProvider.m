//telegram @wz662
#import "GroupsProvider.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "JSQMessage.h"
#import "BasicTool.h"
#import "TimeTool.h"
#import "Protocal.h"
#import "MessagesProvider.h"
#import "MsgBodyRoot.h"


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 私有API
///////////////////////////////////////////////////////////////////////////////////////////

@interface GroupsProvider ()

/** 数据结构形如：<GroupEntity *> */
@property (strong, nonatomic) NSMutableArrayObservableEx *groupsListData;

@end


///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - 本类的代码实现
///////////////////////////////////////////////////////////////////////////////////////////

@implementation GroupsProvider

- (id)init
{
    if(self = [super init])
    {
        // 属性初始化
        self.groupsListData = [[NSMutableArrayObservableEx alloc] init];
    }
    return self;
}


//---------------------------------------------------------------------
#pragma mark - 列表数据模型基本方法

// 更新指定群组的信息（如果老的群信息不存在则本方法什么也不做）。
- (void)updateGroup:(GroupEntity *)newGe
{
    if(newGe != nil)
    {
        GroupEntity *oldGe = [self getGroupInfoByGid:newGe.g_id];
        if(oldGe != nil)
           [oldGe update:newGe];
    }
}

// 加入一个新的群组信息对象.
- (void)putGroup:(int)index withEntity:(GroupEntity *)ree
{
    // 如果该群基本信息已经存在于列表中那就用最新的覆盖
    if([self isUserInGroupList:ree.g_id])
    {
        [self.groupsListData add:[self getIndex:ree.g_id] withObj:ree];
        return;
    }
    [self.groupsListData add:index withObj:ree];
}

// @see #putGroup(int, GroupEntity)
- (void)putGroup:(GroupEntity *)ree
{
    // 默认将新好友加到列表头部
    [self putGroup:0 withEntity:ree];
}

// 用新的群组列表数据集合覆盖原有的数据。
- (void)putGroups:(NSArray<GroupEntity *> *)newDatas
{
    // 批量数据插入时先不更新ui（防止浪费性能）
    [self.groupsListData putDataList:newDatas needNotify:NO];
    // 通知观察者
    if([[self.groupsListData getDataList] count]> 0)
    {
        // 取出最后一个数据单元
        GroupEntity *lastObj = (GroupEntity *)[[self.groupsListData getDataList]
                                               objectAtIndex:([[self.groupsListData getDataList] count] - 1)];
        // 数据全部插完后再更新UI（在好友很多的情况下可以提升性能撒）
        [self.groupsListData notifyObservers:UpdateTypeToObserverADD
                                  whithExtra:lastObj]; // 用最后一个数据单元来通知观察者哦（观察者会不会使用这个data那是它的事）
    }
}

- (BOOL) remove:(int)index
{
    return [self remove:index notify:YES];
}

// 移除列表中指定单元的元素.
- (BOOL) remove:(int)index notify:(BOOL)notifyObserver
{
    if([self checkIndexValid:index])
        return [self.groupsListData remove:index needNotify:notifyObserver] != nil;
    return false;
}

- (BOOL) remove2:(NSString *)gid
{
    return [self remove2:gid notify:YES];
}

- (BOOL) remove2:(NSString *)gid notify:(BOOL)notifyObserver
{
    return [self remove:[self getIndex:gid] notify:notifyObserver];
}

// 指定gid群组是否在群组列表中.
- (BOOL) isUserInGroupList:(NSString *)gid
{
    if(self.groupsListData != nil)
    {
        for(GroupEntity *ree in [self.groupsListData getDataList])
        {
            if([ree.g_id isEqualToString:gid])
                return YES;
        }
    }
    return NO;
}

// 返回"我"群组列表数据集合.
- (NSMutableArrayObservableEx *)getGroupsListData
{
    return self.groupsListData;
}

// 根据gid找到群组列表数据模型中的群组基本信息数据。
- (GroupEntity *) getGroupInfoByGid:(NSString *)gid
{
    if(self.groupsListData != nil)
    {
        for(GroupEntity *ge in [self.groupsListData getDataList])
        {
            if([ge.g_id isEqualToString:gid])
                return ge;
        }
    }

    return nil;
}

// 返回指定群组在列中的索引位置.
- (int) getIndex:(NSString *)gid
{
    int index = -1;
    if(self.groupsListData != nil)
    {
        for(int i = 0; i< [[self.groupsListData getDataList] count]; i++)
        {
            GroupEntity *ree = (GroupEntity *)[self.groupsListData get:i];
            if([ree.g_id isEqualToString:gid])
            {
                index = i;
                break;
            }
        }
    }
    return index;
}

// 返回指定群组在列表中的索引位置.
- (int) getIndexWithObj:(GroupEntity *)r
{
    return [self getIndex:r.g_id];
}

// 检查索引值是否合法（有无超过数据合法索引）。
- (BOOL) checkIndexValid:(int)index
{
    return (index >=0 && index <= ([[self.groupsListData getDataList] count] - 1));
}

- (NSInteger) size
{
    return [[self.groupsListData getDataList] count];
}

// * 世界频道（即原BBS）本来是没有GroupEntity信息的，但为了兼容真正的群聊数据
// * ，本方法将返回默认的世界频道（即原BBS）的GroupEntity对象。暂无大用途，保
// * 持接口兼容而已。
+ (GroupEntity *)getDefaultWordChatEntity
{
    GroupEntity *ge = [[GroupEntity alloc] init];
    ge.g_id = DEFAULT_GROUP_ID_FOR_BBS;
    ge.g_name = DEFAULT_GROUP_NAME_FOR_BBS;

    return ge;
}

// 本地用户是否是指定群的群主
+ (BOOL) isThisGroupOwner:(NSString *)gid
{
    GroupEntity *ge = [[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:gid];
    if(ge != nil){
        return [GroupsProvider isGroupOwner:ge.g_owner_user_uid];
    }
    return NO;
}

// 本地用户是否群主。
+ (BOOL) isGroupOwner:(NSString *)ownerUid
{
    return [[[IMClientManager sharedInstance] localUserInfo].user_uid isEqualToString:ownerUid];
}

// 返回本地用户"我"在指定gid群内的昵称
+ (NSString *) getMyNickNameInGroupEx:(NSString *)gid
{
    NSString *ret = nil;
    @try {
        GroupEntity *ge =[[[IMClientManager sharedInstance] getGroupsProvider] getGroupInfoByGid:gid];
        if (ge != nil)
            ret = [GroupsProvider getMyNickNameInGroup:ge.nickname_ingroup];
        else
            ret = [GroupsProvider getMyNickNameInGroup:nil];
    } @catch (NSException *exception) {
        NSLog(@"%@",exception);
    }
    return ret;
}

// 返回"我"在群内的昵称(如果参数不为空，就直接返回，否则返回"我"的默认昵称作为群内昵称)。
+ (NSString *) getMyNickNameInGroup:(NSString *)nickname_ingroup
{
    if(![BasicTool isStringEmpty:[BasicTool trim:nickname_ingroup]])
        return nickname_ingroup;
    else
    {
        UserEntity *localUser = [[IMClientManager sharedInstance] localUserInfo];
        if(localUser != nil)
            return localUser.nickname;

        return @"";
    }
}

// 返回群内昵称（如果群内昵称为空，则返回默认昵称，否则返回群内昵称）。
+ (NSString *) getNickNameInGroup:(NSString *)nickName and:(NSString *)nickname_ingroup
{
    if(![BasicTool isStringEmpty:[BasicTool trim:nickname_ingroup]])
        return nickname_ingroup;
    else
        return nickName;
}


//---------------------------------------------------------------------
#pragma mark - 列表数据加载和处理方法

- (void)refreshGroupsList:(void (^)(BOOL sucess))refreshComplete
{
    NSString *localServicerUid = [[IMClientManager sharedInstance] localUserInfo].user_uid;

    [[HttpRestHelper sharedInstance] submitGetGroupsListFromServer:localServicerUid complete:^(BOOL sucess, NSArray<GroupEntity *> *newGroupsList) {

        if(sucess)
        {
            DDLogDebug(@"【GroupsProvider】正在刷新群组列表，原始列表数据长度：%lu", (unsigned long)[newGroupsList count]);

            // 用最新的数据刷新群组列表
            [self putGroups:newGroupsList];

            DDLogDebug(@"【GroupsProvider】群组列表读取成功，共有群组数：%ld", (unsigned long)(newGroupsList != nil ? [newGroupsList count] : 0));

            // 刷新成功回调
            if(refreshComplete != nil)
                refreshComplete(YES);
        }
        else
        {
            DDLogDebug(@"【GroupsProvider】群组列表从服务端获取失败.");

            // 刷新失败
            if(refreshComplete != nil)
                refreshComplete(NO);
        }
    } hudParentView:nil];
}


// ========== 大群（读扩散）本地 seq 管理 ==========

/// NSUserDefaults key 前缀（后接群 ID）
static NSString * const kLargeGroupSeqPrefix = @"LargeGroupLastSeq_";

+ (long long)getLastSeqForGroup:(NSString *)gid
{
    if (!gid || gid.length == 0) return 0;
    NSString *key = [kLargeGroupSeqPrefix stringByAppendingString:gid];
    // objectForKey 不存在时返回 nil，转 longLongValue 得 0
    NSNumber *val = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return val ? [val longLongValue] : 0;
}

+ (void)saveLastSeq:(long long)seq forGroup:(NSString *)gid
{
    if (!gid || gid.length == 0) return;
    NSString *key = [kLargeGroupSeqPrefix stringByAppendingString:gid];
    [[NSUserDefaults standardUserDefaults] setObject:@(seq) forKey:key];
}

+ (NSDictionary *)rb_normalizedDictFromLargeGroupFetchRow:(NSDictionary *)raw gid:(NSString *)gid
{
    if (![raw isKindOfClass:[NSDictionary class]]) return @{};
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    NSString *sender = raw[@"sender_uid"];
    if (![sender isKindOfClass:[NSString class]] || sender.length == 0) {
        sender = raw[@"user_uid"];
    }
    m[@"user_uid"] = sender ?: @"";
    NSString *nick = raw[@"nickname"];
    if (![nick isKindOfClass:[NSString class]] || nick.length == 0) {
        nick = raw[@"sender_nickname"];
    }
    if (![nick isKindOfClass:[NSString class]]) nick = raw[@"nickName"];
    m[@"nickName"] = [nick isKindOfClass:[NSString class]] ? nick : @"";
    id mt = raw[@"history_type"];
    if (mt == nil) mt = raw[@"msg_type"];
    m[@"msg_type"] = mt ?: @(0);
    int msgTypeNorm = 0;
    if ([mt isKindOfClass:[NSNumber class]]) {
        msgTypeNorm = [(NSNumber *)mt intValue];
    } else if ([mt isKindOfClass:[NSString class]]) {
        msgTypeNorm = [(NSString *)mt intValue];
    }
    id rawContent = raw[@"history_content"];
    if (rawContent == nil) {
        rawContent = raw[@"msg_content"];
    }
    NSString *msgContentStr = RBNormalizeChatHistoryMsgContentString(rawContent);
    if (msgContentStr == nil) {
        if ([rawContent isKindOfClass:[NSString class]]) {
            msgContentStr = rawContent;
        } else {
            msgContentStr = @"";
        }
    }
    if (msgTypeNorm == TM_TYPE_SHORTVIDEO || msgTypeNorm == TM_TYPE_FILE) {
        NSString *fixedMeta = RBNormalizeFileMetaJSONStringForHistory(msgContentStr);
        if (fixedMeta.length > 0) {
            msgContentStr = fixedMeta;
        }
    }
    m[@"msg_content"] = msgContentStr;
    NSString *ht = raw[@"history_time2"];
    if (![ht isKindOfClass:[NSString class]] || ht.length == 0) {
        ht = raw[@"msg_time2"];
    }
    if (![ht isKindOfClass:[NSString class]]) ht = @"";
    m[@"history_time2"] = ht;
    NSString *fp = raw[@"history_content2"];
    if (![fp isKindOfClass:[NSString class]] || fp.length == 0) {
        fp = raw[@"msg_content2"];
    }
    if (![fp isKindOfClass:[NSString class]] || fp.length == 0) {
        fp = raw[@"fp"];
    }
    if (![fp isKindOfClass:[NSString class]] || fp.length == 0) {
        long long seq = [raw[@"seq"] longLongValue];
        fp = [NSString stringWithFormat:@"lg_%@_%lld", gid ?: @"", seq];
    }
    m[@"msg_content2"] = fp;
    NSString *pf = raw[@"parent_fp"];
    m[@"parent_fp"] = [pf isKindOfClass:[NSString class]] ? pf : @"";
    return m;
}

+ (long long)rb_largeGroupSeqFromFingerPrint:(NSString *)fp gid:(NSString *)gid
{
    if (fp.length == 0 || gid.length == 0) return -1;
    NSString *prefix = [NSString stringWithFormat:@"lg_%@_", gid];
    if ([fp hasPrefix:prefix]) {
        NSString *tail = [fp substringFromIndex:prefix.length];
        if (tail.length == 0) return -1;
        return (long long)[tail longLongValue];
    }
    // 宽松：lg_<gid 段>_<seq>，gid 段与当前会话 gid 数值一致即可（兼容前导零 / 服务端与客户端字符串不一致）
    if (![fp hasPrefix:@"lg_"]) return -1;
    NSString *rest = [fp substringFromIndex:3];
    NSRange lastUs = [rest rangeOfString:@"_" options:NSBackwardsSearch];
    if (lastUs.location == NSNotFound) return -1;
    NSString *gidPart = [rest substringToIndex:lastUs.location];
    NSString *tail = [rest substringFromIndex:lastUs.location + 1];
    if (tail.length == 0) return -1;
    if (![gidPart isEqualToString:gid] && [gidPart longLongValue] != [gid longLongValue]) {
        return -1;
    }
    return (long long)[tail longLongValue];
}

+ (JSQMessage *)rb_jsqMessageFromLargeGroupNormalizedDict:(NSDictionary *)dict localUid:(NSString *)localUid
{
    NSString *srcUid = dict[@"user_uid"];
    if (![srcUid isKindOfClass:[NSString class]]) srcUid = nil;
    if (srcUid.length == 0) return nil;

    NSString *srcNick = [dict[@"nickName"] isKindOfClass:[NSString class]] ? dict[@"nickName"] : @"";
    int msgType = [dict[@"msg_type"] intValue];
    NSString *msgContent = RBNormalizeChatHistoryMsgContentString(dict[@"msg_content"]);
    if (msgContent == nil) {
        msgContent = [dict[@"msg_content"] isKindOfClass:[NSString class]] ? dict[@"msg_content"] : @"";
    }
    if (msgType == TM_TYPE_SHORTVIDEO || msgType == TM_TYPE_FILE) {
        NSString *fixedMeta = RBNormalizeFileMetaJSONStringForHistory(msgContent);
        if (fixedMeta.length > 0) {
            msgContent = fixedMeta;
        }
    }
    NSString *time2Str = [dict[@"history_time2"] isKindOfClass:[NSString class]] ? dict[@"history_time2"] : @"";
    NSString *fp = [dict[@"msg_content2"] isKindOfClass:[NSString class]] ? dict[@"msg_content2"] : @"";
    NSString *parentFp = [dict[@"parent_fp"] isKindOfClass:[NSString class]] ? dict[@"parent_fp"] : @"";

    NSDate *msgDate = [TimeTool convertJavaTimestampToiOSDate:time2Str];
    if (msgDate == nil) msgDate = [NSDate date];

    BOOL isOutgoing = (localUid.length > 0 && [srcUid isEqualToString:localUid]);
    NSString *displayName = isOutgoing ? @"我" : (srcNick.length > 0 ? srcNick : @"");

    JSQMessage *msg = [[JSQMessage alloc] init];
    msg.senderId = srcUid;
    msg.senderDisplayName = displayName;
    msg.date = msgDate;
    msg.text = msgContent ?: @"";
    msg.msgType = msgType;
    msg.fingerPrintOfProtocal = fp;
    msg.fingerPrintOfParent = parentFp;
    msg.sendStatus = SendStatus_BE_RECEIVED;
    msg.sendStatusSecondary = SendStatusSecondary_NONE;
    if (time2Str.length > 0) {
        RBMarkJSQMessageFromHttpHistoryRow(msg);
    }
    return msg;
}

@end
