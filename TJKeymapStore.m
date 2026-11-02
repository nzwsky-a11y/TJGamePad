#import "TJKeymapStore.h"

@implementation TJBinding

+ (instancetype)fromDict:(NSDictionary *)d {
    TJBinding *b = [TJBinding new];
    b.x = [d[@"x"] doubleValue];
    b.y = [d[@"y"] doubleValue];
    b.page = [d[@"page"] integerValue];
    b.usage = [d[@"usage"] integerValue];
    b.type = (TJBindType)[d[@"type"] integerValue];
    b.cps = [d[@"cps"] integerValue] ?: 14;
    return b;
}

- (NSDictionary *)dict {
    return @{@"x": @(self.x), @"y": @(self.y),
             @"page": @(self.page), @"usage": @(self.usage),
             @"type": @(self.type), @"cps": @(self.cps)};
}

- (NSString *)keyName {
    if (self.page == 0x09) {
        switch (self.usage) {
            case 0x01: return @"左键";
            case 0x02: return @"右键";
            case 0x03: return @"中键";
            default:   return [NSString stringWithFormat:@"鼠标%ld", (long)self.usage];
        }
    }
    if (self.page == 0x07) {
        switch (self.usage) {
            case 0x1A: return @"W"; case 0x04: return @"A";
            case 0x16: return @"S"; case 0x07: return @"D";
            case 0x2C: return @"空格"; case 0xE1: return @"Shift";
            case 0xE0: return @"Ctrl"; case 0xE4: return @"Alt";
            default:   return [NSString stringWithFormat:@"键0x%02lX", (long)self.usage];
        }
    }
    return [NSString stringWithFormat:@"%ld/%ld", (long)self.page, (long)self.usage];
}

@end

static NSString *const kSuite = @"com.example.tjgamepad";
static NSString *const kKey   = @"bindings";

@implementation TJKeymapStore

+ (void)ensureDefaults {
    NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    if ([u arrayForKey:kKey].count) return;

    CGRect sc = [UIScreen mainScreen].bounds;
    NSMutableArray *def = [NSMutableArray array];

    // 左键 = 屏幕右侧开火位,速点
    TJBinding *fire = [TJBinding new];
    fire.x = sc.size.width * 0.78; fire.y = 320;
    fire.page = 0x09; fire.usage = 0x01;
    fire.type = TJBindTypeRapid; fire.cps = 14;
    [def addObject:fire];

    // 右键 = 开镜,按住
    TJBinding *aim = [TJBinding new];
    aim.x = sc.size.width * 0.90; aim.y = 240;
    aim.page = 0x09; aim.usage = 0x02;
    aim.type = TJBindTypeHold;
    [def addObject:aim];

    [self save:def];
}

+ (NSArray<TJBinding *> *)load {
    NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    NSArray *raw = [u arrayForKey:kKey];
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *d in raw) {
        if ([d isKindOfClass:[NSDictionary class]]) [out addObject:[TJBinding fromDict:d]];
    }
    return out;
}

+ (void)save:(NSArray<TJBinding *> *)list {
    NSMutableArray *raw = [NSMutableArray array];
    for (TJBinding *b in list) [raw addObject:[b dict]];
    NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    [u setObject:raw forKey:kKey];
    [u synchronize];
}

@end
