//telegram @wz662
//
//  FriendsContent.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/22.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "FriendsContent.h"
#import "FriendTableViewCell.h"
#import "UserEntity.h"
#import "ViewControllerFactory.h"
#import "AlarmsViewController.h"
#import "RBAvatarView.h"

@implementation FriendsContent

/**
 * @Override - 此方法实现了父类中的空方法！
 * 用于SearchViewController中的tableView:cellForRowAtIndexPath:方法调用，从而实现不同搜索内容的表格cell内容显示。
 *
 * @param vc 对应的搜索主界面对象应用
 * @param dto 表格单元对应的数据对象
 * @return 返回对应的表格ceell对象
 */
- (UITableViewCell *) onTableViewCell:(SearchViewController *)vc contentDTO:(UserEntity *)dto{
    UITableViewCell *cell = [vc tableCell:vc.tableView withIdenfity:@"friendCell" xibName:@"FriendTableViewCell" c:[FriendTableViewCell class]];
    if(cell != nil) {
        FriendTableViewCell *theCell = (FriendTableViewCell *)cell;
        // 基本设置
        [theCell baseSetup];
                
        UserEntity *userInfo = dto;
        
        NSString *nickname = userInfo.nickname;
        NSString *friendRemark = userInfo.friendRemark;
        
        // 是否存在好友备注
        BOOL hasFriendRemark = (![BasicTool isStringEmpty:[BasicTool trim:friendRemark]]);
        // 好友备注是否包含关键字
        BOOL friendRemarkMatched = NO;
        if(hasFriendRemark && self.currentKeyword != nil){
            friendRemarkMatched = [[friendRemark lowercaseString] containsString:[self.currentKeyword lowercaseString]];
        }
        
        NSString *nick = nickname;
        
        // 如果好友备注包含关键字，则显示好友备注，并设置关键词高亮显示
        if(friendRemarkMatched){
            nick = [NSString stringWithFormat:@"%@(%@)", friendRemark, nickname];
        }
        // 关键字高亮
        NSMutableAttributedString *ssb = [BasicTool coloredStringForSearch:nick keyword:self.currentKeyword keywordColor:UI_DEFAULT_SEARCH_KEYWORD_COLOR];
        if(ssb != nil) {
            [theCell.viewName setAttributedText:ssb];
        } else {
            theCell.viewName.text = nick;// keyword = self.currentKeyword
        }
        
        // 支持视频头像播放
        [RBAvatarView setAvatarWithFileName:userInfo.userAvatarFileName uid:userInfo.user_uid onImageView:theCell.viewAvadar placeholder:[UIImage imageNamed:@"default_avatar_for_chattingui_40"]];
    }
    
    return cell;
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 点击事件真正的实施方法。子类可重写本方法实现自已的逻辑。
 *
 * @param vc 对应的搜索主界面对象应用
 * @param cell   表格单元对象引用
 * @param dto 表格单元对应的数据对象
 */
- (void)doClickImpl:(SearchViewController *)vc cell:(UITableViewCell *)cell contentDTO:(UserEntity *)dto {
    if(dto != nil) {
        UserEntity *userInfo = dto;
        if(userInfo != nil)
            [AlarmsViewController gotoSingleChattingViewController:vc.navigationController fromUid:userInfo.user_uid fromNickname:[userInfo getNickNameWithRemark] highlight:nil];
    }
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 点击"查看更多"事件真正的实施方法。子类可重写本方法实现自已的逻辑。
 *
 * @param vc 对应的搜索主界面对象应用
 */
- (void)doClickMoreImpl:(SearchViewController *)vc {
    [ViewControllerFactory goSearchViewController:vc.navigationController supportedSearchableContens:@[[[FriendsContent alloc] init]] keyword:self.currentKeyword showAllResult:YES];
}

/**
 * @Override - 重写父类方法
 * 搜索好友的实施方法。
 *
 * @param keyword 要搜索的关键词
 * @param searchAll YES表示显示所有结果，NO表示只显示限定数据的结果（多余部分用“查看更多”这样的cell由用户点进去进一步查看）
 * @return 返回的搜索结果集返回的搜索结果集 (List<R>)
 */
- (NSMutableArray *)doSearchImpl:(NSString *)keyword searchAll:(BOOL)searchAll db:(FMDatabase *)db {
    NSMutableArray<UserEntity *> *result = [NSMutableArray array];
    // 从好友列表中查找包含关键字的好友信息，并加入到查找结果集合中
    if(keyword != nil) {
        // 我的好友列表数据
        NSArray<UserEntity *> *myFriends = (NSArray<UserEntity *> *)[[[[IMClientManager sharedInstance] getFriendsListProvider] getFriendsData] getDataList];
        if (myFriends != nil) {
            for (UserEntity *f in myFriends) {
                // 昵称内是否包含关键字
                BOOL nicknameMatched = (f != nil && f.nickname != nil && [[f.nickname lowercaseString] containsString:[keyword lowercaseString]]);
                // 好友备注内是否包含备注
                BOOL friendRemarkMatched = (f != nil && [f getNickNameWithRemark] != nil && [[[f getNickNameWithRemark] lowercaseString] containsString:[keyword lowercaseString]]);
                if (nicknameMatched || friendRemarkMatched) {
                    [result addObject:f];
                }
            }
        }
    }
    
    return result;
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 返回本搜索内容显示在结果列表界面中时的对应的搜索内容类型常量。
 *
 * @return 搜索内容类型常量
 */
- (int)getContentType {
    return SEARCH_CONTENT_TYPE_FRIEND;
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 返回对应搜索内容的文字描述。
 *
 * @return 对应搜索内容的文字描述
 */
- (NSString *)getContentDescription {
    return @"好友";
}

@end
