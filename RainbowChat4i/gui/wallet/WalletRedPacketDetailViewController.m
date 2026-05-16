#import "WalletRedPacketDetailViewController.h"
#import "HttpRestHelper.h"
#import "BasicTool.h"
#import "IMClientManager.h"
#import "FriendsListProvider.h"
#import "FileDownloadHelper.h"
#import "TimeTool.h"
#import <QuartzCore/QuartzCore.h>
#import "UIViewController+RBPlainCustomNav.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]
// 微信风格配色（顶部红色区域 #f35543）
#define WXRed       HexColor(0xF35543)
#define WXRedDark   HexColor(0xC62F2C)
#define WXGold      HexColor(0xC9A227)
#define WXGoldLight HexColor(0xF5E6C8)
#define WXGrayBg    HexColor(0xEDEDED)
#define WXSectionBg HexColor(0xF7F7F7)
#define WXWhiteBg   [UIColor whiteColor]

static const CGFloat kReceiveRowH = 60;
static const CGFloat kReceiveAvatarSize = 44;
static const NSInteger kReceiveAvatarViewTag = 201;

@interface RedPacketReceiveCell : UITableViewCell
@end

@implementation RedPacketReceiveCell
- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    UIView *avatarView = [self.contentView viewWithTag:kReceiveAvatarViewTag];
    if (avatarView) {
        avatarView.frame = CGRectMake(16, (kReceiveRowH - kReceiveAvatarSize) / 2, kReceiveAvatarSize, kReceiveAvatarSize);
        avatarView.layer.cornerRadius = kReceiveAvatarSize * 0.5f;
    }
    self.imageView.frame = CGRectZero;
    self.imageView.hidden = YES;
    CGFloat left = 16 + kReceiveAvatarSize + 8;
    CGFloat rightW = 90;
    self.textLabel.frame = CGRectMake(left, 10, w - left - rightW, 22);
    self.detailTextLabel.frame = CGRectMake(left, 32, w - left - rightW, 18);
    UILabel *amountLabel = [self.contentView viewWithTag:200];
    if ([amountLabel isKindOfClass:[UILabel class]]) {
        [amountLabel sizeToFit];
        amountLabel.frame = CGRectMake(w - 16 - amountLabel.bounds.size.width, (kReceiveRowH - amountLabel.bounds.size.height) / 2, amountLabel.bounds.size.width, amountLabel.bounds.size.height);
    }
}
@end

static const CGFloat kSenderInfoHeight = 50;  // 发送人信息区高度，收紧下方空白
static const CGFloat kRedHeaderH = 150;   // 圆弧区域直线高度
static const CGFloat kRedArcHeight = 48;  // 凸弧高度

@interface WalletRedPacketDetailViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *redHeaderView;
@property (nonatomic, strong) UIImageView *redHeaderBgImageView;  // SVG 背景图
@property (nonatomic, strong) CAGradientLayer *redGradientLayer;
@property (nonatomic, strong) CAShapeLayer *redArcMaskLayer;  // 底部圆弧遮罩
@property (nonatomic, strong) UIView *redArcStrokeView;      // 圆弧金色描边容器（盖在红区上）
@property (nonatomic, strong) CAShapeLayer *redArcStrokeLayer;
@property (nonatomic, strong) UIView *senderInfoView;  // 白色区域：发送人头像、名称、拼、祝福语、金额
@property (nonatomic, strong) UILabel *typeLabel;       // 「拼」小标签（浅棕边框）
@property (nonatomic, strong) UIImageView *senderAvatarView; // 发送人头像
@property (nonatomic, strong) UILabel *senderNameLabel; // 发送人名称（或「我」）
@property (nonatomic, strong) UILabel *messageLabel;    // 祝福语
@property (nonatomic, strong) UILabel *totalLabel;       // 「1个红包共80.00元」
@property (nonatomic, strong) UILabel *myGrabLabel;      // 「我抢到了 ¥X.XX」或「未抢到」（仅收到的红包显示）
@property (nonatomic, strong) UIButton *grabButton;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSDictionary *packetInfo;
@property (nonatomic, strong) NSArray *receives;
@property (nonatomic, assign) BOOL hasTriedAutoGrab;  // 进入详情页后是否已尝试过自动领取，避免重复请求
@end

@implementation WalletRedPacketDetailViewController

- (NSString *)displayAssetType
{
    NSString *assetType = nil;
    if ([self.packetInfo isKindOfClass:[NSDictionary class]]) {
        id assetValue = self.packetInfo[@"asset_type"];
        if (assetValue && assetValue != [NSNull null]) {
            assetType = [[assetValue description] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
    }
    if (assetType.length == 0) {
        assetType = [self.assetTypeHint stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return (assetType.length > 0 ? assetType : @"CNY");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = WXWhiteBg;
    self.navigationItem.titleView = nil;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    [self rb_installPlainCustomNavigationBarWithTitle:@"红包详情"];

    [self buildTableView];
    [self buildSenderInfoView];  // 白色发送人信息区（头像、名称、拼、祝福语、金额）
    [self buildRedHeaderView];  // 红色圆弧区盖在最上层
    [self loadDetail];
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

- (void)buildRedHeaderView
{
    CGFloat w = self.view.bounds.size.width;
    CGFloat totalRedH = kRedHeaderH + kRedArcHeight;
    _redHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, totalRedH)];
    _redHeaderView.backgroundColor = [UIColor clearColor];
    _redHeaderView.clipsToBounds = YES;
    [self.view addSubview:_redHeaderView];

    _redHeaderBgImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, w, totalRedH)];
    _redHeaderBgImageView.contentMode = UIViewContentModeScaleAspectFill;
    _redHeaderBgImageView.clipsToBounds = YES;
    _redHeaderBgImageView.image = [UIImage imageNamed:@"red_packet_detail_bg"];
    [_redHeaderView addSubview:_redHeaderBgImageView];

    _redGradientLayer = [CAGradientLayer layer];
    _redGradientLayer.colors = @[(__bridge id)WXRed.CGColor, (__bridge id)WXRedDark.CGColor];
    _redGradientLayer.startPoint = CGPointMake(0.5, 0);
    _redGradientLayer.endPoint = CGPointMake(0.5, 1);
    _redGradientLayer.frame = CGRectMake(0, 0, w, totalRedH);
    [_redHeaderView.layer insertSublayer:_redGradientLayer atIndex:1];

    _redArcMaskLayer = [CAShapeLayer layer];
    _redHeaderView.layer.mask = _redArcMaskLayer;

    _redArcStrokeView = [[UIView alloc] initWithFrame:CGRectZero];
    _redArcStrokeView.backgroundColor = [UIColor clearColor];
    _redArcStrokeView.userInteractionEnabled = NO;
    [self.view addSubview:_redArcStrokeView];
    _redArcStrokeLayer = [CAShapeLayer layer];
    _redArcStrokeLayer.fillColor = nil;
    _redArcStrokeLayer.strokeColor = WXGoldLight.CGColor;
    _redArcStrokeLayer.lineWidth = 2;
    _redArcStrokeLayer.lineCap = kCALineCapRound;
    _redArcStrokeLayer.lineJoin = kCALineJoinRound;
    [_redArcStrokeView.layer addSublayer:_redArcStrokeLayer];
}

static const CGFloat kSenderTopPad = 6;
static const CGFloat kSenderAvatarSize = 32;
static const CGFloat kSenderRowGap = 8;

- (void)buildSenderInfoView
{
    CGFloat w = self.view.bounds.size.width;
    CGFloat leftPad = 16;
    CGFloat gap = 8;
    CGFloat pinBoxW = 26;
    CGFloat pinBoxH = 22;

    _senderInfoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, kSenderInfoHeight)];
    _senderInfoView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_senderInfoView];

    _senderAvatarView = [[UIImageView alloc] initWithFrame:CGRectMake(0, kSenderTopPad, kSenderAvatarSize, kSenderAvatarSize)];
    _senderAvatarView.backgroundColor = HexColor(0xE5E5E5);
    _senderAvatarView.layer.cornerRadius = kSenderAvatarSize * 0.5f;
    _senderAvatarView.clipsToBounds = YES;
    _senderAvatarView.contentMode = UIViewContentModeScaleAspectFill;
    _senderAvatarView.image = [UIImage imageNamed:@"default_avatar_60"];
    [_senderInfoView addSubview:_senderAvatarView];

    _senderNameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _senderNameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    _senderNameLabel.textColor = HexColor(0x333333);
    _senderNameLabel.textAlignment = NSTextAlignmentLeft;
    _senderNameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _senderNameLabel.text = @"";
    [_senderInfoView addSubview:_senderNameLabel];

    _typeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, kSenderTopPad + 2, pinBoxW, pinBoxH)];
    _typeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _typeLabel.textColor = HexColor(0xB8860B);
    _typeLabel.textAlignment = NSTextAlignmentCenter;
    _typeLabel.layer.borderColor = [HexColor(0xD4A84B) CGColor];
    _typeLabel.layer.borderWidth = 1;
    _typeLabel.layer.cornerRadius = 4;
    _typeLabel.text = @"拼";
    [_senderInfoView addSubview:_typeLabel];

    _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(leftPad, kSenderTopPad + kSenderAvatarSize + kSenderRowGap, w - leftPad * 2, 20)];
    _messageLabel.font = [UIFont systemFontOfSize:14];
    _messageLabel.textColor = HexColor(0x888888);
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.numberOfLines = 2;
    _messageLabel.text = @"";
    [_senderInfoView addSubview:_messageLabel];

    _totalLabel = [[UILabel alloc] initWithFrame:CGRectMake(leftPad, kSenderTopPad + kSenderAvatarSize + kSenderRowGap + 20 + 6, w - leftPad * 2, 18)];
    _totalLabel.font = [UIFont systemFontOfSize:13];
    _totalLabel.textColor = HexColor(0x888888);
    _totalLabel.textAlignment = NSTextAlignmentCenter;
    _totalLabel.text = @"";
    [_senderInfoView addSubview:_totalLabel];

    _myGrabLabel = [[UILabel alloc] initWithFrame:CGRectMake(leftPad, kSenderTopPad + kSenderAvatarSize + kSenderRowGap + 20 + 6 + 18 + 4, w - leftPad * 2, 20)];
    _myGrabLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _myGrabLabel.textColor = HexColor(0x333333);
    _myGrabLabel.textAlignment = NSTextAlignmentCenter;
    _myGrabLabel.text = @"";
    _myGrabLabel.hidden = YES;
    [_senderInfoView addSubview:_myGrabLabel];

    _grabButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _grabButton.frame = CGRectMake((w - 140) / 2, kSenderInfoHeight - 56, 140, 40);
    [_grabButton setTitle:@"开" forState:UIControlStateNormal];
    _grabButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    _grabButton.backgroundColor = WXRed;
    [_grabButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _grabButton.layer.cornerRadius = 20;
    [_grabButton addTarget:self action:@selector(onGrab) forControlEvents:UIControlEventTouchUpInside];
    _grabButton.hidden = YES;
    [_senderInfoView addSubview:_grabButton];
}

- (void)buildTableView
{
    CGFloat w = self.view.bounds.size.width;
    CGFloat totalRedH = kRedHeaderH + kRedArcHeight;
    CGFloat tableTop = totalRedH + kSenderInfoHeight;  // 列表紧贴发送人信息下方
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, tableTop, w, self.view.bounds.size.height - tableTop) style:UITableViewStyleGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = WXWhiteBg;
    _tableView.separatorInset = UIEdgeInsetsMake(0, 68, 0, 16);
    _tableView.tableFooterView = [[UIView alloc] init];
    _tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 1)];
    if (@available(iOS 15.0, *)) {
        _tableView.sectionHeaderTopPadding = 0;
    }
    _tableView.contentInset = UIEdgeInsetsMake(40, 0, 0, 0);  // 顶部可往下多滑 40pt
    [self.view addSubview:_tableView];
}

- (void)loadDetail
{
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletGetRedPacketDetail:_packetId complete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && data) {
                wself.packetInfo = data;
                wself.receives = data[@"receives"] ?: @[];

                NSString *totalAmount = data[@"total_amount"] ? [data[@"total_amount"] description] : @"0.00";
                int totalCount = [data[@"total_count"] intValue];
                if (totalCount <= 0) totalCount = 1;
                wself.totalLabel.text = [NSString stringWithFormat:@"%d个红包共%@ %@", totalCount, [wself displayAssetType], totalAmount];

                NSString *msg = data[@"message"] ? [data[@"message"] description] : @"";
                wself.messageLabel.text = (msg.length > 0 ? msg : @"恭喜发财，大吉大利");

                NSString *senderUid = data[@"sender_uid"] ? [data[@"sender_uid"] description] : @"";
                NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid ?: @"";
                int totalCountForType = [data[@"total_count"] intValue];
                wself.typeLabel.text = (totalCountForType > 1) ? @"拼" : @"普";

                NSString *senderDisplayName = @"用户";
                if (senderUid.length > 0) {
                    if ([senderUid isEqualToString:localUid]) {
                        UserEntity *me = [[IMClientManager sharedInstance] localUserInfo];
                        senderDisplayName = (me.nickname.length > 0 ? me.nickname : @"我");
                    } else {
                        UserEntity *friendInfo = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:senderUid];
                        if (friendInfo) {
                            NSString *nick = [friendInfo getNickNameWithRemark];
                            senderDisplayName = (nick.length > 0 ? nick : @"用户");
                        }
                    }
                }
                wself.senderNameLabel.text = senderDisplayName;

                if (senderUid.length > 0) {
                    [FileDownloadHelper loadUserAvatarWithUID:senderUid logTag:@"RedPacketDetail-Sender" complete:^(BOOL sucess, UIImage *img) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (img) wself.senderAvatarView.image = img;
                        });
                    } donotLoadFromDisk:NO];
                } else {
                    wself.senderAvatarView.image = [UIImage imageNamed:@"default_avatar_60"];
                }

                // 详情页不显示「开」按钮，抢红包在聊天里点击时已完成
                wself.grabButton.hidden = YES;

                // 收到的红包时显示：我抢到了 ¥X.XX 或 未抢到
                NSString *localUidForGrab = [[IMClientManager sharedInstance] localUserInfo].user_uid ?: @"";
                if (localUidForGrab.length > 0 && ![senderUid isEqualToString:localUidForGrab]) {
                    wself.myGrabLabel.hidden = NO;
                    NSString *myAmount = nil;
                    for (NSDictionary *rec in wself.receives) {
                        NSString *ruid = rec[@"receiver_uid"] ? [rec[@"receiver_uid"] description] : @"";
                        if ([ruid isEqualToString:localUidForGrab]) {
                            myAmount = rec[@"amount"] ? [rec[@"amount"] description] : @"0.00";
                            break;
                        }
                    }
                    if (myAmount.length > 0) {
                        wself.myGrabLabel.text = [NSString stringWithFormat:@"我抢到了 %@ %@", [wself displayAssetType], myAmount];
                        wself.myGrabLabel.textColor = [UIColor whiteColor];
                    } else {
                        wself.myGrabLabel.text = @"未抢到";
                        wself.myGrabLabel.textColor = [WXGoldLight colorWithAlphaComponent:0.95];
                    }
                } else {
                    wself.myGrabLabel.hidden = YES;
                }

                [wself.tableView reloadData];

                // 进入详情页时若尚未领取且非本人所发，自动领取一次（如从红包列表点进、或弹窗未领就进详情）
                NSString *senderUidForGrab = data[@"sender_uid"] ? [data[@"sender_uid"] description] : @"";
                BOOL isMyPacket = (localUidForGrab.length > 0 && [senderUidForGrab isEqualToString:localUidForGrab]);
                BOOL alreadyInReceives = NO;
                if (localUidForGrab.length > 0 && [wself.receives isKindOfClass:[NSArray class]]) {
                    for (NSDictionary *rec in wself.receives) {
                        NSString *ruid = rec[@"receiver_uid"] ? [rec[@"receiver_uid"] description] : @"";
                        if ([ruid isEqualToString:localUidForGrab]) {
                            alreadyInReceives = YES;
                            break;
                        }
                    }
                }
                if (!isMyPacket && !alreadyInReceives && localUidForGrab.length > 0 && !wself.hasTriedAutoGrab) {
                    wself.hasTriedAutoGrab = YES;
                    [[HttpRestHelper sharedInstance] submitWalletGrabRedPacket:wself.packetId complete:^(BOOL grabSucess, NSDictionary *grabData) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (grabSucess) {
                                [wself loadDetail];
                            }
                        });
                    } hudParentView:wself.view];
                }
            }
        });
    } hudParentView:self.view];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger n = _receives.count;
    return (n > 0) ? n : (_packetInfo ? 1 : 0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger n = _receives.count;
    if (n == 0) return 0;
    return 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    BOOL isFirst = (section == 0);
    CGFloat h = isFirst ? 44 : 8;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, h)];
    header.backgroundColor = WXWhiteBg;
    if (isFirst) {
        int total = 0;
        if (_packetInfo && _packetInfo[@"total_count"]) total = [_packetInfo[@"total_count"] intValue];
        if (total <= 0) total = 1;
        NSInteger received = _receives.count;
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, header.bounds.size.width - 80, 20)];
        label.font = [UIFont systemFontOfSize:14];
        label.textColor = HexColor(0x888888);
        label.text = [NSString stringWithFormat:@"领取记录  已领 %ld/%d", (long)received, total];
        [header addSubview:label];
    }
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return (section == 0) ? 44 : 8;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.01;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kReceiveRowH;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __weak typeof(self) wself = self;
    static NSString *cid = @"rp_recv";
    RedPacketReceiveCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[RedPacketReceiveCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.backgroundColor = [UIColor whiteColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.textLabel.textColor = HexColor(0x333333);
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.textColor = HexColor(0x999999);
        UIImageView *avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(16, (kReceiveRowH - kReceiveAvatarSize) / 2, kReceiveAvatarSize, kReceiveAvatarSize)];
        avatarView.tag = kReceiveAvatarViewTag;
        avatarView.layer.cornerRadius = kReceiveAvatarSize * 0.5f;
        avatarView.clipsToBounds = YES;
        avatarView.contentMode = UIViewContentModeScaleAspectFill;
        avatarView.backgroundColor = HexColor(0xE5E5E5);
        [cell.contentView addSubview:avatarView];
    }

    NSDictionary *receive = _receives[indexPath.section];
    NSString *receiverUid = receive[@"receiver_uid"] ? [receive[@"receiver_uid"] description] : @"";
    NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid ?: @"";
    NSString *nickname = receive[@"nickname"] ? [receive[@"nickname"] description] : nil;
    if (!nickname.length && receiverUid.length > 0) {
        if ([receiverUid isEqualToString:localUid]) {
            UserEntity *me = [[IMClientManager sharedInstance] localUserInfo];
            nickname = (me.nickname.length > 0 ? me.nickname : @"我");
        } else {
            UserEntity *friendInfo = [[[IMClientManager sharedInstance] getFriendsListProvider] getFriendInfoByUid2:receiverUid];
            if (friendInfo) {
                NSString *nick = [friendInfo getNickNameWithRemark];
                if (nick.length > 0) nickname = nick;
            }
        }
    }
    if (!nickname.length) nickname = @"用户";
    NSString *amount = receive[@"amount"] ? [receive[@"amount"] description] : @"0.00";
    NSString *timeStr = receive[@"receive_time"] ? [receive[@"receive_time"] description] : @"";
    if (timeStr.length >= 13) {
        long long ms = [timeStr longLongValue];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:ms / 1000.0];
        timeStr = [TimeTool getTimeStringAutoShort2:date mustIncludeTime:YES timeWithSegment:NO];
        NSRange r = [timeStr rangeOfString:@" "];
        if (r.location != NSNotFound && r.location + 1 < timeStr.length) {
            timeStr = [timeStr substringFromIndex:r.location + 1];
        }
    }

    cell.textLabel.text = nickname;
    cell.detailTextLabel.text = timeStr;

    UIImageView *avatarView = [cell.contentView viewWithTag:kReceiveAvatarViewTag];
    if ([avatarView isKindOfClass:[UIImageView class]]) {
        avatarView.image = [UIImage imageNamed:@"default_avatar_60"];
        if (receiverUid.length > 0) {
            NSInteger sec = indexPath.section;
            [FileDownloadHelper loadUserAvatarWithUID:receiverUid logTag:@"RedPacketDetail-Receiver" complete:^(BOOL sucess, UIImage *img) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    RedPacketReceiveCell *c = (RedPacketReceiveCell *)[wself.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:sec]];
                    UIImageView *av = [c.contentView viewWithTag:kReceiveAvatarViewTag];
                    if ([av isKindOfClass:[UIImageView class]] && img) av.image = img;
                });
            } donotLoadFromDisk:NO];
        }
    }

    UILabel *amountLabel = [cell.contentView viewWithTag:200];
    if (!amountLabel) {
        amountLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        amountLabel.tag = 200;
        amountLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        amountLabel.textColor = WXRed;
        [cell.contentView addSubview:amountLabel];
    }
    amountLabel.text = [NSString stringWithFormat:@"%@ %@", [self displayAssetType], amount];

    return cell;
}

- (void)onGrab
{
    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitWalletGrabRedPacket:_packetId complete:^(BOOL sucess, NSDictionary *data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (sucess && data && data[@"amount"]) {
                NSString *amount = [data[@"amount"] description];
                [BasicTool showAlertInfo:[NSString stringWithFormat:@"恭喜您抢到 %@ %@", [wself displayAssetType], amount] parent:wself];
                [wself loadDetail];
            } else {
                NSString *msg = @"抢红包失败";
                if ([data isKindOfClass:[NSDictionary class]] && data[@"msg"]) {
                    NSString *s = [[data[@"msg"] description] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (s.length > 0) msg = s;
                }
                [BasicTool showAlertInfo:msg parent:wself];
            }
        });
    } hudParentView:self.view];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat navTop = 0;
    if (@available(iOS 11.0, *)) {
        navTop = self.view.safeAreaInsets.top;
    }
    CGFloat headerH = kRedHeaderH;
    CGFloat arcHeight = kRedArcHeight;
    CGFloat totalRedH = headerH + arcHeight;
    _redHeaderView.frame = CGRectMake(0, navTop, w, totalRedH);
    _redHeaderBgImageView.frame = CGRectMake(0, 0, w, totalRedH);
    _redGradientLayer.frame = CGRectMake(0, 0, w, totalRedH);
    _redGradientLayer.cornerRadius = 0;

    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(0, 0)];
    [path addLineToPoint:CGPointMake(w, 0)];
    [path addLineToPoint:CGPointMake(w, headerH)];
    [path addQuadCurveToPoint:CGPointMake(0, headerH) controlPoint:CGPointMake(w / 2, headerH + arcHeight)];
    [path closePath];
    _redArcMaskLayer.path = path.CGPath;

    _redArcStrokeView.frame = CGRectMake(0, navTop, w, totalRedH);
    _redArcStrokeLayer.frame = CGRectMake(0, 0, w, totalRedH);
    UIBezierPath *strokePath = [UIBezierPath bezierPath];
    [strokePath moveToPoint:CGPointMake(w, headerH)];
    [strokePath addQuadCurveToPoint:CGPointMake(0, headerH) controlPoint:CGPointMake(w / 2, headerH + arcHeight)];
    _redArcStrokeLayer.path = strokePath.CGPath;

    _senderInfoView.frame = CGRectMake(0, navTop + totalRedH, w, kSenderInfoHeight);  // 紧贴凸弧下方
    CGFloat avatarSize = kSenderAvatarSize;
    CGFloat gap = 8;
    CGFloat pinGap = 6;
    CGFloat pinBoxW = 26;
    CGFloat pinBoxH = 22;
    CGFloat maxNameW = w - avatarSize - gap - pinGap - pinBoxW - 48;
    _senderNameLabel.frame = CGRectMake(0, 0, maxNameW, 22);
    [_senderNameLabel sizeToFit];
    CGFloat nameW = MIN((CGFloat)_senderNameLabel.bounds.size.width, maxNameW);
    CGFloat totalRowW = avatarSize + gap + nameW + pinGap + pinBoxW;
    CGFloat startX = (w - totalRowW) / 2;
    _senderAvatarView.frame = CGRectMake(startX, kSenderTopPad, avatarSize, avatarSize);
    _senderNameLabel.frame = CGRectMake(startX + avatarSize + gap, kSenderTopPad + 2, nameW, 22);
    _typeLabel.frame = CGRectMake(startX + avatarSize + gap + nameW + pinGap, kSenderTopPad + 2, pinBoxW, pinBoxH);
    CGFloat leftPad = 16;
    _messageLabel.frame = CGRectMake(leftPad, kSenderTopPad + avatarSize + kSenderRowGap, w - leftPad * 2, 20);
    _totalLabel.frame = CGRectMake(leftPad, kSenderTopPad + avatarSize + kSenderRowGap + 20 + 6, w - leftPad * 2, 18);
    _myGrabLabel.frame = CGRectMake(leftPad, kSenderTopPad + avatarSize + kSenderRowGap + 20 + 6 + 18 + 4, w - leftPad * 2, 20);
    _grabButton.frame = CGRectMake((w - 140) / 2, kSenderInfoHeight - 56, 140, 40);

    CGFloat tableTop = navTop + totalRedH + kSenderInfoHeight;  // 列表紧贴发送人信息下方
    _tableView.frame = CGRectMake(0, tableTop, w, h - tableTop);
}

@end
