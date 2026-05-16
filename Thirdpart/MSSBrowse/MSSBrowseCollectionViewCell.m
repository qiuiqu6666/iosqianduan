//telegram @wz662
//
//  MSSBrowseCollectionViewCell.m
//  MSSBrowse
//

#import "MSSBrowseCollectionViewCell.h"
#import "MSSBrowseDefine.h"

@interface MSSBrowseCollectionViewCell ()

@property (nonatomic,copy)MSSBrowseCollectionViewCellTapBlock tapBlock;
@property (nonatomic,copy)MSSBrowseCollectionViewCellLongPressBlock longPressBlock;
@property (nonatomic,copy)MSSBrowseCollectionViewCellSaveImageBlock saveImageBlock;

@end

@implementation MSSBrowseCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        [self createCell];
    }
    return self;
}

- (void)createCell
{
    _zoomScrollView = [[MSSBrowseZoomScrollView alloc]init];
    __weak __typeof(self)weakSelf = self;
    [_zoomScrollView tapClick:^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        strongSelf.tapBlock(strongSelf);
    }];
    [self.contentView addSubview:_zoomScrollView];
    
    _loadingView = [[MSSBrowseLoadingImageView alloc]init];
    [_zoomScrollView addSubview:_loadingView];
    
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longPressGesture:)];
//    [self.contentView addGestureRecognizer:longPressGesture];
    [_zoomScrollView addGestureRecognizer:longPressGesture];

    // 保存图片按钮（add by JackJiang 20180630）
    CGFloat safeAreaInsets_bottom = [BasicTool getSafeAreaInsets_bottom];// [[UIApplication sharedApplication] delegate].window.safeAreaInsets.bottom;
//    CGFloat saveImageBtnMargin = 20;
//    CGFloat saveImageBtnWidth = 30;
//    CGFloat saveImageBtnHeight = 30;
//    UIButton *saveImageBtn = [UIButton buttonWithType:UIButtonTypeSystem];
//    saveImageBtn.frame = CGRectMake(MSS_SCREEN_WIDTH - saveImageBtnWidth - saveImageBtnMargin
//                                , MSS_SCREEN_HEIGHT - saveImageBtnHeight - saveImageBtnMargin - safeAreaInsets_bottom
//                                , saveImageBtnWidth
//                                , saveImageBtnHeight);
//    [saveImageBtn setBackgroundImage:[UIImage imageNamed:@"mss_image_save_pics_btn_normal"] forState:UIControlStateNormal];
//    [saveImageBtn setBackgroundImage:[UIImage imageNamed:@"mss_image_save_pics_btn_press"] forState:UIControlStateHighlighted];
//    // 点击事件
//    [saveImageBtn addTarget:self action:@selector(saveImageClick:) forControlEvents:UIControlEventTouchUpInside];
//    // 添加到父组件中以便显示
//    [self.contentView addSubview:saveImageBtn];
    
    // 保存图片按钮（add by JackJiang 20250826）
    CGFloat saveImageBtnMargin = 25;
    CGFloat saveImageBtnWidth = 110;
    CGFloat saveImageBtnHeight = 36;
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(MSS_SCREEN_WIDTH - saveImageBtnWidth - saveImageBtnMargin
                                    , MSS_SCREEN_HEIGHT - saveImageBtnHeight - saveImageBtnMargin - safeAreaInsets_bottom
                                    , saveImageBtnWidth
                                    , saveImageBtnHeight);
    
    [closeBtn setImage:[UIImage imageNamed:@"mss_down"] forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeBtn setTitleColor:RGBACOLOR(255, 255, 255, 130) forState:UIControlStateHighlighted];
    [closeBtn setTitle:@"保存图片" forState:UIControlStateNormal];
    [closeBtn.titleLabel setFont:[UIFont systemFontOfSize:15.0]];
    [closeBtn setImageEdgeInsets:UIEdgeInsetsMake(0, 0, 0, 10)];
    // 水平居中
    closeBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
//    [closeBtn setBackgroundColor:RGBACOLOR(255,255,255, 26)];
    [closeBtn.layer setCornerRadius:18];// 10
    // 点击事件
    [closeBtn addTarget:self action:@selector(saveImageClick:) forControlEvents:UIControlEventTouchUpInside];
    // 添加到父组件中以便显示
    [self.contentView addSubview:closeBtn];
    
    // 针对ios 26的优化：不需要单独的背景色液态玻璃效果更好
    if (@available(iOS 26, *)) {
    } else {
        [closeBtn setBackgroundColor:RGBACOLOR(255,255,255, 26)];
    }
    // 给按钮设置液态玻璃效果
    [BasicTool setClearGlassBgnConfig:closeBtn];
}

- (void)tapClick:(MSSBrowseCollectionViewCellTapBlock)tapBlock
{
    _tapBlock = tapBlock;
}

- (void)longPress:(MSSBrowseCollectionViewCellLongPressBlock)longPressBlock
{
    _longPressBlock = longPressBlock;
}

- (void)saveImage:(MSSBrowseCollectionViewCellSaveImageBlock)saveImageBlock
{
    _saveImageBlock = saveImageBlock;
}

- (void)longPressGesture:(UILongPressGestureRecognizer *)gesture
{
    if(_longPressBlock)
    {
        if(gesture.state == UIGestureRecognizerStateBegan)
        {
            _longPressBlock(self);
        }
    }
}

// 保存图片按钮的点击事件处理
- (void)saveImageClick:(UIBarButtonItem *)sender
{
    if(_saveImageBlock)
    {
        _saveImageBlock(self);
    }
}

@end
