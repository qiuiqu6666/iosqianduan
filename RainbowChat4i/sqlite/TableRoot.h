//telegram @wz662
#import <Foundation/Foundation.h>
#import "FMDatabaseQueue.h"

#define DATABASE_PATH @"rainbowchat_pro.db"


@interface TableRoot : NSObject

//+(FMDatabaseQueue*)getDbQueue;
//+(void)createTable:(NSString*)tableString;
//
//+(void)inDatabase:(void (^)(FMDatabase *db))block;
////+(void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block finished:(void (^)())finished;
//+(void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block;

- (FMResultSet *)query:(FMDatabase *)db tableName:(NSString *)tableName fieldNamesStr:(NSString *)fieldNamesWithStr filterSQL:(NSString *)filterSQL debugTag:(NSString *)tag;

- (FMResultSet *)query:(FMDatabase *)db tableName:(NSString *)tableName fieldNames:(NSArray<NSString *> *)fieldNames filterSQL:(NSString *)filterSQL debugTag:(NSString *)tag;

- (BOOL) delete:(FMDatabase *)db tableName:(NSString *)tableName filterSQL:(NSString *)filterSQL debugTag:(NSString *)tag;

@end
