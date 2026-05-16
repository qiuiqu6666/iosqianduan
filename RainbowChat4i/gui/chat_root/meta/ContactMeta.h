//telegram @wz662
/**
 * 个人名片消息的文件信息元数据.
 *
 * @author JackJiang
 * @since 4.0
 */

#import <Foundation/Foundation.h>

#define CONTACT_TYPE_USER   0
#define CONTACT_TYPE_GROUP  1


@interface ContactMeta : NSObject

/** 名片类型 */
@property (nonatomic, assign) int type;

/** 名片的id（可能是uid、群id） */
// 此字段出于版本兼容考虑，暂时不重构为id，否则将影响多端的兼容性！
@property (nonatomic, retain) NSString *uid;
/** 名片的标题（可能是用户昵称、群名称） */
// 此字段出于版本兼容考虑，暂时不重构为name，否则将影响多端的兼容性！
@property (nonatomic, retain) NSString *nickName;
/**
 * 名片的更多描述信息
 * @since 8.0 */
@property (nonatomic, retain) NSString *desc;

+ (ContactMeta *)initWith:(int)type uid:(NSString *)uid nickname:(NSString *)nickname desc:(NSString *)desc;
+ (ContactMeta *)fromJSON:(NSString *)jsonOfContactMeta;

@end

