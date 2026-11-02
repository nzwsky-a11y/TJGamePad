TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e

# rootless/roothide 都装到 /var/jb(roothide 是软链),两者通用
THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TJGamePad
TJGamePad_FILES = Tweak.xm TJTouch.m TJInput.m TJRapidTap.m TJKeymapStore.m TJEditor.m TJRapidPad.m
TJGamePad_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/include
TJGamePad_FRAMEWORKS = UIKit CoreGraphics Foundation
TJGamePad_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tweak.mk
