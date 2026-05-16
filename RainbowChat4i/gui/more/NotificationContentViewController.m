//telegram @wz662
#import "NotificationContentViewController.h"

static NSString * const kNotificationContentKey = @"APP_NOTIFICATION_DISPLAY_CONTENT_TYPE";
static NSString * const kBannerContentKey = @"APP_BANNER_DISPLAY_CONTENT_TYPE";

@interface NotificationContentViewController ()

@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, strong) NSArray<NSString *> *options;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *checkmarks;

@end

@implementation NotificationContentViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 设置标题
    if (self.contentType == NotificationContentTypeNotification) {
        self.title = @"通知显示内容";
    } else {
        self.title = @"横幅显示内容";
    }
    
    // 背景色
    self.view.backgroundColor = [UIColor colorWithRed:0.941 green:0.941 blue:0.941 alpha:1.0];
    
    // 选项
    self.options = @[
        @"仅显示「你收到了一条消息」",
        @"显示朋友名称、群聊名",
        @"显示朋友名称、群聊名及消息内容"
    ];
    
    // 加载已保存的选择
    [self loadSelection];
    
    // 构建UI
    [self buildUI];
}

#pragma mark - 加载/保存选择

- (NSString *)currentKey
{
    return (self.contentType == NotificationContentTypeNotification) ? kNotificationContentKey : kBannerContentKey;
}

- (void)loadSelection
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud objectForKey:[self currentKey]] != nil) {
        self.selectedIndex = [ud integerForKey:[self currentKey]];
    } else {
        // 默认选择"显示朋友名称、群聊名及消息内容"
        self.selectedIndex = 2;
    }
}

- (void)saveSelection
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setInteger:self.selectedIndex forKey:[self currentKey]];
    [ud synchronize];
}

#pragma mark - 构建UI

- (void)buildUI
{
    self.checkmarks = [NSMutableArray array];
    
    // 白色容器
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:container];
    
    // 容器约束
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:10],
        [container.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
    
    UIView *previousItem = nil;
    
    for (NSInteger i = 0; i < self.options.count; i++) {
        UIView *itemView = [self createItemViewAtIndex:i];
        [container addSubview:itemView];
        
        [NSLayoutConstraint activateConstraints:@[
            [itemView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [itemView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [itemView.heightAnchor constraintEqualToConstant:56],
        ]];
        
        if (previousItem == nil) {
            [itemView.topAnchor constraintEqualToAnchor:container.topAnchor].active = YES;
        } else {
            [itemView.topAnchor constraintEqualToAnchor:previousItem.bottomAnchor].active = YES;
        }
        
        // 分隔线（最后一项不加）
        if (i < self.options.count - 1) {
            UIView *sep = [[UIView alloc] init];
            sep.translatesAutoresizingMaskIntoConstraints = NO;
            sep.backgroundColor = [UIColor colorWithRed:0.91 green:0.918 blue:0.933 alpha:1.0];
            [itemView addSubview:sep];
            
            [NSLayoutConstraint activateConstraints:@[
                [sep.leadingAnchor constraintEqualToAnchor:itemView.leadingAnchor constant:20],
                [sep.trailingAnchor constraintEqualToAnchor:itemView.trailingAnchor],
                [sep.bottomAnchor constraintEqualToAnchor:itemView.bottomAnchor],
                [sep.heightAnchor constraintEqualToConstant:0.5],
            ]];
        }
        
        previousItem = itemView;
    }
    
    // 容器底部约束
    if (previousItem) {
        [container.bottomAnchor constraintEqualToAnchor:previousItem.bottomAnchor].active = YES;
    }
}

- (UIView *)createItemViewAtIndex:(NSInteger)index
{
    UIView *itemView = [[UIView alloc] init];
    itemView.translatesAutoresizingMaskIntoConstraints = NO;
    itemView.backgroundColor = [UIColor clearColor];
    itemView.tag = index;
    
    // 按钮（覆盖整行，处理点击）
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.backgroundColor = [UIColor clearColor];
    btn.tag = index;
    [btn addTarget:self action:@selector(itemTapped:) forControlEvents:UIControlEventTouchUpInside];
    [btn setBackgroundImage:[UIImage imageNamed:@"common_btn_hilight_bg.png"] forState:UIControlStateHighlighted];
    [itemView addSubview:btn];
    
    [NSLayoutConstraint activateConstraints:@[
        [btn.topAnchor constraintEqualToAnchor:itemView.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:itemView.bottomAnchor],
        [btn.leadingAnchor constraintEqualToAnchor:itemView.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:itemView.trailingAnchor],
    ]];
    
    // 标签
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = self.options[index];
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    label.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    label.userInteractionEnabled = NO;
    [itemView addSubview:label];
    
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:itemView.leadingAnchor constant:20],
        [label.centerYAnchor constraintEqualToAnchor:itemView.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:itemView.trailingAnchor constant:-50],
    ]];
    
    // 绿色勾选图标
    UIImageView *checkmark = [[UIImageView alloc] init];
    checkmark.translatesAutoresizingMaskIntoConstraints = NO;
    checkmark.contentMode = UIViewContentModeScaleAspectFit;
    checkmark.userInteractionEnabled = NO;
    
    // 使用 SF Symbol checkmark
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
        checkmark.image = [UIImage systemImageNamed:@"checkmark" withConfiguration:config];
        checkmark.tintColor = [UIColor colorWithRed:0.204 green:0.78 blue:0.349 alpha:1.0]; // #34C759 绿色
    }
    
    checkmark.hidden = (index != self.selectedIndex);
    [itemView addSubview:checkmark];
    [self.checkmarks addObject:checkmark];
    
    [NSLayoutConstraint activateConstraints:@[
        [checkmark.trailingAnchor constraintEqualToAnchor:itemView.trailingAnchor constant:-20],
        [checkmark.centerYAnchor constraintEqualToAnchor:itemView.centerYAnchor],
        [checkmark.widthAnchor constraintEqualToConstant:22],
        [checkmark.heightAnchor constraintEqualToConstant:22],
    ]];
    
    return itemView;
}

#pragma mark - 点击事件

- (void)itemTapped:(UIButton *)sender
{
    NSInteger index = sender.tag;
    
    if (index == self.selectedIndex) {
        return; // 已选中，不做操作
    }
    
    // 更新选中状态
    self.selectedIndex = index;
    
    // 刷新勾选图标
    for (NSInteger i = 0; i < self.checkmarks.count; i++) {
        self.checkmarks[i].hidden = (i != self.selectedIndex);
    }
    
    // 保存选择
    [self saveSelection];
}

#pragma mark - 工具方法

+ (NSString *)descriptionForContentType:(NotificationContentType)type
{
    NSString *key = (type == NotificationContentTypeNotification) ? kNotificationContentKey : kBannerContentKey;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSInteger index = 2; // 默认
    if ([ud objectForKey:key] != nil) {
        index = [ud integerForKey:key];
    }
    
    switch (index) {
        case 0: return @"仅显示「你收到了一条消息」";
        case 1: return @"显示朋友名称、群聊名";
        case 2: return @"显示朋友名称、群聊名及消息内容";
        default: return @"显示朋友名称、群聊名及消息内容";
    }
}

@end
