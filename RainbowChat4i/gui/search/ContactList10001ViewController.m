//
//  ContactList10001ViewController.m
//  RainbowChat4i
//
//  收藏夹内「名片」Tab：与 10001 会话中的名片消息列表，卡片式 UI。
//

#import "ContactList10001ViewController.h"
#import "MsgDetailContentDTO.h"
#import "MsgSummaryContentDTO.h"
#import "MsgSummaryContent.h"
#import "ChatHistoryTable.h"
#import "MyDataBase.h"
#import "IMClientManager.h"
#import "MsgBodyRoot.h"
#import "ContactMeta.h"
#import "FileDownloadHelper.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static NSString *const kContactCellId = @"ContactCell";
static const int kPageSize = 30;

#pragma mark - ContactCardCell

@interface ContactCardCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@end

@implementation ContactCardCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        _avatarView = [[UIImageView alloc] init];
        _avatarView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarView.clipsToBounds = YES;
        _avatarView.layer.cornerRadius = 24;
        _avatarView.backgroundColor = HexColor(0xE8E8E8);
        _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_avatarView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        _titleLabel.textColor = HexColor(0x333333);
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_titleLabel];
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont systemFontOfSize:13];
        _subtitleLabel.textColor = HexColor(0x999999);
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_subtitleLabel];
        
        _timeLabel = [[UILabel alloc] init];
        _timeLabel.font = [UIFont systemFontOfSize:12];
        _timeLabel.textColor = HexColor(0x999999);
        _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_timeLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [_avatarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_avatarView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_avatarView.widthAnchor constraintEqualToConstant:48],
            [_avatarView.heightAnchor constraintEqualToConstant:48],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:14],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_timeLabel.leadingAnchor constant:-8],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14],
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
            [_timeLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_timeLabel.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
        ]];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.avatarView.image = nil;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.timeLabel.text = nil;
}

@end

#pragma mark - ContactList10001ViewController

@interface ContactList10001ViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, assign) int chatType;
@property (nonatomic, copy) NSString *dataId;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *footerSpinner;
@property (nonatomic, strong) NSMutableArray<MsgDetailContentDTO *> *list;
@property (nonatomic, assign) int currentOffset;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMoreData;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation ContactList10001ViewController

- (instancetype)initWithChatType:(int)chatType dataId:(NSString *)dataId
{
    self = [super init];
    if (self) {
        _chatType = chatType;
        _dataId = dataId ?: @"";
        _list = [NSMutableArray array];
        _currentOffset = 0;
        _isLoading = NO;
        _hasMoreData = YES;
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor whiteColor];
    _tableView.separatorInset = UIEdgeInsetsMake(0, 78, 0, 0);
    _tableView.rowHeight = 76;
    _tableView.estimatedRowHeight = 76;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [_tableView registerClass:[ContactCardCell class] forCellReuseIdentifier:kContactCellId];
    [self.view addSubview:_tableView];
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    _footerSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _footerSpinner.center = CGPointMake(footerView.bounds.size.width / 2, 22);
    _footerSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [footerView addSubview:_footerSpinner];
    _tableView.tableFooterView = footerView;
    
    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.text = @"暂无名片";
    _emptyLabel.textColor = HexColor(0x999999);
    _emptyLabel.font = [UIFont systemFontOfSize:15];
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.hidden = YES;
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_emptyLabel];
    
    UILayoutGuide *sa = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:sa.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
    [self loadNextPage];
}

- (void)loadNextPage
{
    if (_isLoading || !_hasMoreData) return;
    _isLoading = YES;
    [_footerSpinner startAnimating];
    int offset = _currentOffset;
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSMutableArray<MsgDetailContentDTO *> *results = nil;
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            ChatHistoryTable *table = [[ChatHistoryTable alloc] init];
            results = [table searchMessagesByTypes:db chatType:wself.chatType uidOrGid:wself.dataId msgTypes:@[@(TM_TYPE_CONTACT)] limit:kPageSize offset:offset];
        }];
        if (!results) results = [NSMutableArray array];
        dispatch_async(dispatch_get_main_queue(), ^{
            [wself.footerSpinner stopAnimating];
            if (results.count < kPageSize) wself.hasMoreData = NO;
            wself.tableView.tableFooterView = wself.hasMoreData ? wself.tableView.tableFooterView : [[UIView alloc] init];
            wself.currentOffset = offset + (int)results.count;
            if (results.count > 0) {
                NSInteger oldCount = wself.list.count;
                [wself.list addObjectsFromArray:results];
                NSMutableArray<NSIndexPath *> *paths = [NSMutableArray arrayWithCapacity:results.count];
                for (NSInteger i = 0; i < (NSInteger)results.count; i++) {
                    [paths addObject:[NSIndexPath indexPathForRow:oldCount + i inSection:0]];
                }
                [wself.tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
            }
            wself.emptyLabel.hidden = (wself.list.count > 0);
            wself.isLoading = NO;
        });
    });
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _list.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ContactCardCell *cell = [tableView dequeueReusableCellWithIdentifier:kContactCellId forIndexPath:indexPath];
    MsgDetailContentDTO *dto = _list[indexPath.row];
    ContactMeta *meta = [ContactMeta fromJSON:dto.text];
    NSString *title = (meta.nickName.length > 0) ? meta.nickName : (meta.uid ?: @"未知");
    cell.titleLabel.text = title;
    cell.subtitleLabel.text = (meta.type == CONTACT_TYPE_GROUP) ? @"群名片" : @"个人名片";
    if (meta.desc.length > 0) {
        cell.subtitleLabel.text = [NSString stringWithFormat:@"%@ · %@", cell.subtitleLabel.text, meta.desc];
    }
    if (dto.date) {
        cell.timeLabel.text = [_dateFormatter stringFromDate:dto.date];
    } else {
        cell.timeLabel.text = @"";
    }
    cell.avatarView.image = [UIImage imageNamed:@"default_avatar_60"];
    if (meta.uid.length > 0) {
        if (meta.type == CONTACT_TYPE_GROUP) {
            [FileDownloadHelper loadGroupAvatar:meta.uid logTag:@"ContactList10001" complete:^(BOOL sucess, UIImage *img) {
                if (sucess && img && cell.avatarView) [cell.avatarView setImage:img];
            }];
        } else {
            [FileDownloadHelper loadUserAvatarIntelligent:nil uid:meta.uid logTag:@"ContactList10001" complete:^(BOOL sucess, UIImage *img) {
                if (sucess && img && cell.avatarView) [cell.avatarView setImage:img];
            } donotLoadFromDisk:NO];
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MsgDetailContentDTO *dto = _list[indexPath.row];
    if (dto.fp.length == 0) return;
    MsgSummaryContentDTO *summaryDTO = [[MsgSummaryContentDTO alloc] init];
    summaryDTO.chatType = _chatType;
    summaryDTO.dataId = _dataId;
    [MsgSummaryContent toChattingPage:self.navigationController hudParentView:self.view parentContentDto:summaryDTO highlightOnceMsgFingerprint:dto.fp anchorMessageDate:dto.date];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!_hasMoreData || _isLoading) return;
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentH = scrollView.contentSize.height;
    CGFloat frameH = scrollView.frame.size.height;
    if (contentH > 0 && offsetY > contentH - frameH - 300) [self loadNextPage];
}

@end
