#import "TJEditor.h"

#pragma mark - 可拖动的点
@interface TJDot : UIView
@property (nonatomic, assign) NSInteger index;
@end

@implementation TJDot
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.75];
        self.layer.cornerRadius = f.size.width / 2;
        self.layer.borderWidth = 2;
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        self.userInteractionEnabled = YES;
    }
    return self;
}
@end

static BOOL gCapturing = NO;
static TJDot *gSelected = nil;
static NSMutableArray<TJBinding *> *gList = nil;

BOOL TJEditorCaptureKey(NSInteger page, NSInteger usage) {
    if (!gCapturing || !gSelected) return NO;
    TJBinding *b = gList[gSelected.index];
    b.page = page;
    b.usage = usage;
    gCapturing = NO;
    [TJKeymapStore save:gList];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TJEditorRefresh" object:nil];
    return YES;
}

@implementation TJEditor {
    UIView *_bar;
    UILabel *_hint;
}

+ (instancetype)shared {
    static TJEditor *e; static dispatch_once_t o;
    dispatch_once(&o, ^{ e = [TJEditor new]; });
    return e;
}

- (instancetype)init {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (!self) return nil;
    self.windowLevel = UIWindowLevelAlert + 200;
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.15];
    self.hidden = YES;
    self.rootViewController = [UIViewController new];

    // 底部工具条
    _bar = [[UIView alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - 96,
                                                    self.bounds.size.width, 96)];
    _bar.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.9];
    [self.rootViewController.view addSubview:_bar];

    NSArray *titles = @[@"＋ 新增", @"绑定按键", @"改类型", @"删除", @"完成"];
    CGFloat w = self.bounds.size.width / titles.count;
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(i * w, 44, w, 44);
        [b setTitle:titles[i] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.tag = 100 + i;
        [b addTarget:self action:@selector(onAction:) forControlEvents:UIControlEventTouchUpInside];
        [_bar addSubview:b];
    }

    _hint = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, self.bounds.size.width - 24, 32)];
    _hint.textColor = [UIColor whiteColor];
    _hint.font = [UIFont systemFontOfSize:13];
    _hint.text = @"拖动圆点定位;选中后点「绑定按键」再按键盘";
    [_bar addSubview:_hint];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"TJEditorRefresh" object:nil queue:nil
        usingBlock:^(NSNotification *n){ [self rebuild]; }];
    return self;
}

- (void)open {
    self.hidden = NO;
    gList = [[TJKeymapStore load] mutableCopy] ?: [NSMutableArray array];
    [self rebuild];
}
- (void)close {
    self.hidden = YES;
    [TJKeymapStore save:gList];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TJConfigChanged" object:nil];
}
- (BOOL)opened { return !self.hidden; }

- (void)rebuild {
    for (UIView *v in self.rootViewController.view.subviews) {
        if ([v isKindOfClass:[TJDot class]]) [v removeFromSuperview];
    }
    if (!gList) gList = [[TJKeymapStore load] mutableCopy] ?: [NSMutableArray array];

    for (NSInteger i = 0; i < gList.count; i++) {
        TJBinding *b = gList[i];
        TJDot *d = [[TJDot alloc] initWithFrame:CGRectMake(0, 0, 46, 46)];
        d.center = CGPointMake(b.x, b.y);
        d.index = i;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
        [d addGestureRecognizer:pan];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onPick:)];
        [d addGestureRecognizer:tap];

        UILabel *l = [[UILabel alloc] initWithFrame:d.bounds];
        l.text = b.keyName;
        l.font = [UIFont boldSystemFontOfSize:11];
        l.textColor = [UIColor whiteColor];
        l.textAlignment = NSTextAlignmentCenter;
        l.userInteractionEnabled = NO;
        [d addSubview:l];

        [self.rootViewController.view addSubview:d];
        if (gSelected && gSelected.index == i) gSelected = d;
    }
}

- (void)onPan:(UIPanGestureRecognizer *)g {
    TJDot *d = (TJDot *)g.view;
    CGPoint t = [g translationInView:self];
    d.center = CGPointMake(d.center.x + t.x, d.center.y + t.y);
    [g setTranslation:CGPointZero inView:self];
    gList[d.index].x = d.center.x;
    gList[d.index].y = d.center.y;
    if (g.state == UIGestureRecognizerStateEnded) [TJKeymapStore save:gList];
}

- (void)onPick:(UITapGestureRecognizer *)g {
    TJDot *d = (TJDot *)g.view;
    for (UIView *v in self.rootViewController.view.subviews) {
        if ([v isKindOfClass:[TJDot class]]) ((TJDot *)v).backgroundColor =
            [UIColor colorWithRed:0.2 green:0.6 blue:1 alpha:0.75];
    }
    d.backgroundColor = [UIColor colorWithRed:1 green:0.45 blue:0.2 alpha:0.9];
    gSelected = d;
    _hint.text = [NSString stringWithFormat:@"已选中 #%ld  %@", (long)d.index, gList[d.index].keyName];
}

- (void)onAction:(UIButton *)b {
    NSInteger idx = b.tag - 100;
    switch (idx) {
        case 0: {   // 新增
            TJBinding *nb = [TJBinding new];
            nb.x = self.bounds.size.width / 2;
            nb.y = self.bounds.size.height / 2;
            nb.page = 0x07; nb.usage = 0x1A; nb.type = TJBindTypeTap; nb.cps = 14;
            [gList addObject:nb];
            [TJKeymapStore save:gList];
            [self rebuild];
            _hint.text = @"已新增一个点,拖到目标位置再绑定按键";
            break;
        }
        case 1: {   // 绑定
            if (!gSelected) { _hint.text = @"先点一个圆点选中它"; return; }
            gCapturing = YES;
            _hint.text = @"请按下要绑定的键(键盘或鼠标)…";
            break;
        }
        case 2: {   // 改类型
            if (!gSelected) { _hint.text = @"先点一个圆点选中它"; return; }
            TJBinding *b2 = gList[gSelected.index];
            b2.type = (TJBindType)((b2.type + 1) % 3);
            [TJKeymapStore save:gList];
            NSString *n = b2.type == TJBindTypeTap ? @"点按" : (b2.type == TJBindTypeHold ? @"按住" : @"速点");
            _hint.text = [NSString stringWithFormat:@"#%ld 类型 → %@", (long)gSelected.index, n];
            break;
        }
        case 3: {   // 删除
            if (!gSelected) { _hint.text = @"先点一个圆点选中它"; return; }
            [gList removeObjectAtIndex:gSelected.index];
            gSelected = nil;
            [TJKeymapStore save:gList];
            [self rebuild];
            _hint.text = @"已删除";
            break;
        }
        case 4:     // 完成
            [self close];
            break;
    }
}

@end
