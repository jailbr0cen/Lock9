INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SlideLS
SlideLS_FILES = $(wildcard *.swift) $(wildcard *.m) Tweak.x
SlideLS_CFLAGS = -fobjc-arc -I./Headers
SlideLS_SWIFTFLAGS += -DTWEAK

include $(THEOS_MAKE_PATH)/tweak.mk
