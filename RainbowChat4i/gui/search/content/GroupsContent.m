//telegram @wz662
//
//  GroupsContent.m
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/23.
//  Copyright © 2022 JackJiang. All rights reserved.
//

#import "GroupsContent.h"
#import "GroupContentDTO.h"
#import "GroupTableViewCell.h"
#import "AlarmsViewController.h"
#import "ViewControllerFactory.h"

@implementation GroupsContent

/**
 * @Override - 此方法实现了父类中的空方法！
 * 用于SearchViewController中的tableView:cellForRowAtIndexPath:方法调用，从而实现不同搜索内容的表格cell内容显示。
 *
 * @param vc 对应的搜索主界面对象应用
 * @param dto 表格单元对应的数据对象
 * @return 返回对应的表格ceell对象
 */
- (UITableViewCell *) onTableViewCell:(SearchViewController *)vc contentDTO:(GroupContentDTO *)dto {
    UITableViewCell *holder = [vc tableCell:vc.tableView withIdenfity:@"groupCell" xibName:@"GroupTableViewCell" c:[GroupTableViewCell class]];
    if(holder != nil) {
        GroupTableViewCell *theCell = (GroupTableViewCell *)holder;
        // 基本设置
        [theCell baseSetup];
        
        GroupContentDTO *gsr = dto;
        GroupEntity *g = gsr.groupInfo;
        if (g == nil){
            DLogWarn(@"GroupViewHolder中无效的GroupEntity，g=null!");
            return nil;
        }
        
        // 设置默认占位图
        [theCell.viewAvadar setImage:[UIImage imageNamed:@"groupchat_groups_icon_default"]];
        // 尝试为群组加载群头像
        [FileDownloadHelper loadGroupAvatar:g.g_id logTag:@"GroupsContent"
            complete:^(BOOL sucess, UIImage *img) {
                if(sucess && img != nil)
                    [theCell.viewAvadar setImage:img];
        }];
        
        // 设置群名称中关键字的高亮显示并在ui上显示出来
        NSString *gname = g.g_name;
        // 关键字高亮
        NSMutableAttributedString *ssb = [BasicTool coloredStringForSearch:gname keyword:self.currentKeyword keywordColor:UI_DEFAULT_SEARCH_KEYWORD_COLOR];
        if(ssb != nil) {
            [theCell.viewName setAttributedText:ssb];
        } else {
            theCell.viewName.text = gname;// keyword = self.currentKeyword
        }
    }
    
    return holder;
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 点击事件真正的实施方法。子类可重写本方法实现自已的逻辑。
 *
 * @param vc 对应的搜索主界面对象应用
 * @param cell   表格单元对象引用
 * @param dto 表格单元对应的数据对象
 */
- (void)doClickImpl:(SearchViewController *)vc cell:(UITableViewCell *)cell contentDTO:(GroupContentDTO *)dto {
    GroupContentDTO *gsr = dto;
    if(gsr != nil) {
        GroupEntity *g = gsr.groupInfo;
        if(g != nil) {
            [AlarmsViewController gotoGroupChattingViewController:vc.navigationController gid:g.g_id ge:g highlight:nil];
        }
    }
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 点击"查看更多"事件真正的实施方法。子类可重写本方法实现自已的逻辑。
 *
 * @param vc 对应的搜索主界面对象应用
 */
- (void)doClickMoreImpl:(SearchViewController *)vc {
    [ViewControllerFactory goSearchViewController:vc.navigationController supportedSearchableContens:@[[[GroupsContent alloc] init]] keyword:self.currentKeyword showAllResult:YES];
}

/**
 * @Override - 重写父类方法
 * 搜索群聊的实施方法。
 *
 * @param keyword 要搜索的关键词
 * @param searchAll YES表示显示所有结果，NO表示只显示限定数据的结果（多余部分用“查看更多”这样的cell由用户点进去进一步查看）
 * @return 返回的搜索结果集 (List<R>)
 */
- (NSMutableArray *)doSearchImpl:(NSString *)keyword searchAll:(BOOL)searchAll db:(FMDatabase *)db {
    NSMutableArray<GroupContentDTO *> *result = [NSMutableArray array];
    // 从好友列表中查找包含关键字的好友信息，并加入到查找结果集合中
    if(keyword != nil) {
        // 我的好友列表数据
        NSArray<GroupEntity *> *groups = [[[[IMClientManager sharedInstance] getGroupsProvider] getGroupsListData] getDataList];
        if (groups != nil) {
            for (GroupEntity *g in groups) {
                // 群名称内是否包含关键字
                
                if(g != nil && g.g_name != nil && [[g.g_name lowercaseString] containsString:[keyword lowercaseString]]){
                    GroupContentDTO *gsr = [[GroupContentDTO alloc] init];
                    gsr.groupInfo = g;
                    gsr.machedType = GSR_MACHED_TYPE_GNAME;
                    
                    [result addObject:gsr];
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
    return SEARCH_CONTENT_TYPE_GROUP;
}

/**
 * @Override - 此方法实现了父类中的空方法！
 * 返回对应搜索内容的文字描述。
 *
 * @return 对应搜索内容的文字描述
 */
- (NSString *)getContentDescription {
    return @"群组";
}

@end
