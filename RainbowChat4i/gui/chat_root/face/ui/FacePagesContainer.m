//telegram @wz662

#import "FacePagesContainer.h"

@interface FacePagesContainer ()<UIScrollViewDelegate>

@property (nonatomic, strong) FaceBoardConfig *config;

@property (nonatomic, strong) UIScrollView *scrollView;
// 表情模型数组
@property (nonatomic, strong) NSArray<FaceMeta *> *emojis;

@property (nonatomic, assign) NSInteger totalPage;
// 避免重复对pageView赋值, 导致性能问题
@property (nonatomic, assign) NSInteger pageFlag;
@end

@implementation FacePagesContainer

- (instancetype)initWithConfig:(FaceBoardConfig * _Nonnull)config {
    if (self = [super init]) {
        self.config = config;
        self.pageFlag = 0;
        [self addSubview:self.scrollView];
        [self.scrollView addSubview:self.leftPageView];
        [self.scrollView addSubview:self.centerPageView];
        [self.scrollView addSubview:self.rightPageView];
    }
    return self;
}

// 设置表情
- (void)setFacesWith:(NSArray<FaceMeta *> *)allFaceMetas totalPage:(NSInteger)totalPage {
    self.emojis = allFaceMetas;
    self.totalPage = totalPage;
    [self.scrollView setContentOffset:CGPointZero animated:NO];
    [self reSetPageViews];
    [self setNeedsLayout];
}

// 更新三个pageView位置
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (_delegate && [_delegate respondsToSelector:@selector(contentView:didScrollViewToIndex:)]) {
        NSInteger pageIndex = roundf(self.scrollView.contentOffset.x / self.bounds.size.width);
        [_delegate contentView:self didScrollViewToIndex:pageIndex];
    }
    // 当表情也小于等于两页的时候就不需要更新了
    if (self.totalPage <= 2) { return; }
    [self updatePagesView];
}

// 更新布局
- (void)layoutSubviews {
    [super layoutSubviews];
    self.scrollView.frame = self.bounds;
    _scrollView.contentSize = CGSizeMake(self.totalPage * self.bounds.size.width, self.bounds.size.height);
    CGFloat pageOffset = self.scrollView.contentOffset.x / self.bounds.size.width;
    [self layoutPageViewsWith:roundf(pageOffset)];
}

// 更新pageView位置以及内容向右滑动后, 将最右边的pageView放在最左边, 重新赋值, 向左滑动也一样>
- (void)updatePagesView {
    CGFloat pageOffset = self.scrollView.contentOffset.x / self.bounds.size.width;
    NSInteger page = roundf(pageOffset);
    if (page != self.pageFlag) {
        FacePageView *aView = nil;
        if (pageOffset > page) { // 向右滑动
            // 将最左边那页赋值过来
            [self.rightPageView configFaceItemsWith:_emojis pageIndex:page - 1];
            // 交换位置
            aView = self.rightPageView;
            self.rightPageView = self.centerPageView;
            self.centerPageView = self.leftPageView;
            self.leftPageView = aView;
        }else { // 向左滑动
            // 将最右边那页赋值过来
            [self.leftPageView configFaceItemsWith:_emojis pageIndex:page + 1];
            // 交换位置
            aView = self.leftPageView;
            self.leftPageView =  self.centerPageView;
            self.centerPageView = self.rightPageView;
            self.rightPageView = aView;
        }
        // 更新pageViews的frame
        [self layoutPageViewsWith:page];
    }
    self.pageFlag = page;
}

// 更新pageView的frame
- (void)layoutPageViewsWith:(NSInteger)page {
    self.leftPageView.frame = CGRectMake((page - 1) * self.bounds.size.width, 0, self.bounds.size.width, self.bounds.size.height);
    self.centerPageView.frame = CGRectMake(page * self.bounds.size.width, 0, self.bounds.size.width, self.bounds.size.height);
    self.rightPageView.frame = CGRectMake((page + 1) * self.bounds.size.width, 0, self.bounds.size.width, self.bounds.size.height);
}

// 重新pageView, 在点击表情包按钮的时候
- (void)reSetPageViews {
    [self.leftPageView configFaceItemsWith:_emojis pageIndex:-1];
    [self.centerPageView configFaceItemsWith:_emojis pageIndex:0];
    [self.rightPageView configFaceItemsWith:_emojis pageIndex:1];
}

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.pagingEnabled = YES;
        _scrollView.delegate = self;
    }
    return _scrollView;
}

- (FacePageView *)leftPageView {
    if (!_leftPageView) {
        _leftPageView = [[FacePageView alloc] initWithConfig:self.config];
        [_leftPageView configFaceItemsWith:_emojis pageIndex:-1];
    }
    return _leftPageView;
}

- (FacePageView *)centerPageView {
    if (!_centerPageView) {
        _centerPageView = [[FacePageView alloc] initWithConfig:self.config];
        [_centerPageView configFaceItemsWith:_emojis pageIndex:0];
    }
    return _centerPageView;
}

- (FacePageView *)rightPageView {
    if (!_rightPageView) {
        _rightPageView = [[FacePageView alloc] initWithConfig:self.config];
        [_rightPageView configFaceItemsWith:_emojis pageIndex:1];
    }
    return _rightPageView;
}

- (NSArray<FaceMeta *> *)emojis {
    if (!_emojis) {
        _emojis = [[[[IMClientManager sharedInstance]getFaceDataProvider]getFaceData]getDataList];
    }
    return _emojis;
}

- (NSInteger)totalPage {
    if (_totalPage == 0) {
        NSInteger columnCount = self.config.emojiColumnCount;
        NSInteger lineCount = self.config.emojiLineCount;

        NSInteger countOffset = self.emojis.count % (columnCount * lineCount - 1) == 0 ? 0 : 1;
        _totalPage = self.emojis.count / (columnCount * lineCount - 1) + countOffset;

    }
    return _totalPage;
}

@end
