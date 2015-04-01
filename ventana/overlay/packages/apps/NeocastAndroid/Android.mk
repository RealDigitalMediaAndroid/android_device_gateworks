LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE := NeocastAndroid
LOCAL_SRC_FILES := NeocastAndroid.apk
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
# tell dexopt not to try resigning the apks
LOCAL_CERTIFICATE := PRESIGNED
# LOCAL_CERTIFICATE := device/rdm/common/security/platform
include $(BUILD_PREBUILT)
