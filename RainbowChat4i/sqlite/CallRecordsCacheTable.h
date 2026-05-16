//telegram @wz662
#import <Foundation/Foundation.h>
#import "TableRoot.h"

@interface CallRecordsCacheTable : TableRoot

+ (NSString *)getTableName;
+ (NSString *)getCreateTableSQL;

- (NSString *)queryJson:(FMDatabase *)db ownerUid:(NSString *)ownerUid cacheKey:(NSString *)cacheKey;
- (BOOL)upsertJson:(FMDatabase *)db ownerUid:(NSString *)ownerUid cacheKey:(NSString *)cacheKey json:(NSString *)json updateTime2:(long long)updateTime2;

@end

