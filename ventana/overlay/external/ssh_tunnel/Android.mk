LOCAL_PATH:= $(call my-dir)

###################### authorized_keys ######################

include $(CLEAR_VARS)
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE := authorized_keys.default
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)/security
LOCAL_SRC_FILES := authorized_keys
include $(BUILD_PREBUILT)

###################### ngrok ######################

include $(CLEAR_VARS)
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE := ngrok
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES := ngrok
include $(BUILD_PREBUILT)

# This symlink is necessary because of ngrok's internal
# networking code. There should be a section in init.rc
# like this:

# on property:net.dns1=*
#     mkdir /data/etc 700 root root
#     rm /data/etc/resolv.conf
#     write /data/etc/resolv.conf "nameserver ${net.dns1}"

$(TARGET_OUT_ETC)/resolv.conf: $(LOCAL_PATH)/Android.mk
	@echo "Symlink: $@ -> /data/etc/resolv.conf"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf /data/etc/resolv.conf $@

$(LOCAL_INSTALLED_MODULE): $(TARGET_OUT_ETC)/resolv.conf

ALL_DEFAULT_INSTALLED_MODULES += $(TARGET_OUT_ETC)/resolv.conf

# We need this so that the installed files could be picked up based on the
# local module name
ALL_MODULES.$(LOCAL_MODULE).INSTALLED := \
    $(ALL_MODULES.$(LOCAL_MODULE).INSTALLED) $(TARGET_OUT_ETC)/resolv.conf

###################### ssh_tunnel ######################

include $(CLEAR_VARS)
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE := ssh_tunnel
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SRC_FILES := ssh_tunnel
include $(BUILD_PREBUILT)
## Todo: figure out how to make ssh_tunnel auto-include
##       the others

# Include this in your init.rc:

# service ssh_tunnel /system/bin/logwrapper /system/bin/ssh_tunnel
#     class main

