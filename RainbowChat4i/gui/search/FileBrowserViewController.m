//
//  FileBrowserViewController.m
//  RainbowChat4i
//
//  文件浏览器（分页加载 + 流畅优化）
//

#import "FileBrowserViewController.h"
#import "MsgSummaryContentDTO.h"
#import "MsgDetailContentDTO.h"
#import "IMClientManager.h"
#import "MsgBodyRoot.h"
#import "FileMeta.h"
#import "TimeTool.h"
#import "MsgSummaryContent.h"
#import "HttpRestHelper.h"
#import "RBConversationMsgSearchHelper.h"
#import "MyDataBase.h"
#import "ChatHistoryTable.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static NSString *const kFileCellId = @"FileCell";
static const int kPageSize = 30;

/// 解析接口 1008-27-9 返回的 create_time（收藏时间），支持 "yyyy-MM-dd HH:mm" / "yyyy-MM-dd HH:mm:ss" 或时间戳
static NSDate *fileDateFromFavoriteCreateTime(id createTime) {
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
static NSString *fileStringFromFavoriteItem(id value) {
    if (value == nil) return @"";
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [(NSNumber *)value stringValue];
    return @"";
}

#pragma mark - FileListCell（圆角扩展名图标 + 文件名 + 大小/日期）

@interface FileListCell : UITableViewCell
@property (nonatomic, strong) UIView *iconContainer;      // 圆角蓝底
@property (nonatomic, strong) UILabel *extensionLabel;   // 扩展名如 "gz" "ips"
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *detailLabel;      // 大小 + 日期时间，如 "5.7 MB  2026年3月8日 21:30"
@end

@implementation FileListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        _iconContainer = [[UIView alloc] init];
        _iconContainer.backgroundColor = HexColor(0x4A90D9);
        _iconContainer.layer.cornerRadius = 8;
        _iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_iconContainer];
        
        _extensionLabel = [[UILabel alloc] init];
        _extensionLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _extensionLabel.textColor = [UIColor whiteColor];
        _extensionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_iconContainer addSubview:_extensionLabel];
        
        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _nameLabel.textColor = HexColor(0x333333);
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_nameLabel];
        
        _detailLabel = [[UILabel alloc] init];
        _detailLabel.font = [UIFont systemFontOfSize:12];
        _detailLabel.textColor = HexColor(0x999999);
        _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_detailLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [_iconContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_iconContainer.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_iconContainer.widthAnchor constraintEqualToConstant:40],
            [_iconContainer.heightAnchor constraintEqualToConstant:40],
            [_extensionLabel.centerXAnchor constraintEqualToAnchor:_iconContainer.centerXAnchor],
            [_extensionLabel.centerYAnchor constraintEqualToAnchor:_iconContainer.centerYAnchor],
            
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_iconContainer.trailingAnchor constant:12],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            
            [_detailLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_detailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_detailLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],
            [_detailLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        ]];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.extensionLabel.text = nil;
    self.nameLabel.text = nil;
    self.detailLabel.text = nil;
}

@end

#pragma mark - FileBrowserViewController

@interface FileBrowserViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, assign) int chatType;
@property (nonatomic, copy)   NSString *dataId;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *footerSpinner;
@property (nonatomic, strong) NSMutableArray<MsgDetailContentDTO *> *fileList;

// 分页
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMoreData;
/// 服务端分页（收藏夹与 26-41 共用）
@property (nonatomic, assign) int serverCurrentPage;
@property (nonatomic, assign) int currentOffset;

// 缓存
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation FileBrowserViewController

- (instancetype)initWithChatType:(int)chatType dataId:(NSString *)dataId
{
    self = [super init];
    if (self) {
        _chatType = chatType;
        _dataId = dataId;
        _isLoading = NO;
        _hasMoreData = YES;
        _serverCurrentPage = 1;
        _currentOffset = 0;
        _fileList = [NSMutableArray array];
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = @"yyyy年M月d日 HH:mm";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self buildUI];
    [self loadNextPage];
}

#pragma mark - UI

- (void)buildUI
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0);
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.rowHeight = 68;
    self.tableView.estimatedRowHeight = 68;
    [self.tableView registerClass:[FileListCell class] forCellReuseIdentifier:kFileCellId];
    [self.view addSubview:self.tableView];
    
    // 底部加载指示器
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.footerSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.footerSpinner.center = CGPointMake(footerView.bounds.size.width / 2, 22);
    self.footerSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [footerView addSubview:self.footerSpinner];
    self.tableView.tableFooterView = footerView;
    
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无文件";
    self.emptyLabel.textColor = HexColor(0x999999);
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
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
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

#pragma mark - 分页加载

- (void)loadNextPage
{
    if (self.isLoading || !self.hasMoreData) return;
    self.isLoading = YES;
    [self.footerSpinner startAnimating];
    
    if (self.useServerFavoritesFor10001 && [self.dataId isEqualToString:@"10001"]) {
        NSString *userUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        if (!userUid.length) {
            [self.footerSpinner stopAnimating];
            self.hasMoreData = NO;
            self.isLoading = NO;
            return;
        }
        int page = self.serverCurrentPage;
        __weak typeof(self) wself = self;
        [[HttpRestHelper sharedInstance] submitGetFavoritesFromServer:userUid
                                                                page:page
                                                            pageSize:kPageSize
                                                             favType:4
                                                            complete:^(BOOL sucess, NSDictionary *result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) self = wself;
                [self.footerSpinner stopAnimating];
                if (!self) return;
                if (!sucess || ![result isKindOfClass:[NSDictionary class]]) {
                    self.hasMoreData = NO;
                    self.isLoading = NO;
                    return;
                }
                NSArray *list = result[@"list"];
                if (![list isKindOfClass:[NSArray class]]) list = @[];
                NSMutableArray<MsgDetailContentDTO *> *results = [NSMutableArray array];
                for (NSDictionary *item in list) {
                    if (![item isKindOfClass:[NSDictionary class]]) continue;
                    if ([item[@"fav_type"] intValue] != 4) continue;
                    MsgDetailContentDTO *dto = [[MsgDetailContentDTO alloc] init];
                    dto.text = fileStringFromFavoriteItem(item[@"content"]);
                    dto.date = fileDateFromFavoriteCreateTime(item[@"create_time"]);
                    dto.fp = fileStringFromFavoriteItem(item[@"id"]);
                    dto.msgType = TM_TYPE_FILE;
                    [results addObject:dto];
                }
                if (results.count < kPageSize) self.hasMoreData = NO;
                self.serverCurrentPage = page + 1;
                if (results.count > 0) {
                    NSInteger oldCount = self.fileList.count;
                    [self.fileList addObjectsFromArray:results];
                    NSMutableArray<NSIndexPath *> *paths = [NSMutableArray arrayWithCapacity:results.count];
                    for (NSInteger i = 0; i < (NSInteger)results.count; i++) {
                        [paths addObject:[NSIndexPath indexPathForRow:(oldCount + i) inSection:0]];
                    }
                    [self.tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
                }
                if (self.fileList.count == 0) self.tableView.tableFooterView = [[UIView alloc] init];
                self.emptyLabel.hidden = (self.fileList.count > 0);
                self.isLoading = NO;
            });
        } hudParentView:nil];
        return;
    }

    // 本地文件检索：分页读取 sqlite 的文件消息
    int offset = self.currentOffset;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        __block NSMutableArray<MsgDetailContentDTO *> *results = nil;
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            NSArray<NSNumber *> *types = @[ @(TM_TYPE_FILE) ];
            results = [[MyDataBase sharedInstance].chatHistoryTable
                       searchMessagesByTypes:db
                       chatType:self.chatType
                       uidOrGid:self.dataId
                       msgTypes:types
                       limit:kPageSize
                       offset:offset];
        }];
        if (results == nil) results = [NSMutableArray array];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.footerSpinner stopAnimating];
            if (results.count < kPageSize) self.hasMoreData = NO;
            self.currentOffset = offset + (int)results.count;
            if (results.count > 0) {
                NSInteger oldCount = self.fileList.count;
                [self.fileList addObjectsFromArray:results];
                NSMutableArray<NSIndexPath *> *paths = [NSMutableArray arrayWithCapacity:results.count];
                for (NSInteger i = 0; i < (NSInteger)results.count; i++) {
                    [paths addObject:[NSIndexPath indexPathForRow:(oldCount + i) inSection:0]];
                }
                [self.tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
            }
            self.emptyLabel.hidden = (self.fileList.count > 0);
            self.isLoading = NO;
        });
    });
}

#pragma mark - 工具方法

- (NSString *)parseFileNameFromText:(NSString *)text
{
    if (text == nil || text.length == 0) return @"未知文件";
    FileMeta *meta = [FileMeta fromJSON:text];
    if (meta && meta.fileName && meta.fileName.length > 0) return meta.fileName;
    return text;
}

- (NSString *)formatFileSize:(long)bytes
{
    if (bytes <= 0) return @"";
    if (bytes < 1024) return [NSString stringWithFormat:@"%ld B", (long)bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    if (bytes < 1024 * 1024 * 1024) return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
    return [NSString stringWithFormat:@"%.1f GB", bytes / (1024.0 * 1024.0 * 1024.0)];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.fileList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FileListCell *cell = [tableView dequeueReusableCellWithIdentifier:kFileCellId forIndexPath:indexPath];
    
    MsgDetailContentDTO *dto = self.fileList[indexPath.row];
    NSString *fileName = [self parseFileNameFromText:dto.text];
    FileMeta *meta = [FileMeta fromJSON:dto.text];
    
    NSString *ext = [[fileName pathExtension] lowercaseString];
    if (ext.length > 0) {
        if (ext.length > 4) ext = [ext substringToIndex:4];
        cell.extensionLabel.text = ext;
    } else {
        cell.extensionLabel.text = @"?";
    }
    cell.nameLabel.text = fileName;
    
    NSMutableString *detail = [NSMutableString string];
    if (meta && meta.fileLength > 0) {
        [detail appendString:[self formatFileSize:meta.fileLength]];
    }
    if (dto.date) {
        if (detail.length > 0) [detail appendString:@"  "];
        [detail appendString:[self.dateFormatter stringFromDate:dto.date]];
    }
    cell.detailLabel.text = detail;
    
    return cell;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!self.hasMoreData || self.isLoading) return;
    
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentH = scrollView.contentSize.height;
    CGFloat frameH = scrollView.frame.size.height;
    
    if (contentH > 0 && offsetY > contentH - frameH - 300) {
        [self loadNextPage];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MsgDetailContentDTO *dto = self.fileList[indexPath.row];
    
    MsgSummaryContentDTO *summaryDTO = [[MsgSummaryContentDTO alloc] init];
    summaryDTO.chatType = self.chatType;
    summaryDTO.dataId = self.dataId;
    
    [MsgSummaryContent toChattingPage:self.navigationController
                        hudParentView:self.view
                     parentContentDto:summaryDTO
              highlightOnceMsgFingerprint:dto.fp
                    anchorMessageDate:dto.date];
}

@end
