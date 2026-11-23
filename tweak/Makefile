INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Lock9
Lock9_FILES = $(wildcard *.swift) $(wildcard *.m) Tweak.x
Lock9_CFLAGS = -fobjc-arc -I./Headers
Lock9_SWIFTFLAGS += -DTWEAK

include $(THEOS_MAKE_PATH)/tweak.mk
