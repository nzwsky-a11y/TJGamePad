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

    IOHIDEventRef hand = IOHIDEventCreateDigitizerEvent(
        kCFAllocatorDefault, t,
        3, 0, 0,
        0, 0,
        1,
        0, 0,
        0, 0, 0, 0,
        0);

    IOHIDEventRef f = IOHIDEventCreateDigitizerFingerEvent(
        kCFAllocatorDefault, t,
        finger,        // index
        finger + 1,    // identity
        p.x, p.y,
        down ? 1 : 0,
        1,
        0, 0,
        0);

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
