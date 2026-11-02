#import "TJRapidPad.h"
#import "TJRapidTap.h"
#import "HIDEvent.h"

static NSString *const kSuite = @"com.example.tjgamepad";

@interface TJPadView : UIView
@end
@implementation TJPadView
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor colorWithWhite:1 alpha:0.02];  // 几乎不可见
        self.layer.cornerRadius = f.size.width / 2;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor colorWithRed:0 green:1 blue:0.4 alpha:0.25].CGColor;
        self.userInteractionEnabled = YES;
    }
    return self;
}
@end

@implementation TJRapidPad {
    TJPadView *_pad;
    BOOL _pressed;
}

+ (instancetype)shared {
    static TJRapidPad *p; static dispatch_once_t o;
    dispatch_once(&o, ^{ p = [TJRapidPad new]; });
    return p;
}

- (instancetype)init {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (!self) return nil;
    self.windowLevel = UIWindowLevelAlert + 98;
    self.backgroundColor = [UIColor clearColor];
    self.rootViewController = [UIViewController new];
    self.hidden = YES;

    _pad = [[TJPadView alloc] initWithFrame:CGRectMake(0, 0, 96, 96)];
    [self.rootViewController.view addSubview:_pad];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
    [_pad addGestureRecognizer:pan];

    UILongPressGestureRecognizer *press =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onPress:)];
    press.minimumPressDuration = 0;
    press.cancelsTouchesInView = NO;
    [_pad addGestureRecognizer:press];

    return self;
}

#pragma mark - 配置
- (void)refresh {
    NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    BOOL on = [u boolForKey:@"rapidpad"];

    CGFloat w = [u doubleForKey:@"rapidpadSize"] ?: 96;
    CGFloat x = [u doubleForKey:@"rapidpadX"] ?: ([UIScreen mainScreen].bounds.size.width * 0.8);
    CGFloat y = [u doubleForKey:@"rapidpadY"] ?: 330.0;

    _pad.frame = CGRectMake(0, 0, w, w);
    _pad.center = CGPointMake(x, y);
    _pad.layer.cornerRadius = w / 2;

    BOOL adjusting = [u boolForKey:@"rapidpadAdjust"];
    self.hidden = !(on || adjusting);
    _pad.layer.borderWidth = adjusting ? 2 : 1;
    _pad.layer.borderColor = adjusting
        ? [UIColor colorWithRed:1 green:0.6 blue:0 alpha:0.9].CGColor
        : [UIColor colorWithRed:0 green:1 blue:0.4 alpha:0.25].CGColor;
    _pad.backgroundColor = adjusting
        ? [UIColor colorWithWhite:1 alpha:0.12]
        : [UIColor colorWithWhite:1 alpha:0.02];
}

- (BOOL)adjusting {
    return [[[NSUserDefaults alloc] initWithSuiteName:kSuite] boolForKey:@"rapidpadAdjust"];
}

// 关键:窗口是全屏的,但除了那小块热区以外必须"透明穿过",否则会挡住游戏所有触摸
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden) return nil;
    CGRect r = [_pad convertRect:_pad.bounds toView:self];
    if (CGRectContainsPoint(r, point)) {
        return [_pad hitTest:[self convertPoint:point toView:_pad] withEvent:event];
    }
    return nil;
}

- (void)beginAdjust {
    NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    [u setBool:YES forKey:@"rapidpadAdjust"];
    [u synchronize];
    [self refresh];
}
- (void)endAdjust {
    NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    [u setBool:NO forKey:@"rapidpadAdjust"];
    [u synchronize];
    [self refresh];
}

#pragma mark - 交互
- (void)onPan:(UIPanGestureRecognizer *)g {
    if (!self.adjusting) return;
    CGPoint t = [g translationInView:self];
    _pad.center = CGPointMake(_pad.center.x + t.x, _pad.center.y + t.y);
    [g setTranslation:CGPointZero inView:self];
    if (g.state == UIGestureRecognizerStateEnded ||
        g.state == UIGestureRecognizerStateCancelled) {
        NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
        [u setDouble:_pad.center.x forKey:@"rapidpadX"];
        [u setDouble:_pad.center.y forKey:@"rapidpadY"];
        [u synchronize];
    }
}

- (void)onPress:(UILongPressGestureRecognizer *)g {
    if (self.adjusting) return;

    NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:kSuite];
    if (![u boolForKey:@"rapidpad"]) { _pressed = NO; return; }

    if (g.state == UIGestureRecognizerStateBegan) {
        if (_pressed) return;
        _pressed = YES;
        TJRapidTap *r = [TJRapidTap shared];
        r.cps = MAX(5, [u integerForKey:@"rapidCPS"] ?: 14);
        [r startAt:_pad.center];
        UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [h impactOccurred];
    } else if (g.state == UIGestureRecognizerStateEnded ||
               g.state == UIGestureRecognizerStateCancelled ||
               g.state == UIGestureRecognizerStateFailed) {
        _pressed = NO;
        [[TJRapidTap shared] stop];
    }
}

@end
