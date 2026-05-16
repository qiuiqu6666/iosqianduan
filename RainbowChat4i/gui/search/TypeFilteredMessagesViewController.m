//
//  TypeFilteredMessagesViewController.m
//  RainbowChat4i
//
//  按消息类型分页展示单个会话内的消息列表（文本/语音等），用于 10001 收藏夹里的「对话」「语音」等分类。
//

#import "TypeFilteredMessagesViewController.h"
#import "ChatHistoryTable.h"
#import "MyDataBase.h"
#import "IMClientManager.h"
#import "MsgDetailContentDTO.h"
#import "MsgSummaryContentDTO.h"
#import "MsgSummaryContent.h"
#import "TimeTool.h"
#import "MsgBodyRoot.h"
#import "JSQAudioMediaItem.h"
#import "FileDownloadHelper.h"
#import "HttpRestHelper.h"

static NSString *const kTypeMsgCellId = @"TypeMsgCell";
static NSString *const kVoiceListCellId = @"VoiceListCell";
static const int kPageSizeTypeFiltered = 30;

// 服务端收藏 fav_type -> msgType（与 ChatViewController 一致）
static int msgTypeFromFavType(int favType) {
    switch (favType) {
        case 0: return TM_TYPE_TEXT;
        case 1: return TM_TYPE_IMAGE;
        case 2: return TM_TYPE_VOICE;
        case 3: return TM_TYPE_SHORTVIDEO;
        case 4: return TM_TYPE_FILE;
        case 5: return TM_TYPE_LOCATION;
        default: return TM_TYPE_TEXT;
    }
}
static NSString *stringFromFavoriteItem(id value) {
    if (value == nil) return @"";
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [(NSNumber *)value stringValue];
    return @"";
}
/// 解析接口 1008-27-9 返回的 create_time（收藏时间），支持 "yyyy-MM-dd HH:mm" / "yyyy-MM-dd HH:mm:ss" 或时间戳
static NSDate *dateFromFavoriteCreateTime(id createTime) {
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

#pragma mark - TypeMsgCell

@interface TypeMsgCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *senderLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@end

@implementation TypeMsgCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        _avatarView = [[UIImageView alloc] init];
        _avatarView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarView.clipsToBounds = YES;
        _avatarView.layer.cornerRadius = 18;
        _avatarView.backgroundColor = HexColor(0xE8E8E8);
        _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_avatarView];
        
        _senderLabel = [[UILabel alloc] init];
        _senderLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        _senderLabel.textColor = HexColor(0x333333);
        _senderLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_senderLabel];
        
        _timeLabel = [[UILabel alloc] init];
        _timeLabel.font = [UIFont systemFontOfSize:12];
        _timeLabel.textColor = HexColor(0x999999);
        _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_timeLabel];
        
        _contentLabel = [[UILabel alloc] init];
        _contentLabel.font = [UIFont systemFontOfSize:14];
        _contentLabel.textColor = HexColor(0x666666);
        _contentLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _contentLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_contentLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [_avatarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_avatarView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_avatarView.widthAnchor constraintEqualToConstant:36],
            [_avatarView.heightAnchor constraintEqualToConstant:36],
            
            [_senderLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:10],
            [_senderLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            
            [_timeLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_timeLabel.centerYAnchor constraintEqualToAnchor:_senderLabel.centerYAnchor],
            
            [_contentLabel.leadingAnchor constraintEqualToAnchor:_senderLabel.leadingAnchor],
            [_contentLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_contentLabel.topAnchor constraintEqualToAnchor:_senderLabel.bottomAnchor constant:4],
        ]];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.avatarView.image = nil;
    self.senderLabel.text = nil;
    self.timeLabel.text = nil;
    self.contentLabel.text = nil;
}

@end

#pragma mark - VoiceListCell（语音 Tab：左侧蓝色播放图标 + 发送者 + 时长・日期时间）

@interface VoiceListCell : UITableViewCell
@property (nonatomic, strong) UIView *playIconContainer;
@property (nonatomic, strong) UIImageView *playIconView;
@property (nonatomic, strong) UILabel *senderLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@end

@implementation VoiceListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        _playIconContainer = [[UIView alloc] init];
        _playIconContainer.backgroundColor = HexColor(0x4A90D9);
        _playIconContainer.layer.cornerRadius = 22;
        _playIconContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_playIconContainer];
        
        _playIconView = [[UIImageView alloc] init];
        UIImage *playImg = [UIImage systemImageNamed:@"play.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium]];
        _playIconView.image = [playImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _playIconView.tintColor = [UIColor whiteColor];
        _playIconView.contentMode = UIViewContentModeScaleAspectFit;
        _playIconView.translatesAutoresizingMaskIntoConstraints = NO;
        [_playIconContainer addSubview:_playIconView];
        
        _senderLabel = [[UILabel alloc] init];
        _senderLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _senderLabel.textColor = HexColor(0x333333);
        _senderLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_senderLabel];
        
        _detailLabel = [[UILabel alloc] init];
        _detailLabel.font = [UIFont systemFontOfSize:12];
        _detailLabel.textColor = HexColor(0x999999);
        _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_detailLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [_playIconContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_playIconContainer.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_playIconContainer.widthAnchor constraintEqualToConstant:44],
            [_playIconContainer.heightAnchor constraintEqualToConstant:44],
            [_playIconView.centerXAnchor constraintEqualToAnchor:_playIconContainer.centerXAnchor],
            [_playIconView.centerYAnchor constraintEqualToAnchor:_playIconContainer.centerYAnchor],
            
            [_senderLabel.leadingAnchor constraintEqualToAnchor:_playIconContainer.trailingAnchor constant:12],
            [_senderLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_senderLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            
            [_detailLabel.leadingAnchor constraintEqualToAnchor:_senderLabel.leadingAnchor],
            [_detailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_detailLabel.topAnchor constraintEqualToAnchor:_senderLabel.bottomAnchor constant:4],
            [_detailLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
        ]];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.senderLabel.text = nil;
    self.detailLabel.text = nil;
}

@end

#pragma mark - TypeFilteredMessagesViewController

@interface TypeFilteredMessagesViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, assign) int chatType;
@property (nonatomic, copy)   NSString *dataId;
@property (nonatomic, strong) NSArray<NSNumber *> *msgTypes;
@property (nonatomic, copy)   NSString *emptyText;
@property (nonatomic, assign) BOOL linkOnlyMode;
@property (nonatomic, assign) BOOL excludeTextWithURL;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *footerSpinner;
@property (nonatomic, strong) NSMutableArray<MsgDetailContentDTO *> *messageList;
@property (nonatomic, strong) NSMutableArray<MsgDetailContentDTO *> *filteredList;

@property (nonatomic, assign) int currentOffset;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMoreData;

@property (nonatomic, assign) int serverCurrentPage;

@property (nonatomic, strong) NSDateFormatter *timeFmt;
@property (nonatomic, strong) NSDateFormatter *voiceDetailDateFmt; // 语音行日期 "yyyy年M月d日 HH:mm"
@property (nonatomic, copy)   NSString *keyword;

- (void)applyFilter;

/// 语音点击播放用（直接复用聊天里的 JSQAudioMediaItem 播放逻辑）
@property (nonatomic, strong) JSQAudioMediaItem *audioItem;

@end

@implementation TypeFilteredMessagesViewController

- (BOOL)rb_usesVoiceRowStyle
{
    if (self.serverFavType == 2) {
        return YES;
    }
    return (!self.linkOnlyMode
            && self.msgTypes.count == 1
            && [self.msgTypes.firstObject intValue] == TM_TYPE_VOICE);
}

- (instancetype)initWithChatType:(int)chatType
                          dataId:(NSString *)dataId
                        msgTypes:(NSArray<NSNumber *> *)msgTypes
                       emptyText:(NSString *)emptyText
{
    self = [super init];
    if (self) {
        _chatType = chatType;
        _dataId = dataId ?: @"";
        _msgTypes = msgTypes;
        _emptyText = emptyText ?: @"暂无内容";
        _currentOffset = 0;
        _serverCurrentPage = 1;
        _serverFavType = 0;
        _isLoading = NO;
        _hasMoreData = YES;
        _messageList = [NSMutableArray array];
        _filteredList = [NSMutableArray array];
        _keyword = @"";
        _timeFmt = [[NSDateFormatter alloc] init];
        _timeFmt.dateFormat = @"yyyy-MM-dd HH:mm";
        _voiceDetailDateFmt = [[NSDateFormatter alloc] init];
        _voiceDetailDateFmt.dateFormat = @"yyyy年M月d日 HH:mm";
    }
    return self;
}

- (instancetype)initWithChatType:(int)chatType
                          dataId:(NSString *)dataId
                        msgTypes:(NSArray<NSNumber *> *)msgTypes
                       emptyText:(NSString *)emptyText
        excludeTextContainingURL:(BOOL)excludeTextContainingURL
{
    self = [super init];
    if (self) {
        _chatType = chatType;
        _dataId = dataId ?: @"";
        _msgTypes = msgTypes;
        _emptyText = emptyText ?: @"暂无内容";
        _linkOnlyMode = NO;
        _excludeTextWithURL = excludeTextContainingURL;
        _currentOffset = 0;
        _serverCurrentPage = 1;
        _serverFavType = 0;
        _isLoading = NO;
        _hasMoreData = YES;
        _messageList = [NSMutableArray array];
        _filteredList = [NSMutableArray array];
        _keyword = @"";
        _timeFmt = [[NSDateFormatter alloc] init];
        _timeFmt.dateFormat = @"yyyy-MM-dd HH:mm";
        _voiceDetailDateFmt = [[NSDateFormatter alloc] init];
        _voiceDetailDateFmt.dateFormat = @"yyyy年M月d日 HH:mm";
    }
    return self;
}

- (instancetype)initWithChatType:(int)chatType
                          dataId:(NSString *)dataId
                       emptyText:(NSString *)emptyText
                        linkOnly:(BOOL)linkOnly
{
    self = [super init];
    if (self) {
        _chatType = chatType;
        _dataId = dataId ?: @"";
        _msgTypes = nil;
        _emptyText = emptyText ?: @"暂无内容";
        _linkOnlyMode = linkOnly;
        _currentOffset = 0;
        _serverCurrentPage = 1;
        _serverFavType = 0;
        _isLoading = NO;
        _hasMoreData = YES;
        _messageList = [NSMutableArray array];
        _filteredList = [NSMutableArray array];
        _keyword = @"";
        _timeFmt = [[NSDateFormatter alloc] init];
        _timeFmt.dateFormat = @"yyyy-MM-dd HH:mm";
        _voiceDetailDateFmt = [[NSDateFormatter alloc] init];
        _voiceDetailDateFmt.dateFormat = @"yyyy年M月d日 HH:mm";
    }
    return self;
}

- (void)dealloc
{
    self.audioItem = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self buildUI];
    [self loadNextPage];
}

- (void)buildUI
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor whiteColor];
    BOOL voiceRows = [self rb_usesVoiceRowStyle];
    self.tableView.separatorInset = voiceRows ? UIEdgeInsetsMake(0, 72, 0, 0) : UIEdgeInsetsMake(0, 16, 0, 0);
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.rowHeight = voiceRows ? 72 : 56;
    self.tableView.estimatedRowHeight = voiceRows ? 72 : 56;
    [self.tableView registerClass:[TypeMsgCell class] forCellReuseIdentifier:kTypeMsgCellId];
    [self.tableView registerClass:[VoiceListCell class] forCellReuseIdentifier:kVoiceListCellId];

    [self.view addSubview:self.tableView];
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.footerSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.footerSpinner.center = CGPointMake(footerView.bounds.size.width / 2, 22);
    self.footerSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [footerView addSubview:self.footerSpinner];
    self.tableView.tableFooterView = footerView;
    
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = self.emptyText;
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

- (void)loadNextPage
{
    if (self.isLoading || !self.hasMoreData) return;
    self.isLoading = YES;
    [self.footerSpinner startAnimating];

    if (self.useServerFavoritesFor10001 && [self.dataId isEqualToString:@"10001"]) {
        NSString *userUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        if (!userUid.length) {
            [self.footerSpinner stopAnimating];
            self.isLoading = NO;
            return;
        }
        int page = self.serverCurrentPage;
        int requestFavType = self.serverFavType;
        NSArray<NSNumber *> *typeFilter = self.serverFavTypeFilter;
        if (typeFilter.count > 0) requestFavType = -1; // 多类型分组：拉全部再按 serverFavTypeFilter 过滤
        __weak typeof(self) wself = self;
        [[HttpRestHelper sharedInstance] submitGetFavoritesFromServer:userUid
                                                                page:page
                                                            pageSize:kPageSizeTypeFiltered
                                                             favType:requestFavType
                                                            complete:^(BOOL sucess, NSDictionary *result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) self = wself;
                if (!self) return;
                [self.footerSpinner stopAnimating];
                self.isLoading = NO;
                if (!sucess || ![result isKindOfClass:[NSDictionary class]]) {
                    self.hasMoreData = NO;
                    self.tableView.tableFooterView = [[UIView alloc] init];
                    [self applyFilter];
                    return;
                }
                NSArray *list = result[@"list"];
                if (![list isKindOfClass:[NSArray class]]) list = @[];
                int total = [result[@"total"] intValue];
                NSInteger added = 0;
                NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid ?: @"";
                for (NSDictionary *item in list) {
                    if (![item isKindOfClass:[NSDictionary class]]) continue;
                    int favType = [item[@"fav_type"] intValue];
                    if (typeFilter.count > 0) {
                        BOOL inSet = NO;
                        for (NSNumber *n in typeFilter) { if ([n intValue] == favType) { inSet = YES; break; } }
                        if (!inSet) continue;
                    }
                    if (self.serverLinkOnlyFilter) {
                        if (favType != 0) continue;
                        NSString *content = stringFromFavoriteItem(item[@"content"]);
                        if (content.length == 0 || ([content rangeOfString:@"http://" options:NSCaseInsensitiveSearch].location == NSNotFound && [content rangeOfString:@"https://" options:NSCaseInsensitiveSearch].location == NSNotFound)) continue;
                    }
                    MsgDetailContentDTO *dto = [[MsgDetailContentDTO alloc] init];
                    dto.chatType = self.chatType;
                    dto.dataId = self.dataId;
                    dto.senderId = stringFromFavoriteItem(item[@"source_from_uid"]);
                    dto.senderDisplayName = stringFromFavoriteItem(item[@"source_from_nickname"]);
                    if (dto.senderDisplayName.length == 0) dto.senderDisplayName = dto.senderId.length > 0 ? dto.senderId : @"";
                    if (dto.senderId.length == 0 || [dto.senderId isEqualToString:@"0"]) {
                        dto.senderId = localUid;
                        dto.senderDisplayName = [IMClientManager sharedInstance].localUserInfo.nickname ?: @"我";
                    }
                    dto.quoteSenderUid = dto.senderId;
                    dto.quoteSenderNick = dto.senderDisplayName;
                    dto.text = stringFromFavoriteItem(item[@"content"]);
                    dto.date = dateFromFavoriteCreateTime(item[@"create_time"]);
                    dto.fp = stringFromFavoriteItem(item[@"id"]);
                    dto.msgType = msgTypeFromFavType(favType);
                    [self.messageList addObject:dto];
                    added++;
                }
                if (list.count < kPageSizeTypeFiltered || (self.messageList.count >= total)) {
                    self.hasMoreData = NO;
                    self.tableView.tableFooterView = [[UIView alloc] init];
                }
                self.serverCurrentPage = page + 1;
                [self applyFilter];
            });
        } hudParentView:nil];
        return;
    }

    int offset = self.currentOffset;
    NSArray<NSNumber *> *types = self.msgTypes;
    BOOL linkOnly = self.linkOnlyMode;
    BOOL excludeLink = self.excludeTextWithURL;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSMutableArray<MsgDetailContentDTO *> *results = nil;
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            ChatHistoryTable *table = [[ChatHistoryTable alloc] init];
            if (linkOnly) {
                results = [table searchTextMessagesContainingURL:db
                                                        chatType:self.chatType
                                                        uidOrGid:self.dataId
                                                           limit:kPageSizeTypeFiltered
                                                          offset:offset];
            } else if (excludeLink && types.count > 0) {
                results = [table searchMessagesByTypes:db
                                              chatType:self.chatType
                                              uidOrGid:self.dataId
                                              msgTypes:types
                              excludeTextContainingURL:YES
                                                 limit:kPageSizeTypeFiltered
                                                offset:offset];
            } else {
                results = [table searchMessagesByTypes:db
                                              chatType:self.chatType
                                              uidOrGid:self.dataId
                                              msgTypes:types
                                                 limit:kPageSizeTypeFiltered
                                                offset:offset];
            }
        }];
        if (results == nil) results = [NSMutableArray array];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.footerSpinner stopAnimating];

            if (results.count < kPageSizeTypeFiltered) {
                self.hasMoreData = NO;
                self.tableView.tableFooterView = [[UIView alloc] init];
            }
            self.currentOffset = offset + (int)results.count;

            if (results.count > 0) {
                [self.messageList addObjectsFromArray:results];
            }

            [self applyFilter];
            self.isLoading = NO;
        });
    });
}

- (void)applyFilter
{
    [self.filteredList removeAllObjects];
    
    NSString *trimmed = [self.keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL hasKeyword = (trimmed.length > 0);
    
    if (!hasKeyword) {
        [self.filteredList addObjectsFromArray:self.messageList];
    } else {
        for (MsgDetailContentDTO *dto in self.messageList) {
            NSString *text = dto.text ?: @"";
            if (text.length == 0) {
                continue;
            }
            if ([text rangeOfString:trimmed options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [self.filteredList addObject:dto];
            }
        }
    }
    
    self.emptyLabel.hidden = (self.filteredList.count > 0);
    [self.tableView reloadData];
}

- (void)updateSearchKeyword:(NSString *)keyword
{
    self.keyword = keyword ?: @"";
    [self applyFilter];
}

- (NSInteger)currentDisplayedCount
{
    return (NSInteger)self.filteredList.count;
}

/// 按消息类型生成可读内容预览，避免多媒体/文件/位置等显示原始 JSON
- (NSString *)displayTextForDTO:(MsgDetailContentDTO *)dto
{
    NSString *raw = dto.text ?: @"";
    switch (dto.msgType) {
        case TM_TYPE_VOICE: {
            int duration = raw.length > 0 ? [TimeTool getDurationFromVoiceFileName:raw] : 0;
            return duration > 0 ? [NSString stringWithFormat:@"[语音] %d''", duration] : @"[语音]";
        }
        case TM_TYPE_IMAGE:
            return @"[图片]";
        case TM_TYPE_SHORTVIDEO:
            return @"[视频]";
        case TM_TYPE_FILE: {
            NSData *jsonData = [raw dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *fileInfo = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] : nil;
            NSString *fileName = [fileInfo isKindOfClass:[NSDictionary class]] && fileInfo[@"file_name"] ? fileInfo[@"file_name"] : raw;
            return fileName.length > 0 ? [NSString stringWithFormat:@"[文件] %@", fileName] : @"[文件]";
        }
        case TM_TYPE_LOCATION: {
            NSData *jsonData = [raw dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *locInfo = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] : nil;
            NSString *address = [locInfo isKindOfClass:[NSDictionary class]] && locInfo[@"address"] ? locInfo[@"address"] : raw;
            return address.length > 0 ? [NSString stringWithFormat:@"[位置] %@", address] : @"[位置]";
        }
        case TM_TYPE_CONTACT: {
            NSData *jsonData = [raw dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *card = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] : nil;
            if ([card isKindOfClass:[NSDictionary class]] && card[@"nickname"]) {
                return [NSString stringWithFormat:@"[名片] %@", card[@"nickname"]];
            }
            return @"[名片]";
        }
        case TM_TYPE_RED_PACKET:
            return @"「红包」";
        case TM_TYPE_TRANSFER:
            return @"「转账」";
        default:
            return raw.length > 0 ? raw : @"";
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.filteredList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MsgDetailContentDTO *dto = self.filteredList[indexPath.row];
    BOOL is10001Favorites = (self.dataId.length > 0 && [self.dataId isEqualToString:@"10001"]);
    NSString *senderName = dto.senderDisplayName;
    if (is10001Favorites && dto.quoteSenderNick.length > 0) {
        senderName = dto.quoteSenderNick;
    }
    if (senderName.length == 0) senderName = @"";
    
    // 语音 Tab（10001 收藏 fav_type=2）：左侧蓝色播放图标 + 发送者 + 时长・日期时间
    if ([self rb_usesVoiceRowStyle]) {
        VoiceListCell *cell = [tableView dequeueReusableCellWithIdentifier:kVoiceListCellId forIndexPath:indexPath];
        cell.senderLabel.text = senderName;
        int duration = (dto.text.length > 0) ? [TimeTool getDurationFromVoiceFileName:dto.text] : 0;
        NSString *durationStr = [TimeTool getMMSSFromSS:duration];
        NSString *dateStr = dto.date ? [self.voiceDetailDateFmt stringFromDate:dto.date] : @"";
        if (durationStr.length > 0 && dateStr.length > 0) {
            cell.detailLabel.text = [NSString stringWithFormat:@"%@ ・ %@", durationStr, dateStr];
        } else if (dateStr.length > 0) {
            cell.detailLabel.text = dateStr;
        } else {
            cell.detailLabel.text = durationStr.length > 0 ? durationStr : @"";
        }
        return cell;
    }
    
    TypeMsgCell *cell = [tableView dequeueReusableCellWithIdentifier:kTypeMsgCellId forIndexPath:indexPath];
    NSString *avatarUid = dto.senderId;
    if (is10001Favorites && dto.quoteSenderUid.length > 0) {
        avatarUid = dto.quoteSenderUid;
    }
    cell.avatarView.image = [UIImage imageNamed:@"default_avatar_60"];
    if (avatarUid.length > 0) {
        [FileDownloadHelper loadUserAvatarIntelligent:nil
                                                 uid:avatarUid
                                              logTag:@"TypeFilteredMessages"
                                             complete:^(BOOL sucess, UIImage *img) {
            if (sucess && img) {
                cell.avatarView.image = img;
            }
        } donotLoadFromDisk:NO];
    }
    cell.senderLabel.text = senderName;
    if (dto.date) {
        cell.timeLabel.text = [self.timeFmt stringFromDate:dto.date];
    } else {
        cell.timeLabel.text = @"";
    }
    cell.contentLabel.text = [self displayTextForDTO:dto];
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self rb_usesVoiceRowStyle] ? 72 : 56;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MsgDetailContentDTO *dto = self.filteredList[indexPath.row];
    
    // 语音 Tab：点击直接播放，不跳转聊天
    if ([self rb_usesVoiceRowStyle] && dto.msgType == TM_TYPE_VOICE && dto.text.length > 0) {
        [self playVoiceWithFileName:dto.text];
        return;
    }
    
    // 其他类型：跳转到聊天页并高亮对应消息
    if (dto.fp.length > 0) {
        MsgSummaryContentDTO *summaryDTO = [[MsgSummaryContentDTO alloc] init];
        summaryDTO.chatType = self.chatType;
        summaryDTO.dataId = self.dataId;
        
        [MsgSummaryContent toChattingPage:self.navigationController
                            hudParentView:self.view
                         parentContentDto:summaryDTO
                  highlightOnceMsgFingerprint:dto.fp
                        anchorMessageDate:dto.date];
    }
}

#pragma mark - 语音播放

- (void)playVoiceWithFileName:(NSString *)fileName
{
    if (fileName.length == 0) return;
    
    // 直接复用聊天界面的 JSQAudioMediaItem 播放逻辑（内部会处理本地缓存/网络下载/AMR 解码）
    self.audioItem = [[JSQAudioMediaItem alloc] initWithData:fileName];
    [self.audioItem onPlayButton:nil];
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

@end
