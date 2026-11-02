#import "HIDEvent.h"

static IOHIDEventSystemClientRef gClient = NULL;

@implementation TJTouch

+ (void)start {
    if (!gClient) {
        gClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    }
}

+ (void)sendPoint:(CGPoint)p down:(BOOL)down {
    [self sendPoint:p down:down finger:1];
}

// finger 从 1 开始;不同 bind 用不同 finger 才能同时按住多个点
+ (void)sendPoint:(CGPoint)p down:(BOOL)down finger:(uint32_t)finger {
    if (!gClient) [self start];
    if (!gClient) return;
    if (finger < 1) finger = 1;

    uint64_t t = mach_absolute_time();

    // 手事件:16 个参数,全部按 Apple 原型的顺序
    IOHIDEventRef hand = IOHIDEventCreateDigitizerEvent(
        kCFAllocatorDefault,
        t,                          // timeStamp
        3,                          // transducerType: kIOHIDDigitizerTransducerTypeHand
        0,                          // index
        0,                          // identity
        0,                          // eventMask
        0,                          // buttonMask
        0.0, 0.0, 0.0,              // x, y, z
        0.0, 0.0,                   // tipPressure, barrelPressure
        1,                          // range  = 在屏幕内
        0,                          // touch
        0,                          // options
        0);                         // senderID

    // 手指事件:12 个参数
    IOHIDEventRef f = IOHIDEventCreateDigitizerFingerEvent(
        kCFAllocatorDefault,
        t,                          // timeStamp
        finger,                     // index
        finger + 1,                 // identity
        p.x, p.y, 0.0,              // x, y, z
        1.0,                        // tipPressure
        0.0,                        // twist
        1,                          // range
        down ? 1 : 0,               // touch
        0);                         // options

    IOHIDEventAppendEvent(hand, f, 0);
    IOHIDEventSetIntegerValue(hand, kFieldDigitizerIsDisplayIntegrated, 1);
    IOHIDEventSystemClientDispatchEvent(gClient, hand);

    CFRelease(f);
    CFRelease(hand);
}

+ (void)tapAt:(CGPoint)p {
    [self sendPoint:p down:YES finger:1];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)),
                   dispatch_get_global_queue(0, 0), ^{
        [self sendPoint:p down:NO finger:1];
    });
}

+ (void)swipeFrom:(CGPoint)a to:(CGPoint)b duration:(NSTimeInterval)d {
    const int steps = 14;
    [self sendPoint:a down:YES finger:1];
    for (int i = 1; i <= steps; i++) {
        double k = (double)i / steps;
        CGPoint p = CGPointMake(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d * k * NSEC_PER_SEC)),
                       dispatch_get_global_queue(0, 0), ^{
            [TJTouch sendPoint:p down:YES finger:1];
        });
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((d + 0.03) * NSEC_PER_SEC)),
                   dispatch_get_global_queue(0, 0), ^{
        [TJTouch sendPoint:b down:NO finger:1];
    });
}

@end
