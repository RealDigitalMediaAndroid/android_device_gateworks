LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)
LOCAL_C_INCLUDES += external/i2c-tools/tools external/i2c-tools/$(KERNEL_DIR)/include
# TODO: figure out how to include the i2c static library inside of ours
# LOCAL_STATIC_LIBRARIES += i2c-tools
LOCAL_SRC_FILES := gw_android_flags.c
LOCAL_MODULE := gw_android_flags
include $(BUILD_STATIC_LIBRARY)
