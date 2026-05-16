//
//  FavPickerViewController.m
//  RainbowChat4i
//
//  收藏内容选择器实现。
//

#import "FavPickerViewController.h"
#import "IMClientManager.h"
#import "BasicTool.h"
#import "FileDownloadHelper.h"
#import "SendImageHelper.h"
#import "UIImageView+WebCache.h"
#import "ChatHistoryTable.h"
#import "MyDataBase.h"
#import "MsgDetailContentDTO.h"
#import "FileMeta.h"
#import "MessagesProvider.h"
#import "ReceivedShortVideoHelper.h"

#define FP_HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

// 收藏类型常量
static const int FP_FAV_TYPE_TEXT     = 0;
static const int FP_FAV_TYPE_IMAGE    = 1;
static const int FP_FAV_TYPE_VOICE    = 2;
static const int FP_FAV_TYPE_VIDEO    = 3;
static const int FP_FAV_TYPE_FILE     = 4;
static const int FP_FAV_TYPE_LOCATION = 5;

static const int kFPPageSize = 50;

static NSString *FPFavoriteTypeTitle(int favType) {
    switch (favType) {
        case FP_FAV_TYPE_TEXT:     return @"文字收藏";
        case FP_FAV_TYPE_IMAGE:    return @"图片收藏";
        case FP_FAV_TYPE_VOICE:    return @"语音收藏";
        case FP_FAV_TYPE_VIDEO:    return @"视频收藏";
        case FP_FAV_TYPE_FILE:     return @"文件收藏";
        case FP_FAV_TYPE_LOCATION: return @"位置收藏";
        default:                   return @"收藏内容";
    }
}

static NSString *FPFavoritePreviewText(NSDictionary *item) {
    int favType = [item[@"fav_type"] intValue];
    NSString *content = item[@"content"] ?: @"";
    switch (favType) {
        case FP_FAV_TYPE_TEXT:
            return (content.length > 0 ? content : @"(空文本)");
        case FP_FAV_TYPE_IMAGE:
            return @"";
        case FP_FAV_TYPE_VOICE:
            return @"[语音]";
        case FP_FAV_TYPE_VIDEO:
            return @"";
        case FP_FAV_TYPE_FILE:
            return @"[文件]";
        case FP_FAV_TYPE_LOCATION:
            return (content.length > 0 ? content : @"[位置]");
        default:
            return (content.length > 0 ? content : @"[收藏内容]");
    }
}

#pragma mark - FavPickerCell

@interface FavPickerCell : UITableViewCell

@property (nonatomic, strong) UIImageView *typeIconView;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UILabel *sourceLabel;
@property (nonatomic, strong) UIImageView *previewImageView;

@end

@implementation FavPickerCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        // 类型图标
        self.typeIconView = [[UIImageView alloc] init];
        self.typeIconView.translatesAutoresizingMaskIntoConstraints = NO;
        self.typeIconView.contentMode = UIViewContentModeScaleAspectFit;
        self.typeIconView.tintColor = FP_HexColor(0x07C160);
        [self.contentView addSubview:self.typeIconView];
        
        // 预览图
        self.previewImageView = [[UIImageView alloc] init];
        self.previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.previewImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.previewImageView.clipsToBounds = YES;
        self.previewImageView.layer.cornerRadius = 4;
        self.previewImageView.hidden = YES;
        [self.contentView addSubview:self.previewImageView];
        
        // 内容标签
        self.contentLabel = [[UILabel alloc] init];
        self.contentLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.contentLabel.font = [UIFont systemFontOfSize:15];
        self.contentLabel.textColor = [UIColor darkTextColor];
        self.contentLabel.numberOfLines = 2;
        [self.contentView addSubview:self.contentLabel];
        
        // 来源标签
        self.sourceLabel = [[UILabel alloc] init];
        self.sourceLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.sourceLabel.font = [UIFont systemFontOfSize:12];
        self.sourceLabel.textColor = [UIColor grayColor];
        [self.contentView addSubview:self.sourceLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.typeIconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [self.typeIconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.typeIconView.widthAnchor constraintEqualToConstant:24],
            [self.typeIconView.heightAnchor constraintEqualToConstant:24],
            
            [self.contentLabel.leadingAnchor constraintEqualToAnchor:self.typeIconView.trailingAnchor constant:12],
            [self.contentLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [self.contentLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-50],
            
            [self.sourceLabel.leadingAnchor constraintEqualToAnchor:self.contentLabel.leadingAnchor],
            [self.sourceLabel.topAnchor constraintEqualToAnchor:self.contentLabel.bottomAnchor constant:4],
            [self.sourceLabel.trailingAnchor constraintEqualToAnchor:self.contentLabel.trailingAnchor],
            [self.sourceLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-10],
            
            [self.previewImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
            [self.previewImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.previewImageView.widthAnchor constraintEqualToConstant:44],
            [self.previewImageView.heightAnchor constraintEqualToConstant:44],
        ]];
    }
    return self;
}

- (void)configureWithData:(NSDictionary *)item
{
    int favType = [item[@"fav_type"] intValue];
    NSString *content = item[@"content"] ?: @"";
    NSString *sourceNick = item[@"source_from_nickname"] ?: @"";
    NSString *memo = item[@"memo"] ?: @"";
    
    self.previewImageView.hidden = YES;
    self.previewImageView.image = nil;
    
    // 类型图标和内容
    if (@available(iOS 13.0, *)) {
        switch (favType) {
            case FP_FAV_TYPE_TEXT:
                self.typeIconView.image = [UIImage systemImageNamed:@"doc.text"];
                self.contentLabel.text = content;
                break;
            case FP_FAV_TYPE_IMAGE:
                self.typeIconView.image = [UIImage systemImageNamed:@"photo"];
                self.contentLabel.text = @"[图片]";
                [self loadImagePreview:content];
                break;
            case FP_FAV_TYPE_VOICE:
                self.typeIconView.image = [UIImage systemImageNamed:@"mic"];
                self.contentLabel.text = @"[语音]";
                break;
            case FP_FAV_TYPE_VIDEO:
                self.typeIconView.image = [UIImage systemImageNamed:@"video"];
                self.contentLabel.text = item[@"preview_text"] ?: @"[视频]";
                [self loadVideoPreview:item];
                break;
            case FP_FAV_TYPE_FILE:
                self.typeIconView.image = [UIImage systemImageNamed:@"doc"];
                self.contentLabel.text = @"[文件]";
                break;
            case FP_FAV_TYPE_LOCATION:
                self.typeIconView.image = [UIImage systemImageNamed:@"location"];
                self.contentLabel.text = @"[位置]";
                break;
            default:
                self.typeIconView.image = [UIImage systemImageNamed:@"star"];
                self.contentLabel.text = content;
                break;
        }
    } else {
        self.contentLabel.text = (favType == FP_FAV_TYPE_TEXT) ? content : [NSString stringWithFormat:@"[收藏内容 - 类型%d]", favType];
    }
    
    // 来源和备注
    NSMutableString *info = [NSMutableString string];
    if (memo.length > 0) {
        [info appendFormat:@"备注：%@", memo];
    }
    if (sourceNick.length > 0) {
        if (info.length > 0) [info appendString:@" · "];
        [info appendFormat:@"来自 %@", sourceNick];
    }
    self.sourceLabel.text = info;
}

- (void)loadImagePreview:(NSString *)fileName
{
    if (fileName.length == 0) return;
    
    self.previewImageView.hidden = NO;
    
    // 列表预览：pv_ + 原文件名（与 savePreviewJpegMaxEdge 一致）
    NSString *previewName = [NSString stringWithFormat:@"pv_%@", fileName];
    NSString *thumbURL = [SendImageHelper getImageDownloadURL:previewName dump:NO];
    if (thumbURL) {
        [self.previewImageView sd_setImageWithURL:[NSURL URLWithString:thumbURL]
                                 placeholderImage:nil];
    }
}

- (void)loadVideoPreview:(NSDictionary *)item
{
    NSString *jsonUse = RBNormalizeFileMetaJSONStringForHistory(item[@"content"]);
    if (jsonUse.length == 0) {
        jsonUse = item[@"content"] ?: @"";
    }
    FileMeta *fileMeta = [FileMeta fromJSON:jsonUse];
    if (fileMeta.fileName.length == 0 || fileMeta.fileMd5.length == 0) {
        self.previewImageView.hidden = YES;
        return;
    }

    self.previewImageView.hidden = NO;
    self.previewImageView.image = [UIImage imageNamed:@"default_short_video_thumb"];
    NSString *thumbName = [ReceivedShortVideoHelper constructShortVideoThumbName_localSaved:fileMeta.fileName];
    NSString *thumbURL = [ReceivedShortVideoHelper getShortVideoThumbDownloadURL:thumbName videofileMd5:fileMeta.fileMd5];
    __weak typeof(self) weakSelf = self;
    [FileDownloadHelper loadChattingShortVideoPreviewImgWithURL:thumbURL logTag:@"收藏选择器-短视频预览" complete:^(BOOL sucess, UIImage *img) {
        if (!weakSelf) return;
        if (sucess && img != nil) {
            weakSelf.previewImageView.image = img;
        }
    }];
}

@end


#pragma mark - FavPickerViewController

@interface FavPickerViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *dataList;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;

@property (nonatomic, assign) int currentOffset;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMoreData;
@property (nonatomic, strong) UIControl *confirmMaskView;
@property (nonatomic, strong) UIView *confirmCardView;
@property (nonatomic, strong) UIImageView *confirmTargetAvatarView;
@property (nonatomic, strong) UILabel *confirmTargetNameLabel;
@property (nonatomic, strong) UILabel *confirmTypeLabel;
@property (nonatomic, strong) UILabel *confirmContentLabel;
@property (nonatomic, strong) UILabel *confirmSourceLabel;
@property (nonatomic, strong) UIImageView *confirmPreviewImageView;
@property (nonatomic, strong) NSLayoutConstraint *confirmPreviewHeightConstraint;
@property (nonatomic, strong) NSDictionary *pendingConfirmItem;

@end

@implementation FavPickerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"选择收藏";
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.dataList = [NSMutableArray array];
    self.currentOffset = 0;
    self.hasMoreData = YES;
    
    [self setupNavigationBar];
    [self setupUI];
    [self loadDataFromChat10001];
}

- (void)setupNavigationBar
{
    // 取消按钮
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(cancelPicker)];
}

- (void)setupUI
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
    [self.tableView registerClass:[FavPickerCell class] forCellReuseIdentifier:@"FavPickerCell"];
    self.tableView.tableFooterView = [[UIView alloc] init];
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    
    // 空状态
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.text = @"暂无收藏内容";
    self.emptyLabel.textColor = [UIColor grayColor];
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
    
    // 加载中指示器
    self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.loadingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingView.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.loadingView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (void)cancelPicker
{
    [self fp_hideConfirmPopupAnimated:NO];
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.completion) {
            self.completion(nil);
        }
    }];
}

#pragma mark - 数据加载

- (NSDictionary *)buildItemFromChatDTO:(MsgDetailContentDTO *)dto
{
    if (!dto) return @{};
    
    int favType = FP_FAV_TYPE_TEXT;
    switch (dto.msgType) {
        case TM_TYPE_TEXT:       favType = FP_FAV_TYPE_TEXT;     break;
        case TM_TYPE_IMAGE:      favType = FP_FAV_TYPE_IMAGE;    break;
        case TM_TYPE_VOICE:      favType = FP_FAV_TYPE_VOICE;    break;
        case TM_TYPE_SHORTVIDEO: favType = FP_FAV_TYPE_VIDEO;    break;
        case TM_TYPE_FILE:       favType = FP_FAV_TYPE_FILE;     break;
        case TM_TYPE_LOCATION:   favType = FP_FAV_TYPE_LOCATION; break;
        default:                 favType = FP_FAV_TYPE_TEXT;     break;
    }
    
    NSString *content = dto.text ?: @"";
    NSString *previewText = nil;
    NSString *videoFileName = @"";
    NSString *videoFileMd5 = @"";
    NSNumber *videoFileLength = @(0);
    if (favType == FP_FAV_TYPE_VIDEO) {
        NSString *jsonUse = RBNormalizeFileMetaJSONStringForHistory(content);
        if (jsonUse.length == 0) {
            jsonUse = content;
        }
        FileMeta *fileMeta = [FileMeta fromJSON:jsonUse];
        if (fileMeta.fileName.length > 0) {
            previewText = fileMeta.fileName;
            videoFileName = fileMeta.fileName ?: @"";
            videoFileMd5 = fileMeta.fileMd5 ?: @"";
            videoFileLength = @(fileMeta.fileLength);
            content = jsonUse ?: content;
        }
    }
    if (previewText.length == 0) {
        previewText = FPFavoritePreviewText(@{
            @"fav_type": @(favType),
            @"content": content ?: @""
        });
    }
    
    // 来源昵称：优先使用 quoteSenderNick，其次 senderDisplayName，最后 uid
    NSString *sourceNick = nil;
    if ([dto respondsToSelector:@selector(quoteSenderNick)] && dto.quoteSenderNick.length > 0) {
        sourceNick = dto.quoteSenderNick;
    } else if (dto.senderDisplayName.length > 0) {
        sourceNick = dto.senderDisplayName;
    } else {
        sourceNick = dto.senderId ?: @"";
    }
    
    return @{
        @"fav_type": @(favType),
        @"content": content,
        @"source_from_nickname": sourceNick ?: @"",
        @"memo": @"",
        @"preview_text": previewText ?: @"",
        @"video_file_name": videoFileName,
        @"video_file_md5": videoFileMd5,
        @"video_file_length": videoFileLength
    };
}

- (void)loadDataFromChat10001
{
    if (self.isLoading || !self.hasMoreData) return;
    self.isLoading = YES;
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!localUid) {
        self.isLoading = NO;
        return;
    }
    
    if (self.dataList.count == 0) {
        [self.loadingView startAnimating];
    }
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSMutableArray<MsgDetailContentDTO *> *results = nil;
        
        [MyDataBase inDatabase:^(FMDatabase *db) {
            ChatHistoryTable *table = [[ChatHistoryTable alloc] init];
            NSArray<NSNumber *> *msgTypes = @[
                @(TM_TYPE_TEXT),
                @(TM_TYPE_IMAGE),
                @(TM_TYPE_VOICE),
                @(TM_TYPE_SHORTVIDEO),
                @(TM_TYPE_FILE),
                @(TM_TYPE_LOCATION)
            ];
            results = [table searchMessagesByTypes:db
                                          chatType:MSSR_SEARCH_RESULT_CHAT_TYPE_SINGLE
                                          uidOrGid:@"10001"
                                          msgTypes:msgTypes
                                             limit:kFPPageSize
                                            offset:weakSelf.currentOffset];
        }];
        
        if (!results) results = [NSMutableArray array];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.isLoading = NO;
            [weakSelf.loadingView stopAnimating];
            
            if (results.count > 0) {
                for (MsgDetailContentDTO *dto in results) {
                    NSDictionary *item = [weakSelf buildItemFromChatDTO:dto];
                    [weakSelf.dataList addObject:item];
                }
                weakSelf.currentOffset += (int)results.count;
                weakSelf.hasMoreData = (results.count == kFPPageSize);
                [weakSelf.tableView reloadData];
            } else {
                weakSelf.hasMoreData = NO;
            }
            
            weakSelf.emptyLabel.hidden = (weakSelf.dataList.count > 0);
        });
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.dataList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FavPickerCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FavPickerCell" forIndexPath:indexPath];
    NSDictionary *item = self.dataList[indexPath.row];
    [cell configureWithData:item];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *item = self.dataList[indexPath.row];
    [self fp_showConfirmPopupForItem:item];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // 滚动到底部自动加载下一页
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat height = scrollView.frame.size.height;
    
    if (offsetY > contentHeight - height - 100 && !self.isLoading && self.hasMoreData) {
        [self loadDataFromChat10001];
    }
}

#pragma mark - 自定义确认弹窗

- (void)fp_ensureConfirmPopup
{
    if (self.confirmMaskView != nil) {
        return;
    }

    UIControl *mask = [[UIControl alloc] init];
    mask.translatesAutoresizingMaskIntoConstraints = NO;
    mask.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.32];
    mask.alpha = 0.0;
    [mask addTarget:self action:@selector(fp_hideConfirmPopupFromMask) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:mask];
    self.confirmMaskView = mask;

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 20.0f;
    if (@available(iOS 11.0, *)) {
        card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    }
    card.clipsToBounds = YES;
    [mask addSubview:card];
    self.confirmCardView = card;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    titleLabel.textColor = FP_HexColor(0x111111);
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.text = @"发送给";
    [card addSubview:titleLabel];

    UIImageView *targetAvatarView = [[UIImageView alloc] init];
    targetAvatarView.translatesAutoresizingMaskIntoConstraints = NO;
    targetAvatarView.backgroundColor = FP_HexColor(0xEDEEF2);
    targetAvatarView.layer.cornerRadius = 22.0f;
    targetAvatarView.clipsToBounds = YES;
    targetAvatarView.contentMode = UIViewContentModeScaleAspectFill;
    targetAvatarView.image = [UIImage imageNamed:@"default_avatar_60"];
    [card addSubview:targetAvatarView];
    self.confirmTargetAvatarView = targetAvatarView;

    UILabel *targetNameLabel = [[UILabel alloc] init];
    targetNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    targetNameLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    targetNameLabel.textColor = FP_HexColor(0x111111);
    targetNameLabel.text = self.targetName.length > 0 ? self.targetName : @"当前聊天";
    [card addSubview:targetNameLabel];
    self.confirmTargetNameLabel = targetNameLabel;

    UILabel *chevronLabel = [[UILabel alloc] init];
    chevronLabel.translatesAutoresizingMaskIntoConstraints = NO;
    chevronLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightRegular];
    chevronLabel.textColor = FP_HexColor(0xA0A4AB);
    chevronLabel.text = @"›";
    [card addSubview:chevronLabel];

    UIView *contentPanel = [[UIView alloc] init];
    contentPanel.translatesAutoresizingMaskIntoConstraints = NO;
    contentPanel.backgroundColor = [UIColor whiteColor];
    contentPanel.layer.cornerRadius = 14.0f;
    [card addSubview:contentPanel];

    UILabel *contentLabel = [[UILabel alloc] init];
    contentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    contentLabel.font = [UIFont systemFontOfSize:16];
    contentLabel.textColor = FP_HexColor(0x1F2329);
    contentLabel.numberOfLines = 6;
    [contentPanel addSubview:contentLabel];
    self.confirmContentLabel = contentLabel;

    UIImageView *previewImageView = [[UIImageView alloc] init];
    previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
    previewImageView.contentMode = UIViewContentModeScaleAspectFill;
    previewImageView.clipsToBounds = YES;
    previewImageView.layer.cornerRadius = 10.0f;
    previewImageView.hidden = YES;
    [contentPanel addSubview:previewImageView];
    self.confirmPreviewImageView = previewImageView;

    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    cancelButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    [cancelButton setTitleColor:FP_HexColor(0x111111) forState:UIControlStateNormal];
    cancelButton.backgroundColor = FP_HexColor(0xEFEFEF);
    cancelButton.layer.cornerRadius = 14.0f;
    cancelButton.clipsToBounds = YES;
    [cancelButton addTarget:self action:@selector(fp_hideConfirmPopupFromButton) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:cancelButton];

    UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    sendButton.translatesAutoresizingMaskIntoConstraints = NO;
    sendButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [sendButton setTitle:@"发送" forState:UIControlStateNormal];
    [sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sendButton.backgroundColor = FP_HexColor(0x07C160);
    sendButton.layer.cornerRadius = 14.0f;
    sendButton.clipsToBounds = YES;
    [sendButton addTarget:self action:@selector(fp_confirmSendSelectedFavorite) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:sendButton];

    self.confirmPreviewHeightConstraint = [previewImageView.heightAnchor constraintEqualToConstant:0.0];

    [NSLayoutConstraint activateConstraints:@[
        [mask.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [mask.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [mask.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [mask.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [card.leadingAnchor constraintEqualToAnchor:mask.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:mask.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:mask.bottomAnchor],

        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],

        [targetAvatarView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:14],
        [targetAvatarView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [targetAvatarView.widthAnchor constraintEqualToConstant:44],
        [targetAvatarView.heightAnchor constraintEqualToConstant:44],

        [targetNameLabel.centerYAnchor constraintEqualToAnchor:targetAvatarView.centerYAnchor],
        [targetNameLabel.leadingAnchor constraintEqualToAnchor:targetAvatarView.trailingAnchor constant:14],
        [targetNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevronLabel.leadingAnchor constant:-10],

        [chevronLabel.centerYAnchor constraintEqualToAnchor:targetAvatarView.centerYAnchor],
        [chevronLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],

        [contentPanel.topAnchor constraintEqualToAnchor:targetAvatarView.bottomAnchor constant:14],
        [contentPanel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [contentPanel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],

        [contentLabel.topAnchor constraintEqualToAnchor:contentPanel.topAnchor constant:20],
        [contentLabel.leadingAnchor constraintEqualToAnchor:contentPanel.leadingAnchor constant:14],
        [contentLabel.trailingAnchor constraintEqualToAnchor:contentPanel.trailingAnchor constant:-14],

        [previewImageView.topAnchor constraintEqualToAnchor:contentLabel.bottomAnchor constant:14],
        [previewImageView.leadingAnchor constraintEqualToAnchor:contentLabel.leadingAnchor],
        [previewImageView.trailingAnchor constraintEqualToAnchor:contentLabel.trailingAnchor],
        self.confirmPreviewHeightConstraint,

        [previewImageView.bottomAnchor constraintEqualToAnchor:contentPanel.bottomAnchor constant:-20],

        [cancelButton.topAnchor constraintEqualToAnchor:contentPanel.bottomAnchor constant:28],
        [cancelButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [cancelButton.heightAnchor constraintEqualToConstant:56],
        [cancelButton.bottomAnchor constraintEqualToAnchor:card.safeAreaLayoutGuide.bottomAnchor constant:-20],

        [sendButton.topAnchor constraintEqualToAnchor:cancelButton.topAnchor],
        [sendButton.leadingAnchor constraintEqualToAnchor:cancelButton.trailingAnchor constant:18],
        [sendButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [sendButton.widthAnchor constraintEqualToAnchor:cancelButton.widthAnchor],
        [sendButton.heightAnchor constraintEqualToAnchor:cancelButton.heightAnchor],
        [sendButton.bottomAnchor constraintEqualToAnchor:cancelButton.bottomAnchor]
    ]];
}

- (void)fp_showConfirmPopupForItem:(NSDictionary *)item
{
    if (item == nil) {
        return;
    }
    [self fp_ensureConfirmPopup];
    self.pendingConfirmItem = item;

    int favType = [item[@"fav_type"] intValue];
    NSString *previewText = FPFavoritePreviewText(item);
    self.confirmContentLabel.text = previewText;
    self.confirmContentLabel.hidden = (previewText.length == 0);
    self.confirmTargetNameLabel.text = self.targetName.length > 0 ? self.targetName : @"当前聊天";

    self.confirmPreviewImageView.hidden = YES;
    self.confirmPreviewImageView.image = nil;
    self.confirmPreviewHeightConstraint.constant = 0.0f;

    if (favType == FP_FAV_TYPE_IMAGE) {
        NSString *fileName = item[@"content"] ?: @"";
        if (fileName.length > 0) {
            NSString *previewName = [NSString stringWithFormat:@"pv_%@", fileName];
            NSString *thumbURL = [SendImageHelper getImageDownloadURL:previewName dump:NO];
            if (thumbURL.length > 0) {
                self.confirmPreviewImageView.hidden = NO;
                self.confirmPreviewHeightConstraint.constant = 190.0f;
                [self.confirmPreviewImageView sd_setImageWithURL:[NSURL URLWithString:thumbURL] placeholderImage:nil];
            }
        }
    }
    else if (favType == FP_FAV_TYPE_VIDEO) {
        NSString *jsonUse = RBNormalizeFileMetaJSONStringForHistory(item[@"content"]);
        if (jsonUse.length == 0) {
            jsonUse = item[@"content"] ?: @"";
        }
        FileMeta *fileMeta = [FileMeta fromJSON:jsonUse];
        if (fileMeta.fileName.length > 0 && fileMeta.fileMd5.length > 0) {
            NSString *thumbName = [ReceivedShortVideoHelper constructShortVideoThumbName_localSaved:fileMeta.fileName];
            NSString *thumbUrl = [ReceivedShortVideoHelper getShortVideoThumbDownloadURL:thumbName videofileMd5:fileMeta.fileMd5];
            self.confirmPreviewImageView.hidden = NO;
            self.confirmPreviewHeightConstraint.constant = 190.0f;
            self.confirmPreviewImageView.image = [UIImage imageNamed:@"default_short_video_thumb"];
            [FileDownloadHelper loadChattingShortVideoPreviewImgWithURL:thumbUrl logTag:@"收藏确认弹窗-短视频预览" complete:^(BOOL sucess, UIImage *img) {
                if (sucess && img != nil) {
                    self.confirmPreviewImageView.image = img;
                }
            }];
        }
    }

    [self fp_refreshConfirmTargetAvatar];

    self.confirmMaskView.hidden = NO;
    [self.confirmMaskView layoutIfNeeded];
    self.confirmCardView.transform = CGAffineTransformMakeTranslation(0.0, CGRectGetHeight(self.confirmCardView.bounds) + self.view.safeAreaInsets.bottom + 20.0);
    [UIView animateWithDuration:0.2 animations:^{
        self.confirmMaskView.alpha = 1.0;
        self.confirmCardView.transform = CGAffineTransformIdentity;
    }];
}


- (void)fp_refreshConfirmTargetAvatar
{
    self.confirmTargetAvatarView.image = [UIImage imageNamed:@"default_avatar_60"];
    if (self.targetId.length > 0) {
        __weak typeof(self) weakSelf = self;
        [FileDownloadHelper loadUserAvatarWithUID:self.targetId logTag:@"FavPicker-TargetAvatar" complete:^(BOOL sucess, UIImage *img) {
            if (!weakSelf) return;
            if (sucess && img != nil) {
                weakSelf.confirmTargetAvatarView.image = img;
            }
        } donotLoadFromDisk:NO];
    }
}
- (void)fp_hideConfirmPopupAnimated:(BOOL)animated
{
    if (self.confirmMaskView == nil || self.confirmMaskView.hidden) {
        return;
    }
    void (^animations)(void) = ^{
        self.confirmMaskView.alpha = 0.0;
        self.confirmCardView.transform = CGAffineTransformMakeTranslation(0.0, CGRectGetHeight(self.confirmCardView.bounds) + self.view.safeAreaInsets.bottom + 20.0);
    };
    void (^completion)(BOOL) = ^(BOOL finished) {
        self.confirmMaskView.hidden = YES;
        self.pendingConfirmItem = nil;
        self.confirmCardView.transform = CGAffineTransformIdentity;
    };
    if (animated) {
        [UIView animateWithDuration:0.18 animations:animations completion:completion];
    } else {
        animations();
        completion(YES);
    }
}

- (void)fp_hideConfirmPopupFromMask
{
    [self fp_hideConfirmPopupAnimated:YES];
}

- (void)fp_hideConfirmPopupFromButton
{
    [self fp_hideConfirmPopupAnimated:YES];
}

- (void)fp_confirmSendSelectedFavorite
{
    NSDictionary *item = self.pendingConfirmItem;
    [self fp_hideConfirmPopupAnimated:NO];
    if (item == nil) {
        return;
    }
    [self dismissViewControllerAnimated:YES completion:^{
        if (self.completion) {
            self.completion(item);
        }
    }];
}

@end
