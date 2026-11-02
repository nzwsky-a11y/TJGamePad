#import <UIKit/UIKit.h>

/// 手搓速点热区:盖在游戏开火键上的透明窗口,按住即高频点射
@interface TJRapidPad : UIWindow
+ (instancetype)shared;
- (void)refresh;                 // 读配置并应用(位置/大小/开关)
@property (nonatomic, readonly) BOOL adjusting;   // 是否处于"拖动调整"模式
- (void)beginAdjust;
- (void)endAdjust;
@end
