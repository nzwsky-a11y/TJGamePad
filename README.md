# TJGamePad —— 按逆向结果复刻的"游戏厅"

> iPhone 13 Pro / iOS 15.5 / Dopamine(roothide)
> 从零复刻的同架构实现（不含原版任何代码或资源）

## 功能现状

| 功能 | 状态 | 说明 |
|---|---|---|
| 悬浮球（拖动/吸附/点击开面板） | ✅ | `TJBall` |
| 设置面板（开关持久化） | ✅ | `TJPanel` + NSUserDefaults |
| **HID 触摸注入** | ✅ | `TJTouch`，整套功能的地基 |
| **键鼠映射**（WASD → 摇杆，左键 → 开火） | ✅ | `TJInput.m`（IOHID 监听 + 30Hz 映射引擎） |
| **速点（按住高频连点，频率/抖动可调）** | ✅ | `TJRapidTap.m`（5~30 发/秒，独立高优先级队列） |
| **虚拟摇杆** | ✅ | `TJStick`，按下原点 + 按向量移动 + 松手抬起 |
| 准心 | ✅ | `TJCross` |
| 自动连点 / 宏（演示） | ✅ | `TJAutoFire` |
| **键位自定义 UI（拖点 + 按键绑定）** | ✅ | `TJEditor.m` + `TJKeymapStore.m`（JSON 持久化） |
| **手搓速点区（纯触屏，按住即速点）** | ✅ | `TJRapidPad.m`（盖在开火键上的透明热区） |
| 压枪（OpenCV 识别 + 反向拖动） | — | 需求方明确不需要，未实现 |
| 键位自定义 UI / 分享码 / 云同步 | ⬜ | 纯业务层 |

## 1. 原理（一句话）

原版所有"按键、摇杆、宏、压枪"最终都收敛到同一个原语：

```objc
IOHIDEventCreateDigitizerFingerEvent(..., x, y, touch, ...)   // 造一根手指
IOHIDEventAppendEvent(hand, finger);
IOHIDEventSystemClientDispatchEvent(client, hand);            // 系统当成真手指
```

本复刻完整实现了这一层，剩下的都是在它上面拼坐标。

反向那一半是键盘/鼠标输入：

```objc
IOHIDEventSystemClientCreate();
IOHIDEventSystemClientRegisterEventCallback(client, cb, 0, 0);
IOHIDEventSystemClientScheduleWithRunLoop(client, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
// cb 里读 usagePage(0x07 键盘 / 0x09 鼠标) + usage + down
```

## 2. 目录

```
clone/
├── Makefile                        Theos 构建(arm64 + arm64e)
├── control / TJGamePad.plist       包信息 + 只注入 SpringBoard
├── Tweak.xm                        悬浮球 / 面板 / 准心 / 自动连点 / 启动装配
├── TJTouch.m                       触摸注入
├── TJInput.m                       键鼠监听 + 摇杆 + 映射引擎
├── include/HIDEvent.h              私有 API 声明
└── .github/workflows/build.yml     推上去自动出 deb
```

## 3. 编译

**GitHub Actions（不需要 Mac）**：把 `clone/` 推到仓库 → Actions 跑完 → 下载 artifact 里的 `.deb`。

**本机 Theos**：
```bash
export THEOS=~/theos          # $THEOS/sdks/ 里要有 iPhoneOS15.x.sdk
cd clone && make package FINALPACKAGE=1
```

安装：deb 丢进 Filza 点安装 → `sbreload`。

## 4. 用起来

装上 3 秒后桌面出现半透明 **G** 球：

- 拖动 → 移动，松手吸附边缘
- 点击 → 打开面板

面板开关：

| 开关 | 效果 |
|---|---|
| **手搓速点区 (按住即速点)** | 开火键上盖一个透明热区，手指按住就以设定频率替你点射，松手即停 |
| **调整速点区位置** | 热区变橙色可拖动，拖到游戏开火键正上方再点一次结束 |
| **键鼠映射 (WASD + 左键)** | 连上蓝牙键鼠后，W/A/S/D 驱动屏幕左下摇杆，左键在屏幕右侧开火 |
| **速点模式 (左键按住连点)** | 左键按住时按设定频率持续注入"按下-抬起"循环 |
| 速点频率 | 点一下循环切换：8 → 14 → 20 → 26 → 30 发/秒 |
| 自动连点 | 每 0.12s 往右侧注入一次点击（不按键的自动版，用于挂机演示） |
| 显示准心 | 屏幕正中绿色十字，独立 UIWindow，不挡触摸 |
| 点击测试 | 往屏幕正中注入一次点击，用来验证注入链路 |

### 速点引擎细节

```
每次点击:  down → 保持 8ms → up
间隔:      1/cps × (1 ± jitter/2)     默认 cps=14, jitter=0.25
线程:      专用串行队列 + QOS_CLASS_USER_INTERACTIVE,不占主线程
```

- **8ms 按下时间**：太短游戏可能识别成一帧滑动，太长会吃掉下一发；8~12ms 是通用安全区，可在 `TJRapidTap -init` 里调
- **抖动 25%**：避免固定节拍被轨迹特征识别，手感也更像真人点射
- **松手立即停**：`stop` 只置标志位，循环下一拍自然退出，不会卡住手指不抬起

**首次启动会自动生成默认键位**：左键=右侧开火位（速点 14 发/秒）、右键=开镜（按住）、WASD=左下摇杆。想改就在面板里进「编辑键位」。

**摇杆原点默认 `(120, 屏幕高-170)`**，对应和平精英默认位置；换游戏改 `TJStick -init` 里的 `_origin` 和 `_radius`。

## 5. 键位自定义（换游戏不用改代码）

面板 → **编辑键位(拖动/绑定)**，进入编辑模式（此时映射暂停，不会误触）：

| 按钮 | 作用 |
|---|---|
| ＋ 新增 | 在屏幕中央生成一个圆点 |
| 拖动圆点 | 移到游戏里目标按钮的位置 |
| 点圆点选中 | 变橙色 = 已选中 |
| 绑定按键 | 提示"请按键"，**按一下键盘/鼠标即绑定** |
| 改类型 | 在 点按 → 按住 → 速点 之间循环 |
| 删除 | 删掉选中的点 |
| 完成 | 保存并退出，映射立即生效 |

绑定数据以 JSON 存在 NSUserDefaults（键 `bindings`），每条：

```json
{"x": 640, "y": 300, "page": 7, "usage": 26, "type": 2, "cps": 14}
```

- `page/usage` 是 HID 原始码：`page=7` 键盘（W=0x1A、A=0x04…），`page=9` 鼠标（左键=0x01）
- `type`：`0` 点按、`1` 按住（长按开镜/持续开火）、`2` 速点
- 每个绑定用**独立 finger 序号**注入，所以可以同时按住多个点（摇杆 + 开镜 + 开火并行）

## 6. 手搓模式（不用键鼠）

手机上直接玩（手搓）的话，键鼠映射整块都用不上，只需要：

1. 面板里打开 **手搓速点区**
2. 点 **调整速点区位置** → 一个橙色圆圈出现，拖到游戏**开火键**上 → 再点一次该菜单结束
3. 进游戏，手指按在那个位置：按住即以 **速点频率**（默认 14 发/秒，面板可调）持续点射，松手立刻停

实现要点：

```objc
// 窗口是全屏的，但除了热区以外必须放行，否则会挡住游戏所有触摸
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden) return nil;
    if (CGRectContainsPoint(padRectInWindow, point)) return [pad hitTest:...];
    return nil;
}
```

- 热区透明（运行时不显示边框），不影响观感
- 触感反馈：按下时一次轻震动，确认已识别
- 热区大小默认 96×96，可直接改 `TJRapidPad -init` 里的 `CGRectMake(0,0,96,96)`

## 7. 注意

- `include/HIDEvent.h` 里的 `kFieldKeyboard*` 数值是 iOS 15 实测值，换 iOS 版本可能要校准；若键位收不到，先把 `TJHIDCallback` 里收到的 `usagePage/usage/down` 全打出来对齐。
- 摇杆/连点目标坐标是按和平精英布局写的，其他游戏自己改坐标。
- 装完 SpringBoard 起不来：删 `/Library/MobileSubstrate/DynamicLibraries/TJGamePad.dylib`（roothide 下是 `/var/jb/同路径`）后 respring。
- 它和原版一样走系统 HID，游戏侧看到的是真实触摸 —— 反作弊风险自负。
