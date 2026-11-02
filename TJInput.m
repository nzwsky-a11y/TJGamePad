#import <Foundation/Foundation.h>
#import "HIDEvent.h"
#import "TJRapidTap.h"
#import "TJKeymapStore.h"
#import "TJEditor.h"
#include <math.h>

#pragma mark - 摇杆(固定用 finger 1)
@interface TJStick : NSObject
@property (nonatomic, assign) CGPoint origin;
@property (nonatomic, assign) CGFloat radius;
@property (nonatomic, assign) BOOL active;
+ (instancetype)shared;
- (void)setVector:(CGPoint)v;
- (void)releaseStick;
@end

@implementation TJStick {
    CGPoint _last;
}
+ (instancetype)shared { static TJStick *s; static dispatch_once_t o; dispatch_once(&o, ^{ s = [TJStick new]; }); return s; }
- (instancetype)init {
    if ((self = [super init])) {
        CGRect sc = [UIScreen mainScreen].bounds;
        _origin = CGPointMake(120, sc.size.height - 170);
        _radius = 70;
        _last = _origin;
    }
    return self;
}
- (void)setVector:(CGPoint)v {
    CGFloat len = sqrt(v.x * v.x + v.y * v.y);
    if (len > 1.0) { v.x /= len; v.y /= len; }
    CGPoint target = CGPointMake(_origin.x + v.x * _radius, _origin.y + v.y * _radius);
    if (!_active) {
        [TJTouch sendPoint:_origin down:YES finger:1];
        _active = YES; _last = _origin;
    }
    if (fabs(target.x - _last.x) > 0.5 || fabs(target.y - _last.y) > 0.5) {
        [TJTouch sendPoint:target down:YES finger:1];
        _last = target;
    }
}
- (void)releaseStick {
    if (!_active) return;
    [TJTouch sendPoint:_last down:NO finger:1];
    _active = NO; _last = _origin;
}
@end

#pragma mark - 键位状态表
static NSMutableDictionary<NSNumber *, NSNumber *> *gKeyState = nil;
static inline NSNumber *KeyID(NSInteger page, NSInteger usage) {
    return @((page << 16) | (usage & 0xFFFF));
}
static BOOL KeyDown(NSInteger page, NSInteger usage) {
    return [gKeyState[KeyID(page, usage)] boolValue];
}

#pragma mark - HID 监听
static IOHIDEventSystemClientRef gMon = NULL;

static void TJHIDCallback(void *target, void *refcon, IOHIDEventServiceRef service, IOHIDEventRef event) {
    if (!event) return;
    if (IOHIDEventGetType(event) != kIOHIDEventTypeKeyboard) return;

    NSInteger page  = (NSInteger)IOHIDEventGetIntegerValue(event, kFieldKeyboardUsagePage);
    NSInteger usage = (NSInteger)IOHIDEventGetIntegerValue(event, kFieldKeyboardUsage);
    BOOL down       = IOHIDEventGetIntegerValue(event, kFieldKeyboardDown) != 0;

    if (down && TJEditorCaptureKey(page, usage)) return;   // 编辑模式下被吃掉

    if (!gKeyState) gKeyState = [NSMutableDictionary dictionary];
    gKeyState[KeyID(page, usage)] = @(down ? 1 : 0);
}

@interface TJInput : NSObject
+ (instancetype)shared;
- (void)startMonitoring;
@end

@implementation TJInput
+ (instancetype)shared { static TJInput *i; static dispatch_once_t o; dispatch_once(&o, ^{ i = [TJInput new]; }); return i; }
- (void)startMonitoring {
    if (gMon) return;
    gMon = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!gMon) return;
    IOHIDEventSystemClientRegisterEventCallback(gMon, TJHIDCallback, NULL, NULL);
    IOHIDEventSystemClientScheduleWithRunLoop(gMon, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    gKeyState = [NSMutableDictionary dictionary];
}
@end

#pragma mark - 映射引擎:每帧按绑定表注入
@interface TJKeymap : NSObject
+ (instancetype)shared;
- (void)refresh;
@end

@implementation TJKeymap {
    NSTimer *_tick;
    NSArray<TJBinding *> *_binds;
    NSMutableDictionary<NSNumber *, NSNumber *> *_holdActive;   // index -> 1
    NSMutableDictionary<NSNumber *, NSNumber *> *_edge;        // index -> 1(已触发)
}
+ (instancetype)shared { static TJKeymap *m; static dispatch_once_t o; dispatch_once(&o, ^{ m = [TJKeymap new]; }); return m; }

- (instancetype)init {
    if ((self = [super init])) {
        _holdActive = [NSMutableDictionary dictionary];
        _edge = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)refresh {
    NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:@"com.example.tjgamepad"];
    BOOL on = [u boolForKey:@"keymap"];

    [_tick invalidate]; _tick = nil;
    [_holdActive removeAllObjects];
    [_edge removeAllObjects];
    [[TJStick shared] releaseStick];
    [[TJRapidTap shared] stop];

    if (!on) return;

    [[TJInput shared] startMonitoring];
    _binds = [TJKeymapStore load];

    _tick = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0 repeats:YES block:^(NSTimer *t) {
        [self step];
    }];
}

- (void)step {
    if ([[TJEditor shared] opened]) return;   // 编辑时暂停映射

    // ---- WASD -> 虚拟摇杆(finger 1)----
    CGFloat vx = 0, vy = 0;
    if (KeyDown(0x07, 0x1A)) vy -= 1;   // W
    if (KeyDown(0x07, 0x16)) vy += 1;   // S
    if (KeyDown(0x07, 0x04)) vx -= 1;   // A
    if (KeyDown(0x07, 0x07)) vx += 1;   // D
    if (vx == 0 && vy == 0) [[TJStick shared] releaseStick];
    else [[TJStick shared] setVector:CGPointMake(vx, vy)];

    for (NSInteger i = 0; i < _binds.count; i++) {
        TJBinding *b = _binds[i];
        BOOL down = KeyDown(b.page, b.usage);
        uint32_t finger = (uint32_t)(i + 2);   // 1 留给摇杆
        CGPoint p = CGPointMake(b.x, b.y);

        switch (b.type) {
            case TJBindTypeHold: {
                BOOL act = [_holdActive[@(i)] boolValue];
                if (down && !act) { _holdActive[@(i)] = @1; [TJTouch sendPoint:p down:YES finger:finger]; }
                if (!down && act) { [_holdActive removeObjectForKey:@(i)]; [TJTouch sendPoint:p down:NO finger:finger]; }
                break;
            }
            case TJBindTypeTap: {
                BOOL act = [_edge[@(i)] boolValue];
                if (down && !act) { _edge[@(i)] = @1; [TJTouch tapAt:p]; }
                if (!down && act) { [_edge removeObjectForKey:@(i)]; }
                break;
            }
            case TJBindTypeRapid: {
                if (down) {
                    TJRapidTap *r = [TJRapidTap shared];
                    r.cps = b.cps ?: 14;
                    [r startAt:p];
                } else {
                    [[TJRapidTap shared] stop];
                }
                break;
            }
        }
    }
}
@end

void TJStartKeymap(void) { [[TJKeymap shared] refresh]; }
void TJStopKeymap(void)  { [[TJStick shared] releaseStick]; [[TJRapidTap shared] stop]; }
