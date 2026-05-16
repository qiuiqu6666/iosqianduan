//telegram @wz662
#import "RBDebugSQLiteMessagesViewController.h"
#import "RBDebugSQLiteMessageDetailViewController.h"
#import "MyDataBase.h"
#import "IMClientManager.h"
#import "ChatHistoryTable.h"
#import "GroupChatHistoryTable.h"
#import "JSQMessage.h"
#import "TimeTool.h"
#import "FMDatabase.h"
#import "VoipRecordMeta.h"
#import "MsgBodyRoot.h"

@interface RBDebugSQLiteMsgRow : NSObject
@property (nonatomic, assign) long long rowId;
@property (nonatomic, assign) long long dateRawStored;
@property (nonatomic, copy) NSString *conversationId;
@property (nonatomic, strong) JSQMessage *msg;
@property (nonatomic, copy) NSString *updateTimeRaw;
@property (nonatomic, assign) BOOL isGroupChat;
@property (nonatomic, assign) int sendStatusFromDb;
@end

@implementation RBDebugSQLiteMsgRow
@end

@interface RBDebugSQLiteMessagesViewController ()
@property (nonatomic, assign) BOOL isGroupChat;
@property (nonatomic, copy) NSString *conversationId;
@property (nonatomic, copy) NSArray<RBDebugSQLiteMsgRow *> *rows;
@end

@implementation RBDebugSQLiteMessagesViewController

- (instancetype)initWithIsGroupChat:(BOOL)isGroupChat conversationId:(NSString *)conversationId
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _isGroupChat = isGroupChat;
        _conversationId = [conversationId copy];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = self.conversationId ?: @"消息";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
    [self reloadFromDB];
}

- (NSString *)accountUid
{
    return [IMClientManager sharedInstance].localUserInfo.user_uid ?: @"";
}

- (void)reloadFromDB
{
    NSString *acct = [self accountUid];
    if (acct.length == 0 || self.conversationId.length == 0) {
        self.rows = @[];
        [self.tableView reloadData];
        return;
    }
    BOOL isG = self.isGroupChat;
    NSString *conv = self.conversationId;
    __weak typeof(self) wself = self;
    [MyDataBase inDatabase:^(FMDatabase *db) {
        NSMutableArray<RBDebugSQLiteMsgRow *> *out = [NSMutableArray array];
        FMResultSet *rs = nil;
        if (!isG) {
            NSString *sql = [NSString stringWithFormat:
                             @"SELECT _id, senderId, senderDisplayName, date, text, finger_print_of_protocal, msgType, send_status, "
                             @"quote_fp, quote_sender_uid, quote_sender_nick, quote_status, quote_content, quote_type, _update_time "
                             @"FROM '%@' WHERE _acount_uid=? AND _uid=? ORDER BY _id DESC LIMIT 400",
                             [ChatHistoryTable getTableName]];
            rs = [db executeQuery:sql, acct, conv];
        } else {
            NSString *sql = [NSString stringWithFormat:
                             @"SELECT _id, senderId, senderDisplayName, date, text, finger_print_of_protocal, finger_print_of_parent, msgType, "
                             @"quote_fp, quote_sender_uid, quote_sender_nick, quote_status, quote_content, quote_type, _update_time "
                             @"FROM '%@' WHERE _acount_uid=? AND _gid=? ORDER BY _id DESC LIMIT 400",
                             [GroupChatHistoryTable getTableName]];
            rs = [db executeQuery:sql, acct, conv];
        }
        if (rs) {
            while ([rs next]) {
                RBDebugSQLiteMsgRow *row = [[RBDebugSQLiteMsgRow alloc] init];
                row.rowId = [rs longLongIntForColumn:@"_id"];
                row.isGroupChat = isG;
                row.conversationId = [conv copy];
                row.updateTimeRaw = [rs stringForColumn:@"_update_time"] ?: @"";
                long long dateRaw = [rs longLongIntForColumn:@"date"];
                row.dateRawStored = dateRaw;
                JSQMessage *cp = [[JSQMessage alloc] init];
                cp.senderId = [rs stringForColumn:@"senderId"];
                cp.senderDisplayName = [rs stringForColumn:@"senderDisplayName"];
                cp.date = [TimeTool dateFromChatHistoryStoredTime:dateRaw];
                cp.text = [rs stringForColumn:@"text"];
                cp.fingerPrintOfProtocal = [rs stringForColumn:@"finger_print_of_protocal"];
                if (isG) {
                    cp.fingerPrintOfParent = [rs stringForColumn:@"finger_print_of_parent"];
                    cp.sendStatus = SendStatus_BE_RECEIVED;
                    row.sendStatusFromDb = -1;
                } else {
                    int savedSendStatus = [rs intForColumn:@"send_status"];
                    row.sendStatusFromDb = savedSendStatus;
                    cp.sendStatus = (savedSendStatus == SendStatus_SEND_FAILD || savedSendStatus == SendStatus_SNEDING) ? savedSendStatus : SendStatus_BE_RECEIVED;
                }
                cp.msgType = [rs intForColumn:@"msgType"];
                cp.quote_fp = [rs stringForColumn:@"quote_fp"];
                cp.quote_sender_uid = [rs stringForColumn:@"quote_sender_uid"];
                cp.quote_sender_nick = [rs stringForColumn:@"quote_sender_nick"];
                cp.quote_status = [rs intForColumn:@"quote_status"];
                cp.quote_content = [rs stringForColumn:@"quote_content"];
                cp.quote_type = [rs intForColumn:@"quote_type"];
                if (cp.msgType == TM_TYPE_VOIP_RECORD && cp.text.length > 0 && [cp.text hasPrefix:@"{"]) {
                    cp.voipRecordMeta = [VoipRecordMeta fromJSON:cp.text];
                }
                row.msg = cp;
                [out addObject:row];
            }
            [rs close];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) s = wself;
            if (!s) return;
            s.rows = out;
            [s.tableView reloadData];
        });
    }];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cid = @"m";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.numberOfLines = 2;
        cell.detailTextLabel.numberOfLines = 2;
    }
    RBDebugSQLiteMsgRow *row = self.rows[(NSUInteger)indexPath.row];
    JSQMessage *m = row.msg;
    NSString *preview = m.text ?: @"";
    if (preview.length > 80) {
        preview = [[preview substringToIndex:80] stringByAppendingString:@"…"];
    }
    NSString *who = m.senderDisplayName.length ? m.senderDisplayName : (m.senderId ?: @"");
    cell.textLabel.text = [NSString stringWithFormat:@"#%lld · %@ · type=%d", row.rowId, who, m.msgType];
    NSString *fp = m.fingerPrintOfProtocal.length ? m.fingerPrintOfProtocal : @"(无fp)";
    if (fp.length > 36) {
        fp = [[fp substringToIndex:36] stringByAppendingString:@"…"];
    }
    NSString *dateStr = m.date ? [NSDateFormatter localizedStringFromDate:m.date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterMediumStyle] : @"";
    if (!row.isGroupChat && row.sendStatusFromDb >= 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · send_status=%d · fp:%@\n%@", dateStr, row.sendStatusFromDb, fp, preview];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · fp:%@\n%@", dateStr, fp, preview];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    RBDebugSQLiteMsgRow *row = self.rows[(NSUInteger)indexPath.row];
    NSString *detail = [self.class buildDetailTextForRow:row];
    NSString *title = [NSString stringWithFormat:@"#%lld", row.rowId];
    RBDebugSQLiteMessageDetailViewController *vc = [[RBDebugSQLiteMessageDetailViewController alloc] initWithDetailText:detail title:title];
    [self.navigationController pushViewController:vc animated:YES];
}

+ (NSString *)buildDetailTextForRow:(RBDebugSQLiteMsgRow *)row
{
    JSQMessage *m = row.msg;
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"SQLite _id: %lld\n", row.rowId];
    [s appendFormat:@"会话ID: %@\n", row.conversationId ?: @""];
    [s appendFormat:@"类型: %@\n", row.isGroupChat ? @"群聊(groupchat_msg)" : @"单聊(chat_msg)"];
    [s appendString:@"\n—— 时间与状态 ——\n"];
    [s appendFormat:@"date(库原始值): %lld\n", row.dateRawStored];
    if (m.date) {
        [s appendFormat:@"date(显示): %@\n", [NSDateFormatter localizedStringFromDate:m.date dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterFullStyle]];
    } else {
        [s appendString:@"date(显示): (nil)\n"];
    }
    [s appendFormat:@"_update_time(库): %@\n", row.updateTimeRaw.length ? row.updateTimeRaw : @"(空)"];
    if (!row.isGroupChat) {
        [s appendFormat:@"send_status(库): %d\n", row.sendStatusFromDb];
    }
    [s appendFormat:@"isOutgoing(内存推断): %@\n", [m isOutgoing] ? @"YES" : @"NO"];

    [s appendString:@"\n—— 发送者与展示 ——\n"];
    [s appendFormat:@"senderId: %@\n", m.senderId ?: @"(nil)"];
    [s appendFormat:@"senderDisplayName: %@\n", m.senderDisplayName ?: @"(nil)"];

    [s appendString:@"\n—— 类型与指纹 ——\n"];
    [s appendFormat:@"msgType: %d\n", m.msgType];
    [s appendFormat:@"fingerPrintOfProtocal: %@\n", m.fingerPrintOfProtocal ?: @"(nil)"];
    if (row.isGroupChat) {
        [s appendFormat:@"fingerPrintOfParent: %@\n", m.fingerPrintOfParent ?: @"(nil)"];
    }

    [s appendString:@"\n—— 引用(quote) ——\n"];
    [s appendFormat:@"quote_fp: %@\n", m.quote_fp ?: @"(nil)"];
    [s appendFormat:@"quote_sender_uid: %@\n", m.quote_sender_uid ?: @"(nil)"];
    [s appendFormat:@"quote_sender_nick: %@\n", m.quote_sender_nick ?: @"(nil)"];
    [s appendFormat:@"quote_status: %d\n", m.quote_status];
    [s appendFormat:@"quote_type: %d\n", m.quote_type];
    [s appendFormat:@"quote_content: %@\n", m.quote_content ?: @"(nil)"];

    [s appendString:@"\n—— text(全文) ——\n"];
    [s appendString:m.text ?: @"(nil)"];

    return s;
}

@end
