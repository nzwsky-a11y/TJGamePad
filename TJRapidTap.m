#import "TJRapidTap.h"
#import "HIDEvent.h"
#include <unistd.h>
#include <stdlib.h>

@implementation TJRapidTap {
    dispatch_queue_t _q;
    BOOL _running;
    CGPoint _pt;
}

+ (instancetype)shared {
    static TJRapidTap *r; static dispatch_once_t o;
    dispatch_once(&o, ^{ r = [TJRapidTap new]; });
    return r;
}

- (instancetype)init {
    if ((self = [super init])) {
        _q = dispatch_queue_create("com.example.tjgamepad.rapid", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_q, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0));
        _cps = 14;
        _jitter = 0.25;
        _pressDuration = 0.008;   // 8ms 按下,足够游戏识别成一次点击
        _running = NO;
    }
    return self;
}

- (BOOL)running { return _running; }

- (void)startAt:(CGPoint)p {
    if (_running) { _pt = p; return; }
    _pt = p;
    _running = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async(_q, ^{ [weakSelf loop]; });
}

- (void)stop {
    _running = NO;
}

- (void)loop {
    if (!_running) return;

    CGPoint p = _pt;

    // 一次"按下 → 保持 → 抬起"
    [TJTouch sendPoint:p down:YES];
    usleep((useconds_t)(_pressDuration * 1000000.0));
    [TJTouch sendPoint:p down:NO];

    if (!_running) return;

    // 间隔 = 1/cps,叠加 ±jitter/2 的随机抖动
    double base = 1.0 / MAX(1, _cps);
    double rnd  = (double)arc4random() / (double)UINT32_MAX;      // 0..1
    double k    = 1.0 - _jitter * 0.5 + _jitter * rnd;            // 0.875..1.125 (jitter=0.25)
    double iv   = base * k;

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(iv * NSEC_PER_SEC)), _q, ^{
        [weakSelf loop];
    });
}

@end
