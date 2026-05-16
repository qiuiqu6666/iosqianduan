//
//  LocationList10001ViewController.m
//  RainbowChat4i
//
//  收藏夹内「位置」Tab：与 10001 会话中的位置消息列表。
//

#import "LocationList10001ViewController.h"
#import "MsgDetailContentDTO.h"
#import "MsgSummaryContentDTO.h"
#import "MsgSummaryContent.h"
#import "ChatHistoryTable.h"
#import "MyDataBase.h"
#import "MsgBodyRoot.h"
#import "LocationMeta.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static NSString *const kLocationCellId = @"LocationCell";
static const int kPageSize = 30;

/// 解析接口 1008-27-9 返回的 create_time（收藏时间），支持 "yyyy-MM-dd HH:mm" / "yyyy-MM-dd HH:mm:ss" 或时间戳
static NSDate *locDateFromFavoriteCreateTime(id createTime) {
    if (createTime == nil) return [NSDate date];
    if ([createTime isKindOfClass:[NSNumber class]]) {
        NSTimeInterval sec = [createTime doubleValue];
        if (sec > 1e10) sec /= 1000.0;
        return [NSDate dateWithTimeIntervalSince1970:sec];
    }
    if ([createTime isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)createTime;
        if (s.length == 0) return [NSDate date];
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        f.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        NSDate *d = [f dateFromString:s];
        if (!d) {
            f.dateFormat = @"yyyy-MM-dd HH:mm";
            d = [f dateFromString:s];
        }
        return d ?: [NSDate date];
    }
    return [NSDate date];
}
static NSString *locStringFromFavoriteItem(id value) {
    if (value == nil) return @"";
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [(NSNumber *)value stringValue];
    return @"";
}

#pragma mark - LocationListCell

@interface LocationListCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@end

@implementation LocationListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = HexColor(0x34C759);
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_iconView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _titleLabel.textColor = HexColor(0x333333);
        _titleLabel.numberOfLines = 2;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_titleLabel];
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont systemFontOfSize:13];
        _subtitleLabel.textColor = HexColor(0x999999);
        _subtitleLabel.numberOfLines = 2;
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_subtitleLabel];
        
        _timeLabel = [[UILabel alloc] init];
        _timeLabel.font = [UIFont systemFontOfSize:12];
        _timeLabel.textColor = HexColor(0x999999);
        _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_timeLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:40],
            [_iconView.heightAnchor constraintEqualToConstant:40],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_timeLabel.leadingAnchor constant:-8],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
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
    self.iconView.image = nil;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.timeLabel.text = nil;
}

@end

#pragma mark - LocationList10001ViewController

@interface LocationList10001ViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, assign) int chatType;
@property (nonatomic, copy) NSString *dataId;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *footerSpinner;
@property (nonatomic, strong) NSMutableArray<MsgDetailContentDTO *> *list;
@property (nonatomic, assign) int currentOffset;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMoreData;
@property (nonatomic, assign) int serverCurrentPage;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation LocationList10001ViewController

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
        _serverCurrentPage = 1;
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
    _tableView.separatorInset = UIEdgeInsetsMake(0, 68, 0, 0);
    _tableView.rowHeight = 72;
    _tableView.estimatedRowHeight = 72;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [_tableView registerClass:[LocationListCell class] forCellReuseIdentifier:kLocationCellId];
    [self.view addSubview:_tableView];
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    _footerSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _footerSpinner.center = CGPointMake(footerView.bounds.size.width / 2, 22);
    _footerSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [footerView addSubview:_footerSpinner];
    _tableView.tableFooterView = footerView;
    
    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.text = @"暂无位置";
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
    
    if (self.useServerFavoritesFor10001 && [self.dataId isEqualToString:@"10001"]) {
        NSString *userUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        if (!userUid.length) {
            [_footerSpinner stopAnimating];
            _hasMoreData = NO;
            _isLoading = NO;
            return;
        }
        int page = _serverCurrentPage;
        __weak typeof(self) wself = self;
        [[HttpRestHelper sharedInstance] submitGetFavoritesFromServer:userUid
                                                                page:page
                                                            pageSize:kPageSize
                                                             favType:5
                                                            complete:^(BOOL sucess, NSDictionary *result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [wself.footerSpinner stopAnimating];
                if (!wself) return;
                if (!sucess || ![result isKindOfClass:[NSDictionary class]]) {
                    wself.hasMoreData = NO;
                    wself.isLoading = NO;
                    return;
                }
                NSArray *list = result[@"list"];
                if (![list isKindOfClass:[NSArray class]]) list = @[];
                NSMutableArray<MsgDetailContentDTO *> *results = [NSMutableArray array];
                for (NSDictionary *item in list) {
                    if (![item isKindOfClass:[NSDictionary class]]) continue;
                    if ([item[@"fav_type"] intValue] != 5) continue;
                    MsgDetailContentDTO *dto = [[MsgDetailContentDTO alloc] init];
                    dto.text = locStringFromFavoriteItem(item[@"content"]);
                    dto.date = locDateFromFavoriteCreateTime(item[@"create_time"]);
                    dto.fp = locStringFromFavoriteItem(item[@"id"]);
                    dto.msgType = TM_TYPE_LOCATION;
                    [results addObject:dto];
                }
                if (results.count < kPageSize) wself.hasMoreData = NO;
                wself.serverCurrentPage = page + 1;
                if (results.count > 0) {
                    NSInteger oldCount = wself.list.count;
                    [wself.list addObjectsFromArray:results];
                    NSMutableArray<NSIndexPath *> *paths = [NSMutableArray arrayWithCapacity:results.count];
                    for (NSInteger i = 0; i < (NSInteger)results.count; i++) {
                        [paths addObject:[NSIndexPath indexPathForRow:oldCount + i inSection:0]];
                    }
                    [wself.tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
                }
                if (wself.list.count == 0) wself.tableView.tableFooterView = [[UIView alloc] init];
                wself.emptyLabel.hidden = (wself.list.count > 0);
                wself.isLoading = NO;
            });
        } hudParentView:nil];
        return;
    }
    
    int offset = _currentOffset;
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSMutableArray<MsgDetailContentDTO *> *results = nil;
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            ChatHistoryTable *table = [[ChatHistoryTable alloc] init];
            results = [table searchMessagesByTypes:db chatType:wself.chatType uidOrGid:wself.dataId msgTypes:@[@(TM_TYPE_LOCATION)] limit:kPageSize offset:offset];
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
    LocationListCell *cell = [tableView dequeueReusableCellWithIdentifier:kLocationCellId forIndexPath:indexPath];
    MsgDetailContentDTO *dto = _list[indexPath.row];
    LocationMeta *meta = [LocationMeta fromJSON:dto.text];
    NSString *title = (meta.locationTitle.length > 0) ? meta.locationTitle : @"位置";
    NSString *subtitle = (meta.locationContent.length > 0) ? meta.locationContent : @"";
    if (meta.latitude != 0 || meta.longitude != 0) {
        if (subtitle.length > 0) subtitle = [subtitle stringByAppendingFormat:@"  %.4f, %.4f", meta.latitude, meta.longitude];
        else subtitle = [NSString stringWithFormat:@"%.4f, %.4f", meta.latitude, meta.longitude];
    }
    cell.titleLabel.text = title;
    cell.subtitleLabel.text = subtitle;
    if (dto.date) {
        cell.timeLabel.text = [_dateFormatter stringFromDate:dto.date];
    } else {
        cell.timeLabel.text = @"";
    }
    if (@available(iOS 13.0, *)) {
        cell.iconView.image = [UIImage systemImageNamed:@"mappin.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightRegular]];
    } else {
        cell.iconView.image = nil;
        cell.iconView.backgroundColor = HexColor(0x34C759);
        cell.iconView.layer.cornerRadius = 20;
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
