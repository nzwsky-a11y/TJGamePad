#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <mach/mach_time.h>

// ---------- IOHID 私有类型 ----------
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef struct __IOHIDEventSystem *IOHIDEventSystemRef;
typedef struct __IOHIDEventService *IOHIDEventServiceRef;

// ---------- 事件类型 ----------
#define kIOHIDEventTypeKeyboard 3

// ---------- 字段编号(iOS 15 实测值,换版本可能要校准) ----------
#define kFieldDigitizerIsDisplayIntegrated 0x000B0000
#define kFieldKeyboardUsagePage            0x00030000
#define kFieldKeyboardUsage                0x00030001
#define kFieldKeyboardDown                 0x00030002

// ---------- 合成事件 ----------
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef);
extern void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef, IOHIDEventRef);
extern IOHIDEventRef IOHIDEventCreateDigitizerEvent(CFAllocatorRef allocator, uint64_t timeStamp,
                                                    uint32_t transducerType, uint32_t index, uint32_t identity,
                                                    uint32_t eventMask, uint32_t buttonMask,
                                                    double x, double y, double z,
                                                    double tipPressure, double barrelPressure,
                                                    uint32_t range, uint32_t touch,
                                                    uint32_t options, uint32_t senderID);

extern IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(CFAllocatorRef allocator, uint64_t timeStamp,
                                                          uint32_t index, uint32_t identity,
                                                          double x, double y, double z,
                                                          double tipPressure, double twist,
                                                          uint32_t range, uint32_t touch,
                                                          uint32_t options);

extern void IOHIDEventAppendEvent(IOHIDEventRef, IOHIDEventRef, uint32_t);
extern void IOHIDEventSetIntegerValue(IOHIDEventRef, uint32_t, int64_t);

// ---------- 监听事件 ----------
typedef void (*TJEventCallback)(void *target, void *refcon, IOHIDEventServiceRef service, IOHIDEventRef event);
extern void IOHIDEventSystemClientRegisterEventCallback(IOHIDEventSystemClientRef, TJEventCallback,
                                                        void *, void *);
extern void IOHIDEventSystemClientScheduleWithRunLoop(IOHIDEventSystemClientRef, CFRunLoopRef, CFStringRef);
extern int  IOHIDEventGetType(IOHIDEventRef);
extern int64_t IOHIDEventGetIntegerValue(IOHIDEventRef, uint32_t);

// ---------- 触摸注入 ----------
@interface TJTouch : NSObject
+ (void)start;
+ (void)sendPoint:(CGPoint)p down:(BOOL)down;
+ (void)sendPoint:(CGPoint)p down:(BOOL)down finger:(uint32_t)finger;
+ (void)tapAt:(CGPoint)p;
+ (void)swipeFrom:(CGPoint)a to:(CGPoint)b duration:(NSTimeInterval)d;
@end
