DEBUG=0
FINALPACKAGE=1
GO_EASY_ON_ME=1

THEOS_PACKAGE_SCHEME = rootless

THEOS_USE_NEW_ABI=1
TARGET = iphone:14.5:14.5
ARCHS = arm64 arm64e

THEOS_DEVICE_IP = 127.0.0.1 -p 2222

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BlurryAlerts

BlurryAlerts_FILES = Tweak.xm
BlurryAlerts_CFLAGS = -fobjc-arc
# BlurryAlerts_LIBRARIES = colorpicker

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += blurryalerts
include $(THEOS_MAKE_PATH)/aggregate.mk

internal-stage::
	$(ECHO_NOTHING)install_name_tool -change /usr/lib/libcolorpicker.dylib /var/jb/usr/lib/libcolorpicker.dylib $(THEOS_STAGING_DIR)/Library/PreferenceBundles/BlurryAlerts.bundle/BlurryAlerts$(ECHO_END)
	$(ECHO_NOTHING)ldid -S $(THEOS_STAGING_DIR)/Library/PreferenceBundles/BlurryAlerts.bundle/BlurryAlerts$(ECHO_END)