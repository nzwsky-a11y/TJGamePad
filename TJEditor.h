#import <UIKit/UIKit.h>
#import "TJKeymapStore.h"

/// 键位编辑覆盖层:拖点定位 + 按键绑定
@interface TJEditor : UIWindow
+ (instancetype)shared;
- (void)open;
- (void)close;
@property (nonatomic, readonly) BOOL opened;
@end

/// 供 TJInput 在捕获模式下回调(返回 YES 表示已消费该按键)
BOOL TJEditorCaptureKey(NSInteger page, NSInteger usage);
