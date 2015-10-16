LOCAL_PATH:= $(call my-dir)

###################### manifest.xml ######################

# TODO: There is probably a simpler and better way to run
#       a command and leave the output in a file that is
#       included inside the system image.

include $(CLEAR_VARS)

LOCAL_MODULE_TAGS := optional
LOCAL_MODULE := build_manifest
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)

$(TARGET_OUT_ETC)/manifest.xml:
	@echo "Generating build manifest.xml -> $@"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide)repo manifest -r -o $@

LOCAL_ADDITIONAL_DEPENDENCIES += $(TARGET_OUT_ETC)/manifest.xml

ALL_DEFAULT_INSTALLED_MODULES += $(TARGET_OUT_ETC)/manifest.xml

# We need this so that the installed files could be picked up based on the
# local module name
ALL_MODULES.$(LOCAL_MODULE).INSTALLED := \
    $(ALL_MODULES.$(LOCAL_MODULE).INSTALLED) $(TARGET_OUT_ETC)/manifest.xml

include $(BUILD_PHONY_PACKAGE)
