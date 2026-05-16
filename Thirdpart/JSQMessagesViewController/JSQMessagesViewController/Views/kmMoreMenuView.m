//telegram @wz662
//
//  kmMoreMenuView.m
//  JSQMessages
//
//  Created by Keye Myria on 10/7/15.
//  Copyright © 2015 Hexed Bits. All rights reserved.
//

#import "kmMoreMenuView.h"
#import "Masonry.h"


#define kmScreenWidth            [UIScreen mainScreen].bounds.size.width
#define kmScreenHeight           [UIScreen mainScreen].bounds.size.height

#define kmMenuPageControlHeight  22//30;

#define kmMoreMenuItemWidth      60
#define kmMoreMenuItemHeight     80
/** 更多菜单图标统一显示尺寸，使红包/转账与音视频等 SVG 图标视觉一致 */
#define kmMoreMenuIconDisplaySize 44
/** 红包、转账图标略小一号（群聊 10/11，单聊 12/13） */
#define kmMoreMenuIconDisplaySizeWallet 36
/** 收藏、红包等再缩小一档 */
#define kmMoreMenuIconDisplaySizeCompact 30

#define kmShareMenuPerRowItemCount ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 10 : 4)
#define kmShareMenuPerColumn     2


@interface kmMoreMenuItemView : UIView

@property (nonatomic, weak) UIButton *menuItemButton;
@property (nonatomic, weak) UILabel *menuItemTitleLabel;

@end

@implementation kmMoreMenuItemView

- (void)configureView {
	if (!_menuItemButton) {
		UIButton *miButton = [UIButton buttonWithType:(UIButtonTypeCustom)];
		miButton.frame = CGRectMake(0, 0, kmMoreMenuItemWidth, kmMoreMenuItemWidth);
        
//		miButton.backgroundColor = [UIColor clearColor];
		UIImage *iNormal = [BasicTool imageWithColor:[UIColor whiteColor] withSize:CGSizeMake(kmMoreMenuItemWidth, kmMoreMenuItemWidth) cornerRadius:12];
        UIImage *iSelected = [BasicTool imageWithColor:HexColor(0xF0F0F0) withSize:CGSizeMake(kmMoreMenuItemWidth, kmMoreMenuItemWidth) cornerRadius:12];
        [miButton setBackgroundImage:iNormal forState: UIControlStateNormal];
        [miButton setBackgroundImage:iSelected forState: UIControlStateHighlighted];
        [BasicTool setBorder:miButton width:0 color:HexColor(0xE5E5E5) radius:12];
        
		[self addSubview:miButton];
		self.menuItemButton = miButton;
        
//        [BasicTool setBorder:miButton width:1.0f color:[UIColor redColor] radius:10.0f];// TODO: !!!!!!
	}
	
	if (!_menuItemTitleLabel) {
        // 文字跟图标的问距
        int GAP = 7.0f;
        
//		UILabel *miLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.menuItemButton.frame), kmMoreMenuItemWidth, kmMoreMenuItemHeight - kmMoreMenuItemWidth)];
        UILabel *miLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.menuItemButton.frame)+GAP, kmMoreMenuItemWidth, kmMoreMenuItemHeight - kmMoreMenuItemWidth - GAP)];
        miLabel.backgroundColor = [UIColor clearColor];
        miLabel.textColor = RGBCOLOR(122, 126, 129);
		miLabel.font = [UIFont systemFontOfSize:12];
        miLabel.textColor = HexColor(0x636363);
		miLabel.textAlignment = NSTextAlignmentCenter;
		[self addSubview:miLabel];
		self.menuItemTitleLabel = miLabel;
	}
}

- (void)awakeFromNib {
    [super awakeFromNib];
	[self configureView];
}

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		[self configureView];
	}
	return self;
}

@end


@interface kmMoreMenuView ()<UIScrollViewDelegate>

@property (nonatomic, weak) UIScrollView *menuScrollView;
@property (nonatomic, weak) UIPageControl *menuPageControl;

@end


@implementation kmMoreMenuView

- (void)menuItemButtonAction:(UIButton*)sender {
	if ([self.delegate respondsToSelector:@selector(didSelecteMoreMenuItem:atIndex:)]) {
		NSInteger index = sender.tag;
		if (index < self.shareMenuItems.count) {
			[self.delegate didSelecteMoreMenuItem:[self.shareMenuItems objectAtIndex:index] atIndex:index];
		}
	}
}

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		[self configureView];
	}
	return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
	[self configureView];
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
	if (newSuperview) {
		[self reloadData];
	}
}

- (void)configureView {
	self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	if (!_menuScrollView) {
		CGRect frame = CGRectMake(0, 0,
                                  [self getSelfWidth],
								  [self getSelfHeight] - kmMenuPageControlHeight);
		UIScrollView *mscrollview = [[UIScrollView alloc] initWithFrame:frame];
		mscrollview.delegate = self;
		mscrollview.canCancelContentTouches = NO;
		mscrollview.delaysContentTouches = YES;
		mscrollview.showsHorizontalScrollIndicator = NO;
		mscrollview.showsVerticalScrollIndicator = NO;
		[mscrollview setScrollsToTop:NO];
		mscrollview.pagingEnabled = YES;
		
		[self addSubview:mscrollview];
		self.menuScrollView = mscrollview;
	}
	
	if (!_menuPageControl) {
		CGRect frame = CGRectMake(0, CGRectGetMaxY(self.menuScrollView.frame)
                                  // [注意]：by 20180303 Jack Jiang，UIPageControl的宽度出现一个奇怪的问题，那就是明
                                  //        明在此强设了它的宽度为屏幕宽(比如320)，而在最终显示时会诡异的变为265（一个很奇
                                  //        怪的值），可以肯定的是代码中除此之外不会对此宽度再做任何更改。
                                  // [原因]：经过查找资料，据说是苹果在此控件被后做过什么（但JackJiang没有找到准确地官方说明），
                                  //        但在CocoaChina论坛中有人反应UIPageControl的宽度使用它的当前区域宽度作为它的宽度
                                  //        (即本代码中使用它的父控件宽度CGRectGetWidth(self.bounds))，果然解决问题，实测
                                  //         在SE和iPhone 8Plus上都正常，问题解决！！
                                  , CGRectGetWidth(self.bounds)//[self getSelfWidth]
                                  , kmMenuPageControlHeight);
		UIPageControl *mpc = [[UIPageControl alloc] initWithFrame:frame];
        mpc.backgroundColor = self.backgroundColor;
        mpc.currentPageIndicatorTintColor = HexColor(0x7a7b7b);//RGBCOLOR(133, 142, 152);
        mpc.pageIndicatorTintColor = HexColor(0xdededd);//RGBCOLOR(190, 195, 200);
        mpc.hidesForSinglePage = YES;
		mpc.defersCurrentPageDisplay = YES;

		[self addSubview:mpc];
		self.menuPageControl = mpc;
	}
}

/** 将图标缩放到统一尺寸，保证红包/转账与音视频等图标在更多菜单中展示一致 */
+ (UIImage *)km_resizeMenuIcon:(UIImage *)img size:(CGFloat)size {
	if (!img || size <= 0) { return img; }
	CGSize targetSize = CGSizeMake(size, size);
	CGFloat w = img.size.width, h = img.size.height;
	if (w <= 0 || h <= 0) { return img; }
	CGFloat scale = MIN(size / w, size / h);
	if (scale >= 1.0 && w <= size && h <= size) { return img; }
	CGSize drawSize = CGSizeMake(w * scale, h * scale);
	CGRect drawRect = CGRectMake((size - drawSize.width) / 2, (size - drawSize.height) / 2, drawSize.width, drawSize.height);
	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize];
	UIImage *result = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
		[img drawInRect:drawRect];
	}];
	return result ?: img;
}

- (void)setShareMenuItems:(NSArray *)shareMenuItems {
	_shareMenuItems = shareMenuItems;
	if (shareMenuItems) {
		[self reloadData];
	}
}

- (void)reloadData {
	if (!_shareMenuItems.count) { return; }
	
	[[self.menuScrollView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	CGFloat scw = [self getSelfWidth];
	CGFloat paddingX = (scw - kmMoreMenuItemWidth * kmShareMenuPerRowItemCount) / (kmShareMenuPerRowItemCount + 1);
    CGFloat paddingY = 13;//(scw > 320) ? 13 : 10;
	
	for (kmMoreMenuItem *anItem in self.shareMenuItems) {
		NSInteger index = [self.shareMenuItems indexOfObject:anItem];
		NSInteger page = index / (kmShareMenuPerRowItemCount * kmShareMenuPerColumn);
		CGRect miframe = [self getFrameWithPerRowItemCount:kmShareMenuPerRowItemCount
														perColumItemCount:kmShareMenuPerColumn
																itemWidth:kmMoreMenuItemWidth
															   itemHeight:kmMoreMenuItemHeight
																 paddingX:paddingX
																 paddingY:paddingY
																  atIndex:index
																   onPage:page];
		
		kmMoreMenuItemView *mmItemView = [[kmMoreMenuItemView alloc] initWithFrame:miframe];
		mmItemView.menuItemButton.tag = index;
		[mmItemView.menuItemButton addTarget:self action:@selector(menuItemButtonAction:) forControlEvents:(UIControlEventTouchUpInside)];
        
//        // TODO: test!!!!!!!!!!!!
//        UIImage *iNormal = [BasicTool imageWithColor:HexColor(0x353535) withSize:CGSizeMake(26, 26) cornerRadius:3];
//        [mmItemView.menuItemButton setImage:iNormal forState:(UIControlStateNormal)];
        
		CGFloat iconSize = kmMoreMenuIconDisplaySize;
		if (anItem.usesCompactMenuIcon) {
			iconSize = kmMoreMenuIconDisplaySizeCompact;
		} else if (anItem.usesWalletStyleIcon) {
			iconSize = kmMoreMenuIconDisplaySizeWallet;
		}
		UIImage *normalImg = [[self class] km_resizeMenuIcon:anItem.normalIconImage size:iconSize];
		UIImage *highlightImg = [[self class] km_resizeMenuIcon:anItem.highlightIconImage size:iconSize];
		[mmItemView.menuItemButton setImage:normalImg forState:(UIControlStateNormal)];
		[mmItemView.menuItemButton setImage:highlightImg forState:(UIControlStateHighlighted)];
		mmItemView.menuItemTitleLabel.text = anItem.title;

		[self.menuScrollView addSubview:mmItemView];
	}
	
	self.menuPageControl.numberOfPages = (self.shareMenuItems.count / (kmShareMenuPerRowItemCount * 2) + (self.shareMenuItems.count % (kmShareMenuPerRowItemCount * 2) ? 1 : 0));
	[self.menuScrollView setContentSize:CGSizeMake(self.menuPageControl.numberOfPages * [self getSelfWidth], CGRectGetHeight(self.menuScrollView.bounds))];
}

/**
 * 【说明】：原本代码中都是将 CGRectGetWidth(self.bounds) 作为屏幕宽度的，但比如本类在RainbowChat里使用时是通过约束
 * 自动拉伸为整个屏幕宽度，那么带来一个问题就是在大一点的屏幕时此时使用的宽度会有问题，因为AutoLayout的约束是在
 * viewWillAppear之后才会生效，而不是在viewDidLoad之后。而通常UI的初始化包括RainbowChat中使用本类时也是在viewDidLoad
 * 中进行的初始化，那就导致了此时读取的控制宽度还没有通过约束更新了屏幕宽度了！
 *
 * 【解决办法】：如果你的控制宽度是通过约束来自动拉伸为屏幕宽度，则要想拿到的控制宽度是正确的（拉伸完成后的结果），就只能在viewWillAppear
 * 或之后使用。或者像本类中一样，因为本类使用时通常都会是填满屏幕宽度，干脃简单地使用屏幕绝对宽度作为本控制的最终宽度了！
 */
- (CGFloat)getSelfWidth
{
//  return CGRectGetWidth(self.bounds);
    return kmScreenWidth;
}

- (CGFloat)getSelfHeight
{
    return CGRectGetHeight(self.bounds);
}

- (void)dealloc {
	self.shareMenuItems = nil;
	self.menuScrollView.delegate = nil;
	self.menuScrollView = nil;
	self.menuPageControl = nil;
}

/**
 *  通过目标的参数，获取一个grid布局
 *
 *  @param perRowItemCount   每行有多少列
 *  @param perColumItemCount 每列有多少行
 *  @param itemWidth         gridItem的宽度
 *  @param itemHeight        gridItem的高度
 *  @param paddingX          gridItem之间的X轴间隔
 *  @param paddingY          gridItem之间的Y轴间隔
 *  @param index             某个gridItem所在的index序号
 *  @param page              某个gridItem所在的页码
 *
 *  @return 返回一个已经处理好的gridItem frame
 */
- (CGRect)getFrameWithPerRowItemCount:(NSInteger)perRowItemCount
					perColumItemCount:(NSInteger)perColumItemCount
							itemWidth:(CGFloat)itemWidth
						   itemHeight:(NSInteger)itemHeight
							 paddingX:(CGFloat)paddingX
							 paddingY:(CGFloat)paddingY
							  atIndex:(NSInteger)index
							   onPage:(NSInteger)page {
	CGRect itemFrame =
	CGRectMake((index % perRowItemCount) * (itemWidth + paddingX) + paddingX + (page * [self getSelfWidth]),
			   ((index / perRowItemCount) - perColumItemCount * page) * (itemHeight + paddingY) + paddingY,
			   itemWidth,
			   itemHeight);
	return itemFrame;
}


#pragma mark - UIScrollView delegate

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	CGFloat pageWidth = CGRectGetWidth(scrollView.bounds);
	NSInteger currentPage = floor((scrollView.contentOffset.x - pageWidth/2)/pageWidth) + 1;
	[self.menuPageControl setCurrentPage:currentPage];
}

@end
