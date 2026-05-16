//telegram @wz662

#import "FaceBoardView.h"
#import "StickerManager.h"
#import "IMClientManager.h"
#import "UIImageView+WebCache.h"
#import "Default.h"

static NSString * const kStickerCellId = @"StickerCell";
static NSString * const kStickerAddCellId = @"StickerAddCell";

@interface FaceBoardView ()<FaceTabbarDelegate, FacePagesContainerDelegate, FacePageViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, strong) FaceBoardConfig *config;

@end

@implementation FaceBoardView

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame config:[FaceBoardConfig defaultConfig]];
}

- (instancetype)initWithFrame:(CGRect)frame config:(FaceBoardConfig * _Nonnull)config {
    return [self initWithFrame:frame config:config delegate:nil];
}

- (instancetype)initWithDlegate:(_Nonnull id <FaceBoardViewDelegate>)delegate {
    return [self initWithFrame:CGRectZero config:[FaceBoardConfig defaultConfig] delegate:delegate];
}

- (instancetype)initWithFrame:(CGRect)frame config:(FaceBoardConfig * _Nonnull)config delegate:(nullable id <FaceBoardViewDelegate>)delegate {
    if (self = [super initWithFrame:frame]) {
        self.config = config;
        self.delegate = delegate;
        [self addSubViews];
        [self initContentViewAndPageControl];
    }
    return self;
}

- (void)addSubViews {
    // 与原版输入栏/更多面板一致：灰底长条，无圆角卡片
    self.backgroundColor = UI_DEFAULT_CHAT_INPUT_BAR_BG;
    self.layer.cornerRadius = 0.f;
    self.layer.masksToBounds = YES;
    [self addSubview:self.tabbar];
    [self addSubview:self.pageControl];
    [self addSubview:self.contentView];
    [self addSubview:self.stickerCollectionView];
    
    // 默认显示 emoji 模式
    self.stickerCollectionView.hidden = YES;
}

- (void)initContentViewAndPageControl {
    NSArray<FaceMeta *> *faceData = [[[[IMClientManager sharedInstance]getFaceDataProvider]getFaceData]getDataList];
    NSInteger numberPages = [self numberPageOfFaces:faceData];
    self.pageControl.numberOfPages = numberPages;
    self.pageControl.currentPage = 0;
    [self.contentView setFacesWith:faceData totalPage:numberPages];
}

#pragma mark - FaceTabbarDelegate

// 点击发送
- (void)tabbar:(FaceTabbar *)tabbar clickedSendAction:(UIButton *)button {
    if (_delegate && [_delegate respondsToSelector:@selector(faceBoardView:clickedSendWith:)]) {
        [_delegate faceBoardView:self clickedSendWith:button];
    }
}

// 切换到 Emoji
- (void)tabbar:(FaceTabbar *)tabbar didSelectEmojiTab:(UIButton *)button {
    [self showEmojiMode];
}

// 切换到 Sticker
- (void)tabbar:(FaceTabbar *)tabbar didSelectStickerTab:(UIButton *)button {
    [self showStickerMode];
}

// 点击管理
- (void)tabbar:(FaceTabbar *)tabbar didClickManageAction:(UIButton *)button {
    if (_delegate && [_delegate respondsToSelector:@selector(faceBoardViewDidClickManage:)]) {
        [_delegate faceBoardViewDidClickManage:self];
    }
}

#pragma mark - 模式切换

- (void)showEmojiMode {
    self.contentView.hidden = NO;
    self.pageControl.hidden = NO;
    self.stickerCollectionView.hidden = YES;
}

- (void)showStickerMode {
    self.contentView.hidden = YES;
    self.pageControl.hidden = YES;
    self.stickerCollectionView.hidden = NO;
    
    // 如果尚未加载则从服务端刷新
    if (![StickerManager sharedInstance].loaded) {
        [[StickerManager sharedInstance] refreshStickersFromServer:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.stickerCollectionView reloadData];
            });
        }];
    } else {
        [self.stickerCollectionView reloadData];
    }
}

- (void)reloadStickerData {
    [[StickerManager sharedInstance] refreshStickersFromServer:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.stickerCollectionView reloadData];
        });
    }];
}

#pragma mark - FacePagesContainerViewDelegate

// 滚动pageView
- (void)contentView:(FacePagesContainer *)contentView didScrollViewToIndex:(NSInteger)index {
    
}

#pragma mark - FacePageViewDelegate

// 点击emoji表情
- (void)pageView:(FacePageView *)pageView clickedEmojiWith:(FaceMeta *)emoji{
    if (_delegate && [_delegate respondsToSelector:@selector(faceBoardView:clickedEmojiWith:)]) {
        [_delegate faceBoardView:self clickedEmojiWith:emoji];
    }
}

// 点击删除
- (void)pageView:(FacePageView *)pageView clickedDeleteWith:(UIButton *)button {
    if (_delegate && [_delegate respondsToSelector:@selector(faceBoardView:clickedDeleteWith:)]) {
        [_delegate faceBoardView:self clickedDeleteWith:button];
    }
}

#pragma mark - UICollectionView DataSource & Delegate (Sticker 网格)

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    // 表情列表 + 1 个"添加"按钮
    return [StickerManager sharedInstance].stickerList.count + 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSDictionary *> *stickers = [StickerManager sharedInstance].stickerList;
    
    if (indexPath.item == 0) {
        // 第一位："添加" Cell
        UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kStickerAddCellId forIndexPath:indexPath];
        
        for (UIView *sv in cell.contentView.subviews) {
            [sv removeFromSuperview];
        }
        
        UIImageView *addIcon = [[UIImageView alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 12, 12)];
        addIcon.contentMode = UIViewContentModeScaleAspectFit;
        addIcon.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        addIcon.image = [UIImage systemImageNamed:@"plus"];
        addIcon.tintColor = [UIColor grayColor];
        [cell.contentView addSubview:addIcon];
        
        cell.contentView.layer.borderWidth = 1;
        cell.contentView.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1.0].CGColor;
        cell.contentView.layer.cornerRadius = 6;
        
        return cell;
    } else {
        // 表情 Cell（index 1 起对应 stickerList[0]、stickerList[1]...）
        NSInteger stickerIndex = indexPath.item - 1;
        UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kStickerCellId forIndexPath:indexPath];
        
        // 清除旧内容
        for (UIView *sv in cell.contentView.subviews) {
            [sv removeFromSuperview];
        }
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 4, 4)];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageView.tag = 100;
        [cell.contentView addSubview:imageView];
        
        // 使用 sd_setImageWithURL 直接加载表情图片（最可靠的方式）
        NSDictionary *info = stickers[stickerIndex];
        NSString *fileName = [info objectForKey:@"file_name"];
        NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        NSString *urlStr = [[StickerManager sharedInstance] stickerDownloadURLForFileName:fileName userUid:uid];
        NSURL *imgURL = [NSURL URLWithString:urlStr];
        
        // NSLog(@"【FaceBoard】加载表情[%ld]: file_name=%@, url=%@", (long)indexPath.item, fileName, urlStr); // ★ 性能优化：移除热路径日志
        
        [imageView sd_setImageWithURL:imgURL
                     placeholderImage:nil
                              options:SDWebImageRetryFailed
                            completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
            if (image) {
                // NSLog(@"【FaceBoard】表情加载成功[%ld]: %@ (cacheType=%ld)", (long)stickerIndex, fileName, (long)cacheType); // ★ 性能优化
            } else {
                // NSLog(@"【FaceBoard】表情加载失败[%ld]: %@, error=%@", (long)stickerIndex, fileName, error); // ★ 性能优化
            }
        }];
        
        return cell;
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSDictionary *> *stickers = [StickerManager sharedInstance].stickerList;
    
    if (indexPath.item == 0) {
        // 点击第一位"添加" → 打开管理页
        if (_delegate && [_delegate respondsToSelector:@selector(faceBoardViewDidClickManage:)]) {
            [_delegate faceBoardViewDidClickManage:self];
        }
    } else {
        // 点击表情 → 发送（index 1 起对应 stickerList）
        NSInteger stickerIndex = indexPath.item - 1;
        if (stickerIndex < (NSInteger)stickers.count) {
            NSDictionary *info = stickers[stickerIndex];
            if (_delegate && [_delegate respondsToSelector:@selector(faceBoardView:clickedStickerWith:)]) {
                [_delegate faceBoardView:self clickedStickerWith:info];
            }
        }
    }
}

#pragma mark - pravite method

- (NSInteger)numberPageOfFaces:(NSArray<FaceMeta *> *)allFaces {
    NSInteger columnCount = self.config.emojiColumnCount;
    NSInteger lineCount = self.config.emojiLineCount;

    NSInteger countOffset = allFaces.count % (columnCount * lineCount - 1) == 0 ? 0 : 1;
    NSUInteger totalPage = allFaces.count / (columnCount * lineCount - 1) + countOffset;
    return totalPage;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.tabbar.frame = CGRectMake(0, self.bounds.size.height-self.config.tabBarHeigh, self.bounds.size.width, self.config.tabBarHeigh);
    self.pageControl.frame = CGRectMake(0
                                        , CGRectGetMinY(self.tabbar.frame)-self.config.pageControlHeigh - 10
                                        , self.bounds.size.width
                                        , self.config.pageControlHeigh);
    self.contentView.frame = CGRectMake(0, 0, self.bounds.size.width, CGRectGetMinY(self.pageControl.frame));
    
    // Sticker collection 占据 emoji 内容区域 + pageControl 区域
    self.stickerCollectionView.frame = CGRectMake(0, 0, self.bounds.size.width, CGRectGetMinY(self.tabbar.frame));
}

- (FaceTabbar *)tabbar {
    if (!_tabbar) {
        _tabbar = [[FaceTabbar alloc] initWithConfig:self.config];
        _tabbar.delegate = self;
    }
    return _tabbar;
}

- (UIPageControl *)pageControl {
    if (!_pageControl) {
        _pageControl = [[UIPageControl alloc] init];
        
        _pageControl.backgroundColor = [UIColor clearColor];  // 使用系统 inputView 背景
        
        _pageControl.pageIndicatorTintColor = self.config.pageIndicatorTintColor;
        _pageControl.currentPageIndicatorTintColor = self.config.currentPageIndicatorTintColor;
        _pageControl.hidesForSinglePage = YES;
        _pageControl.numberOfPages = [self numberPageOfFaces: [[[[IMClientManager sharedInstance]getFaceDataProvider]getFaceData]getDataList]];
    }
    return _pageControl;
}

- (FacePagesContainer *)contentView {
    if (!_contentView) {
        _contentView = [[FacePagesContainer alloc] initWithConfig:self.config];
        _contentView.leftPageView.delegate = self;
        _contentView.centerPageView.delegate = self;
        _contentView.rightPageView.delegate = self;
        _contentView.delegate = self;
    }
    return _contentView;
}

- (UICollectionView *)stickerCollectionView {
    if (!_stickerCollectionView) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.itemSize = CGSizeMake(60, 60);
        layout.minimumInteritemSpacing = 10;
        layout.minimumLineSpacing = 10;
        layout.sectionInset = UIEdgeInsetsMake(10, 15, 10, 15);
        
        _stickerCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        _stickerCollectionView.backgroundColor = [UIColor clearColor];  // 使用系统 inputView 背景
        _stickerCollectionView.delegate = self;
        _stickerCollectionView.dataSource = self;
        _stickerCollectionView.showsVerticalScrollIndicator = NO;
        
        [_stickerCollectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:kStickerCellId];
        [_stickerCollectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:kStickerAddCellId];
    }
    return _stickerCollectionView;
}

@end
