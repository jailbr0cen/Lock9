TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = Lock9Prefs

Lock9Prefs_FILES = Lock9RootListController.m
Lock9Prefs_FRAMEWORKS = UIKit
Lock9Prefs_PRIVATE_FRAMEWORKS = Preferences
Lock9Prefs_INSTALL_PATH = /Library/PreferenceBundles
Lock9Prefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/bundle.mk
