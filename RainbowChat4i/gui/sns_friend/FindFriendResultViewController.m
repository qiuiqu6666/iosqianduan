//telegram @wz662
#import "FindFriendResultViewController.h"
#import "UserEntity.h"
#import "FindFriendResultTableViewCell.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "AppDelegate.h"
#import "ViewControllerFactory.h"
#import "HttpRestHelper.h"
#import "IMClientManager.h"

@interface FindFriendResultViewController ()
/** 传进来的参数： "-1" - 表示不区分是否在线，"1" - 表示只查在线，"0" - 表示只查离线 */
@property (nonatomic, retain) NSString *sexConditionForInit;
/** 传进来的参数："-1" - 表示不区分性别，"1"  - 表示只查男性，"0" - 表示只查女性 */
@property (nonatomic, retain) NSString *onlineConditionForInit;
/** 查询结果的数据集合 */
@property (nonatomic, retain) NSMutableArray<UserEntity *> *usersList;
@end

@implementation FindFriendResultViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withSexCondition:(NSString *)sex withOnlineCondition:(NSString *)onlineStatus
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.sexConditionForInit = sex;
        self.onlineConditionForInit = onlineStatus;
        
        // 初始化数据集合
        self.usersList = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 添加导航栏右边的“更多”按钮（无背景图标样式）
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"widget_title_btn_refresh_t"]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(doLoadData:)];
    
    // 表格基本设置
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    // 去掉空白行的显示
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    //  // 让表格行分隔线从左边0像素处绘制（默认左边会有一点空白，不好看）
    //  [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    // 让表格行分隔线从左边指定像素处绘制
    [self.tableView setSeparatorInset:UIEdgeInsetsMake(0, 78, 0, 0)];
    // 表格的背景色
    self.tableView.backgroundColor = UI_DEFAULT_BG;
    // 表格分隔线的颜色
    self.tableView.separatorColor = UI_DEFAULT_TABLE_VIEW_DIVIDER_GRAY;
    // 针对ios 26的优化：ios 26上这个分隔显示的又粗颜色又深，干脆就不要显示分隔线了
    if (@available(iOS 26, *)) {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }

    self.title = @"查找结果";

    // 刷新ui显示
    [self refreshUI];
    
    // 加载数据
    [self loadData];
}

// 根据UIViewController的生命周期，本方法将在每次本界面每次回到前台时被调用
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // 无条件尝试刷新表格的数据显示（解决从跳转的页面回来时，本
    // 表格的行选中状态还在，那选中背景色一直显示的话看起来就怪怪的）- 20190807 by Jack Jiang
    [self.tableView reloadData];
}

// 点击“换一批”按钮时调用的方法
- (void)doLoadData:(UIBarButtonItem *)sender
{
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak FindFriendResultViewController *safeSelf = self;
    
    // 确认对话框
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"友情提示" message:@"您确认\"换一批\"吗？" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okActin=[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action){
        [safeSelf loadData];
    }];
    UIAlertAction *cancelAction=[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:okActin];
    [alert addAction:cancelAction];
    
    // 显示确认对话框架
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)refreshUI
{
    // 列表无数据时的ui显示
    if([self.usersList count] > 0)
    {
        self.tableView.hidden = NO;
        self.layoutTableEmptyHint.hidden = YES;
    }
    else
    {
        self.tableView.hidden = YES;
        self.layoutTableEmptyHint.hidden = NO;
    }
    
    [self.tableView reloadData];
}


/**
 从服务端查询数据并刷新到界面显示。
 */
- (void)loadData
{
    [self.usersList removeAllObjects];
    
    // 为了在block代码中安全地使用本类“self”，请在block代码中使用safeSelf
    __weak FindFriendResultViewController *safeSelf = self;
    NSString *localUid = [[IMClientManager sharedInstance] localUserInfo].user_uid;
    
    // 提交查询请求
    [[HttpRestHelper sharedInstance] submitGetRandomFindFriendsToServer:localUid sex:self.sexConditionForInit online:self.onlineConditionForInit complete:^(BOOL sucess, NSArray<UserEntity *> *rosterList) {
        
        if(sucess && rosterList != nil)
        {
            NSLog(@"当前查询到的随机好友列表长度为%ld", (long)[rosterList count]);
            
            // 更新结果数据集合
            safeSelf.usersList = [rosterList mutableCopy];
            // 刷新数据在UI上的显示
            [safeSelf refreshUI];
        }
        else
        {
//            AlertError(@"很遗憾，没有更多结果！");
            [BasicTool showAlertError:@"很遗憾，没有更多结果！" parent:safeSelf];
        }
        
    } hudParentView:self.view];
}


#pragma mark - Table view delegate

// 表格行数
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.usersList count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

// 表格行高
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 68;//62 + 6
}

// 表示行的UI显示内容
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *theCell = nil;
    UserEntity *ree = (UserEntity *)[self.usersList objectAtIndex:indexPath.section];
    

    //** 表格单元可重用ui
    static NSString *idenfity=@"CellMain";
    FindFriendResultTableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:idenfity];
    if(cell==nil) {
        NSArray* arr = [[NSBundle mainBundle] loadNibNamed:@"FindFriendResultTableViewCell" owner:self options:nil];
        for (id obj in arr) {
            if ([obj isKindOfClass:[FindFriendResultTableViewCell class]]) {
                cell = (FindFriendResultTableViewCell *)obj;
            }
        }
    }
    theCell = cell;
    

    //** 表格单元选中时的颜色
    cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    cell.selectedBackgroundView.backgroundColor = UI_DEFAULT_TABLE_VIEW_SELECTED_BG_DARK_COLOR;
    // 为了跟表格背景色一致，cell的背景设为透明
    cell.backgroundColor=[UIColor clearColor];
    

    //** 利表格单元对应的数据对象对ui进行设置 ------------------------------------- START
    // 基本组件的值设置
    BOOL whatsupEmpty = [BasicTool isStringEmpty:ree.whatsUp];
    cell.viewNikcName.text = [ree getNickNameWithRemark];
    cell.viewContent.text = (whatsupEmpty ? [NSString stringWithFormat:@"ID：%@", ree.user_uid] : ree.whatsUp);
    
    // 设置性别的显示
    if([ree isMan])
    {
        [cell.viewSex setTitle:@"男" forState:UIControlStateNormal];
        [cell.viewSex setTitleColor:HexColor(0x12B7F5) forState:UIControlStateNormal];
        [cell.viewSex setImage:[UIImage imageNamed:@"sns_find_friend_result_flag_pink_man"] forState:UIControlStateNormal];
        [cell.viewSex setBackgroundImage:[UIImage imageNamed:@"sns_find_friend_result_flag_blue"] forState:UIControlStateNormal];
    }
    else
    {
        [cell.viewSex setTitle:@"女" forState:UIControlStateNormal];
        [cell.viewSex setTitleColor:HexColor(0xff6991) forState:UIControlStateNormal];
        [cell.viewSex setImage:[UIImage imageNamed:@"sns_find_friend_result_flag_pink_woman"] forState:UIControlStateNormal];
        [cell.viewSex setBackgroundImage:[UIImage imageNamed:@"sns_find_friend_result_flag_pink"] forState:UIControlStateNormal];
    }
    // 设置按钮拉伸图片（不然图片因组件在autolayout下自适配屏幕后而变形）
    [BasicTool setStretchBackgroundImage:cell.viewSex capInsets:UIEdgeInsetsMake(4, 4, 4, 4) img:[cell.viewSex backgroundImageForState:UIControlStateNormal] forState:UIControlStateNormal];
    
    // 设置在线状态显示
    if([ree isOnline])
    {
        [cell.viewStatus setTitle:@"在线" forState:UIControlStateNormal];
        [cell.viewStatus setTitleColor:HexColor(0x42c958) forState:UIControlStateNormal];
        [cell.viewStatus setBackgroundImage:[UIImage imageNamed:@"sns_find_friend_result_flag_green_kong"] forState:UIControlStateNormal];
    }
    else
    {
        [cell.viewStatus setTitle:@"离线" forState:UIControlStateNormal];
        [cell.viewStatus setBackgroundImage:[UIImage imageNamed:@"sns_find_friend_result_flag_gray_kong"] forState:UIControlStateNormal];
        [cell.viewStatus setTitleColor:HexColor(0xb2b2b2) forState:UIControlStateNormal];
    }
    // 设置按钮拉伸图片（不然图片因组件在autolayout下自适配屏幕后而变形）
    [BasicTool setStretchBackgroundImage:cell.viewStatus capInsets:UIEdgeInsetsMake(4, 4, 4, 4) img:[cell.viewStatus backgroundImageForState:UIControlStateNormal] forState:UIControlStateNormal];

    // 图片圆角
    cell.viewAvatar.layer.cornerRadius = 25;
    cell.viewAvatar.layer.masksToBounds = YES;

    // 按需载入用户头像（支持视频头像播放）
    [RBAvatarView setAvatarWithFileName:ree.userAvatarFileName uid:ree.user_uid onImageView:cell.viewAvatar placeholder:nil];
    //** 利表格单元对应的数据对象对ui进行设置 ------------------------------------- END

    return theCell;
}


#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexP
// 点击表格行时要调用的方法
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UserEntity *ree = (UserEntity *)[self.usersList objectAtIndex:indexPath.section];
    if(ree != nil){
        [ViewControllerFactory goFriendInfoViewController:self.navigationController withDatas:ree canOpenChat:YES addSource:@"random"];
    }
}

@end
