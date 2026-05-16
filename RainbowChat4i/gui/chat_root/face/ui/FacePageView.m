//telegram @wz662

#import "FacePageView.h"
#import "FacePreviewView.h"

#import "IMClientManager.h"
#import "AppDelegate.h"

@interface FacePageView ()

@property (nonatomic, strong) FaceBoardConfig *config;

@property (nonatomic, strong) NSMutableArray<FaceItemView *> *faceItems;

@property (nonatomic, strong) UIButton *deleteBtn;

@property (nonatomic, strong) FacePreviewView *facePreview;

@end

@implementation FacePageView

- (instancetype)initWithConfig:(FaceBoardConfig * _Nonnull)config {
    if (self = [super init]) {
        self.config = config;
        self.backgroundColor = config.pageViewBackgroundColor;
        self.faceItems = [NSMutableArray array];
        // 初始化, 循环创建表情按钮(每页的按钮数量 = 行数 x 列数, 最后一个为删除按钮, 所以表情按钮数量要 -1<大表情就不需要-1了>)
        NSInteger btnCount = config.emojiLineCount * config.emojiColumnCount-1;
        for (NSUInteger i = 0; i < btnCount; i++) {
            FaceItemView *emojiItem = [[FaceItemView alloc] init];
            [emojiItem addTarget:self action:@selector(clickedEmojiItemView:)];
                       
            [_faceItems addObject:emojiItem];
            [self addSubview:emojiItem];
        }
        // 删除按钮
        self.deleteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.deleteBtn setImage:self.config.pageViewDeleteButtonImage forState:UIControlStateNormal];
        [self.deleteBtn setImage:self.config.pageViewDeleteButtonPressedImage forState:UIControlStateHighlighted];
        [self.deleteBtn addTarget:self action:@selector(clickedDeleteButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.deleteBtn];
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressPageView:)];
        longPress.minimumPressDuration = 0.25;
        [self addGestureRecognizer:longPress];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapPageView:)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)tapPageView:(UITapGestureRecognizer *)tap{

}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    NSInteger columnCount = self.config.emojiColumnCount;
    NSInteger lineCount = self.config.emojiLineCount;
    
    // 计算表情按钮宽度
    CGFloat width = (self.bounds.size.width - self.config.pageViewEdgeInsets.left - self.config.pageViewEdgeInsets.right - ((columnCount - 1) * self.config.pageViewMinColumnSpace)) / (CGFloat)columnCount;
    // 计算表情按钮高度
    CGFloat heigh = (self.bounds.size.height - self.config.pageViewEdgeInsets.top - self.config.pageViewEdgeInsets.bottom - ((lineCount - 1) * self.config.pageViewMinLineSpace)) / (CGFloat)lineCount;
    // 表情按钮为正方形, 所以取一个最小值作为宽高, 那么久需要重新计算行间距列间距
    CGFloat minSize = MIN(width, heigh);
    // 计算行间距
    CGFloat lineSpace = (self.bounds.size.height - self.config.pageViewEdgeInsets.top - self.config.pageViewEdgeInsets.bottom - minSize * lineCount) / (CGFloat)(lineCount + 1);
    // 计算列间距
    CGFloat columnSpace = (self.bounds.size.width - self.config.pageViewEdgeInsets.left - self.config.pageViewEdgeInsets.right - minSize * columnCount) / (CGFloat)(columnCount + 1);
    
    // 遍历设置表情按钮的frame
    for (int i = 0; i < self.faceItems.count; i ++) {
        NSInteger line = i / columnCount;   // 当前行数
        NSInteger column = i % columnCount; // 当前列数
        // 表情按钮的最小 x 和最小 y
        CGFloat minX = self.config.pageViewEdgeInsets.left + column * minSize + ((column + 1) * columnSpace);
        CGFloat minY = self.config.pageViewEdgeInsets.top + (line * minSize) + ((line + 1) * lineSpace);
        CGRect frame = CGRectMake(minX, minY, minSize, minSize);
        self.faceItems[i].frame = frame;
    }
    // 删除按钮
    self.deleteBtn.frame = CGRectMake(self.bounds.size.width - self.config.pageViewEdgeInsets.right - minSize - columnSpace, self.bounds.size.height - self.config.pageViewEdgeInsets.bottom - minSize - lineSpace, minSize, minSize);
}

// 点击表情
- (void)clickedEmojiItemView:(UITapGestureRecognizer *)tap {
    FaceItemView *emojiItemView = (FaceItemView *)tap.view;
    if (emojiItemView.emoji == nil) return;
    if (_delegate && [_delegate respondsToSelector:@selector(pageView:clickedEmojiWith:)]) {
        [_delegate pageView:self clickedEmojiWith:emojiItemView.emoji];
    }
}

// 点击删除
- (void)clickedDeleteButtonAction:(UIButton *)sender {
    if (_delegate && [_delegate respondsToSelector:@selector(pageView:clickedDeleteWith:)]) {
        [_delegate pageView:self clickedDeleteWith:sender];
    }
}

- (void)configFaceItemsWith:(NSArray<FaceMeta *> *)facesData pageIndex:(NSInteger)pageIndex {
    //一个页面的表情数组
    NSArray<FaceMeta *> *aPageEmojis = [self emojiItemsWith:facesData pageIndex:pageIndex];
    self.hidden = aPageEmojis.count == 0;
    for (int i = 0; i < self.faceItems.count; i ++) {
        FaceItemView *emojiItemView = self.faceItems[i];
        // 设置表情图片 当表情数量不满一整页的时候, 其余按钮图片置空
        FaceMeta *emoji = i < aPageEmojis.count ? aPageEmojis[i] : nil;
        [emojiItemView setEmoji:emoji];
    }
    [self setNeedsLayout];
}

// 获取表情包对应页码的模型数组
- (NSArray<FaceMeta *> *)emojiItemsWith:(NSArray *)facesData pageIndex:(NSInteger )pageIndex {
    if (!facesData || !facesData.count) {
        return nil;
    }
    NSInteger columnCount = self.config.emojiColumnCount;
    NSInteger lineCount = self.config.emojiLineCount;
    NSInteger emojiCountOfPage = columnCount * lineCount - 1;
    NSInteger countOffset = facesData.count % emojiCountOfPage == 0 ? 0 : 1;
    NSUInteger totalPage = facesData.count / emojiCountOfPage + countOffset;
    if (pageIndex >= totalPage || pageIndex < 0) {
        return nil;
    }
    BOOL isLastPage = (pageIndex == totalPage - 1 ? YES : NO);
    // 截取的初始位置
    NSUInteger beginIndex = pageIndex * emojiCountOfPage;
    // 截取长度
    NSUInteger length = isLastPage ? (facesData.count - pageIndex * emojiCountOfPage) : emojiCountOfPage;
    //一个页面的表情数组
    NSArray *aPageFaces = [facesData subarrayWithRange:NSMakeRange(beginIndex, length)];
    return aPageFaces;
}

- (void)longPressPageView:(UILongPressGestureRecognizer *)longPress {   
    FaceItemView *emojiItemView = nil;
    CGPoint point = [longPress locationInView:self];
    // 遍历当前页所有按钮, 找到手指所在的按钮
    for (FaceItemView *emojiItem in self.faceItems) {
        if (CGRectContainsPoint(emojiItem.frame, point)) {
            emojiItemView = emojiItem;
        }else {
            emojiItem.backgroundColor = UIColor.clearColor;
        }
    }
    
    if (longPress.state == UIGestureRecognizerStateFailed ||
        longPress.state == UIGestureRecognizerStateCancelled ||
        longPress.state == UIGestureRecognizerStateEnded ||
        emojiItemView.emoji == nil) {
        // hide preview
        self.facePreview.hidden = YES;
    }else {
        // show preview
        self.facePreview.hidden = NO;
        UIWindow *window = [[[UIApplication sharedApplication] windows] lastObject];
        // 先计算出相对于window的位置, 然后计算预览视图的frame
        CGRect rectOfWindow = [emojiItemView convertRect:emojiItemView.bounds toView:window];
        // 预览视图的宽度
        CGFloat preview_w = self.config.emojiPreviewSize.width;
        // 预览视图的高度
        CGFloat preview_h = self.config.emojiPreviewSize.height;
        // 预览视图的x
        CGFloat preview_x = CGRectGetMaxX(rectOfWindow) - preview_w + (preview_w - rectOfWindow.size.width) / 2.0;
        // 预览视图的y
        CGFloat preview_y = CGRectGetMaxY(rectOfWindow) - preview_h;

        CGRect frame = CGRectMake(preview_x, preview_y, preview_w, preview_h);
        // 将当前手指所在位置的表情模型给预览视图进行显示
        [self.facePreview setEmojiItemModel:emojiItemView.emoji];
        self.facePreview.frame = frame;

    }
}


- (FacePreviewView *)facePreview {
    if (!_facePreview) {
        _facePreview = [[FacePreviewView alloc] initWithConfig:self.config];
        UIWindow *window = [[[UIApplication sharedApplication] windows] lastObject];
        [window addSubview:_facePreview];
    }
    return _facePreview;
}


@end
