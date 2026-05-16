//
//  MemberMessageViewController.m
//  RainbowChat4i
//
//  群成员发言记录 — 先显示群成员列表，选择成员后再查看其本地发言历史（群聊专用）。
//

#import "MemberMessageViewController.h"
#import "GroupMemberEntity.h"
#import "IMClientManager.h"
#import "MyDataBase.h"
#import "ChatHistoryTable.h"
#import "MsgDetailContentDTO.h"
#import "MsgSummaryContentDTO.h"
#import "MsgSummaryContent.h"
#import "VoipRecordMeta.h"
#import "TimeTool.h"
#import "FileDownloadHelper.h"
#import "UIViewController+RBPlainCustomNav.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static const int kMemberMessagePageSize = 30;

static NSString *RBMemberDisplayName(GroupMemberEntity *member)
{
    NSString *name = [BasicTool trim:member.nickname_ingroup];
    if (name.length > 0) return name;
    name = [BasicTool trim:member.nickname];
    if (name.length > 0) return name;
    return [BasicTool trim:member.user_uid] ?: @"";
}

static NSString *RBMessageSummaryText(int msgType, NSString *text)
{
    switch (msgType) {
        case TM_TYPE_IMAGE:      return @"[图片]";
        case TM_TYPE_VOICE:      return @"[语音]";
        case TM_TYPE_FILE:       return @"[文件]";
        case TM_TYPE_SHORTVIDEO: return @"[视频]";
        case TM_TYPE_LOCATION:   return @"[位置]";
        case TM_TYPE_CONTACT:    return @"[名片]";
        case TM_TYPE_GIFT_SEND:
        case TM_TYPE_GIFT_GET:   return @"[礼物]";
        case TM_TYPE_RED_PACKET: return @"「红包」";
        case TM_TYPE_TRANSFER:   return @"「转账」";
        case TM_TYPE_SYSTEAM_INFO: return @"[系统消息]";
        case TM_TYPE_REVOKE:     return @"[已撤回]";
        case TM_TYPE_VOIP_RECORD: {
            if (text != nil && [text hasPrefix:@"{"]) {
                VoipRecordMeta *vrm = [VoipRecordMeta fromJSON:text];
                if (vrm != nil) {
                    NSString *typeStr = (vrm.voipType == VOIP_TYPE_VOICE) ? @"语音通话" : @"视频通话";
                    return [NSString stringWithFormat:@"[%@]", typeStr];
                }
            }
            return @"[通话记录]";
        }
        default:
            return text ?: @"";
    }
}

@interface RBIndexedGroupMemberItem : NSObject
@property (nonatomic, strong) GroupMemberEntity *member;
@property (nonatomic, copy) NSString *displayName;
@end

@implementation RBIndexedGroupMemberItem
@end

@interface RBGroupMemberSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSArray<RBIndexedGroupMemberItem *> *items;
@end

@implementation RBGroupMemberSection
@end

@interface RBGroupMemberCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, copy) NSString *avatarUid;
- (void)configureWithItem:(RBIndexedGroupMemberItem *)item;
@end

@implementation RBGroupMemberCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        _avatarView = [[UIImageView alloc] init];
        _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        _avatarView.layer.cornerRadius = 17.f;
        _avatarView.clipsToBounds = YES;
        _avatarView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarView.image = [UIImage imageNamed:@"default_avatar_60"];
        [self.contentView addSubview:_avatarView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:15];
        _nameLabel.textColor = HexColor(0x333333);
        [self.contentView addSubview:_nameLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_avatarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_avatarView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_avatarView.widthAnchor constraintEqualToConstant:34],
            [_avatarView.heightAnchor constraintEqualToConstant:34],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:10],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-40],
            [_nameLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        ]];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.avatarUid = nil;
    self.avatarView.image = [UIImage imageNamed:@"default_avatar_60"];
    self.nameLabel.text = nil;
}

- (void)configureWithItem:(RBIndexedGroupMemberItem *)item
{
    GroupMemberEntity *member = item.member;
    self.nameLabel.text = item.displayName;
    self.avatarUid = member.user_uid ?: @"";
    self.avatarView.image = [UIImage imageNamed:@"default_avatar_60"];
    if (self.avatarUid.length == 0) {
        return;
    }

    NSString *currentUid = [self.avatarUid copy];
    __weak typeof(self) wself = self;
    [FileDownloadHelper loadUserAvatarIntelligent:nil
                                             uid:currentUid
                                          logTag:@"MemberMessageViewController"
                                         complete:^(BOOL sucess, UIImage *img) {
        __strong typeof(wself) self = wself;
        if (!self) return;
        if (sucess && img != nil && [self.avatarUid isEqualToString:currentUid]) {
            self.avatarView.image = img;
        }
    } donotLoadFromDisk:NO];
}

@end

@interface RBMemberMessageHistoryViewController : CommonViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, copy) NSString *gid;
@property (nonatomic, strong) GroupMemberEntity *member;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *footerSpinner;
@property (nonatomic, strong) NSMutableArray<MsgDetailContentDTO *> *messageList;
@property (nonatomic, assign) int currentOffset;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMoreData;
@property (nonatomic, strong) NSDateFormatter *timeFmt;
@end

@implementation RBMemberMessageHistoryViewController

- (instancetype)initWithGid:(NSString *)gid member:(GroupMemberEntity *)member
{
    self = [super init];
    if (self) {
        _gid = [gid copy] ?: @"";
        _member = member;
        _messageList = [NSMutableArray array];
        _currentOffset = 0;
        _isLoading = NO;
        _hasMoreData = YES;
        _timeFmt = [[NSDateFormatter alloc] init];
        _timeFmt.dateFormat = @"MM-dd HH:mm";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = RBMemberDisplayName(self.member);
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:self.title ?: @"成员发言记录"];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 56;
    self.tableView.estimatedRowHeight = 56;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 0);
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"RBMemberMessageCell"];
    [self.view addSubview:self.tableView];

    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.footerSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.footerSpinner.center = CGPointMake(footerView.bounds.size.width / 2, 22);
    self.footerSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [footerView addSubview:self.footerSpinner];
    self.tableView.tableFooterView = footerView;

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无该成员的本地聊天记录";
    self.emptyLabel.textColor = HexColor(0x999999);
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.emptyLabel];

    UILayoutGuide *sa = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:sa.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.topAnchor constraintEqualToAnchor:sa.topAnchor constant:40],
    ]];

    [self loadNextPage];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rb_plainCustomNavHostViewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self rb_plainCustomNavHostViewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self rb_plainCustomNavHostViewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self rb_plainCustomNavHostViewDidDisappear:animated];
}

- (void)loadNextPage
{
    if (self.isLoading || !self.hasMoreData) return;
    self.isLoading = YES;
    [self.footerSpinner startAnimating];

    int offset = self.currentOffset;
    NSString *gid = self.gid ?: @"";
    NSString *senderUid = self.member.user_uid ?: @"";
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSMutableArray<MsgDetailContentDTO *> *results = nil;
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            ChatHistoryTable *table = [[ChatHistoryTable alloc] init];
            results = [table searchMessagesBySender:db
                                                gid:gid
                                          senderUid:senderUid
                                              limit:kMemberMessagePageSize
                                             offset:offset];
        }];
        if (results == nil) results = [NSMutableArray array];

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) self = wself;
            if (!self) return;
            [self.footerSpinner stopAnimating];
            if (results.count < kMemberMessagePageSize) {
                self.hasMoreData = NO;
                self.tableView.tableFooterView = [[UIView alloc] init];
            }
            self.currentOffset = offset + (int)results.count;
            if (results.count > 0) {
                NSInteger oldCount = self.messageList.count;
                [self.messageList addObjectsFromArray:results];
                NSMutableArray<NSIndexPath *> *paths = [NSMutableArray arrayWithCapacity:results.count];
                for (NSInteger i = 0; i < (NSInteger)results.count; i++) {
                    [paths addObject:[NSIndexPath indexPathForRow:(oldCount + i) inSection:0]];
                }
                [self.tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
            }
            self.emptyLabel.hidden = (self.messageList.count > 0);
            self.isLoading = NO;
        });
    });
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.messageList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RBMemberMessageCell" forIndexPath:indexPath];
    MsgDetailContentDTO *dto = self.messageList[indexPath.row];
    cell.textLabel.text = RBMessageSummaryText(dto.msgType, dto.text);
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    cell.textLabel.textColor = HexColor(0x333333);
    cell.detailTextLabel.text = nil;

    UILabel *timeLabel = [cell.contentView viewWithTag:1001];
    if (!timeLabel) {
        timeLabel = [[UILabel alloc] init];
        timeLabel.tag = 1001;
        timeLabel.font = [UIFont systemFontOfSize:12];
        timeLabel.textColor = HexColor(0x999999);
        timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:timeLabel];
        [NSLayoutConstraint activateConstraints:@[
            [timeLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [timeLabel.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        ]];
    }
    timeLabel.text = dto.date ? [self.timeFmt stringFromDate:dto.date] : @"";
    return cell;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentH = scrollView.contentSize.height;
    CGFloat frameH = scrollView.frame.size.height;
    if (self.hasMoreData && !self.isLoading && contentH > 0 && offsetY > contentH - frameH - 300) {
        [self loadNextPage];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MsgDetailContentDTO *dto = self.messageList[indexPath.row];
    MsgSummaryContentDTO *summaryDTO = [[MsgSummaryContentDTO alloc] init];
    summaryDTO.chatType = MSSR_SEARCH_RESULT_CHAT_TYPE_SGROUP;
    summaryDTO.dataId = self.gid;
    [MsgSummaryContent toChattingPage:self.navigationController
                        hudParentView:self.view
                     parentContentDto:summaryDTO
              highlightOnceMsgFingerprint:dto.fp
                    anchorMessageDate:dto.date];
}

@end

@interface MemberMessageViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic, copy) NSString *gid;
@property (nonatomic, strong) UIView *searchContainer;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSMutableArray<RBIndexedGroupMemberItem *> *allMemberItems;
@property (nonatomic, strong) NSArray<RBIndexedGroupMemberItem *> *displayedItems;
@property (nonatomic, strong) UILocalizedIndexedCollation *collation;
@end

@implementation MemberMessageViewController

- (instancetype)initWithGid:(NSString *)gid
{
    self = [super init];
    if (self) {
        _gid = [gid copy] ?: @"";
        _allMemberItems = [NSMutableArray array];
        _collation = [UILocalizedIndexedCollation currentCollation];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"选择群成员";
    self.view.backgroundColor = [UIColor whiteColor];

    [self rb_buildUI];
    [self loadGroupMembers];
}

- (void)rb_buildUI
{
    self.searchContainer = [[UIView alloc] init];
    self.searchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchContainer.backgroundColor = HexColor(0xF5F5F5);
    self.searchContainer.layer.cornerRadius = 8.f;
    self.searchContainer.clipsToBounds = YES;
    [self.view addSubview:self.searchContainer];

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索群成员";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.showsCancelButton = NO;
    self.searchBar.backgroundImage = [UIImage new];
    if (@available(iOS 13.0, *)) {
        UITextField *textField = self.searchBar.searchTextField;
        textField.backgroundColor = [UIColor clearColor];
        textField.borderStyle = UITextBorderStyleNone;
        textField.font = [UIFont systemFontOfSize:15];
    }
    [self.searchContainer addSubview:self.searchBar];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 52;
    self.tableView.estimatedRowHeight = 52;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0);
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:[RBGroupMemberCell class] forCellReuseIdentifier:@"RBGroupMemberCell"];
    [self.view addSubview:self.tableView];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无群成员";
    self.emptyLabel.textColor = HexColor(0x999999);
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.emptyLabel];

    UILayoutGuide *sa = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.searchContainer.topAnchor constraintEqualToAnchor:sa.topAnchor constant:8],
        [self.searchContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.searchContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.searchContainer.heightAnchor constraintEqualToConstant:36],
        [self.searchBar.topAnchor constraintEqualToAnchor:self.searchContainer.topAnchor constant:1],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor constant:2],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor constant:-2],
        [self.searchBar.bottomAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor constant:-1],
        [self.tableView.topAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor constant:8],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.topAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor constant:40],
    ]];
}

- (NSArray<RBIndexedGroupMemberItem *> *)rb_filteredMemberItemsWithKeyword:(NSString *)keyword
{
    NSString *trimmed = [[keyword ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    BOOL hasKeyword = (trimmed.length > 0);

    NSArray<RBIndexedGroupMemberItem *> *source = self.allMemberItems ?: @[];
    NSMutableArray<RBIndexedGroupMemberItem *> *filtered = [NSMutableArray array];
    for (RBIndexedGroupMemberItem *item in source) {
        NSString *name = [[item.displayName ?: @"" lowercaseString] copy];
        NSString *uidSource = item.member.user_uid ?: @"";
        NSString *uid = [[uidSource lowercaseString] copy];
        if (!hasKeyword || [name containsString:trimmed] || [uid containsString:trimmed]) {
            [filtered addObject:item];
        }
    }
    return [filtered copy];
}

- (void)rb_rebuildDisplayedSectionsWithKeyword:(NSString *)keyword
{
    NSArray<RBIndexedGroupMemberItem *> *filtered = [self rb_filteredMemberItemsWithKeyword:keyword];
    NSInteger sectionCount = self.collation.sectionTitles.count;
    NSMutableArray<NSMutableArray<RBIndexedGroupMemberItem *> *> *sections = [NSMutableArray arrayWithCapacity:sectionCount];
    for (NSInteger i = 0; i < sectionCount; i++) {
        [sections addObject:[NSMutableArray array]];
    }

    for (RBIndexedGroupMemberItem *item in filtered) {
        NSInteger index = [self.collation sectionForObject:item collationStringSelector:@selector(displayName)];
        if (index >= 0 && index < sectionCount) {
            [sections[index] addObject:item];
        }
    }

    NSMutableArray<RBIndexedGroupMemberItem *> *sortedItems = [NSMutableArray array];
    for (NSInteger i = 0; i < sectionCount; i++) {
        NSArray *sorted = [self.collation sortedArrayFromArray:sections[i] collationStringSelector:@selector(displayName)];
        if (sorted.count > 0) {
            [sortedItems addObjectsFromArray:sorted];
        }
    }
    self.displayedItems = [sortedItems copy];
    self.emptyLabel.hidden = (filtered.count > 0);
    [self.tableView reloadData];
}

- (void)loadGroupMembers
{
    NSString *myUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (myUid.length == 0 || self.gid.length == 0) {
        self.emptyLabel.hidden = NO;
        return;
    }

    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSMutableArray<GroupMemberEntity *> *groupMembersList = [NSMutableArray array];
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            NSString *sql = @"SELECT senderId, MAX(senderDisplayName) AS senderDisplayName, MAX(date) AS latestDate "
                            @"FROM groupchat_msg "
                            @"WHERE _acount_uid=? AND _gid=? "
                            @"AND senderId IS NOT NULL AND senderId<>'' AND senderId<>'0' "
                            @"AND msgType<>? AND msgType<>? "
                            @"GROUP BY senderId "
                            @"ORDER BY latestDate DESC";
            FMResultSet *rs = [db executeQuery:sql
                          withArgumentsInArray:@[
                myUid,
                self.gid ?: @"",
                @(TM_TYPE_SYSTEAM_INFO),
                @(TM_TYPE_REVOKE)
            ]];
            if (rs != nil) {
                while ([rs next]) {
                    NSString *senderId = [BasicTool trim:[rs stringForColumn:@"senderId"]];
                    if (senderId.length <= 0) {
                        continue;
                    }
                    GroupMemberEntity *member = [[GroupMemberEntity alloc] init];
                    member.user_uid = senderId;
                    NSString *senderDisplayName = [BasicTool trim:[rs stringForColumn:@"senderDisplayName"]];
                    member.nickname_ingroup = senderDisplayName;
                    member.nickname = senderDisplayName;
                    [groupMembersList addObject:member];
                }
                [rs close];
            }
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) self = wself;
            if (!self) return;
            [self.allMemberItems removeAllObjects];
            if (groupMembersList.count > 0) {
                for (GroupMemberEntity *member in groupMembersList) {
                    RBIndexedGroupMemberItem *item = [[RBIndexedGroupMemberItem alloc] init];
                    item.member = member;
                    item.displayName = RBMemberDisplayName(member);
                    [self.allMemberItems addObject:item];
                }
            }
            [self rb_rebuildDisplayedSectionsWithKeyword:self.searchBar.text];
        });
    });
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.displayedItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    RBGroupMemberCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RBGroupMemberCell" forIndexPath:indexPath];
    RBIndexedGroupMemberItem *item = self.displayedItems[indexPath.row];
    [cell configureWithItem:item];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    RBIndexedGroupMemberItem *item = self.displayedItems[indexPath.row];
    GroupMemberEntity *member = item.member;
    RBMemberMessageHistoryViewController *vc = [[RBMemberMessageHistoryViewController alloc] initWithGid:self.gid member:member];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self rb_rebuildDisplayedSectionsWithKeyword:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = @"";
    [self rb_rebuildDisplayedSectionsWithKeyword:@""];
    [searchBar resignFirstResponder];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:NO animated:YES];
}

@end
