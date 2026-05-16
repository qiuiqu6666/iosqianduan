//telegram @wz662
//
//  MSSBrowseBaseViewController.m
//  MSSBrowse
//
//  Created by 于威 on 16/4/26.
//  Copyright © 2016年 于威. All rights reserved.
//

#import "MSSBrowseBaseViewController.h"
#import "UIImageView+WebCache.h"
#import "SDImageCache.h"
#import "UIImage+MSSScale.h"
#import "MSSBrowseRemindView.h"
#import "MSSBrowseActionSheet.h"
#import "MSSBrowseDefine.h"
#import "LPActionSheet.h" // @since 7.0 add by JackJiang

@interface MSSBrowseBaseViewController ()

@property (nonatomic,strong)NSArray *browseItemArray;
@property (nonatomic,assign)NSInteger currentIndex;
@property (nonatomic,assign)BOOL isRotate;// 判断是否正在切换横竖屏
@property (nonatomic,strong)UILabel *countLabel;// 当前图片位置
@property (nonatomic,strong)UIView *snapshotView;
@property (nonatomic,strong)NSMutableArray *verticalBigRectArray;
@property (nonatomic,strong)NSMutableArray *horizontalBigRectArray;
@property (nonatomic,strong)UIView *bgView;
@property (nonatomic,assign)UIDeviceOrientation currentOrientation;
@property (nonatomic,strong)MSSBrowseActionSheet *browseActionSheet;
@property (nonatomic,strong)MSSBrowseRemindView *browseRemindView;

//@property (nonatomic,assign)CGFloat topBarHeight;// !!!!!!

@end

@implementation MSSBrowseBaseViewController

- (instancetype)initWithBrowseItem:(MSSBrowseModel *)browseItem
{
    NSMutableArray *browseItemArray = [[NSMutableArray alloc]init];
    [browseItemArray addObject:browseItem];
    return [self initWithBrowseItemArray:browseItemArray currentIndex:0];
}

- (instancetype)initWithBrowseItemArray:(NSArray *)browseItemArray currentIndex:(NSInteger)currentIndex
{
    self = [super init];
    if(self)
    {
        _browseItemArray = browseItemArray;
        _currentIndex = currentIndex;
        _isEqualRatio = YES;
        _isFirstOpen = YES;
        _screenWidth = MSS_SCREEN_WIDTH;
        _screenHeight = MSS_SCREEN_HEIGHT;
        _currentOrientation = UIDeviceOrientationPortrait;
        _verticalBigRectArray = [[NSMutableArray alloc]init];
        _horizontalBigRectArray = [[NSMutableArray alloc]init];
    }
    return self;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)showBrowseViewController
{
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    if([[[UIDevice currentDevice]systemVersion]floatValue] >= 8.0)
    {
        self.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    }
    else
    {
        _snapshotView = [rootViewController.view snapshotViewAfterScreenUpdates:NO];
    }
    [rootViewController presentViewController:self animated:NO completion:^{
        
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initData];
    [self createBrowseView];
}

- (void)initData
{
    for (MSSBrowseModel *browseItem in _browseItemArray)
    {
        CGRect verticalRect = CGRectZero;
        CGRect horizontalRect = CGRectZero;
        // 等比可根据小图宽高计算大图宽高
        if(_isEqualRatio)
        {
            if(browseItem.smallImageView)
            {
                verticalRect = [browseItem.smallImageView.image mss_getBigImageRectSizeWithScreenWidth:MSS_SCREEN_WIDTH screenHeight:MSS_SCREEN_HEIGHT];
                horizontalRect = [browseItem.smallImageView.image mss_getBigImageRectSizeWithScreenWidth:MSS_SCREEN_HEIGHT screenHeight:MSS_SCREEN_WIDTH];
            }
        }
        NSValue *verticalValue = [NSValue valueWithCGRect:verticalRect];
        [_verticalBigRectArray addObject:verticalValue];
        NSValue *horizontalValue = [NSValue valueWithCGRect:horizontalRect];
        [_horizontalBigRectArray addObject:horizontalValue];
    }
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

// 获取指定视图在window中的位置
- (CGRect)getFrameInWindow:(UIView *)view
{
    // 改用[UIApplication sharedApplication].keyWindow.rootViewController.view，防止present新viewController坐标转换不准问题
    return [view.superview convertRect:view.frame toView:[UIApplication sharedApplication].keyWindow.rootViewController.view];
}

- (void)createBrowseView
{
    self.view.backgroundColor = [UIColor blackColor];
    if(_snapshotView)
    {
        _snapshotView.hidden = YES;
        [self.view addSubview:_snapshotView];
    }
    
    _bgView = [[UIView alloc]initWithFrame:self.view.bounds];
    _bgView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_bgView];
    
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc]init];
    flowLayout.minimumLineSpacing = 0;
    // 布局方式改为从上至下，默认从左到右
    flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    // Section Inset就是某个section中cell的边界范围
    flowLayout.sectionInset = UIEdgeInsetsMake(0, 0, 0, 0);
    // 每行内部cell item的间距
    flowLayout.minimumInteritemSpacing = 0;
    // 每行的间距
    flowLayout.minimumLineSpacing = 0;
    
    _collectionView = [[UICollectionView alloc]initWithFrame:CGRectMake(0, 0, _screenWidth + kBrowseSpace, _screenHeight) collectionViewLayout:flowLayout];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.pagingEnabled = YES;
    _collectionView.bounces = NO;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.showsVerticalScrollIndicator = NO;
    _collectionView.backgroundColor = [UIColor blackColor];
    [_collectionView registerClass:[MSSBrowseCollectionViewCell class] forCellWithReuseIdentifier:@"MSSBrowserCell"];
    _collectionView.contentOffset = CGPointMake(_currentIndex * (_screenWidth + kBrowseSpace), 0);
    [_bgView addSubview:_collectionView];

    // 只有要查看的图片数大1的情况下才在下方显示“1/2”这样的信息，表示当前正的查看的图片号和总图片数，1张时就不显示了——这样显的UI干净一点
    if((long)_browseItemArray.count > 1)
    {
        _countLabel = [[UILabel alloc]init];
        _countLabel.textColor = [UIColor whiteColor];
        _countLabel.frame = CGRectMake(0, _screenHeight - 50, _screenWidth, 50);
        _countLabel.text = [NSString stringWithFormat:@"%ld/%ld",(long)_currentIndex + 1,(long)_browseItemArray.count];
        _countLabel.textAlignment = NSTextAlignmentCenter;
        [_bgView addSubview:_countLabel];
    }
    
    _browseRemindView = [[MSSBrowseRemindView alloc]initWithFrame:_bgView.bounds];
    [_bgView addSubview:_browseRemindView];

    // 在图片查看界面的上方显示一行提示信息（仅用于显示而已，别无它用）
    [self createBrowseView_extraTip:_bgView];
}

// 在图片查看界面的上方显示一行提示信息（仅用于显示而已，别无它用）， add by JackJiang 20180701
- (void)createBrowseView_extraTip:(UIView *)parentView
{
//    CGFloat padding = 8;
    // 不使用硬编码值，以便兼容刘海屏
    CGFloat topBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;//21;
    CGFloat btnWH = 36;
//
//    // 信息提示组件图标
//    CGFloat iconWidth = 16;
//    CGFloat iconHeight = 16;
//    UIImageView *infoIconView = [[UIImageView alloc] initWithFrame:CGRectMake(padding, padding+topBarHeight, iconWidth, iconHeight)];
//    infoIconView.image = [UIImage imageNamed:@"mss_image_hint_ico"];
//    // 图标的相对显示位置
//    [parentView addSubview:infoIconView];
//
//    // 信息提示文本组件
//    CGFloat labelWidth = 300;
//    CGFloat labelHeight = 14;
//    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding+iconWidth+3, padding+topBarHeight+1, labelWidth, labelHeight)];
//    infoLabel.text = @"提示：支持多点触控缩放图片";
//    infoLabel.font = [UIFont systemFontOfSize:12.0f];
//    infoLabel.textColor = HexColor(0x9f9f9f);
    // 文本组件的相对显示位置
//    [parentView addSubview:infoLabel];
    
    // 关闭按钮
    // 在非留海屏的老iphone手机上，[BasicTool getSafeAreaInsets_top]返回的结果居然不是0，又是系统的bug？
    CGFloat safeAreaInsets_top = topBarHeight;//20;// [BasicTool getSafeAreaInsets_top];
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(25 ,0 + safeAreaInsets_top, btnWH, btnWH);
    [closeBtn setImage:[UIImage imageNamed:@"mss_close2"] forState:UIControlStateNormal];
//    closeBtn.imageView.image = [UIImage imageNamed:@"mss_close2"];
//    [closeBtn setBackgroundColor:RGBACOLOR(255,255,255, 26)];
    [closeBtn.layer setCornerRadius:18];// 10
//    [closeBtn.layer setBorderColor:RGBACOLOR(255,255,255, 28).CGColor];
//    [closeBtn.layer setBorderWidth:1.0f];
    [closeBtn addTarget:self action:@selector(closeViewController) forControlEvents:UIControlEventTouchUpInside];
    
    // 菜单按钮
    UIButton *menuBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    menuBtn.frame = CGRectMake(ScreenWidth - 25 - btnWH  ,0 + safeAreaInsets_top, btnWH, btnWH);
    [menuBtn setImage:[UIImage imageNamed:@"mss_menu"] forState:UIControlStateNormal];
//    [menuBtn setBackgroundColor:RGBACOLOR(255,255,255, 26)];
    [menuBtn.layer setCornerRadius:18];// 10
    [menuBtn addTarget:self action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];
    
    parentView.backgroundColor = [UIColor clearColor];
    
    [parentView addSubview:closeBtn];
    [parentView addSubview:menuBtn];
    
    // 针对ios 26的优化：不需要单独的背景色液态玻璃效果更好
    if (@available(iOS 26, *)) {
    } else {
        [closeBtn setBackgroundColor:RGBACOLOR(255,255,255, 26)];
        [menuBtn setBackgroundColor:RGBACOLOR(255,255,255, 26)];
    }
    // 给按钮设置液态玻璃效果
    [BasicTool setClearGlassBgnConfig:closeBtn];
    [BasicTool setClearGlassBgnConfig:menuBtn];
}


#pragma mark UIColectionViewDelegate
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{        
    MSSBrowseCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MSSBrowserCell" forIndexPath:indexPath];
    if(cell)
    {
        MSSBrowseModel *browseItem = [_browseItemArray objectAtIndex:indexPath.row];
        // 还原初始缩放比例
        cell.zoomScrollView.frame = CGRectMake(0, 0, _screenWidth, _screenHeight);
        cell.zoomScrollView.zoomScale = 1.0f;
        // 将scrollview的contentSize还原成缩放前
        cell.zoomScrollView.contentSize = CGSizeMake(_screenWidth, _screenHeight);
        cell.zoomScrollView.zoomImageView.contentMode = browseItem.smallImageView.contentMode;
        cell.zoomScrollView.zoomImageView.clipsToBounds = browseItem.smallImageView.clipsToBounds;
        [cell.loadingView mss_setFrameInSuperViewCenterWithSize:CGSizeMake(30, 30)];
        CGRect bigImageRect = [_verticalBigRectArray[indexPath.row] CGRectValue];
        if(_currentOrientation != UIDeviceOrientationPortrait)
        {
            bigImageRect = [_horizontalBigRectArray[indexPath.row] CGRectValue];
        }
        [self loadBrowseImageWithBrowseItem:browseItem Cell:cell bigImageRect:bigImageRect];
        
        __weak __typeof(self)weakSelf = self;
        [cell tapClick:^(MSSBrowseCollectionViewCell *browseCell) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            [strongSelf tap:browseCell];
        }];
        [cell longPress:^(MSSBrowseCollectionViewCell *browseCell) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;

            // comment by JackJiang 20180630：加上此行，则查看本地图片时不出现保存图片等长按菜单
//            if([[SDImageCache sharedImageCache]diskImageExistsWithKey:browseItem.bigImageUrl])
            {
                [strongSelf longPress:browseCell];
            }
        }];
        // 设置保存图片按钮的block回调（add by JackJiang 20180630）
        [cell saveImage:^(MSSBrowseCollectionViewCell *browseCell) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;

            [strongSelf saveImage:browseCell];
        }];
    }
    return cell;
}

// 子类重写此方法
- (void)loadBrowseImageWithBrowseItem:(MSSBrowseModel *)browseItem Cell:(MSSBrowseCollectionViewCell *)cell bigImageRect:(CGRect)bigImageRect
{

}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return _browseItemArray.count;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake(_screenWidth + kBrowseSpace, _screenHeight);
}

#pragma mark UIScrollViewDeletate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if(!_isRotate)
    {
        _currentIndex = scrollView.contentOffset.x / (_screenWidth + kBrowseSpace);
        _countLabel.text = [NSString stringWithFormat:@"%ld/%ld",(long)_currentIndex + 1,(long)_browseItemArray.count];
    }
    _isRotate = NO;
}

#pragma mark Tap Method
- (void)tap:(MSSBrowseCollectionViewCell *)browseCell
{
    // 移除通知
    [[NSNotificationCenter defaultCenter]removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    
    // 动画结束前不可点击
    _collectionView.userInteractionEnabled = NO;
    // 显示状态栏
    [self setNeedsStatusBarAppearanceUpdate];
    // 停止加载
    NSArray *cellArray = _collectionView.visibleCells;
    for (MSSBrowseCollectionViewCell *cell in cellArray)
    {
        [cell.loadingView stopAnimation];
    }
    [_countLabel removeFromSuperview];
    _countLabel = nil;
    
    NSIndexPath *indexPath = [_collectionView indexPathForCell:browseCell];
    browseCell.zoomScrollView.zoomScale = 1.0f;
    MSSBrowseModel *browseItem = _browseItemArray[indexPath.row];
    /*
     建议小图列表的collectionView尽量不要复用，因为当小图的列表collectionview复用时，传进来的BrowseItem数组只有当前显示cell的smallImageView，在当前屏幕外的cell上的小图由于复用关系实际是没有的，所以只能有简单的渐变动画
     */
    if(browseItem.smallImageView)
    {
        // ★ 有缩略图：背景先变透明，再动画回缩
        if(_snapshotView)
        {
            _snapshotView.hidden = NO;
        }
        else
        {
            self.view.backgroundColor = [UIColor clearColor];
        }
        _collectionView.backgroundColor = [UIColor clearColor];
        
        CGRect rect = [self getFrameInWindow:browseItem.smallImageView];
        CGAffineTransform transform = CGAffineTransformMakeRotation(0);
        if(_currentOrientation == UIDeviceOrientationLandscapeLeft)
        {
            transform = CGAffineTransformMakeRotation(- M_PI / 2);
            rect = CGRectMake(rect.origin.y, MSS_SCREEN_WIDTH - rect.size.width - rect.origin.x, rect.size.height, rect.size.width);
        }
        else if(_currentOrientation == UIDeviceOrientationLandscapeRight)
        {
            transform = CGAffineTransformMakeRotation(M_PI / 2);
            rect = CGRectMake(MSS_SCREEN_HEIGHT - rect.size.height - rect.origin.y, rect.origin.x, rect.size.height, rect.size.width);
        }
        [UIView animateWithDuration:0.3 animations:^{
            browseCell.zoomScrollView.zoomImageView.transform = transform;
            browseCell.zoomScrollView.zoomImageView.frame = rect;
        } completion:^(BOOL finished) {
            [self dismissViewControllerAnimated:NO completion:nil];
        }];
    }
    else
    {
        // ★ 无缩略图：背景色不瞬间变透明，整体一起淡出，避免颜色闪烁
        [UIView animateWithDuration:0.25 animations:^{
            self.view.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self dismissViewControllerAnimated:NO completion:nil];
        }];
    }
}

-(void)closeViewController
{
    [self closeViewController:0.3];
}

/**
 *  显示弹出菜单。
 */
-(void)showMenu
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:self.currentIndex inSection:0];
    MSSBrowseCollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
    if(cell) {
        [self longPress:cell];
    }
}

-(void)closeViewController:(NSTimeInterval)animationsDudation
{
    [UIView animateWithDuration:animationsDudation animations:^{// 0.1
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:^{
            
        }];
    }];
}

- (void)longPress:(MSSBrowseCollectionViewCell *)browseCell
{
    //**** 以下是v7.0前的原版弹出菜单代码
//    [_browseActionSheet removeFromSuperview];
//    _browseActionSheet = nil;
    __weak __typeof(self)weakSelf = self;
//    _browseActionSheet = [[MSSBrowseActionSheet alloc]initWithTitleArray:@[@"保存图片",@"复制图片地址"] cancelButtonTitle:@"取消" didSelectedBlock:^(NSInteger index) {
//        __strong __typeof(weakSelf)strongSelf = weakSelf;
//        [strongSelf browseActionSheetDidSelectedAtIndex:index currentCell:browseCell];
//    }];
//    [_browseActionSheet showInView:_bgView];
    
    //**** 以下是v7.0及以后的原版弹出菜单代码
    //### 弹出菜单功能事件处理block
    LPActionSheetBlock moreActionSheetHandler = ^(LPActionSheet *actionSheet, NSInteger index) {
        // 点击的是“保存图片"
        if(index == 1){
//            [weakSelf doReport];
            [weakSelf browseActionSheetDidSelectedAtIndex:index-1 currentCell:browseCell];
        }
    };
    
    //### 仿微信的弹出菜单：用于显示标题栏右边的“更多”按钮对应功能
    [LPActionSheet showActionSheetWithTitle:nil
                          cancelButtonTitle:@"取消"
                     destructiveButtonTitle:nil
                          otherButtonTitles:@[@"保存图片"]
                                    handler:moreActionSheetHandler];
}

- (void)saveImage:(MSSBrowseCollectionViewCell *)browseCell
{
//    MSSBrowseModel *currentBwowseItem = _browseItemArray[_currentIndex];
    UIImageWriteToSavedPhotosAlbum(browseCell.zoomScrollView.zoomImageView.image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}


#pragma mark StatusBar Method
- (BOOL)prefersStatusBarHidden
{
    if(!_collectionView.userInteractionEnabled)
    {
        return NO;
    }
    return YES;
}

#pragma mark Orientation Method
- (void)deviceOrientationDidChange:(NSNotification *)notification
{
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    if(orientation == UIDeviceOrientationPortrait || orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight)
    {
        _isRotate = YES;
        _currentOrientation = orientation;
        if(_currentOrientation == UIDeviceOrientationPortrait)
        {
            _screenWidth = MSS_SCREEN_WIDTH;
            _screenHeight = MSS_SCREEN_HEIGHT;
            [UIView animateWithDuration:0.5 animations:^{
                _bgView.transform = CGAffineTransformMakeRotation(0);
            }];
        }
        else
        {
            _screenWidth = MSS_SCREEN_HEIGHT;
            _screenHeight = MSS_SCREEN_WIDTH;
            if(_currentOrientation == UIDeviceOrientationLandscapeLeft)
            {
                [UIView animateWithDuration:0.5 animations:^{
                    _bgView.transform = CGAffineTransformMakeRotation(M_PI / 2);
                }];
            }
            else
            {
                [UIView animateWithDuration:0.5 animations:^{
                    _bgView.transform = CGAffineTransformMakeRotation(- M_PI / 2);
                }];
            }
        }
        _bgView.frame = CGRectMake(0, 0, MSS_SCREEN_WIDTH, MSS_SCREEN_HEIGHT);
        _browseRemindView.frame = CGRectMake(0, 0, _screenWidth, _screenHeight);
        if(_browseActionSheet)
        {
            [_browseActionSheet updateFrame];
        }
        _countLabel.frame = CGRectMake(0, _screenHeight - 50, _screenWidth, 50);
        [_collectionView.collectionViewLayout invalidateLayout];
        _collectionView.frame = CGRectMake(0, 0, _screenWidth + kBrowseSpace, _screenHeight);
        _collectionView.contentOffset = CGPointMake((_screenWidth + kBrowseSpace) * _currentIndex, 0);
        [_collectionView reloadData];
    }
}

#pragma mark MSSActionSheetClick
- (void)browseActionSheetDidSelectedAtIndex:(NSInteger)index currentCell:(MSSBrowseCollectionViewCell *)currentCell
{    // 保存图片
    if(index == 0)
    {
//     UIImageWriteToSavedPhotosAlbum(currentCell.zoomScrollView.zoomImageView.image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
        [self saveImage:currentCell];
    }
    // 复制图片地址
    else if(index == 1)
    {
        MSSBrowseModel *currentBwowseItem = _browseItemArray[_currentIndex];
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];

        // 不判断非nil则存在崩溃的风险哦
        if(currentBwowseItem.bigImageUrl != nil)
            pasteboard.string = currentBwowseItem.bigImageUrl;
        else
            pasteboard.string = @"[无图片地址]";

        [self showBrowseRemindViewWithText:@"复制图片地址成功"];
    }
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    NSString *text = nil;
    if(error)
    {
        text = @"保存失败";
        [self showBrowseRemindViewWithText:text];
    }
    else
    {
        text = @"保存成功";
        [BasicTool showUserDefintToast:text
                                  view:self.view
                                // Toast消失时的回调
                                atHide:^(void){
                                }];
    }
}

#pragma mark RemindView Method
- (void)showBrowseRemindViewWithText:(NSString *)text
{
    [_browseRemindView showRemindViewWithText:text];
    _bgView.userInteractionEnabled = NO;
    [self performSelector:@selector(hideRemindView) withObject:nil afterDelay:0.7];
}

- (void)hideRemindView
{
    [_browseRemindView hideRemindView];
    _bgView.userInteractionEnabled = YES;
}

@end
