//telegram @wz662
#import "CallRecordsCacheTable.h"
#import "MyDataBase.h"

static NSString * const kCallRecordsCacheTable = @"call_records_cache";

@implementation CallRecordsCacheTable

+ (NSString *)getTableName
{
    return kCallRecordsCacheTable;
}

+ (NSString *)getCreateTableSQL
{
    return @"CREATE TABLE IF NOT EXISTS call_records_cache ("
           "_id INTEGER PRIMARY KEY AUTOINCREMENT, "
           "_acount_uid TEXT NOT NULL, "
           "cache_key TEXT NOT NULL, "
           "json TEXT, "
           "update_time2 INTEGER DEFAULT 0, "
           "UNIQUE(_acount_uid, cache_key)"
           ")";
}

- (NSString *)queryJson:(FMDatabase *)db ownerUid:(NSString *)ownerUid cacheKey:(NSString *)cacheKey
{
    if (db == nil || ownerUid.length == 0 || cacheKey.length == 0) return nil;
    NSString *sql = [NSString stringWithFormat:@"SELECT json FROM %@ WHERE _acount_uid=? AND cache_key=? LIMIT 1", [CallRecordsCacheTable getTableName]];
    FMResultSet *rs = [db executeQuery:sql, ownerUid, cacheKey];
    NSString *json = nil;
    if (rs && [rs next]) {
        json = [rs stringForColumn:@"json"];
    }
    [rs close];
    return json;
}

- (BOOL)upsertJson:(FMDatabase *)db ownerUid:(NSString *)ownerUid cacheKey:(NSString *)cacheKey json:(NSString *)json updateTime2:(long long)updateTime2
{
    if (db == nil || ownerUid.length == 0 || cacheKey.length == 0) return NO;
    NSString *sql = [NSString stringWithFormat:
                     @"INSERT INTO %@ (_acount_uid, cache_key, json, update_time2) VALUES (?, ?, ?, ?) "
                     "ON CONFLICT(_acount_uid, cache_key) DO UPDATE SET json=excluded.json, update_time2=excluded.update_time2",
                     [CallRecordsCacheTable getTableName]];
    BOOL ok = [db executeUpdate:sql, ownerUid, cacheKey, (json ?: @""), @(updateTime2)];
    if (!ok) {
        [MyDataBase printErrorForDebug:db tag:@"CallRecordsCacheTable-upsert"];
    }
    return ok;
}

@end

