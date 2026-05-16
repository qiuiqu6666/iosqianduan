//
//  FavoritesViewController.m
//  RainbowChat4i
//
//  收藏列表页面实现（微信风格，支持分页加载、类型筛选、编辑备注、批量删除、点击查看内容）。
//

#import "FavoritesViewController.h"
#import "BasicTool.h"
#import "IMClientManager.h"
#import "HttpRestHelper.h"
#import "FileDownloadHelper.h"
#import "SendImageHelper.h"
#import "SendVoiceHelper.h"
#import "ReceivedShortVideoHelper.h"
#import "ViewControllerFactory.h"
#import "LPActionSheet.h"
#import "AppDelegate.h"
#import "Default.h"
#import "DDLog.h"
#import "UIImageView+WebCache.h"
#import "UIView+WebCache.h"
#import "MSSBrowseNetworkViewController.h"
#import "MSSBrowseModel.h"
#import "MessageHelper.h"
#import "GMessageHelper.h"
#import "TMessageHelper.h"
#import "MsgBodyRoot.h"
#import "ChatRootViewController.h"
#import "TargetSourceFilterFactory.h"
#import "Protocal.h"
#import "ChatDataHelper.h"
#import "TChatDataHelper.h"
#import "GChatDataHelper.h"
#import "JSQMessage.h"
#import "MessagesProvider.h"
#import "FileMeta.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <MapKit/MapKit.h>

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

// 收藏类型常量
static const int FAV_TYPE_ALL      = -1;
static const int FAV_TYPE_TEXT     = 0;
static const int FAV_TYPE_IMAGE    = 1;
static const int FAV_TYPE_VOICE    = 2;
static const int FAV_TYPE_VIDEO    = 3;
static const int FAV_TYPE_FILE     = 4;
static const int FAV_TYPE_LOCATION = 5;

static const int kPageSize = 20;

#pragma mark - FavoritesCell

@interface FavoritesCell : UITableViewCell

@property (nonatomic, strong) UIImageView *typeIconView;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UILabel *sourceLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIImageView *previewImageView;

// 用于动态切换的约束
@property (nonatomic, strong) NSLayoutConstraint *contentTrailingToEdge;
@property (nonatomic, strong) NSLayoutConstraint *contentTrailingToPreview;
@property (nonatomic, strong) NSLayoutConstraint *timeLabelTrailingToEdge;
@property (nonatomic, strong) NSLayoutConstraint *timeLabelTrailingToPreview;

// 视频播放图标
@property (nonatomic, strong) UIImageView *playIconView;
/// 防止异步回调写到已复用的 cell
@property (nonatomic, copy) NSString *rb_previewLoadToken;

@end

@implementation FavoritesCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = [UIColor whiteColor];
        self.accessoryType = UITableViewCellAccessoryNone;
        
        // 类型图标
        self.typeIconView = [[UIImageView alloc] init];
        self.typeIconView.translatesAutoresizingMaskIntoConstraints = NO;
        self.typeIconView.contentMode = UIViewContentModeScaleAspectFit;
        self.typeIconView.tintColor = [UIColor grayColor];
        [self.contentView addSubview:self.typeIconView];
        
        // 预览图（图片/视频类型使用）
        self.previewImageView = [[UIImageView alloc] init];
        self.previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.previewImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.previewImageView.clipsToBounds = YES;
        self.previewImageView.layer.cornerRadius = 4;
        self.previewImageView.hidden = YES;
        self.previewImageView.userInteractionEnabled = YES;
        [self.contentView addSubview:self.previewImageView];
        
        // 视频播放图标（覆盖在 previewImageView 上）
        self.playIconView = [[UIImageView alloc] init];
        self.playIconView.translatesAutoresizingMaskIntoConstraints = NO;
        self.playIconView.contentMode = UIViewContentModeScaleAspectFit;
        self.playIconView.hidden = YES;
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
            self.playIconView.image = [UIImage systemImageNamed:@"play.circle.fill" withConfiguration:config];
            self.playIconView.tintColor = [UIColor whiteColor];
        }
        [self.previewImageView addSubview:self.playIconView];
        
        // 内容
        self.contentLabel = [[UILabel alloc] init];
        self.contentLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.contentLabel.font = [UIFont systemFontOfSize:15];
        self.contentLabel.textColor = [UIColor blackColor];
        self.contentLabel.numberOfLines = 2;
        [self.contentView addSubview:self.contentLabel];
        
        // 来源
        self.sourceLabel = [[UILabel alloc] init];
        self.sourceLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.sourceLabel.font = [UIFont systemFontOfSize:12];
        self.sourceLabel.textColor = [UIColor grayColor];
        [self.contentView addSubview:self.sourceLabel];
        
        // 时间
        self.timeLabel = [[UILabel alloc] init];
        self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.timeLabel.font = [UIFont systemFontOfSize:11];
        self.timeLabel.textColor = [UIColor lightGrayColor];
        self.timeLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:self.timeLabel];
        
        // 创建动态约束
        self.contentTrailingToEdge = [self.contentLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16];
        self.contentTrailingToPreview = [self.contentLabel.trailingAnchor constraintEqualToAnchor:self.previewImageView.leadingAnchor constant:-10];
        
        self.timeLabelTrailingToEdge = [self.timeLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16];
        self.timeLabelTrailingToPreview = [self.timeLabel.trailingAnchor constraintEqualToAnchor:self.previewImageView.leadingAnchor constant:-10];
        
        // 默认激活 toEdge
        self.contentTrailingToEdge.active = YES;
        self.timeLabelTrailingToEdge.active = YES;
        
        [NSLayoutConstraint activateConstraints:@[
            // 类型图标
            [self.typeIconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [self.typeIconView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14],
            [self.typeIconView.widthAnchor constraintEqualToConstant:20],
            [self.typeIconView.heightAnchor constraintEqualToConstant:20],
            
            // 预览图
            [self.previewImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [self.previewImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [self.previewImageView.widthAnchor constraintEqualToConstant:60],
            [self.previewImageView.heightAnchor constraintEqualToConstant:60],
            [self.previewImageView.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-12],
            
            // 播放图标居中于预览图
            [self.playIconView.centerXAnchor constraintEqualToAnchor:self.previewImageView.centerXAnchor],
            [self.playIconView.centerYAnchor constraintEqualToAnchor:self.previewImageView.centerYAnchor],
            [self.playIconView.widthAnchor constraintEqualToConstant:28],
            [self.playIconView.heightAnchor constraintEqualToConstant:28],
            
            // 内容
            [self.contentLabel.leadingAnchor constraintEqualToAnchor:self.typeIconView.trailingAnchor constant:10],
            [self.contentLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            
            // 来源
            [self.sourceLabel.leadingAnchor constraintEqualToAnchor:self.contentLabel.leadingAnchor],
            [self.sourceLabel.topAnchor constraintEqualToAnchor:self.contentLabel.bottomAnchor constant:6],
            [self.sourceLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-12],
            
            // 时间（与来源同行，靠右）
            [self.timeLabel.centerYAnchor constraintEqualToAnchor:self.sourceLabel.centerYAnchor],
            [self.timeLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.sourceLabel.trailingAnchor constant:8],
        ]];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.previewImageView sd_cancelCurrentImageLoad];
    self.rb_previewLoadToken = nil;
    self.previewImageView.hidden = YES;
    self.previewImageView.image = nil;
    self.playIconView.hidden = YES;
    self.contentLabel.text = nil;
    self.sourceLabel.text = nil;
    self.timeLabel.text = nil;
    self.typeIconView.image = nil;
    
    // 重置约束到默认
    self.contentTrailingToPreview.active = NO;
    self.timeLabelTrailingToPreview.active = NO;
    self.contentTrailingToEdge.active = YES;
    self.timeLabelTrailingToEdge.active = YES;
}

- (void)configureWithData:(NSDictionary *)data
{
    int favType = [data[@"fav_type"] intValue];
    NSString *content = data[@"content"] ?: @"";
    NSString *sourceNickname = data[@"source_from_nickname"] ?: @"";
    NSString *createTime = data[@"create_time"] ?: @"";
    
    // 重置
    self.previewImageView.hidden = YES;
    self.previewImageView.image = nil;
    self.playIconView.hidden = YES;
    BOOL showPreview = NO;
    
    switch (favType) {
        case FAV_TYPE_TEXT: {
            if (@available(iOS 13.0, *)) {
                self.typeIconView.image = [UIImage systemImageNamed:@"doc.text"];
            }
            self.contentLabel.text = content;
            break;
        }
        case FAV_TYPE_IMAGE: {
            if (@available(iOS 13.0, *)) {
                self.typeIconView.image = [UIImage systemImageNamed:@"photo"];
            }
            self.contentLabel.text = @"[图片]";
            // 加载预览图（pv_ + 原图文件名，savePreviewJpegMaxEdge）
            showPreview = YES;
            self.previewImageView.hidden = NO;
            NSString *previewName = [NSString stringWithFormat:@"pv_%@", content];
            NSString *url = [SendImageHelper getImageDownloadURL:previewName dump:NO];
            if (url) {
                [self.previewImageView sd_setImageWithURL:[NSURL URLWithString:url] placeholderImage:[UIImage imageNamed:@"default_avatar_70"]];
            }
            break;
        }
        case FAV_TYPE_VOICE: {
            if (@available(iOS 13.0, *)) {
                self.typeIconView.image = [UIImage systemImageNamed:@"waveform"];
            }
            self.contentLabel.text = @"[语音消息]";
            break;
        }
        case FAV_TYPE_VIDEO: {
            if (@available(iOS 13.0, *)) {
                self.typeIconView.image = [UIImage systemImageNamed:@"video"];
            }
            self.contentLabel.text = @"[视频]";
            showPreview = YES;
            self.previewImageView.hidden = NO;
            self.playIconView.hidden = NO;

            NSString *loadToken = [NSString stringWithFormat:@"%@", data[@"id"] ?: content];
            self.rb_previewLoadToken = loadToken;

            // 与聊天/漫游一致：FileMeta JSON + ShortVideoThumbDownloader（含 Authorization，见 FileDownloadHelper）
            NSString *jsonUse = RBNormalizeFileMetaJSONStringForHistory(content);
            if (jsonUse.length == 0) jsonUse = content;
            FileMeta *fileMeta = [FileMeta fromJSON:jsonUse];
            if (fileMeta.fileName.length > 0 && fileMeta.fileMd5.length > 0) {
                NSString *imgLocalSavedName = [ReceivedShortVideoHelper constructShortVideoThumbName_localSaved:fileMeta.fileName];
                NSString *thumbUrl = [ReceivedShortVideoHelper getShortVideoThumbDownloadURL:imgLocalSavedName videofileMd5:fileMeta.fileMd5];
                self.previewImageView.image = [UIImage imageNamed:@"default_short_video_thumb"];
                __weak FavoritesCell *weakSelf = self;
                [FileDownloadHelper loadChattingShortVideoPreviewImgWithURL:thumbUrl logTag:@"收藏夹列表-短视频预览" complete:^(BOOL sucess, UIImage *imageDlownload) {
                    if (!weakSelf || ![weakSelf.rb_previewLoadToken isEqualToString:loadToken]) return;
                    if (sucess && imageDlownload != nil)
                        weakSelf.previewImageView.image = imageDlownload;
                }];
                break;
            }

            // 兼容旧接口字段或非 FileMeta 的 JSON
            NSDictionary *videoInfo = nil;
            NSData *jsonData = [content dataUsingEncoding:NSUTF8StringEncoding];
            if (jsonData) {
                videoInfo = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            }
            if ([videoInfo isKindOfClass:[NSDictionary class]]) {
                NSString *thumbFileName = videoInfo[@"thumb_file_name"];
                if (thumbFileName.length > 0) {
                    NSString *thumbUrl = [SendImageHelper getImageDownloadURL:thumbFileName dump:NO];
                    if (thumbUrl) {
                        [self.previewImageView sd_setImageWithURL:[NSURL URLWithString:thumbUrl] placeholderImage:[UIImage imageNamed:@"default_avatar_70"]];
                    }
                } else {
                    NSString *fileName = videoInfo[@"file_name"] ?: content;
                    NSString *previewName = [NSString stringWithFormat:@"pv_%@", fileName];
                    NSString *url = [SendImageHelper getImageDownloadURL:previewName dump:NO];
                    if (url) {
                        [self.previewImageView sd_setImageWithURL:[NSURL URLWithString:url] placeholderImage:[UIImage imageNamed:@"default_avatar_70"]];
                    }
                }
            } else {
                self.previewImageView.image = [UIImage imageNamed:@"default_avatar_70"];
            }
            break;
        }
        case FAV_TYPE_FILE: {
            if (@available(iOS 13.0, *)) {
                self.typeIconView.image = [UIImage systemImageNamed:@"doc"];
            }
            NSData *jsonData = [content dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *fileInfo = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            NSString *fileName = [fileInfo isKindOfClass:[NSDictionary class]] ? fileInfo[@"file_name"] : content;
            self.contentLabel.text = [NSString stringWithFormat:@"[文件] %@", fileName];
            break;
        }
        case FAV_TYPE_LOCATION: {
            if (@available(iOS 13.0, *)) {
                self.typeIconView.image = [UIImage systemImageNamed:@"location"];
            }
            NSData *jsonData = [content dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *locInfo = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            NSString *address = [locInfo isKindOfClass:[NSDictionary class]] ? locInfo[@"address"] : content;
            self.contentLabel.text = [NSString stringWithFormat:@"[位置] %@", address];
            break;
        }
        default: {
            if (@available(iOS 13.0, *)) {
                self.typeIconView.image = [UIImage systemImageNamed:@"star"];
            }
            self.contentLabel.text = content;
            break;
        }
    }
    
    // 动态调整约束：有预览图时，内容和时间不与预览图重叠
    if (showPreview) {
        self.contentTrailingToEdge.active = NO;
        self.timeLabelTrailingToEdge.active = NO;
        self.contentTrailingToPreview.active = YES;
        self.timeLabelTrailingToPreview.active = YES;
    } else {
        self.contentTrailingToPreview.active = NO;
        self.timeLabelTrailingToPreview.active = NO;
        self.contentTrailingToEdge.active = YES;
        self.timeLabelTrailingToEdge.active = YES;
    }
    
    // 来源
    if (sourceNickname.length > 0) {
        self.sourceLabel.text = [NSString stringWithFormat:@"来自 %@", sourceNickname];
    } else {
        self.sourceLabel.text = @"";
    }
    
    // 时间（格式化显示）
    self.timeLabel.text = [self formatTimeString:createTime];
}

- (NSString *)formatTimeString:(NSString *)timeStr
{
    if (timeStr.length == 0) return @"";
    
    // 解析接口 1008-27-9 返回的 create_time（收藏时间），支持 "yyyy-MM-dd HH:mm" / "yyyy-MM-dd HH:mm:ss"
    NSDateFormatter *inputFormatter = [[NSDateFormatter alloc] init];
    inputFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSDate *date = [inputFormatter dateFromString:timeStr];
    if (!date) {
        inputFormatter.dateFormat = @"yyyy-MM-dd HH:mm";
        date = [inputFormatter dateFromString:timeStr];
    }
    if (!date) {
        return timeStr;
    }
    
    // 判断是否是今天
    NSCalendar *calendar = [NSCalendar currentCalendar];
    if ([calendar isDateInToday:date]) {
        NSDateFormatter *todayFmt = [[NSDateFormatter alloc] init];
        todayFmt.dateFormat = @"HH:mm";
        return [todayFmt stringFromDate:date];
    }
    
    // 判断是否是昨天
    if ([calendar isDateInYesterday:date]) {
        NSDateFormatter *timeFmt = [[NSDateFormatter alloc] init];
        timeFmt.dateFormat = @"HH:mm";
        return [NSString stringWithFormat:@"昨天 %@", [timeFmt stringFromDate:date]];
    }
    
    // 判断是否是今年
    NSInteger currentYear = [calendar component:NSCalendarUnitYear fromDate:[NSDate date]];
    NSInteger dateYear = [calendar component:NSCalendarUnitYear fromDate:date];
    
    if (currentYear == dateYear) {
        NSDateFormatter *yearFmt = [[NSDateFormatter alloc] init];
        yearFmt.dateFormat = @"M月d日";
        return [yearFmt stringFromDate:date];
    }
    
    // 不是今年
    NSDateFormatter *fullFmt = [[NSDateFormatter alloc] init];
    fullFmt.dateFormat = @"yyyy年M月d日";
    return [fullFmt stringFromDate:date];
}

@end

#pragma mark - FavDetailTextViewController

// 文本内容详情页
@interface FavDetailTextViewController : UIViewController
@property (nonatomic, copy) NSString *textContent;
@property (nonatomic, copy) NSString *sourceFrom;
@property (nonatomic, copy) NSString *createTime;
@end

@implementation FavDetailTextViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"收藏内容";
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];
    
    UILabel *textLabel = [[UILabel alloc] init];
    textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    textLabel.font = [UIFont systemFontOfSize:16];
    textLabel.textColor = [UIColor blackColor];
    textLabel.numberOfLines = 0;
    textLabel.text = self.textContent;
    [scrollView addSubview:textLabel];
    
    UILabel *infoLabel = [[UILabel alloc] init];
    infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    infoLabel.font = [UIFont systemFontOfSize:12];
    infoLabel.textColor = [UIColor lightGrayColor];
    infoLabel.numberOfLines = 0;
    NSMutableString *info = [NSMutableString string];
    if (self.sourceFrom.length > 0) {
        [info appendFormat:@"来自 %@", self.sourceFrom];
    }
    if (self.createTime.length > 0) {
        if (info.length > 0) [info appendString:@"  ·  "];
        [info appendString:self.createTime];
    }
    infoLabel.text = info;
    [scrollView addSubview:infoLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [textLabel.topAnchor constraintEqualToAnchor:scrollView.topAnchor constant:20],
        [textLabel.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor constant:20],
        [textLabel.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor constant:-20],
        [textLabel.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor constant:-40],
        
        [infoLabel.topAnchor constraintEqualToAnchor:textLabel.bottomAnchor constant:30],
        [infoLabel.leadingAnchor constraintEqualToAnchor:textLabel.leadingAnchor],
        [infoLabel.trailingAnchor constraintEqualToAnchor:textLabel.trailingAnchor],
        [infoLabel.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-30],
    ]];
}

@end

#pragma mark - FavoritesViewController

@interface FavoritesViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *dataList;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UISegmentedControl *filterSegment;

@property (nonatomic, assign) int currentPage;
@property (nonatomic, assign) int totalCount;
@property (nonatomic, assign) int currentFavType;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMoreData;

// 编辑模式
@property (nonatomic, assign) BOOL isEditMode;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedIds;
@property (nonatomic, strong) UIBarButtonItem *editBarButton;
@property (nonatomic, strong) UIView *bottomToolbar;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UILabel *selectCountLabel;

// 语音播放
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

// 转发：暂存待转发的收藏项
@property (nonatomic, strong) NSDictionary *pendingForwardItem;

@end

@implementation FavoritesViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"收藏";
    self.view.backgroundColor = HexColor(0xF0F0F0);
    self.hidesBottomBarWhenPushed = YES;
    
    self.dataList = [NSMutableArray array];
    self.selectedIds = [NSMutableSet set];
    self.currentPage = 1;
    self.totalCount = 0;
    self.currentFavType = FAV_TYPE_ALL;
    self.hasMoreData = YES;
    
    [self setupNavigationBar];
    [self setupFilterBar];
    [self setupUI];
    [self setupBottomToolbar];
    [self loadFirstPage];
}

- (void)dealloc
{
    if (self.audioPlayer) {
        [self.audioPlayer stop];
        self.audioPlayer = nil;
    }
}

#pragma mark - 导航栏

- (void)setupNavigationBar
{
    self.editBarButton = [[UIBarButtonItem alloc] initWithTitle:@"管理"
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(toggleEditMode)];
    self.navigationItem.rightBarButtonItem = self.editBarButton;
}

- (void)toggleEditMode
{
    self.isEditMode = !self.isEditMode;
    
    if (self.isEditMode) {
        self.editBarButton.title = @"完成";
        [self.selectedIds removeAllObjects];
        self.bottomToolbar.hidden = NO;
        [self updateDeleteButtonState];
    } else {
        self.editBarButton.title = @"管理";
        [self.selectedIds removeAllObjects];
        self.bottomToolbar.hidden = YES;
    }
    
    [self.tableView reloadData];
}

#pragma mark - 筛选条

- (void)setupFilterBar
{
    NSArray *titles = @[@"全部", @"文本", @"图片", @"语音", @"视频", @"文件", @"位置"];
    self.filterSegment = [[UISegmentedControl alloc] initWithItems:titles];
    self.filterSegment.translatesAutoresizingMaskIntoConstraints = NO;
    self.filterSegment.selectedSegmentIndex = 0;
    [self.filterSegment addTarget:self action:@selector(filterChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 微信风格：白底 + 绿色选中
    self.filterSegment.backgroundColor = [UIColor whiteColor];
    if (@available(iOS 13.0, *)) {
        self.filterSegment.selectedSegmentTintColor = HexColor(0x07C160);
    }
    [self.filterSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blackColor], NSFontAttributeName: [UIFont systemFontOfSize:13]} forState:UIControlStateNormal];
    [self.filterSegment setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]} forState:UIControlStateSelected];
    
    [self.view addSubview:self.filterSegment];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.filterSegment.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.filterSegment.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.filterSegment.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.filterSegment.heightAnchor constraintEqualToConstant:32],
    ]];
}

- (void)filterChanged:(UISegmentedControl *)sender
{
    int types[] = {FAV_TYPE_ALL, FAV_TYPE_TEXT, FAV_TYPE_IMAGE, FAV_TYPE_VOICE, FAV_TYPE_VIDEO, FAV_TYPE_FILE, FAV_TYPE_LOCATION};
    self.currentFavType = types[(int)sender.selectedSegmentIndex];
    [self loadFirstPage];
}

#pragma mark - UI

- (void)setupUI
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = HexColor(0xF0F0F0);
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 46, 0, 0);
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 80;
    [self.tableView registerClass:[FavoritesCell class] forCellReuseIdentifier:@"FavoritesCell"];
    self.tableView.tableFooterView = [[UIView alloc] init];
    [self.view addSubview:self.tableView];
    
    // 下拉刷新
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(pullToRefresh:) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = refreshControl;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.filterSegment.bottomAnchor constant:8],
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
}

- (void)setupBottomToolbar
{
    self.bottomToolbar = [[UIView alloc] init];
    self.bottomToolbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomToolbar.backgroundColor = [UIColor whiteColor];
    self.bottomToolbar.hidden = YES;
    
    // 顶部分隔线
    UIView *topLine = [[UIView alloc] init];
    topLine.translatesAutoresizingMaskIntoConstraints = NO;
    topLine.backgroundColor = HexColor(0xE5E5E5);
    [self.bottomToolbar addSubview:topLine];
    
    self.selectCountLabel = [[UILabel alloc] init];
    self.selectCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectCountLabel.font = [UIFont systemFontOfSize:14];
    self.selectCountLabel.textColor = [UIColor grayColor];
    self.selectCountLabel.text = @"未选择";
    [self.bottomToolbar addSubview:self.selectCountLabel];
    
    self.deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.deleteButton setTitle:@"删除" forState:UIControlStateNormal];
    [self.deleteButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.deleteButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    self.deleteButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.deleteButton.enabled = NO;
    [self.deleteButton addTarget:self action:@selector(deleteSelectedFavorites) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomToolbar addSubview:self.deleteButton];
    
    [self.view addSubview:self.bottomToolbar];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.bottomToolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomToolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomToolbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [self.bottomToolbar.heightAnchor constraintEqualToConstant:50],
        
        [topLine.topAnchor constraintEqualToAnchor:self.bottomToolbar.topAnchor],
        [topLine.leadingAnchor constraintEqualToAnchor:self.bottomToolbar.leadingAnchor],
        [topLine.trailingAnchor constraintEqualToAnchor:self.bottomToolbar.trailingAnchor],
        [topLine.heightAnchor constraintEqualToConstant:0.5],
        
        [self.selectCountLabel.leadingAnchor constraintEqualToAnchor:self.bottomToolbar.leadingAnchor constant:16],
        [self.selectCountLabel.centerYAnchor constraintEqualToAnchor:self.bottomToolbar.centerYAnchor],
        
        [self.deleteButton.trailingAnchor constraintEqualToAnchor:self.bottomToolbar.trailingAnchor constant:-16],
        [self.deleteButton.centerYAnchor constraintEqualToAnchor:self.bottomToolbar.centerYAnchor],
    ]];
}

#pragma mark - 数据加载

- (void)loadFirstPage
{
    self.currentPage = 1;
    self.hasMoreData = YES;
    [self.dataList removeAllObjects];
    [self.tableView reloadData];
    [self loadDataFromServer];
}

- (void)pullToRefresh:(UIRefreshControl *)sender
{
    [self loadFirstPage];
}

- (void)loadDataFromServer
{
    if (self.isLoading || !self.hasMoreData) return;
    self.isLoading = YES;
    
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!localUid) {
        self.isLoading = NO;
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    [[HttpRestHelper sharedInstance] submitGetFavoritesFromServer:localUid
                                                            page:self.currentPage
                                                        pageSize:kPageSize
                                                         favType:self.currentFavType
                                                        complete:^(BOOL sucess, NSDictionary *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.isLoading = NO;
            [weakSelf.tableView.refreshControl endRefreshing];
            
            if (sucess && result) {
                weakSelf.totalCount = [result[@"total"] intValue];
                NSArray *list = result[@"list"];
                
                if (weakSelf.currentPage == 1) {
                    [weakSelf.dataList removeAllObjects];
                }
                
                if ([list isKindOfClass:[NSArray class]] && list.count > 0) {
                    [weakSelf.dataList addObjectsFromArray:list];
                    weakSelf.currentPage++;
                    weakSelf.hasMoreData = (weakSelf.dataList.count < weakSelf.totalCount);
                } else {
                    weakSelf.hasMoreData = NO;
                }
                
                [weakSelf.tableView reloadData];
            } else {
                if (weakSelf.currentPage == 1) {
                    // 首页加载失败
                }
            }
            
            [weakSelf updateEmptyState];
        });
    } hudParentView:(self.currentPage == 1 ? self.view : nil)];
}

- (void)updateEmptyState
{
    self.emptyLabel.hidden = (self.dataList.count > 0);
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.dataList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FavoritesCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FavoritesCell" forIndexPath:indexPath];
    
    NSDictionary *item = self.dataList[indexPath.row];
    [cell configureWithData:item];
    
    // 编辑模式：选中状态
    if (self.isEditMode) {
        NSString *favId = item[@"id"];
        BOOL selected = [self.selectedIds containsObject:favId];
        cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.tintColor = HexColor(0x07C160);
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *item = self.dataList[indexPath.row];
    NSString *favId = item[@"id"];
    
    if (self.isEditMode) {
        // 编辑模式：切换选中
        if ([self.selectedIds containsObject:favId]) {
            [self.selectedIds removeObject:favId];
        } else {
            [self.selectedIds addObject:favId];
        }
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [self updateDeleteButtonState];
        return;
    }
    
    // 非编辑模式：查看内容
    [self viewContentForItem:item];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // 滚动到底部自动加载下一页
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat height = scrollView.frame.size.height;
    
    if (offsetY > contentHeight - height - 100 && !self.isLoading && self.hasMoreData) {
        [self loadDataFromServer];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return !self.isEditMode;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __weak typeof(self) weakSelf = self;
    NSDictionary *item = self.dataList[indexPath.row];
    NSString *favId = item[@"id"];
    
    // 删除
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:@"删除"
                                                                             handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf deleteFavoriteIds:@[favId] complete:^(BOOL success) {
            if (success) {
                [weakSelf.dataList removeObjectAtIndex:indexPath.row];
                [weakSelf.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                [weakSelf updateEmptyState];
            }
            completionHandler(success);
        }];
    }];
    
    // 转发
    UIContextualAction *forwardAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                                title:@"转发"
                                                                              handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf forwardFavoriteItem:item];
        completionHandler(YES);
    }];
    forwardAction.backgroundColor = HexColor(0x576B95);
    
    // 编辑（仅文本类型可编辑内容）
    UIContextualAction *editAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                             title:@"编辑"
                                                                           handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf editFavoriteItem:item atIndex:indexPath.row];
        completionHandler(YES);
    }];
    editAction.backgroundColor = HexColor(0x07C160);
    
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, forwardAction, editAction]];
    config.performsFirstActionWithFullSwipe = NO;
    return config;
}

#pragma mark - 查看收藏内容

- (void)viewContentForItem:(NSDictionary *)item
{
    int favType = [item[@"fav_type"] intValue];
    NSString *content = item[@"content"] ?: @"";
    NSString *sourceNickname = item[@"source_from_nickname"] ?: @"";
    NSString *createTime = item[@"create_time"] ?: @"";
    
    switch (favType) {
        case FAV_TYPE_TEXT:
            [self viewTextContent:content source:sourceNickname time:createTime];
            break;
        case FAV_TYPE_IMAGE:
            [self viewImageContent:content];
            break;
        case FAV_TYPE_VOICE:
            [self viewVoiceContent:content];
            break;
        case FAV_TYPE_VIDEO:
            [self viewVideoContent:content];
            break;
        case FAV_TYPE_FILE:
            [self viewFileContent:content];
            break;
        case FAV_TYPE_LOCATION:
            [self viewLocationContent:content];
            break;
        default:
            [self viewTextContent:content source:sourceNickname time:createTime];
            break;
    }
}

// 查看文本
- (void)viewTextContent:(NSString *)content source:(NSString *)source time:(NSString *)time
{
    FavDetailTextViewController *vc = [[FavDetailTextViewController alloc] init];
    vc.textContent = content;
    vc.sourceFrom = source;
    vc.createTime = time;
    [self.navigationController pushViewController:vc animated:YES];
}

// 查看图片（全屏浏览）
- (void)viewImageContent:(NSString *)content
{
    // content 是图片文件名（不带 pv_ 前缀的原图文件名）
    NSString *fullImageUrl = [SendImageHelper getImageDownloadURL:content dump:NO];
    if (fullImageUrl) {
        [BasicTool showImageWithURL:fullImageUrl];
    } else {
        [BasicTool showAlertWarn:@"无法加载图片" parent:self];
    }
}

// 播放语音
- (void)viewVoiceContent:(NSString *)content
{
    // 停止之前的播放
    if (self.audioPlayer && self.audioPlayer.isPlaying) {
        [self.audioPlayer stop];
        self.audioPlayer = nil;
    }
    
    // content 是语音文件名
    NSString *voiceUrl = [SendVoiceHelper getVoiceDownloadURL:content dump:NO];
    if (!voiceUrl || voiceUrl.length == 0) {
        [BasicTool showAlertWarn:@"无法加载语音" parent:self];
        return;
    }
    
    // 显示加载提示
    [APP showUserDefineToast_OK:@"正在加载语音..."];
    
    // 下载并播放
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *audioData = [NSData dataWithContentsOfURL:[NSURL URLWithString:voiceUrl]];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (audioData && audioData.length > 0) {
                NSError *error = nil;
                weakSelf.audioPlayer = [[AVAudioPlayer alloc] initWithData:audioData error:&error];
                if (weakSelf.audioPlayer && !error) {
                    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
                    [[AVAudioSession sharedInstance] setActive:YES error:nil];
                    [weakSelf.audioPlayer play];
                    [APP showUserDefineToast_OK:@"正在播放语音"];
                } else {
                    [BasicTool showAlertWarn:@"语音播放失败" parent:weakSelf];
                }
            } else {
                [BasicTool showAlertWarn:@"语音文件下载失败" parent:weakSelf];
            }
        });
    });
}

// 播放视频
- (void)viewVideoContent:(NSString *)content
{
    // 尝试解析 JSON 格式的视频信息
    NSDictionary *videoInfo = nil;
    NSData *jsonData = [content dataUsingEncoding:NSUTF8StringEncoding];
    if (jsonData) {
        videoInfo = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    }
    
    NSString *fileName = nil;
    NSString *fileMd5 = nil;
    int duration = 10;
    
    if ([videoInfo isKindOfClass:[NSDictionary class]]) {
        fileName = videoInfo[@"file_name"];
        fileMd5 = videoInfo[@"file_md5"] ?: @"";
        duration = [videoInfo[@"duration"] intValue];
        if (duration <= 0) duration = 10;
    } else {
        // content 直接是文件名
        fileName = content;
        fileMd5 = @"";
    }
    
    if (!fileName || fileName.length == 0) {
        [BasicTool showAlertWarn:@"无法加载视频" parent:self];
        return;
    }
    
    // 构造视频下载 URL
    NSString *videoUrl = [ReceivedShortVideoHelper getShortVideoDownloadURL:fileName md5:fileMd5];
    if (videoUrl && self.navigationController) {
        [ViewControllerFactory goShortVideoPlayerViewController_fromUrl:self.navigationController duaration:duration httpUrl:videoUrl];
    } else {
        [BasicTool showAlertWarn:@"无法播放视频" parent:self];
    }
}

// 查看文件
- (void)viewFileContent:(NSString *)content
{
    NSDictionary *fileInfo = nil;
    NSData *jsonData = [content dataUsingEncoding:NSUTF8StringEncoding];
    if (jsonData) {
        fileInfo = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    }
    
    NSString *fileName = @"未知文件";
    if ([fileInfo isKindOfClass:[NSDictionary class]]) {
        fileName = fileInfo[@"file_name"] ?: @"未知文件";
    }
    
    // 显示文件信息
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"收藏的文件"
                                                                  message:[NSString stringWithFormat:@"文件名：%@", fileName]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// 查看位置
- (void)viewLocationContent:(NSString *)content
{
    NSDictionary *locInfo = nil;
    NSData *jsonData = [content dataUsingEncoding:NSUTF8StringEncoding];
    if (jsonData) {
        locInfo = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    }
    
    if ([locInfo isKindOfClass:[NSDictionary class]]) {
        double lat = [locInfo[@"latitude"] doubleValue];
        double lng = [locInfo[@"longitude"] doubleValue];
        NSString *address = locInfo[@"address"] ?: @"未知地址";
        
        if (lat != 0 && lng != 0) {
            // 打开系统地图
            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat, lng);
            MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:coordinate];
            MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
            mapItem.name = address;
            [mapItem openInMapsWithLaunchOptions:@{
                MKLaunchOptionsMapCenterKey: [NSValue valueWithMKCoordinate:coordinate],
                MKLaunchOptionsMapSpanKey: [NSValue valueWithMKCoordinateSpan:MKCoordinateSpanMake(0.01, 0.01)]
            }];
        } else {
            [BasicTool showAlertInfo:[NSString stringWithFormat:@"位置：%@", address] parent:self];
        }
    } else {
        [BasicTool showAlertInfo:[NSString stringWithFormat:@"位置：%@", content] parent:self];
    }
}

#pragma mark - 转发收藏

- (void)forwardFavoriteItem:(NSDictionary *)item
{
    int favType = [item[@"fav_type"] intValue];
    // 检查是否支持转发
    if (favType != FAV_TYPE_TEXT && favType != FAV_TYPE_IMAGE && favType != FAV_TYPE_VOICE && favType != FAV_TYPE_LOCATION) {
        [APP showToastWarn:@"该类型收藏暂不支持转发"];
        return;
    }
    
    // 暂存待转发的收藏项
    self.pendingForwardItem = item;
    
    // 打开目标选择界面
    [ViewControllerFactory goTargetChooseViewController:self.navigationController
                                 supportedTargetSource:TargetSourceLatestChatting | TargetSourceFriend | TargetSourceGroup
                                  latestChattingFilter:nil
                                          friendFilter:nil
                                           groupFilter:nil
                                    groupMemberFilter:nil
                                              extraObj:item
                                                   gid:nil
                                           requestCode:TARGET_CHOOSE_REQUEST_CODE_FOR_FORWARD
                                              delegate:self];
}

// UserChooseCompleteDelegate — 单选
- (void)processTargetChooseComplete:(TargetEntity *)selectedTarget extraObj:(id)obj requestCode:(int)requestCode
{
    if (selectedTarget == nil) return;
    
    if (requestCode == TARGET_CHOOSE_REQUEST_CODE_FOR_FORWARD) {
        NSDictionary *item = (NSDictionary *)obj;
        if (item == nil) item = self.pendingForwardItem;
        if (item == nil) return;
        
        [self doForwardItem:item toChatType:selectedTarget.targetChatType toId:selectedTarget.targetId toName:selectedTarget.targetName];
        [APP showUserDefineToast_OK:@"转发完成"];
        self.pendingForwardItem = nil;
    }
}

// UserChooseCompleteDelegate — 多选
- (void)processMultiTargetChooseComplete:(NSArray<TargetEntity *> *)selectedTargets extraObj:(id)obj requestCode:(int)requestCode
{
    if (selectedTargets == nil || selectedTargets.count == 0) return;
    
    if (requestCode == TARGET_CHOOSE_REQUEST_CODE_FOR_FORWARD) {
        NSDictionary *item = (NSDictionary *)obj;
        if (item == nil) item = self.pendingForwardItem;
        if (item == nil) return;
        
        for (TargetEntity *te in selectedTargets) {
            [self doForwardItem:item toChatType:te.targetChatType toId:te.targetId toName:te.targetName];
        }
        
        NSString *msg = selectedTargets.count > 1
            ? [NSString stringWithFormat:@"已转发给 %lu 位联系人", (unsigned long)selectedTargets.count]
            : @"转发完成";
        [APP showUserDefineToast_OK:msg];
        self.pendingForwardItem = nil;
    }
}

// 执行转发：根据收藏类型发送消息到目标会话
- (void)doForwardItem:(NSDictionary *)item toChatType:(int)chatType toId:(NSString *)toId toName:(NSString *)toName
{
    int favType = [item[@"fav_type"] intValue];
    NSString *content = item[@"content"] ?: @"";
    if (content.length == 0) return;
    
    switch (favType) {
        case FAV_TYPE_TEXT: {
            if (chatType == CHAT_TYPE_FREIDN_CHAT) {
                [MessageHelper sendPlainTextMessageAsync:toId withMessage:content quote:nil forSucess:nil];
            } else if (chatType == CHAT_TYPE_GUEST_CHAT) {
                [TMessageHelper sendPlainTextMessageAsync:toId tuname:toName withMessage:content quote:nil forSucess:nil];
            } else if (chatType == CHAT_TYPE_GROUP_CHAT) {
                [GMessageHelper sendPlainTextMessageAsync:toId withMessage:content at:nil quote:nil forSucess:nil];
            }
            break;
        }
        case FAV_TYPE_IMAGE: {
            NSString *fp = [Protocal genFingerPrint];
            // 创建本地消息实体并加入聊天数据（用于 UI 显示）
            JSQMessage *entity = [JSQMessage createChatMsgEntity_OUTGO_IMAGE:content withFingerPrint:fp];
            entity.sendStatusSecondary = SendStatusSecondary_NONE;
            if (chatType == CHAT_TYPE_FREIDN_CHAT) {
                [ChatDataHelper addChatMessageData_outgoing:toId withData:entity];
                [MessageHelper sendImageMessageAsync:toId withImage:content fp:fp forSucess:nil];
            } else if (chatType == CHAT_TYPE_GUEST_CHAT) {
                [TChatDataHelper addChatMessageData_outgoing:toId withData:entity];
                [TMessageHelper sendImageMessageAsync:toId tuname:toName withImage:content fp:fp forSucess:nil];
            } else if (chatType == CHAT_TYPE_GROUP_CHAT) {
                [GChatDataHelper addChatMessageData_outgoing:toId withData:entity];
                [GMessageHelper sendImageMessageAsync:toId withImage:content fp:fp forSucess:nil];
            }
            break;
        }
        case FAV_TYPE_VOICE: {
            NSString *fp = [Protocal genFingerPrint];
            // 创建本地消息实体并加入聊天数据（用于 UI 显示）
            JSQMessage *entity = [JSQMessage createChatMsgEntity_OUTGO_VOICE:content withFingerPrint:fp];
            entity.sendStatusSecondary = SendStatusSecondary_NONE;
            if (chatType == CHAT_TYPE_FREIDN_CHAT) {
                [ChatDataHelper addChatMessageData_outgoing:toId withData:entity];
                [MessageHelper sendVoiceMessageAsync:toId withVoice:content fp:fp forSucess:nil];
            } else if (chatType == CHAT_TYPE_GUEST_CHAT) {
                [TChatDataHelper addChatMessageData_outgoing:toId withData:entity];
                [TMessageHelper sendVoiceMessageAsync:toId tuname:toName withVoice:content fp:fp forSucess:nil];
            } else if (chatType == CHAT_TYPE_GROUP_CHAT) {
                [GChatDataHelper addChatMessageData_outgoing:toId withData:entity];
                [GMessageHelper sendVoiceMessageAsync:toId withVoice:content fp:fp forSucess:nil];
            }
            break;
        }
        case FAV_TYPE_LOCATION: {
            @try {
                NSData *jsonData = [content dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *locInfo = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
                if ([locInfo isKindOfClass:[NSDictionary class]]) {
                    double lat = [locInfo[@"latitude"] doubleValue];
                    double lng = [locInfo[@"longitude"] doubleValue];
                    NSString *address = locInfo[@"address"] ?: @"";
                    NSString *locationJSON = [NSString stringWithFormat:@"{\"latitude\":%f,\"longitude\":%f,\"address\":\"%@\"}", lat, lng, address];
                    if (chatType == CHAT_TYPE_FREIDN_CHAT) {
                        [MessageHelper sendPlainTextMessageAsync:toId withMessage:locationJSON quote:nil forSucess:nil];
                    } else if (chatType == CHAT_TYPE_GROUP_CHAT) {
                        [GMessageHelper sendPlainTextMessageAsync:toId withMessage:locationJSON at:nil quote:nil forSucess:nil];
                    }
                }
            } @catch (NSException *e) {
                DDLogWarn(@"转发位置收藏失败: %@", e);
            }
            break;
        }
        default:
            break;
    }
}

#pragma mark - 编辑收藏

- (void)editFavoriteItem:(NSDictionary *)item atIndex:(NSInteger)index
{
    int favType = [item[@"fav_type"] intValue];
    
    if (favType != FAV_TYPE_TEXT) {
        [APP showToastWarn:@"仅支持编辑文本类型的收藏"];
        return;
    }
    
    NSString *favId = item[@"id"];
    NSString *currentContent = item[@"content"] ?: @"";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"编辑收藏"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"输入内容";
        textField.text = currentContent;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    
    __weak typeof(self) weakSelf = self;
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *newContent = alert.textFields.firstObject.text ?: @"";
        if (newContent.length == 0) {
            [APP showToastWarn:@"内容不能为空"];
            return;
        }
        [weakSelf updateFavoriteContent:favId newContent:newContent atIndex:index];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateFavoriteContent:(NSString *)favId newContent:(NSString *)content atIndex:(NSInteger)index
{
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!localUid) return;
    
    __weak typeof(self) weakSelf = self;
    
    // 使用备注接口保存编辑内容（服务端将 memo 作为编辑后的内容展示）
    [[HttpRestHelper sharedInstance] submitModifyFavoriteMemoToServer:localUid
                                                               favId:favId
                                                                memo:content
                                                            complete:^(BOOL sucess, NSString *resultCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && [resultCode isEqualToString:@"1"]) {
                // 更新本地数据
                if (index < (NSInteger)weakSelf.dataList.count) {
                    NSMutableDictionary *updatedItem = [weakSelf.dataList[index] mutableCopy];
                    updatedItem[@"content"] = content;
                    [weakSelf.dataList replaceObjectAtIndex:index withObject:updatedItem];
                    [weakSelf.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
                }
                [APP showUserDefineToast_OK:@"已保存"];
            } else {
                [BasicTool showAlertError:@"保存失败" parent:weakSelf];
            }
        });
    } hudParentView:self.view];
}

#pragma mark - 删除收藏

- (void)updateDeleteButtonState
{
    NSUInteger count = self.selectedIds.count;
    self.deleteButton.enabled = (count > 0);
    self.selectCountLabel.text = count > 0 ? [NSString stringWithFormat:@"已选择 %lu 项", (unsigned long)count] : @"未选择";
}

- (void)deleteSelectedFavorites
{
    if (self.selectedIds.count == 0) return;
    
    NSArray *ids = [self.selectedIds allObjects];
    
    __weak typeof(self) weakSelf = self;
    
    LPActionSheetBlock handler = ^(LPActionSheet *actionSheet, NSInteger index) {
        if (index == -1) {
            [weakSelf deleteFavoriteIds:ids complete:^(BOOL success) {
                if (success) {
                    // 从列表中移除
                    NSMutableArray *toRemove = [NSMutableArray array];
                    for (NSDictionary *item in weakSelf.dataList) {
                        if ([ids containsObject:item[@"id"]]) {
                            [toRemove addObject:item];
                        }
                    }
                    [weakSelf.dataList removeObjectsInArray:toRemove];
                    [weakSelf.selectedIds removeAllObjects];
                    [weakSelf.tableView reloadData];
                    [weakSelf updateDeleteButtonState];
                    [weakSelf updateEmptyState];
                    [APP showUserDefineToast_OK:[NSString stringWithFormat:@"已删除 %lu 项收藏", (unsigned long)ids.count]];
                }
            }];
        }
    };
    
    [LPActionSheet showActionSheetWithTitle:[NSString stringWithFormat:@"确定删除选中的 %lu 项收藏吗？", (unsigned long)ids.count]
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:@"删除"
                          otherButtonTitles:nil
                                    handler:handler];
}

- (void)deleteFavoriteIds:(NSArray<NSString *> *)ids complete:(void (^)(BOOL success))complete
{
    NSString *localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    if (!localUid) {
        if (complete) complete(NO);
        return;
    }
    
    NSString *idsStr = [ids componentsJoinedByString:@","];
    
    [[HttpRestHelper sharedInstance] submitDeleteFavoritesToServer:localUid
                                                              ids:idsStr
                                                         complete:^(BOOL sucess, NSString *resultCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && [resultCode isEqualToString:@"1"]) {
                if (complete) complete(YES);
            } else {
                [BasicTool showAlertError:@"删除失败，请稍后重试" parent:self];
                if (complete) complete(NO);
            }
        });
    } hudParentView:self.view];
}

@end
