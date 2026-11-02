#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/// 速点引擎:按住时以可控频率注入"按下-抬起"循环
@interface TJRapidTap : NSObject
@property (nonatomic, assign) NSInteger cps;            // 每秒点击次数 5~30
@property (nonatomic, assign) CGFloat   jitter;         // 0~1,间隔随机抖动比例
@property (nonatomic, assign) NSTimeInterval pressDuration;  // 单次按下保持时间
@property (nonatomic, readonly) BOOL running;

+ (instancetype)shared;
- (void)startAt:(CGPoint)p;
- (void)stop;
@end
