#import "StickerManageViewController.h"
#import "StickerManager.h"
#import "BasicTool.h"
#import "IMClientManager.h"
#import "UIImageView+WebCache.h"

static NSString * const kManageStickerCellId = @"ManageStickerCell";
static NSString * const kManageAddCellId = @"ManageAddCell";

@interface StickerManageViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, assign) BOOL isEditMode; // 编辑（删除）模式

@end

@implementation StickerManageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"我的表情";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 导航栏按钮
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                                                            style:UIBarButtonItemStylePlain
                                                                           target:self
                                                                           action:@selector(closeTapped)];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"编辑"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(toggleEditMode)];
    
    // 集合视图
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat padding = 15;
    CGFloat spacing = 10;
    int columns = 4;
    CGFloat itemWidth = (screenWidth - padding * 2 - spacing * (columns - 1)) / columns;
    layout.itemSize = CGSizeMake(itemWidth, itemWidth);
    layout.minimumInteritemSpacing = spacing;
    layout.minimumLineSpacing = spacing;
    layout.sectionInset = UIEdgeInsetsMake(padding, padding, padding, padding);
    
    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.backgroundColor = [UIColor whiteColor];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:kManageStickerCellId];
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:kManageAddCellId];
    [self.view addSubview:self.collectionView];
    
    // 加载数据
    [self loadData];
}

- (void)loadData {
    [[StickerManager sharedInstance] refreshStickersFromServer:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView reloadData];
        });
    }];
}

#pragma mark - 导航栏操作

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)toggleEditMode {
    self.isEditMode = !self.isEditMode;
    self.navigationItem.rightBarButtonItem.title = self.isEditMode ? @"完成" : @"编辑";
    [self.collectionView reloadData];
}

#pragma mark - UICollectionView DataSource & Delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    // 非编辑模式下最后一个是"+"按钮
    NSInteger count = [StickerManager sharedInstance].stickerList.count;
    return self.isEditMode ? count : count + 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSDictionary *> *stickers = [StickerManager sharedInstance].stickerList;
    
    if (indexPath.item < (NSInteger)stickers.count) {
        UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kManageStickerCellId forIndexPath:indexPath];
        
        // 清除旧内容
        for (UIView *sv in cell.contentView.subviews) {
            [sv removeFromSuperview];
        }
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 6, 6)];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageView.tag = 200;
        [cell.contentView addSubview:imageView];
        
        cell.contentView.layer.borderWidth = 0.5;
        cell.contentView.layer.borderColor = [UIColor colorWithWhite:0.9 alpha:1.0].CGColor;
        cell.contentView.layer.cornerRadius = 8;
        cell.contentView.clipsToBounds = YES;
        
        // 编辑模式下显示删除按钮
        if (self.isEditMode) {
            UIButton *deleteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            deleteBtn.frame = CGRectMake(cell.contentView.bounds.size.width - 24, 0, 24, 24);
            deleteBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
            UIImage *xIcon = [UIImage systemImageNamed:@"xmark.circle.fill"];
            [deleteBtn setImage:xIcon forState:UIControlStateNormal];
            deleteBtn.tintColor = [UIColor redColor];
            deleteBtn.tag = 300 + indexPath.item;
            [deleteBtn addTarget:self action:@selector(deleteStickerTapped:) forControlEvents:UIControlEventTouchUpInside];
            [cell.contentView addSubview:deleteBtn];
        }
        
        // 使用 sd_setImageWithURL 直接加载表情图片（最可靠的方式，与应用其他图片加载一致）
        NSDictionary *info = stickers[indexPath.item];
        NSString *fileName = [info objectForKey:@"file_name"];
        NSString *uid = [IMClientManager sharedInstance].localUserInfo.user_uid;
        NSString *urlStr = [[StickerManager sharedInstance] stickerDownloadURLForFileName:fileName userUid:uid];
        NSURL *imgURL = [NSURL URLWithString:urlStr];
        
        // NSLog(@"【StickerManage】加载表情[%ld]: file_name=%@, url=%@", (long)indexPath.item, fileName, urlStr); // ★ 性能优化
        
        [imageView sd_setImageWithURL:imgURL
                     placeholderImage:nil
                              options:SDWebImageRetryFailed
                            completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
            if (image) {
                // NSLog(@"【StickerManage】表情加载成功[%ld]: %@ (cacheType=%ld)", (long)indexPath.item, fileName, (long)cacheType); // ★ 性能优化
            } else {
                // NSLog(@"【StickerManage】表情加载失败[%ld]: %@, error=%@", (long)indexPath.item, fileName, error); // ★ 性能优化
            }
        }];
        
        return cell;
    } else {
        // "添加"按钮 Cell
        UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kManageAddCellId forIndexPath:indexPath];
        
        for (UIView *sv in cell.contentView.subviews) {
            [sv removeFromSuperview];
        }
        
        UIImageView *addIcon = [[UIImageView alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 20, 20)];
        addIcon.contentMode = UIViewContentModeScaleAspectFit;
        addIcon.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        addIcon.image = [UIImage systemImageNamed:@"plus"];
        addIcon.tintColor = [UIColor grayColor];
        [cell.contentView addSubview:addIcon];
        
        cell.contentView.layer.borderWidth = 1.5;
        cell.contentView.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
        cell.contentView.layer.cornerRadius = 8;
        cell.contentView.clipsToBounds = YES;
        
        return cell;
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSDictionary *> *stickers = [StickerManager sharedInstance].stickerList;
    
    if (indexPath.item >= (NSInteger)stickers.count) {
        // 点击 "+" → 从相册选择
        [self openImagePicker];
    }
}

#pragma mark - 删除表情

- (void)deleteStickerTapped:(UIButton *)sender {
    NSInteger idx = sender.tag - 300;
    NSArray<NSDictionary *> *stickers = [StickerManager sharedInstance].stickerList;
    if (idx < 0 || idx >= (NSInteger)stickers.count) return;
    
    NSDictionary *info = stickers[idx];
    NSString *stickerId = [info objectForKey:@"id"];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除表情"
                                                                  message:@"确定要删除这个自定义表情吗？"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[StickerManager sharedInstance] deleteStickers:@[stickerId] complete:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [self.collectionView reloadData];
                    if (self.manageDelegate && [self.manageDelegate respondsToSelector:@selector(stickerManageDidChange)]) {
                        [self.manageDelegate stickerManageDidChange];
                    }
                } else {
                    [BasicTool showAlertInfo:@"删除失败，请重试" parent:self];
                }
            });
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 添加表情（图片选择器）

- (void)openImagePicker {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.allowsEditing = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        if (image) {
            [self uploadStickerImage:image];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)uploadStickerImage:(UIImage *)image {
    // 显示加载指示
    UIAlertController *loading = [UIAlertController alertControllerWithTitle:nil message:@"正在上传表情..." preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:loading animated:YES completion:nil];
    
    [[StickerManager sharedInstance] uploadSticker:image complete:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [loading dismissViewControllerAnimated:YES completion:^{
                if (success) {
                    [self.collectionView reloadData];
                    if (self.manageDelegate && [self.manageDelegate respondsToSelector:@selector(stickerManageDidChange)]) {
                        [self.manageDelegate stickerManageDidChange];
                    }
                } else {
                    [BasicTool showAlertInfo:@"上传失败，请重试" parent:self];
                }
            }];
        });
    }];
}

@end
