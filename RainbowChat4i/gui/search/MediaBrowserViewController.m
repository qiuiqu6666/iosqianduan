//
//  MediaBrowserViewController.m
//  RainbowChat4i
//
//  图片与视频浏览器（分页加载 + 流畅优化）
//

#import "MediaBrowserViewController.h"
#import "MsgSummaryContentDTO.h"
#import "MsgDetailContentDTO.h"
#import "IMClientManager.h"
#import "SendImageHelper.h"
#import "MsgBodyRoot.h"
#import "FileMeta.h"
#import "ReceivedShortVideoHelper.h"
#import "MSSBrowseNetworkViewController.h"
#import "MSSBrowseModel.h"
#import "UnifiedMediaBrowserViewController.h"
#import "UIImageView+WebCache.h"
#import "UIView+WebCache.h"
#import "SDImageCache.h"
#import "SDWebImagePrefetcher.h"
#import "HttpRestHelper.h"
#import "FileDownloadHelper.h"
#import "RBConversationMsgSearchHelper.h"
#import "MyDataBase.h"
#import "ChatHistoryTable.h"

#define HexColor(hex) [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0 green:((hex >> 8) & 0xFF) / 255.0 blue:(hex & 0xFF) / 255.0 alpha:1.0]

static NSString *const kMediaCellId = @"MediaCell";
static const int kPageSize = 60;

/// 解析接口 1008-27-9 返回的 create_time（收藏时间），支持 "yyyy-MM-dd HH:mm" / "yyyy-MM-dd HH:mm:ss" 或时间戳
static NSDate *mediaDateFromFavoriteCreateTime(id createTime) {
    if (createTime == nil) return [NSDate date];
    if ([createTime isKindOfClass:[NSNumber class]]) {
        NSTimeInterval sec = [createTime doubleValue];
        if (sec > 1e10) sec /= 1000.0;
        return [NSDate dateWithTimeIntervalSince1970:sec];
    }
    if ([createTime isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)createTime;
        if (s.length == 0) return [NSDate date];
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        f.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        NSDate *d = [f dateFromString:s];
        if (!d) {
            f.dateFormat = @"yyyy-MM-dd HH:mm";
            d = [f dateFromString:s];
        }
        return d ?: [NSDate date];
    }
    return [NSDate date];
}
static NSString *mediaStringFromFavoriteItem(id value) {
    if (value == nil) return @"";
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [(NSNumber *)value stringValue];
    return @"";
}

#pragma mark - MediaGridCell（子视图只创建一次，复用时只更新内容）

@interface MediaGridCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *playIcon;
@property (nonatomic, copy) NSString *rb_thumbLoadToken;
@end

@implementation MediaGridCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _imageView = [[UIImageView alloc] initWithFrame:self.contentView.bounds];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.backgroundColor = HexColor(0xEEEEEE);
        [self.contentView addSubview:_imageView];
        
        _playIcon = [[UIImageView alloc] init];
        UIImage *playSF = [UIImage systemImageNamed:@"play.circle.fill"
                                      withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightRegular]];
        _playIcon.image = playSF;
        _playIcon.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
        _playIcon.translatesAutoresizingMaskIntoConstraints = NO;
        _playIcon.hidden = YES;
        [self.contentView addSubview:_playIcon];
        
        [NSLayoutConstraint activateConstraints:@[
            [_playIcon.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
            [_playIcon.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        ]];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.imageView sd_cancelCurrentImageLoad];
    self.rb_thumbLoadToken = nil;
    self.imageView.image = nil;
    self.playIcon.hidden = YES;
}

@end

#pragma mark - 加载中Footer

@interface MediaLoadingFooter : UICollectionReusableView
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation MediaLoadingFooter

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _spinner.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_spinner];
        [NSLayoutConstraint activateConstraints:@[
            [_spinner.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_spinner.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];
    }
    return self;
}

@end

#pragma mark - MediaBrowserViewController

@interface MediaBrowserViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching>

@property (nonatomic, assign) int chatType;
@property (nonatomic, copy)   NSString *dataId;

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UILabel *emptyLabel;

// 按月分组
@property (nonatomic, strong) NSMutableArray<NSString *> *sectionTitles;
@property (nonatomic, strong) NSMutableArray<NSMutableArray<MsgDetailContentDTO *> *> *sectionItems;

// 分页状态
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL hasMoreData;

@property (nonatomic, assign) int serverCurrentPage;
@property (nonatomic, assign) int currentOffset;

// 缓存 DateFormatter（避免每个 cell 创建）
@property (nonatomic, strong) NSDateFormatter *monthFormatter;

@end

@implementation MediaBrowserViewController

- (instancetype)initWithChatType:(int)chatType dataId:(NSString *)dataId
{
    self = [super init];
    if (self) {
        _chatType = chatType;
        _dataId = dataId;
        _serverCurrentPage = 1;
        _currentOffset = 0;
        _isLoading = NO;
        _hasMoreData = YES;
        _sectionTitles = [NSMutableArray array];
        _sectionItems = [NSMutableArray array];
        _monthFormatter = [[NSDateFormatter alloc] init];
        _monthFormatter.dateFormat = @"yyyy年M月";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self buildCollectionView];
    [self loadNextPage];
}

#pragma mark - UI

- (void)buildCollectionView
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 1;
    layout.minimumLineSpacing = 1;
    layout.sectionHeadersPinToVisibleBounds = YES;
    
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.prefetchDataSource = self;
    self.collectionView.backgroundColor = [UIColor whiteColor];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.collectionView registerClass:[MediaGridCell class] forCellWithReuseIdentifier:kMediaCellId];
    [self.collectionView registerClass:[UICollectionReusableView class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:@"SectionHeader"];
    [self.collectionView registerClass:[MediaLoadingFooter class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                   withReuseIdentifier:@"LoadingFooter"];
    [self.view addSubview:self.collectionView];
    
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无图片与视频";
    self.emptyLabel.textColor = HexColor(0x999999);
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.hidden = YES;
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.emptyLabel];
    
    UILayoutGuide *sa = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:sa.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

#pragma mark - 分页加载

- (void)loadNextPage
{
    if (self.isLoading || !self.hasMoreData) return;
    self.isLoading = YES;

    if (self.useServerFavoritesFor10001 && [self.dataId isEqualToString:@"10001"]) {
        NSString *userUid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        if (!userUid.length) {
            self.isLoading = NO;
            return;
        }
        int page = self.serverCurrentPage;
        __weak typeof(self) wself = self;
        [[HttpRestHelper sharedInstance] submitGetFavoritesFromServer:userUid
                                                                page:page
                                                            pageSize:kPageSize
                                                             favType:-1
                                                            complete:^(BOOL sucess, NSDictionary *result) {
            if (!sucess || ![result isKindOfClass:[NSDictionary class]]) {
                dispatch_async(dispatch_get_main_queue(), ^{ wself.hasMoreData = NO; wself.isLoading = NO; });
                return;
            }
            NSArray *list = result[@"list"];
            if (![list isKindOfClass:[NSArray class]]) list = @[];
            NSMutableArray<MsgDetailContentDTO *> *results = [NSMutableArray array];
            for (NSDictionary *item in list) {
                if (![item isKindOfClass:[NSDictionary class]]) continue;
                int favType = [item[@"fav_type"] intValue];
                if (favType != 1 && favType != 3) continue; // 1 图片 3 视频
                MsgDetailContentDTO *dto = [[MsgDetailContentDTO alloc] init];
                dto.text = mediaStringFromFavoriteItem(item[@"content"]);
                dto.date = mediaDateFromFavoriteCreateTime(item[@"create_time"]);
                dto.fp = mediaStringFromFavoriteItem(item[@"id"]);
                dto.msgType = (favType == 1) ? TM_TYPE_IMAGE : TM_TYPE_SHORTVIDEO;
                [results addObject:dto];
            }
            NSMutableArray<NSString *> *newKeys = [NSMutableArray array];
            NSMutableDictionary<NSString *, NSMutableArray *> *grouped = [NSMutableDictionary dictionary];
            NSDateFormatter *monthFmt = [[NSDateFormatter alloc] init];
            monthFmt.dateFormat = @"yyyy年M月";
            for (MsgDetailContentDTO *dto in results) {
                NSString *key = dto.date ? [monthFmt stringFromDate:dto.date] : @"未知日期";
                if (!grouped[key]) {
                    grouped[key] = [NSMutableArray array];
                    [newKeys addObject:key];
                }
                [grouped[key] addObject:dto];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) self = wself;
                if (!self) return;
                self.hasMoreData = (list.count >= kPageSize);
                self.serverCurrentPage = page + 1;
                NSMutableArray<NSIndexPath *> *insertPaths = [NSMutableArray array];
                NSMutableIndexSet *insertSections = [NSMutableIndexSet indexSet];
                for (NSString *key in newKeys) {
                    NSUInteger sectionIdx = [self.sectionTitles indexOfObject:key];
                    NSMutableArray *items = grouped[key];
                    if (sectionIdx == NSNotFound) {
                        sectionIdx = self.sectionTitles.count;
                        [self.sectionTitles addObject:key];
                        [self.sectionItems addObject:items];
                        [insertSections addIndex:sectionIdx];
                    } else {
                        NSInteger oldCount = self.sectionItems[sectionIdx].count;
                        [self.sectionItems[sectionIdx] addObjectsFromArray:items];
                        for (NSInteger i = 0; i < items.count; i++) {
                            [insertPaths addObject:[NSIndexPath indexPathForItem:(oldCount + i) inSection:sectionIdx]];
                        }
                    }
                }
                self.emptyLabel.hidden = (self.sectionTitles.count > 0);
                if (insertSections.count > 0 || insertPaths.count > 0) {
                    [self.collectionView performBatchUpdates:^{
                        if (insertSections.count > 0) [self.collectionView insertSections:insertSections];
                        if (insertPaths.count > 0) [self.collectionView insertItemsAtIndexPaths:insertPaths];
                    } completion:nil];
                } else if (self.sectionTitles.count == 0) {
                    self.emptyLabel.hidden = NO;
                }
                self.isLoading = NO;
            });
        } hudParentView:nil];
        return;
    }

    // 本地消息多媒体检索：分页读取 sqlite 的图片/短视频消息
    int offset = self.currentOffset;
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        __block NSMutableArray<MsgDetailContentDTO *> *results = nil;
        [[MyDataBase getDbQueue] inDatabase:^(FMDatabase *db) {
            NSArray<NSNumber *> *types = @[ @(TM_TYPE_IMAGE), @(TM_TYPE_SHORTVIDEO) ];
            results = [[MyDataBase sharedInstance].chatHistoryTable
                       searchMessagesByTypes:db
                       chatType:self.chatType
                       uidOrGid:self.dataId
                       msgTypes:types
                       limit:kPageSize
                       offset:offset];
        }];
        if (results == nil) results = [NSMutableArray array];

        NSMutableDictionary<NSString *, NSMutableArray<MsgDetailContentDTO *> *> *grouped = [NSMutableDictionary dictionary];
        NSMutableArray<NSString *> *newKeys = [NSMutableArray array];
        for (MsgDetailContentDTO *dto in results) {
            NSString *key = dto.date ? [wself.monthFormatter stringFromDate:dto.date] : @"未知时间";
            if (key.length == 0) key = @"未知时间";
            if (grouped[key] == nil) {
                grouped[key] = [NSMutableArray array];
                [newKeys addObject:key];
            }
            [grouped[key] addObject:dto];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) self = wself;
            if (!self) return;
            self.currentOffset = offset + (int)results.count;
            if (results.count < kPageSize) {
                self.hasMoreData = NO;
            }

            NSMutableArray<NSIndexPath *> *insertPaths = [NSMutableArray array];
            NSMutableIndexSet *insertSections = [NSMutableIndexSet indexSet];
            for (NSString *key in newKeys) {
                NSUInteger sectionIdx = [self.sectionTitles indexOfObject:key];
                NSMutableArray *items = grouped[key];
                if (sectionIdx == NSNotFound) {
                    sectionIdx = self.sectionTitles.count;
                    [self.sectionTitles addObject:key];
                    [self.sectionItems addObject:[items mutableCopy]];
                    [insertSections addIndex:sectionIdx];
                } else {
                    NSInteger oldCount = [self.sectionItems[sectionIdx] count];
                    [self.sectionItems[sectionIdx] addObjectsFromArray:items];
                    for (NSInteger i = 0; i < (NSInteger)items.count; i++) {
                        [insertPaths addObject:[NSIndexPath indexPathForItem:(oldCount + i) inSection:sectionIdx]];
                    }
                }
            }
            self.emptyLabel.hidden = (self.sectionTitles.count > 0);
            if (insertSections.count > 0 || insertPaths.count > 0) {
                [self.collectionView performBatchUpdates:^{
                    if (insertSections.count > 0) [self.collectionView insertSections:insertSections];
                    if (insertPaths.count > 0) [self.collectionView insertItemsAtIndexPaths:insertPaths];
                } completion:nil];
            } else if (self.sectionTitles.count == 0) {
                self.emptyLabel.hidden = NO;
                [self.collectionView reloadData];
            }
            self.isLoading = NO;
        });
    });
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return self.sectionTitles.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.sectionItems[section].count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    MediaGridCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kMediaCellId forIndexPath:indexPath];
    
    MsgDetailContentDTO *dto = self.sectionItems[indexPath.section][indexPath.item];
    
    if (dto.msgType == TM_TYPE_IMAGE) {
        cell.playIcon.hidden = YES;
        NSString *previewName = [NSString stringWithFormat:@"pv_%@", dto.text ?: @""];
        NSString *url = [SendImageHelper getImageDownloadURL:previewName dump:NO];
        [cell.imageView sd_setImageWithURL:[NSURL URLWithString:url]
                          placeholderImage:nil
                                   options:SDWebImageRetryFailed | SDWebImageScaleDownLargeImages];
    }
    else if (dto.msgType == TM_TYPE_SHORTVIDEO) {
        cell.playIcon.hidden = NO;
        NSString *jsonUse = RBNormalizeFileMetaJSONStringForHistory(dto.text);
        if (jsonUse.length == 0) jsonUse = dto.text ?: @"";
        FileMeta *meta = [FileMeta fromJSON:jsonUse];
        if (meta.fileName.length > 0 && meta.fileMd5.length > 0) {
            NSString *thumbName = [ReceivedShortVideoHelper constructShortVideoThumbName_localSaved:meta.fileName];
            NSString *url = [ReceivedShortVideoHelper getShortVideoThumbDownloadURL:thumbName videofileMd5:meta.fileMd5];
            NSString *token = [NSString stringWithFormat:@"%ld-%ld-%@", (long)indexPath.section, (long)indexPath.item, url ?: @""];
            cell.rb_thumbLoadToken = token;
            cell.imageView.image = [UIImage imageNamed:@"default_short_video_thumb"];
            __weak MediaGridCell *weakCell = cell;
            [FileDownloadHelper loadChattingShortVideoPreviewImgWithURL:url logTag:@"媒体相册-短视频缩略图" complete:^(BOOL sucess, UIImage *imageDlownload) {
                if (!weakCell || ![weakCell.rb_thumbLoadToken isEqualToString:token]) return;
                if (sucess && imageDlownload != nil)
                    weakCell.imageView.image = imageDlownload;
            }];
        }
    }
    
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        UICollectionReusableView *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                             withReuseIdentifier:@"SectionHeader"
                                                                                    forIndexPath:indexPath];
        // 复用标签而不是每次重建
        UILabel *label = [header viewWithTag:1001];
        if (!label) {
            for (UIView *sub in header.subviews) [sub removeFromSuperview];
            header.backgroundColor = [UIColor whiteColor];
            label = [[UILabel alloc] init];
            label.tag = 1001;
            label.font = [UIFont boldSystemFontOfSize:14];
            label.textColor = HexColor(0x666666);
            label.translatesAutoresizingMaskIntoConstraints = NO;
            [header addSubview:label];
            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:8],
                [label.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
            ]];
        }
        label.text = self.sectionTitles[indexPath.section];
        return header;
    }
    else {
        // Footer（加载指示器）
        MediaLoadingFooter *footer = [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                                                       withReuseIdentifier:@"LoadingFooter"
                                                                              forIndexPath:indexPath];
        if (self.hasMoreData) {
            [footer.spinner startAnimating];
        } else {
            [footer.spinner stopAnimating];
        }
        return footer;
    }
}

#pragma mark - UICollectionViewDataSourcePrefetching（预加载）

- (void)collectionView:(UICollectionView *)collectionView prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    for (NSIndexPath *ip in indexPaths) {
        if (ip.section >= (NSInteger)self.sectionItems.count) continue;
        NSArray *items = self.sectionItems[ip.section];
        if (ip.item >= (NSInteger)items.count) continue;
        
        MsgDetailContentDTO *dto = items[ip.item];
        NSString *url = nil;
        if (dto.msgType == TM_TYPE_IMAGE) {
            NSString *previewName = [NSString stringWithFormat:@"pv_%@", dto.text ?: @""];
            url = [SendImageHelper getImageDownloadURL:previewName dump:NO];
        } else if (dto.msgType == TM_TYPE_SHORTVIDEO) {
            // 短视频缩略图请求需 Authorization，SDWebImagePrefetcher 无法附带，略过预取（滑到时 cell 内加载）
            continue;
        }
        if (url) {
            NSURL *nsurl = [NSURL URLWithString:url];
            if (nsurl) [urls addObject:nsurl];
        }
    }
    
    // SDWebImage 预加载列表预览（pv_）
    if (urls.count > 0) {
        [[SDWebImagePrefetcher sharedImagePrefetcher] prefetchURLs:urls];
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat side = (CGRectGetWidth(self.view.bounds) - 3) / 4.0;
    return CGSizeMake(side, side);
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
referenceSizeForHeaderInSection:(NSInteger)section
{
    return CGSizeMake(CGRectGetWidth(self.view.bounds), 32);
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
referenceSizeForFooterInSection:(NSInteger)section
{
    // 只在最后一个 section 显示 footer
    if (section == (NSInteger)self.sectionTitles.count - 1 && self.hasMoreData) {
        return CGSizeMake(CGRectGetWidth(self.view.bounds), 44);
    }
    return CGSizeZero;
}

#pragma mark - UIScrollViewDelegate（上拉加载更多）

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!self.hasMoreData || self.isLoading) return;
    
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentH = scrollView.contentSize.height;
    CGFloat frameH = scrollView.frame.size.height;
    
    if (contentH > 0 && offsetY > contentH - frameH - 300) {
        [self loadNextPage];
    }
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // ★ 收集所有已加载的图片和视频，构建统一媒体数据数组
    NSMutableArray<NSDictionary *> *mediaDataArray = [NSMutableArray array];
    NSMutableArray<MSSBrowseModel *> *browseItems = [NSMutableArray array];
    NSInteger tappedMediaIndex = 0;
    
    for (NSInteger s = 0; s < (NSInteger)self.sectionItems.count; s++) {
        NSArray<MsgDetailContentDTO *> *items = self.sectionItems[s];
        for (NSInteger r = 0; r < (NSInteger)items.count; r++) {
            MsgDetailContentDTO *dto = items[r];
            
            if (dto.msgType == TM_TYPE_IMAGE) {
                NSString *fullUrl = [SendImageHelper getImageDownloadURL:dto.text dump:NO];
                if (fullUrl.length == 0) continue;
                
                NSMutableDictionary *item = [NSMutableDictionary dictionary];
                item[@"type"]     = @(TM_TYPE_IMAGE);
                item[@"imageUrl"] = fullUrl;
                [mediaDataArray addObject:item];
                
                MSSBrowseModel *model = [[MSSBrowseModel alloc] init];
                model.bigImageUrl = fullUrl;
                [browseItems addObject:model];
                
                // 匹配当前点击的 item
                if (s == indexPath.section && r == indexPath.item) {
                    tappedMediaIndex = mediaDataArray.count - 1;
                }
            }
            else if (dto.msgType == TM_TYPE_SHORTVIDEO) {
                NSString *jsonUse = RBNormalizeFileMetaJSONStringForHistory(dto.text);
                if (jsonUse.length == 0) jsonUse = dto.text ?: @"";
                FileMeta *meta = [FileMeta fromJSON:jsonUse];
                if (meta == nil || meta.fileName == nil) continue;
                
                NSString *videoUrl = [ReceivedShortVideoHelper getShortVideoDownloadURL:meta.fileName md5:meta.fileMd5];
                NSString *thumbName = [ReceivedShortVideoHelper constructShortVideoThumbName_localSaved:meta.fileName];
                NSString *thumbUrl = [ReceivedShortVideoHelper getShortVideoThumbDownloadURL:thumbName videofileMd5:meta.fileMd5];
                
                NSMutableDictionary *item = [NSMutableDictionary dictionary];
                item[@"type"]     = @(TM_TYPE_SHORTVIDEO);
                item[@"videoUrl"] = (videoUrl ?: @"");
                item[@"imageUrl"] = (thumbUrl ?: @"");
                item[@"fileMeta"] = meta;
                [mediaDataArray addObject:item];
                
                MSSBrowseModel *model = [[MSSBrowseModel alloc] init];
                model.bigImageUrl = thumbUrl;
                [browseItems addObject:model];
                
                if (s == indexPath.section && r == indexPath.item) {
                    tappedMediaIndex = mediaDataArray.count - 1;
                }
            }
        }
    }
    
    if (mediaDataArray.count == 0) return;
    
    // ★ 使用统一媒体浏览器，支持左右滑动切换图片和视频
    UnifiedMediaBrowserViewController *browser =
        [[UnifiedMediaBrowserViewController alloc] initWithMediaDataArray:mediaDataArray
                                                            currentIndex:tappedMediaIndex
                                                             browseItems:browseItems];
    browser.playbackNavigationController = self.navigationController;
    [browser showBrowserViewController];
}

@end
