#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, TJBindType) {
    TJBindTypeTap = 0,     // 按一下 = 点一下
    TJBindTypeHold = 1,    // 按住 = 按住屏幕(摇杆/持续开火/开镜)
    TJBindTypeRapid = 2,   // 按住 = 速点
};

/// 一条键位绑定:屏幕坐标 + 键 + 行为
@interface TJBinding : NSObject
@property (nonatomic, assign) CGFloat x, y;
@property (nonatomic, assign) NSInteger page;    // HID usagePage (0x07 键盘 / 0x09 鼠标)
@property (nonatomic, assign) NSInteger usage;   // HID usage
@property (nonatomic, assign) TJBindType type;
@property (nonatomic, assign) NSInteger cps;     // 仅 rapid 用
+ (instancetype)fromDict:(NSDictionary *)d;
- (NSDictionary *)dict;
- (NSString *)keyName;
@end

/// JSON 持久化(存在 NSUserDefaults 里的一个数组,等价原版的键位配置文件)
@interface TJKeymapStore : NSObject
+ (NSArray<TJBinding *> *)load;
+ (void)save:(NSArray<TJBinding *> *)list;
+ (void)ensureDefaults;   // 首次启动写入默认键位
@end
