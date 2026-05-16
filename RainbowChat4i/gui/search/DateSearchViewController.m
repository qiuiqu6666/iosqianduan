//
//  DateSearchViewController.m
//  RainbowChat4i
//
//  按日期搜索消息（分页加载 + 流畅优化）
//

#import "DateSearchViewController.h"
#import "MsgSummaryContentDTO.h"
#import "MsgDetailContentDTO.h"
#import "IMClientManager.h"
#import "MsgBodyRoot.h"
#import "TimeTool.h"
#import "MsgSummaryContent.h"
#import "VoipRecordMeta.h"
#import "HttpRestHelper.h"
#import "RBConversationMsgSearchHelper.h"
#import "BasicTool.h"
#import "MyDataBase.h"
#import "ChatHistoryTable.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static NSString *const kDateMsgCellId = @"DateMsgCell";
static const int kPageSize = 30;

#pragma mark - DateMsgCell（子视图只创建一次）

@interface DateMsgCell : UITableViewCell
@property (nonatomic, strong) UILabel *senderLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@end

@implementation DateMsgCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        
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
            [_senderLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
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
    self.senderLabel.text = nil;
    self.timeLabel.text = nil;
    self.contentLabel.text = nil;
}

@end

#pragma mark - DateSearchViewController

@interface DateSearchViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, assign) int chatType;
@property (nonatomic, copy)   NSString *dataId;

@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) UILabel *dateInfoLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *footerSpinner;
@property (nonatomic, strong) NSMutableArray<MsgDetailContentDTO *> *messageList;

// 分页
@property (nonatomic, assign) int currentOffset;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMoreData;

// 当前选中日期
@property (nonatomic, assign) long currentFromDate;
@property (nonatomic, assign) long currentToDate;
@property (nonatomic, strong) NSDate *currentSelectedDate;

// 缓存
@property (nonatomic, strong) NSDateFormatter *timeFmt;
@property (nonatomic, strong) NSDateFormatter *dateFmt;
@property (nonatomic, copy) NSString *localUid;

// 日期选择器折叠
@property (nonatomic, strong) UIView *dateContainerView;  // 包裹 datePicker + dateInfoLabel + separator
@property (nonatomic, strong) NSLayoutConstraint *dateContainerHeightConstraint;
@property (nonatomic, assign) CGFloat dateContainerFullHeight; // 展开时的完整高度
@property (nonatomic, assign) BOOL datePickerCollapsed;
@property (nonatomic, assign) CGFloat lastScrollOffsetY;

@end

@implementation DateSearchViewController

- (instancetype)initWithChatType:(int)chatType dataId:(NSString *)dataId
{
    self = [super init];
    if (self) {
        _chatType = chatType;
        _dataId = dataId;
        _currentOffset = 0;
        _isLoading = NO;
        _hasMoreData = YES;
        _messageList = [NSMutableArray array];
        _timeFmt = [[NSDateFormatter alloc] init];
        _timeFmt.dateFormat = @"HH:mm";
        _dateFmt = [[NSDateFormatter alloc] init];
        _dateFmt.dateFormat = @"yyyy年M月d日";
        _localUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self buildUI];
    [self onDateChanged:self.datePicker];
}

#pragma mark - UI

- (void)buildUI
{
    // ============================
    // 日期容器（包裹 datePicker + dateInfoLabel + separator），方便折叠
    // ============================
    self.dateContainerView = [[UIView alloc] init];
    self.dateContainerView.clipsToBounds = YES;
    self.dateContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.dateContainerView];
    
    self.datePicker = [[UIDatePicker alloc] init];
    self.datePicker.datePickerMode = UIDatePickerModeDate;
    self.datePicker.maximumDate = [NSDate date];
    self.datePicker.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 14.0, *)) {
        self.datePicker.preferredDatePickerStyle = UIDatePickerStyleInline;
    }
    self.datePicker.tintColor = HexColor(0x4A90D9);
    [self.datePicker addTarget:self action:@selector(onDateChanged:) forControlEvents:UIControlEventValueChanged];
    [self.dateContainerView addSubview:self.datePicker];
    
    self.dateInfoLabel = [[UILabel alloc] init];
    self.dateInfoLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.dateInfoLabel.textColor = HexColor(0x666666);
    self.dateInfoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dateContainerView addSubview:self.dateInfoLabel];
    
    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = HexColor(0xE5E5E5);
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.dateContainerView addSubview:separator];
    
    // 折叠切换按钮（日期折叠后显示，点击可展开）
    UIButton *toggleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    toggleBtn.translatesAutoresizingMaskIntoConstraints = NO;
    toggleBtn.tag = 999;
    toggleBtn.hidden = YES;
    [toggleBtn setTitle:@"▼ 选择日期" forState:UIControlStateNormal];
    [toggleBtn setTitleColor:HexColor(0x4A90D9) forState:UIControlStateNormal];
    toggleBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [toggleBtn addTarget:self action:@selector(toggleDatePicker) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:toggleBtn];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 0);
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.rowHeight = 56;
    self.tableView.estimatedRowHeight = 56;
    [self.tableView registerClass:[DateMsgCell class] forCellReuseIdentifier:kDateMsgCellId];
    [self.view addSubview:self.tableView];
    
    // Footer spinner
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.footerSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.footerSpinner.center = CGPointMake(footerView.bounds.size.width / 2, 22);
    self.footerSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [footerView addSubview:self.footerSpinner];
    self.tableView.tableFooterView = footerView;
    
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"当日无消息";
    self.emptyLabel.textColor = HexColor(0x999999);
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.emptyLabel];
    
    UILayoutGuide *sa = self.view.safeAreaLayoutGuide;
    
    // 日期容器内部约束
    [NSLayoutConstraint activateConstraints:@[
        [self.datePicker.topAnchor constraintEqualToAnchor:self.dateContainerView.topAnchor constant:4],
        [self.datePicker.leadingAnchor constraintEqualToAnchor:self.dateContainerView.leadingAnchor constant:8],
        [self.datePicker.trailingAnchor constraintEqualToAnchor:self.dateContainerView.trailingAnchor constant:-8],
        
        [self.dateInfoLabel.topAnchor constraintEqualToAnchor:self.datePicker.bottomAnchor constant:8],
        [self.dateInfoLabel.leadingAnchor constraintEqualToAnchor:self.dateContainerView.leadingAnchor constant:16],
        [self.dateInfoLabel.trailingAnchor constraintEqualToAnchor:self.dateContainerView.trailingAnchor constant:-16],
        
        [separator.topAnchor constraintEqualToAnchor:self.dateInfoLabel.bottomAnchor constant:8],
        [separator.leadingAnchor constraintEqualToAnchor:self.dateContainerView.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:self.dateContainerView.trailingAnchor],
        [separator.heightAnchor constraintEqualToConstant:0.5],
        [separator.bottomAnchor constraintEqualToAnchor:self.dateContainerView.bottomAnchor],
    ]];
    
    // 日期容器外部约束
    [NSLayoutConstraint activateConstraints:@[
        [self.dateContainerView.topAnchor constraintEqualToAnchor:sa.topAnchor],
        [self.dateContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.dateContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        [toggleBtn.topAnchor constraintEqualToAnchor:self.dateContainerView.bottomAnchor],
        [toggleBtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [toggleBtn.heightAnchor constraintEqualToConstant:30],
        
        [self.tableView.topAnchor constraintEqualToAnchor:toggleBtn.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
        [self.emptyLabel.topAnchor constraintEqualToAnchor:self.tableView.topAnchor constant:40],
    ]];
    
    self.datePickerCollapsed = NO;
    self.lastScrollOffsetY = 0;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    // 记录日期容器展开后的完整高度（仅记录一次）
    if (self.dateContainerFullHeight <= 0 && self.dateContainerView.bounds.size.height > 0) {
        self.dateContainerFullHeight = self.dateContainerView.bounds.size.height;
    }
}

#pragma mark - 日期选择器折叠/展开

- (void)collapseDatePicker
{
    if (self.datePickerCollapsed) return;
    self.datePickerCollapsed = YES;
    
    // 保存完整高度
    if (self.dateContainerFullHeight <= 0) {
        self.dateContainerFullHeight = self.dateContainerView.bounds.size.height;
    }
    
    // 动态添加高度约束 = 0
    if (!self.dateContainerHeightConstraint) {
        self.dateContainerHeightConstraint = [self.dateContainerView.heightAnchor constraintEqualToConstant:0];
    }
    self.dateContainerHeightConstraint.constant = 0;
    self.dateContainerHeightConstraint.active = YES;
    
    UIButton *toggleBtn = (UIButton *)[self.view viewWithTag:999];
    
    [UIView animateWithDuration:0.3 animations:^{
        [self.view layoutIfNeeded];
        self.dateContainerView.alpha = 0;
    } completion:^(BOOL finished) {
        toggleBtn.hidden = NO;
        [toggleBtn setTitle:[NSString stringWithFormat:@"▼ %@", [self.dateFmt stringFromDate:self.currentSelectedDate ?: [NSDate date]]]
                   forState:UIControlStateNormal];
    }];
}

- (void)expandDatePicker
{
    if (!self.datePickerCollapsed) return;
    self.datePickerCollapsed = NO;
    
    UIButton *toggleBtn = (UIButton *)[self.view viewWithTag:999];
    toggleBtn.hidden = YES;
    
    // 移除高度约束，恢复自然高度
    self.dateContainerHeightConstraint.active = NO;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.dateContainerView.alpha = 1;
        [self.view layoutIfNeeded];
    }];
}

- (void)toggleDatePicker
{
    if (self.datePickerCollapsed) {
        [self expandDatePicker];
    } else {
        [self collapseDatePicker];
    }
}

#pragma mark - Actions

- (void)onDateChanged:(UIDatePicker *)picker
{
    NSDate *selectedDate = picker.date;
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *startOfDay = [cal startOfDayForDate:selectedDate];
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    comps.day = 1;
    NSDate *endOfDay = [cal dateByAddingComponents:comps toDate:startOfDay options:0];
    
    // 聊天历史表的 date 列当前以 Java 毫秒为主，传毫秒范围可命中新数据。
    self.currentFromDate = (long)[TimeTool javaMillisFromNSDate:startOfDay];
    self.currentToDate = (long)[TimeTool javaMillisFromNSDate:endOfDay];
    self.currentSelectedDate = selectedDate;
    
    // 重置
    self.currentOffset = 0;
    self.hasMoreData = YES;
    self.isLoading = NO;
    [self.messageList removeAllObjects];
    [self.tableView reloadData];
    self.dateInfoLabel.text = [NSString stringWithFormat:@"%@  加载中...", [self.dateFmt stringFromDate:selectedDate]];
    self.emptyLabel.hidden = YES;
    
    // 恢复 footer
    if (!self.tableView.tableFooterView || self.tableView.tableFooterView.frame.size.height < 10) {
        UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
        self.footerSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        self.footerSpinner.center = CGPointMake(footerView.bounds.size.width / 2, 22);
        self.footerSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [footerView addSubview:self.footerSpinner];
        self.tableView.tableFooterView = footerView;
    }
    
    [self loadNextPage];
}

#pragma mark - 分页加载

- (void)loadNextPage
{
    if (self.isLoading || !self.hasMoreData) return;
    self.isLoading = YES;
    [self.footerSpinner startAnimating];

    int offset = self.currentOffset;
    long fromDate = self.currentFromDate;
    long toDate = self.currentToDate;
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSMutableArray<MsgDetailContentDTO *> *results = nil;
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            ChatHistoryTable *table = [[ChatHistoryTable alloc] init];
            results = [table searchMessagesByDateRange:db
                                              chatType:wself.chatType
                                              uidOrGid:wself.dataId
                                              fromDate:fromDate
                                                toDate:toDate
                                                 limit:kPageSize
                                                offset:offset];
        }];
        if (results == nil) results = [NSMutableArray array];

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) self = wself;
            if (!self) return;
            [self.footerSpinner stopAnimating];
            if (results.count < kPageSize) {
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

            BOOL hasAny = (self.messageList.count > 0);
            self.emptyLabel.hidden = hasAny;
            self.dateInfoLabel.text = [NSString stringWithFormat:@"%@  %@",
                                       [self.dateFmt stringFromDate:self.currentSelectedDate ?: [NSDate date]],
                                       hasAny ? [NSString stringWithFormat:@"共%ld条消息", (long)self.messageList.count] : @"当日无消息"];
            self.isLoading = NO;
        });
    });
}

#pragma mark - 工具方法

- (NSString *)msgTypeSummary:(int)msgType text:(NSString *)text
{
    switch (msgType) {
        case TM_TYPE_IMAGE:      return @"[图片]";
        case TM_TYPE_VOICE:      return @"[语音]";
        case TM_TYPE_FILE:       return @"[文件]";
        case TM_TYPE_SHORTVIDEO: return @"[视频]";
        case TM_TYPE_LOCATION:   return @"[位置]";
        case TM_TYPE_CONTACT:    return @"[名片]";
        case TM_TYPE_GIFT_SEND:  return @"[礼物]";
        case TM_TYPE_GIFT_GET:   return @"[礼物]";
        case TM_TYPE_RED_PACKET: return @"「红包」";
        case TM_TYPE_TRANSFER:   return @"「转账」";
        case TM_TYPE_SYSTEAM_INFO: return @"[系统消息]";
        case TM_TYPE_REVOKE:     return @"[已撤回]";
        case TM_TYPE_VOIP_RECORD:
        {
            // 解析 JSON，显示"语音通话"或"视频通话"及其状态
            if (text != nil && [text hasPrefix:@"{"]) {
                VoipRecordMeta *vrm = [VoipRecordMeta fromJSON:text];
                if (vrm != nil) {
                    NSString *typeStr = (vrm.voipType == VOIP_TYPE_VOICE) ? @"语音通话" : @"视频通话";
                    NSString *statusStr = @"";
                    switch (vrm.recordType) {
                        case VOIP_RECORD_TYPE_REQUEST_CANCEL:
                            statusStr = @"已取消";
                            break;
                        case VOIP_RECORD_TYPE_REQUEST_REJECT:
                            statusStr = @"已拒绝";
                            break;
                        case VOIP_RECORD_TYPE_CALLING_TIMEOUT:
                            statusStr = @"未接听";
                            break;
                        case VOIP_RECORD_TYPE_CHATTING_DURATION:
                        {
                            int dur = vrm.duration;
                            if (dur > 0) {
                                int m = dur / 60;
                                int s = dur % 60;
                                statusStr = m > 0 ? [NSString stringWithFormat:@"%d分%d秒", m, s]
                                                  : [NSString stringWithFormat:@"%d秒", s];
                            }
                            break;
                        }
                        default:
                            break;
                    }
                    return statusStr.length > 0
                        ? [NSString stringWithFormat:@"[%@ %@]", typeStr, statusStr]
                        : [NSString stringWithFormat:@"[%@]", typeStr];
                }
            }
            return @"[通话记录]";
        }
        default:                 return text ?: @"";
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.messageList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DateMsgCell *cell = [tableView dequeueReusableCellWithIdentifier:kDateMsgCellId forIndexPath:indexPath];
    
    MsgDetailContentDTO *dto = self.messageList[indexPath.row];
    BOOL isSelf = [dto.senderId isEqualToString:self.localUid];
    
    // 只更新内容
    cell.senderLabel.text = isSelf ? @"我" : (dto.senderDisplayName ?: @"未知");
    cell.timeLabel.text = dto.date ? [self.timeFmt stringFromDate:dto.date] : @"";
    cell.contentLabel.text = [self msgTypeSummary:dto.msgType text:dto.text];
    
    return cell;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView != self.tableView) return;
    
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentH = scrollView.contentSize.height;
    CGFloat frameH = scrollView.frame.size.height;
    
    // 上拉加载更多
    if (self.hasMoreData && !self.isLoading && contentH > 0 && offsetY > contentH - frameH - 300) {
        [self loadNextPage];
    }
    
    // 向下滑动时折叠日期选择器，仅在有消息数据时才折叠
    CGFloat delta = offsetY - self.lastScrollOffsetY;
    if (delta > 10 && !self.datePickerCollapsed && self.messageList.count > 0) {
        [self collapseDatePicker];
    }
    self.lastScrollOffsetY = offsetY;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MsgDetailContentDTO *dto = self.messageList[indexPath.row];
    
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
