//telegram @wz662
//
//  MsgSummaryContent.h
//  RainbowChat4i
//
//  Created by Jack Jiang on 2022/9/24.
//  Copyright © 2022 JackJiang. All rights reserved.
//
/**
 * 聊天记录可搜索内容实现类（数据将聚合显示）。
 * <p>
 * 该类是为了拆解并分散搜索功能的复杂性，同时提高不同搜索内容的可重用性等，主要是基于设计模式考虑。
 * <p>
 * 该类将实现搜索逻辑、搜索结果的UITableView里的显示效果、点击事件处理等。
 *
 * @author JackJiang
 * @since 6.0
 */

#import "SearchableContent.h"
#import "MsgDetailContent.h"


@interface MsgSummaryContent : SearchableContent

/**
 * 尝试读取了陌生人的昵称（因陌生人信息没有本地缓存，所以只能从间接渠道尝试读取）。
 *
 * @param guestUid 陌生人uid
 * @param defaultGuestNickname 默认的陌生的昵称，可为nil（对于聊天详情搜索结果来说，当不存在首页消息item时优化用消息记录中存的昵称，兜底才是用uid显示）
 * @return 返回昵称字符串
 */
+ (NSString *)tryGetGustNickname:(NSString *)guestUid defaultNick:(NSString *)defaultGuestNickname;

/**
 * 进入聊天界面。
 *
 * @param m 列表item数据对象
 * @param highlightOnceMsgFingerprint 该指纹码的消息将高亮显示一次（当前用于搜索功能中进到聊天界面时）
 */
+ (void)toChattingPage:(UINavigationController *)nc hudParentView:(UIView *)view parentContentDto:(MsgSummaryContentDTO *)m highlightOnceMsgFingerprint:(NSString *)highlightOnceMsgFingerprint;

/// @param anchorMessageDate 被点击那条消息的时间。传 nil 时仅能用 parentContentDto.date（例如「单条概要」行）。
+ (void)toChattingPage:(UINavigationController *)nc hudParentView:(UIView *)view parentContentDto:(MsgSummaryContentDTO *)m highlightOnceMsgFingerprint:(NSString *)highlightOnceMsgFingerprint anchorMessageDate:(NSDate *)anchorMessageDate;

/**
 * 从聊天概要（多天聊天消息合并的列表项，形如“共N条相关聊天记录”）继续进入到聊天详情（不合并同类聊天消息，有多少列多少）。
 *
 * @param currentKeyword 搜索关键字（可为空）
 * @param currentSummaryContentDTO 注意此参数，它将决定子级页面里搜索的消息范围为该item指定的聊天对象范围内的消息记录
 */
+ (void)toSearchMsgDetail:(UINavigationController *)nc keyword:(NSString *)currentKeyword summaryContent:(MsgSummaryContentDTO *) currentSummaryContentDTO;

@end

