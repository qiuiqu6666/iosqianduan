//
//  FavoritesChatViewController.m
//  RainbowChat4i
//
//  收藏夹（10001）专用聊天页：与普通单聊一致，列表数据来自 MessagesProvider / SQLite（chattingDatas）。
//

#import "FavoritesChatViewController.h"
#import "IMClientManager.h"
#import "ClientCoreSDK.h"
#import "Protocal.h"
#import "BasicTool.h"
#import "NotificationCenterFactory.h"
#import "FileDownloadHelper.h"
#import "RBAvatarView.h"
#import "AlarmType.h"
#import "JSQMessages.h"
#import "UserEntity.h"
#import "ViewControllerFactory.h"
#import "MessageSearch10001ViewController.h"
#import "NSMutableArrayObservableEx.h"
#import "ChatMessageModeMenu.h"
#import "kmMoreMenuItem.h"
#import "LPActionSheet.h"
#import "HttpRestHelper.h"
#import "MessagesProvider.h"
#import "TimeTool.h"
#import "MyDataBase.h"

// 与 ChatViewController 的 MORE_ACTION_ID_* 一致，用于更多菜单
static const int kMoreActionIdImage = 1;
static const int kMoreActionIdPhoto = 2;
static const int kMoreActionIdFile = 6;
static const int kMoreActionIdLocation = 8;
static const int kMoreActionIdContactFriend = 9;
static const int kMoreActionIdContactMerged = 15;
static const NSInteger kFavoritesHistoryBackfillPageSize = 200;
static const NSInteger kFavoritesHistoryBackfillMaxPages = 100;

static NSMutableSet<NSString *> *RBFavoritesHistoryBackfillInFlightUids(void)
{
    static NSMutableSet<NSString *> *set;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSMutableSet set];
    });
    return set;
}

static NSString *RBFavoritesHistoryBackfillDoneDefaultsKey(NSString *localUid)
{
    return [NSString stringWithFormat:@"rb.favorites.10001.history.backfill.done.%@", localUid ?: @""];
}

static NSString *RBFavoritesHistoryDedupRepairDoneDefaultsKey(NSString *localUid)
{
    return [NSString stringWithFormat:@"rb.favorites.10001.history.dedup.repair.done.%@", localUid ?: @""];
}

static NSString *RBFavoritesNormalizedFingerprint(NSString *fp)
{
    if (fp == nil) return nil;
    NSString *trimmed = [[fp stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    return trimmed.length > 0 ? trimmed : nil;
}

@interface FavoritesChatViewController () <kmMoreMenuViewDelegate>
@property (nonatomic, retain) NSMutableArrayObservableEx *chattingDatas;
@property (strong, nonatomic) UIImage *outgoingAvatarImage;
@property (nonatomic, assign) BOOL rb_didAttemptFavoritesHistoryBackfill;
@end

@implementation FavoritesChatViewController

- (instancetype)initWithHighlight:(NSString *)highlightOnceMsgFingerprint
{
    if (self = [super initWithNibName:nil bundle:nil]) {
        self.chatType = CHAT_TYPE_FREIDN_CHAT;
        self.toId = @"10001";
        self.toName = @"收藏夹";
        self.highlightOnceMsgFingerprint = highlightOnceMsgFingerprint;
    }
    return self;
}

/// 10001 收藏夹自定义顶栏：左返回 + 标题「收藏夹」+ 右侧仅搜索
- (void)setupMinimalNavigationBar
{
    [super setupMinimalNavigationBar];
    UIView *container = [ChatMessageModeMenu navSearchOnlyButtonWithTarget:self
                                                                    action:@selector(rb_openFavoritesSearch)];
    [self rb_attachViewToChatCustomNavRight:container];
    self.rb_chromeNavigationBar.titleLabel.text = self.toName ?: @"";
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 收藏夹：只显示对方（来源）头像，不显示我方头像
    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    if ([flowLayout respondsToSelector:@selector(setOutgoingAvatarViewSize:)]) {
        [(id)flowLayout setOutgoingAvatarViewSize:CGSizeZero];
    }

    [self setupMinimalNavigationBar];
    [self initObservers];

    // 与单聊一致：本会话 uid=10001 的 IM 列表（含 SQLite 首屏同步）
    self.chattingDatas = [[[IMClientManager sharedInstance] getMessagesProvider] getMessages:self.toId];
    [self rb_deferredSetupAfterFirstFrame];
    [self rb_runFavoritesDuplicateRepairIfNeeded];
    [self startFavoritesHistoryBackfillIfNeeded];

    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [wself initAvatarImage];
    });
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [IMClientManager sharedInstance].currentFrontChattingUserUID = self.toId;
    if (self.chattingDatas && self.chattingDatasObserver) {
        [self.chattingDatas removeObserver:self.chattingDatasObserver];
        [self.chattingDatas addObserver:self.chattingDatasObserver];
    }
    if (self.rb_initialSessionUnreadCount <= 0) {
        AlarmsProvider *ap = [[IMClientManager sharedInstance] getAlarmsProvider];
        int idx = ap ? [ap getAlarmIndex:AMT_friendChatMessage dataId:self.toId] : -1;
        if (idx >= 0) {
            self.rb_initialSessionUnreadCount = [ap getFlagNum:idx];
        }
    }
    [[[IMClientManager sharedInstance] getAlarmsProvider] resetFlagNum:AMT_friendChatMessage dataId:self.toId flagNumToReset:0 needUpdateSqlite:YES];
    [NotificationCenterFactory refreshMainPageTotalUnread_POST];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [IMClientManager sharedInstance].currentFrontChattingUserUID = nil;
    [self.chattingDatas removeObserver:self.chattingDatasObserver];
    [super viewDidDisappear:animated];
}

- (void)deallocImpl
{
    [self.chattingDatas removeObserver:self.chattingDatasObserver];
    [super deallocImpl];
}

- (void)rb_deferredSetupCustomNavigationBar
{
    self.title = self.toName;
}

- (void)rb_didSetupCustomNavigationBar
{
    UIView *container = [ChatMessageModeMenu navSearchOnlyButtonWithTarget:self
                                                                    action:@selector(rb_openFavoritesSearch)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:container];
}

- (void)rb_openFavoritesSearch
{
    [ViewControllerFactory goMessageSearch10001ViewController:self.navigationController
                                                     chatType:CHAT_TYPE_FREIDN_CHAT
                                                       dataId:@"10001"
                                                  partnerName:@"收藏夹"
                                       showSearchBarWhenPushed:YES
                                          initialSearchKeyword:nil];
}

- (void)rb_onNavMoreTappedFor10001
{
    __weak typeof(self) wself = self;
    [ChatMessageModeMenu showFromViewController:self
                                    anchorView:self.navigationItem.rightBarButtonItem.customView
                                 onSelectIndex:^(NSInteger index) {
        if (index == 0) {
            [ViewControllerFactory goMessageSearch10001ViewController:wself.navigationController
                                                             chatType:CHAT_TYPE_FREIDN_CHAT
                                                               dataId:@"10001"
                                                          partnerName:@"收藏夹"
                                               showSearchBarWhenPushed:NO
                                                  initialSearchKeyword:nil];
        }
    }];
}

- (void)rb_deferredSetupAfterFirstFrame
{
    [super rb_deferredSetupAfterFirstFrame];
}

- (void)startFavoritesHistoryBackfillIfNeeded
{
    if (self.rb_didAttemptFavoritesHistoryBackfill) {
        return;
    }
    self.rb_didAttemptFavoritesHistoryBackfill = YES;

    NSString *localUid = [BasicTool trim:[IMClientManager sharedInstance].localUserInfo.user_uid];
    if (localUid.length == 0) {
        return;
    }
    NSString *defaultsKey = RBFavoritesHistoryBackfillDoneDefaultsKey(localUid);
    if ([[NSUserDefaults standardUserDefaults] boolForKey:defaultsKey]) {
        NSLog(@"【RB-FAVORITES-BACKFILL】skip done localUid=%@", localUid);
        return;
    }

    NSMutableSet<NSString *> *inflight = RBFavoritesHistoryBackfillInFlightUids();
    @synchronized (inflight) {
        if ([inflight containsObject:localUid]) {
            NSLog(@"【RB-FAVORITES-BACKFILL】skip in-flight localUid=%@", localUid);
            return;
        }
        [inflight addObject:localUid];
    }

    NSLog(@"【RB-FAVORITES-BACKFILL】start localUid=%@", localUid);
    [MessagesProvider beginSyncKeyBulkMessageApply];
    [self rb_backfillFavoritesHistoryPageForLocalUid:localUid
                                        endTimestamp:nil
                                      endFingerprint:nil
                                       pagesRemaining:kFavoritesHistoryBackfillMaxPages
                                      insertedSoFar:0];
}

- (void)rb_runFavoritesDuplicateRepairIfNeeded
{
    NSString *localUid = [BasicTool trim:[IMClientManager sharedInstance].localUserInfo.user_uid];
    if (localUid.length == 0) {
        return;
    }
    NSString *repairKey = RBFavoritesHistoryDedupRepairDoneDefaultsKey(localUid);
    if ([[NSUserDefaults standardUserDefaults] boolForKey:repairKey]) {
        return;
    }
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(wself) sself = wself;
        if (!sself) {
            return;
        }
        [sself rb_cleanupFavoritesHistoryDuplicatesForLocalUid:localUid];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:repairKey];
        dispatch_async(dispatch_get_main_queue(), ^{
            [sself rb_compactFavoritesInMemoryDuplicates];
            MessagesProvider *provider = [[IMClientManager sharedInstance] getMessagesProvider];
            [provider notifyObserversForChatUid:@"10001"];
        });
    });
}

- (void)rb_finishFavoritesHistoryBackfillForLocalUid:(NSString *)localUid completed:(BOOL)completed insertedCount:(NSInteger)insertedCount
{
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (completed && localUid.length > 0) {
            [wself rb_cleanupFavoritesHistoryDuplicatesForLocalUid:localUid];
        }
        [MessagesProvider endSyncKeyBulkMessageApply];
        NSMutableSet<NSString *> *inflight = RBFavoritesHistoryBackfillInFlightUids();
        @synchronized (inflight) {
            [inflight removeObject:localUid ?: @""];
        }
        if (completed && localUid.length > 0) {
            NSString *defaultsKey = RBFavoritesHistoryBackfillDoneDefaultsKey(localUid);
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:defaultsKey];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wself) sself = wself;
            if (completed) {
                NSLog(@"【RB-FAVORITES-BACKFILL】finish ok localUid=%@ inserted=%ld", localUid, (long)insertedCount);
            } else {
                NSLog(@"【RB-FAVORITES-BACKFILL】finish interrupted localUid=%@ inserted=%ld", localUid, (long)insertedCount);
            }
            [sself rb_compactFavoritesInMemoryDuplicates];
            MessagesProvider *provider = [[IMClientManager sharedInstance] getMessagesProvider];
            [provider notifyObserversForChatUid:@"10001"];
        });
    });
}

- (void)rb_cleanupFavoritesHistoryDuplicatesForLocalUid:(NSString *)localUid
{
    if (localUid.length == 0) {
        return;
    }
    [MyDataBase inDatabase:^(FMDatabase *db) {
        NSString *sql = @"DELETE FROM chat_msg "
                         @"WHERE _acount_uid=? AND _uid='10001' "
                         @"AND finger_print_of_protocal IS NOT NULL AND trim(finger_print_of_protocal)<>'' "
                         @"AND rowid NOT IN ("
                         @"  SELECT MIN(rowid) "
                         @"  FROM chat_msg "
                         @"  WHERE _acount_uid=? AND _uid='10001' "
                         @"  AND finger_print_of_protocal IS NOT NULL AND trim(finger_print_of_protocal)<>'' "
                         @"  GROUP BY lower(trim(finger_print_of_protocal))"
                         @")";
        BOOL ok = [db executeUpdate:sql withArgumentsInArray:@[localUid, localUid]];
        NSLog(@"【RB-FAVORITES-BACKFILL】cleanup sqlite duplicates ok=%d changed=%d", ok ? 1 : 0, db.changes);
    }];
}

- (void)rb_compactFavoritesInMemoryDuplicates
{
    NSMutableArrayObservableEx *list = self.chattingDatas;
    if (list == nil) {
        return;
    }
    NSMutableArray *dataList = [list getDataList];
    if (dataList.count <= 1) {
        return;
    }
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    NSMutableArray *deduped = [NSMutableArray arrayWithCapacity:dataList.count];
    NSInteger removed = 0;
    for (JSQMessage *msg in dataList) {
        NSString *normalizedFp = RBFavoritesNormalizedFingerprint(msg.fingerPrintOfProtocal);
        if (normalizedFp.length > 0) {
            if ([seen containsObject:normalizedFp]) {
                removed += 1;
                continue;
            }
            [seen addObject:normalizedFp];
        }
        [deduped addObject:msg];
    }
    if (removed > 0) {
        [list putDataList:deduped needNotify:NO];
        [MessagesProvider sortMessagesByDateAscending:list];
        NSLog(@"【RB-FAVORITES-BACKFILL】cleanup memory duplicates removed=%ld", (long)removed);
    }
}

- (void)rb_backfillFavoritesHistoryPageForLocalUid:(NSString *)localUid
                                      endTimestamp:(NSString *)endTimestamp
                                    endFingerprint:(NSString *)endFingerprint
                                     pagesRemaining:(NSInteger)pagesRemaining
                                    insertedSoFar:(NSInteger)insertedSoFar
{
    if (localUid.length == 0 || pagesRemaining <= 0) {
        [self rb_finishFavoritesHistoryBackfillForLocalUid:localUid completed:YES insertedCount:insertedSoFar];
        return;
    }

    __weak typeof(self) wself = self;
    [[HttpRestHelper sharedInstance] submitQueryChatHistoryFromServer:localUid
                                                            remoteUid:@"10001"
                                                                  gid:nil
                                                             rowCount:kFavoritesHistoryBackfillPageSize
                                                         endTimestamp:endTimestamp
                                                       endFingerprint:endFingerprint
                                                             complete:^(BOOL success, NSArray<NSArray *> *messages, BOOL hasMore) {
        __strong typeof(wself) sself = wself;
        if (!sself) {
            [MessagesProvider endSyncKeyBulkMessageApply];
            NSMutableSet<NSString *> *inflight = RBFavoritesHistoryBackfillInFlightUids();
            @synchronized (inflight) {
                [inflight removeObject:localUid ?: @""];
            }
            return;
        }
        if (!success) {
            [sself rb_finishFavoritesHistoryBackfillForLocalUid:localUid completed:NO insertedCount:insertedSoFar];
            return;
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            MessagesProvider *provider = [[IMClientManager sharedInstance] getMessagesProvider];
            FriendsListProvider *friendsProvider = [[IMClientManager sharedInstance] getFriendsListProvider];
            NSString *nextEndTimestamp = nil;
            NSString *nextEndFingerprint = nil;
            NSInteger insertedThisPage = 0;

            for (id rowObj in messages) {
                if (![rowObj isKindOfClass:[NSArray class]]) {
                    continue;
                }
                NSArray *row = (NSArray *)rowObj;
                JSQMessage *msg = RBParseJSQMessageFrom26_8HistoryRow(row, localUid, NO, friendsProvider);
                if (msg == nil) {
                    continue;
                }
                insertedThisPage += 1;
                if (msg.date != nil) {
                    long long millis = (long long)[TimeTool javaMillisFromNSDate:msg.date];
                    nextEndTimestamp = [NSString stringWithFormat:@"%lld", millis];
                }
                nextEndFingerprint = [BasicTool trim:msg.fingerPrintOfProtocal];
                [provider putMessage:@"10001" withData:msg];
            }

            NSInteger totalInserted = insertedSoFar + insertedThisPage;
            BOOL shouldContinue = hasMore && messages.count > 0 && nextEndTimestamp.length > 0;
            NSLog(@"【RB-FAVORITES-BACKFILL】page localUid=%@ rows=%lu inserted=%ld hasMore=%d nextTs=%@ nextFp=%@ pagesRemaining=%ld",
                  localUid,
                  (unsigned long)messages.count,
                  (long)insertedThisPage,
                  hasMore ? 1 : 0,
                  nextEndTimestamp ?: @"",
                  nextEndFingerprint ?: @"",
                  (long)pagesRemaining);

            if (shouldContinue) {
                [sself rb_backfillFavoritesHistoryPageForLocalUid:localUid
                                                     endTimestamp:nextEndTimestamp
                                                   endFingerprint:nextEndFingerprint
                                                    pagesRemaining:(pagesRemaining - 1)
                                                   insertedSoFar:totalInserted];
            } else {
                [sself rb_finishFavoritesHistoryBackfillForLocalUid:localUid completed:YES insertedCount:totalInserted];
            }
        });
    } hudParentView:nil];
}

/// 初始化「+」更多面板，使点击加号能显示照片/拍摄/文件等（与单聊 10001 菜单一致，无收藏/红包/转账/音视频）
- (void)initMoreContentView
{
    self.bottomBoxMoreView.delegate = self;
    NSMutableArray *moreMenuItems = [NSMutableArray array];
    [moreMenuItems addObject:[[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_img"] highlightIconImage:[UIImage imageNamed:@"chatting_more_func_img"] title:@"照片" actionId:kMoreActionIdImage]];
    [moreMenuItems addObject:[[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_camra"] highlightIconImage:[UIImage imageNamed:@"chatting_more_func_camra"] title:@"拍摄" actionId:kMoreActionIdPhoto]];
    [moreMenuItems addObject:[[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_file"] highlightIconImage:[UIImage imageNamed:@"chatting_more_func_file"] title:@"文件" actionId:kMoreActionIdFile]];
    [moreMenuItems addObject:[[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_location"] highlightIconImage:[UIImage imageNamed:@"chatting_more_func_location"] title:@"位置" actionId:kMoreActionIdLocation]];
    [moreMenuItems addObject:[[kmMoreMenuItem alloc] initWithNormalIconImage:[UIImage imageNamed:@"chatting_more_func_user"] highlightIconImage:[UIImage imageNamed:@"chatting_more_func_user"] title:@"名片" actionId:kMoreActionIdContactMerged]];
    self.bottomBoxMoreView.shareMenuItems = moreMenuItems;
}

- (void)didSelecteMoreMenuItem:(kmMoreMenuItem *)shareMenuItem atIndex:(NSInteger)index
{
    switch (shareMenuItem.actionId) {
        case kMoreActionIdImage:
            [self.imagePickerWrapper takeAlbum:YES];
            break;
        case kMoreActionIdPhoto:
            [self.imagePickerWrapper takePhoto];
            break;
        case kMoreActionIdFile:
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            [self openFilePicker];
            break;
        case kMoreActionIdLocation:
            [self openLocationChoose];
            break;
        case kMoreActionIdContactMerged:
        {
            if (self.inputToolbar.contentView.textView.isFirstResponder) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
            }
            __weak typeof(self) wself = self;
            [self hideBottomBoxAnim:YES completion:^{
                __strong typeof(wself) s = wself;
                if (!s) return;
                [LPActionSheet showActionSheetWithTitle:nil
                                      cancelButtonTitle:@"取消"
                                 destructiveButtonTitle:nil
                                      otherButtonTitles:@[@"个人名片", @"群名片"]
                                    otherButtonImages:nil
                                                handler:^(LPActionSheet *actionSheet, NSInteger index) {
                    __strong typeof(wself) ss = wself;
                    if (!ss) return;
                    if (index == 0) return;
                    if (index == 1) [ss openUserChoose];
                    else if (index == 2) [ss openGroupChoose];
                }];
            }];
            return;
        }
        case kMoreActionIdContactFriend:
            [self openUserChoose];
            break;
        default:
            [BasicTool showAlertInfo:@"此功能暂未开放，敬请关注！" parent:self];
            break;
    }
    [self hideBottomBoxAnim:YES];
}

- (NSMutableArray<JSQMessage *> *)getChattingDatasList
{
    return [self.chattingDatas getDataList];
}

- (void)refresh10001FavoritesListIfNeeded
{
    [self refreshCollectionView];
}

#pragma mark - 头像与 cell 配置

- (void)rb_collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath_avatar:(NSIndexPath *)indexPath withImageView:(UIImageView *)avatarView
{
    avatarView.layer.cornerRadius = kJSQMessagesCollectionViewAvatarSizeDefault * 0.5f;
    avatarView.layer.masksToBounds = YES;
    NSArray *list = [self getChattingDatasList];
    if (indexPath.item >= list.count) return;
    JSQMessage *entity = list[indexPath.item];
    UIImage *placeImg = [UIImage imageNamed:@"chat_avatar_default"];
    BOOL isOutgoing = [entity.senderId isEqualToString:self.senderId];
    if (isOutgoing) {
        [RBAvatarView removeAvatarFromImageView:avatarView];
        avatarView.image = self.outgoingAvatarImage ?: placeImg;
        return;
    }
    [RBAvatarView removeAvatarFromImageView:avatarView];
    UIImage *img = [collectionView.dataSource collectionView:collectionView avatarImageDataForItemAtIndexPath:indexPath];
    avatarView.image = img ?: placeImg;
}

- (void)rb_updateVisibleAvatarImages
{
    if (!self.collectionView.window) return;
    NSArray *list = [self getChattingDatasList];
    if (!list.count) return;
    UIImage *outImg = self.outgoingAvatarImage ?: [UIImage imageNamed:@"chat_avatar_default"];
    NSString *myId = self.senderId ?: @"";
    for (NSIndexPath *path in [self.collectionView indexPathsForVisibleItems]) {
        if (path.section != 0 || path.item >= list.count) continue;
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:path];
        if (![cell isKindOfClass:[JSQMessagesCollectionViewCell class]]) continue;
        JSQMessagesCollectionViewCell *msgCell = (JSQMessagesCollectionViewCell *)cell;
        UIImageView *avatarView = msgCell.avatarImageView;
        if (!avatarView) continue;
        JSQMessage *msg = list[path.item];
        BOOL isOutgoing = [msg.senderId isEqualToString:myId];
        [RBAvatarView removeAvatarFromImageView:avatarView];
        if (isOutgoing) {
            avatarView.image = outImg;
        } else {
            UIImage *img = [self collectionView:self.collectionView avatarImageDataForItemAtIndexPath:path];
            avatarView.image = img ?: outImg;
        }
        avatarView.layer.cornerRadius = kJSQMessagesCollectionViewAvatarSizeDefault * 0.5f;
        avatarView.layer.masksToBounds = YES;
    }
}

- (void)initAvatarImage
{
    __weak typeof(self) wself = self;
    self.outgoingAvatarImage = nil;
    UserEntity *curUser = [IMClientManager sharedInstance].localUserInfo;
    if (curUser && ![BasicTool isStringEmpty:curUser.userAvatarFileName]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *path = [FileDownloadHelper getUserAvatarDownloadURLExt:YES fileName:curUser.userAvatarFileName uid:curUser.user_uid];
            UIImage *img = [FileDownloadHelper loadUserAvatarFromCacheOnly:path donotLoadFromDisk:NO];
            if (img == nil) {
                [FileDownloadHelper loadUserAvatarWithFileName:curUser.userAvatarFileName uid:curUser.user_uid logTag:@"FavoritesChat-OutAvatar" complete:^(BOOL succ, UIImage *img) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (wself && img) {
                            wself.outgoingAvatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:img diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
                            [wself rb_updateVisibleAvatarImages];
                        }
                    });
                }];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (wself) {
                        wself.outgoingAvatarImage = [JSQMessagesAvatarImageFactory avatarImageWithImage:img diameter:kJSQMessagesCollectionViewAvatarSizeDefault];
                        [wself rb_updateVisibleAvatarImages];
                    }
                });
            }
        });
    }
}

@end
