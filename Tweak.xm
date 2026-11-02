#import <UIKit/UIKit.h>
#import "HIDEvent.h"
#import "TJEditor.h"
#import "TJKeymapStore.h"
#import "TJRapidPad.h"

extern void TJStartKeymap(void);
extern void TJStopKeymap(void);

// 简易配置存储 —— 对应原版 ldys3_* 那套 NSUserDefaults
static NSString *const kSuite = @"com.example.gamepad";
static NSUserDefaults *Cfg(void) {
    static NSUserDefaults *u;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ u = [[NSUserDefaults alloc] initWithSuiteName:kSuite]; });
    return u;
}

@interface TJBall : UIWindow
@end

@interface TJPanel : UIWindow <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) NSArray *items;
@end

@implementation TJBall {
    CGPoint _start;
    BOOL _moved;
}
- (instancetype)init {
    CGRect f = CGRectMake(20, 200, 56, 56);
    self = [super initWithFrame:f];
    if (!self) return nil;
    self.windowLevel = UIWindowLevelAlert + 100;
    self.backgroundColor = [UIColor clearColor];
    self.rootViewController = [UIViewController new];
    self.hidden = NO;

    UIView *ball = [[UIView alloc] initWithFrame:self.bounds];
    ball.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    ball.layer.cornerRadius = 28;
    ball.layer.borderWidth = 1.5;
    ball.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.5].CGColor;
    UILabel *l = [[UILabel alloc] initWithFrame:ball.bounds];
    l.text = @"G";
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont boldSystemFontOfSize:24];
    l.textAlignment = NSTextAlignmentCenter;
    [ball addSubview:l];
    ball.userInteractionEnabled = NO;
    [self.rootViewController.view addSubview:ball];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
    [self addGestureRecognizer:pan];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
    [self addGestureRecognizer:tap];
    return self;
}
- (void)onPan:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:nil];
    if (g.state == UIGestureRecognizerStateBegan) _start = self.center;
    if (g.state == UIGestureRecognizerStateChanged) {
        self.center = CGPointMake(_start.x + t.x, _start.y + t.y);
        if (fabs(t.x) + fabs(t.y) > 8) _moved = YES;
    }
    if (g.state == UIGestureRecognizerStateEnded) {
        // 吸附左右边
        CGRect s = [UIScreen mainScreen].bounds;
        CGFloat x = self.center.x < s.size.width / 2 ? 28 + 12 : s.size.width - 28 - 12;
        [UIView animateWithDuration:0.2 animations:^{ self.center = CGPointMake(x, self.center.y); }];
    }
}
- (void)onTap {
    [[TJPanel shared] toggle];
}
+ (instancetype)shared {
    static TJBall *b; static dispatch_once_t o;
    dispatch_once(&o, ^{ b = [TJBall new]; });
    return b;
}
@end

@implementation TJPanel {
    UITableView *_table;
}
+ (instancetype)shared {
    static TJPanel *p; static dispatch_once_t o;
    dispatch_once(&o, ^{ p = [TJPanel new]; });
    return p;
}
- (instancetype)init {
    CGFloat w = 300, h = 260;
    CGRect s = [UIScreen mainScreen].bounds;
    self = [super initWithFrame:CGRectMake((s.size.width - w) / 2, (s.size.height - h) / 2, w, h)];
    if (!self) return nil;
    self.windowLevel = UIWindowLevelAlert + 101;
    self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    self.layer.cornerRadius = 14;
    self.clipsToBounds = YES;
    self.hidden = YES;

    UIViewController *vc = [UIViewController new];
    self.rootViewController = vc;
    _table = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
    _table.backgroundColor = [UIColor clearColor];
    _table.delegate = self;
    _table.dataSource = self;
    [vc.view addSubview:_table];

    self.items = @[
        @{@"t": @"键鼠映射 (WASD + 左键)", @"k": @"keymap"},
        @{@"t": @"手搓速点区 (按住即速点)", @"k": @"rapidpad"},
        @{@"t": @"调整速点区位置", @"k": @"rapidpadadj"},
        @{@"t": @"速点模式 (键鼠左键)", @"k": @"rapid"},
        @{@"t": @"速点频率", @"k": @"rapidcps"},
        @{@"t": @"编辑键位(拖动/绑定)", @"k": @"editor"},
        @{@"t": @"恢复默认键位", @"k": @"resetbind"},
        @{@"t": @"自动连点(演示)", @"k": @"autofire"},
        @{@"t": @"显示准心", @"k": @"crosshair"},
        @{@"t": @"扫描一次点击测试", @"k": @"tapdemo"},
    ];
    return self;
}
- (void)toggle {
    self.hidden = !self.hidden;
    [_table reloadData];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.items.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"];
    c.backgroundColor = [UIColor clearColor];
    c.textLabel.textColor = [UIColor whiteColor];
    c.textLabel.text = self.items[ip.row][@"t"];
    NSString *k = self.items[ip.row][@"k"];
    if ([k isEqualToString:@"editor"] || [k isEqualToString:@"resetbind"] ||
        [k isEqualToString:@"rapidpadadj"]) {
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }
    if ([k isEqualToString:@"rapidcps"]) {
        NSInteger cps = [Cfg() integerForKey:@"rapidCPS"] ?: 14;
        c.textLabel.text = [NSString stringWithFormat:@"速点频率  %ld 发/秒", (long)cps];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }
    if (![k isEqualToString:@"tapdemo"]) {
        UISwitch *sw = [UISwitch new];
        sw.on = [Cfg() boolForKey:k];
        sw.tag = 1000 + ip.row;
        [sw addTarget:self action:@selector(onSwitch:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
    }
    return c;
}
- (void)onSwitch:(UISwitch *)sw {
    NSString *k = self.items[sw.tag - 1000][@"k"];
    [Cfg() setBool:sw.on forKey:k];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TJConfigChanged" object:k];
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    NSString *kk = self.items[ip.row][@"k"];
    if ([kk isEqualToString:@"rapidpadadj"]) {
        TJRapidPad *pad = [TJRapidPad shared];
        [pad refresh];
        if (pad.adjusting) { [pad endAdjust]; }
        else { [pad beginAdjust]; }
        [_table reloadData];
        return;
    }
    if ([kk isEqualToString:@"resetbind"]) {
        NSUserDefaults *u = [[NSUserDefaults alloc] initWithSuiteName:@"com.example.tjgamepad"];
        [u removeObjectForKey:@"bindings"];
        [u synchronize];
        [TJKeymapStore ensureDefaults];
        [[TJRapidPad shared] refresh];
        TJStartKeymap();
        return;
    }
    if ([kk isEqualToString:@"editor"]) {
        [[TJEditor shared] open];
        return;
    }
    if ([kk isEqualToString:@"rapidcps"]) {
        NSInteger cps = [Cfg() integerForKey:@"rapidCPS"] ?: 14;
        cps = cps >= 30 ? 8 : cps + 6;              // 8 → 14 → 20 → 26 → 30 → 8 循环
        if (cps > 30) cps = 30;
        [Cfg() setInteger:cps forKey:@"rapidCPS"];
        [_table reloadData];
        return;
    }
    if ([kk isEqualToString:@"tapdemo"]) {
        CGPoint c = CGPointMake([UIScreen mainScreen].bounds.size.width / 2,
                                [UIScreen mainScreen].bounds.size.height / 2);
        [TJTouch tapAt:c];
    }
}
@end

// 自动连点演示:对应原版"宏/连点"能力的最小实现
@interface TJAutoFire : NSObject
@property (nonatomic, strong) NSTimer *timer;
+ (instancetype)shared;
- (void)refresh;
@end

@implementation TJAutoFire
+ (instancetype)shared { static TJAutoFire *a; static dispatch_once_t o; dispatch_once(&o, ^{ a = [TJAutoFire new]; }); return a; }
- (void)refresh {
    [self.timer invalidate]; self.timer = nil;
    if (![Cfg() boolForKey:@"autofire"]) return;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.12 repeats:YES block:^(NSTimer *t) {
        CGPoint p = CGPointMake([UIScreen mainScreen].bounds.size.width * 0.75, 400);
        [TJTouch tapAt:p];
    }];
}
@end


#pragma mark - 准心
@interface TJCross : UIWindow
+ (instancetype)shared;
- (void)refresh;
@end

@implementation TJCross
+ (instancetype)shared { static TJCross *c; static dispatch_once_t o; dispatch_once(&o, ^{ c = [TJCross new]; }); return c; }
- (instancetype)init {
    self = [super initWithFrame:CGRectMake(0, 0, 40, 40)];
    if (!self) return nil;
    self.windowLevel = UIWindowLevelAlert + 99;
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    self.rootViewController = [UIViewController new];
    UILabel *l = [[UILabel alloc] initWithFrame:self.bounds];
    l.text = @"+";
    l.textColor = [UIColor colorWithRed:0 green:1 blue:0.3 alpha:0.9];
    l.font = [UIFont boldSystemFontOfSize:30];
    l.textAlignment = NSTextAlignmentCenter;
    [self.rootViewController.view addSubview:l];
    self.hidden = YES;
    return self;
}
- (void)refresh {
    BOOL on = [Cfg() boolForKey:@"crosshair"];
    CGPoint c = CGPointMake([UIScreen mainScreen].bounds.size.width / 2,
                            [UIScreen mainScreen].bounds.size.height / 2);
    self.center = c;
    self.hidden = !on;
}
@end

__attribute__((constructor)) static void TJInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [TJTouch start];
        [TJKeymapStore ensureDefaults];
        [[TJRapidPad shared] refresh];
        [TJBall shared];
        [[NSNotificationCenter defaultCenter] addObserverForName:@"TJConfigChanged" object:nil queue:nil
            usingBlock:^(NSNotification *n){
                [[TJAutoFire shared] refresh];
                TJStartKeymap();
                [[TJCross shared] refresh];
                [[TJRapidPad shared] refresh];
            }];
        [[TJAutoFire shared] refresh];
        TJStartKeymap();
        [[TJCross shared] refresh];
    });
}
