//telegram @wz662
#import "RBDebugSQLiteChatsViewController.h"
#import "RBDebugSQLiteMessagesViewController.h"
#import "MyDataBase.h"
#import "IMClientManager.h"
#import "ChatHistoryTable.h"
#import "GroupChatHistoryTable.h"
#import "FMDatabase.h"

@interface RBDebugSQLiteChatsViewController ()
@property (nonatomic, strong) UISegmentedControl *seg;
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;
@end

@implementation RBDebugSQLiteChatsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"本地消息库";
    self.tableView.rowHeight = 52;
    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;

    self.seg = [[UISegmentedControl alloc] initWithItems:@[ @"单聊", @"群聊" ]];
    self.seg.selectedSegmentIndex = 0;
    [self.seg addTarget:self action:@selector(onSegChanged) forControlEvents:UIControlEventValueChanged];
    UIView *wrap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 48)];
    self.seg.frame = CGRectInset(CGRectMake(0, 8, CGRectGetWidth(wrap.bounds), 32), 16, 0);
    self.seg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [wrap addSubview:self.seg];
    self.tableView.tableHeaderView = wrap;

    [self reloadFromDB];
}

- (void)onSegChanged
{
    [self reloadFromDB];
}

- (NSString *)accountUid
{
    return [IMClientManager sharedInstance].localUserInfo.user_uid ?: @"";
}

- (void)reloadFromDB
{
    NSString *acct = [self accountUid];
    if (acct.length == 0) {
        self.rows = @[];
        [self.tableView reloadData];
        return;
    }
    BOOL isGroup = (self.seg.selectedSegmentIndex == 1);
    __weak typeof(self) wself = self;
    [MyDataBase inDatabase:^(FMDatabase *db) {
        NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
        if (!isGroup) {
            NSString *sql = [NSString stringWithFormat:
                             @"SELECT _uid, COUNT(*) AS c, MAX(_id) AS mx FROM '%@' WHERE _acount_uid=? GROUP BY _uid ORDER BY mx DESC LIMIT 500",
                             [ChatHistoryTable getTableName]];
            FMResultSet *rs = [db executeQuery:sql, acct];
            if (rs) {
                while ([rs next]) {
                    NSString *uid = [rs stringForColumn:@"_uid"];
                    int c = [rs intForColumn:@"c"];
                    if (uid.length) {
                        [out addObject:@{ @"id": uid, @"count": @(c), @"group": @NO }];
                    }
                }
                [rs close];
            }
        } else {
            NSString *sql = [NSString stringWithFormat:
                             @"SELECT _gid, COUNT(*) AS c, MAX(_id) AS mx FROM '%@' WHERE _acount_uid=? GROUP BY _gid ORDER BY mx DESC LIMIT 500",
                             [GroupChatHistoryTable getTableName]];
            FMResultSet *rs = [db executeQuery:sql, acct];
            if (rs) {
                while ([rs next]) {
                    NSString *gid = [rs stringForColumn:@"_gid"];
                    int c = [rs intForColumn:@"c"];
                    if (gid.length) {
                        [out addObject:@{ @"id": gid, @"count": @(c), @"group": @YES }];
                    }
                }
                [rs close];
            }
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
    static NSString *cid = @"c";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSDictionary *row = self.rows[(NSUInteger)indexPath.row];
    cell.textLabel.text = row[@"id"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"本地 %@ 条", row[@"count"]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *row = self.rows[(NSUInteger)indexPath.row];
    BOOL isG = [row[@"group"] boolValue];
    NSString *cid = row[@"id"];
    RBDebugSQLiteMessagesViewController *vc = [[RBDebugSQLiteMessagesViewController alloc] initWithIsGroupChat:isG conversationId:cid];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
