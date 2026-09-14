TARGET := iphone:clang:latest:26.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME := rootless
FINALPACKAGE := 1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := WeChat26Demo

WeChat26Demo_FILES := \
	main.m \
	AppDelegate.m \
	SceneDelegate.m \
	LocalData.swift \
	DemoSeed.swift \
	Models.swift \
	MediaViews.swift \
	PhotoLayoutMetrics.swift \
	NativePhotoStack.swift \
	ProfileViews.swift \
	RootViews.swift \
	ChatViews.swift \
	SecondaryViews.swift

WeChat26Demo_FRAMEWORKS := UIKit SwiftUI PhotosUI ImageIO QuickLook
WeChat26Demo_CFLAGS := -fobjc-arc
WeChat26Demo_SWIFTFLAGS := -parse-as-library

ifeq ($(IPA_BUILD),1)
WeChat26Demo_CODESIGN_FLAGS := -S
else
WeChat26Demo_CODESIGN_FLAGS := -SEntitlements.plist
endif

WeChat26Demo_RESOURCE_DIRS := Resources

include $(THEOS_MAKE_PATH)/application.mk
