#include "gw_android_flags.h"

#include <linux/i2c-dev.h>
#include <i2cbusses.h>

#define ANDROID_RECOVERY_BOOT   (1 << 7)
#define ANDROID_FASTBOOT_BOOT   (1 << 6)

static int set_flag(int mask, int set);

int set_gw_android_recovery_flag(int set) {
  return set_flag(ANDROID_RECOVERY_BOOT, set);
}

int set_gw_android_fastboot_flag(int set) {
  return set_flag(ANDROID_FASTBOOT_BOOT, set);
}

static int set_i2c_flag(int mask, int value) {
    int i2cbus = 0;
    int chip_address = 0x51;
    int daddress = 0xDF;
    int file;
    char filename[20];
    int res;
    int force = 1;
    int ret = 0;
    
    // We're doing the equivalent of this:
    //     i2cset -f -y -m $((0x80)) 0 0x51 0xDF 0
    // To verify:
    //     i2cget -f -y 0 0x51 0xDF

    file = open_i2c_dev(i2cbus, filename, sizeof(filename), 0);
    if (file < 0 || set_slave_addr(file, chip_address, force))
        goto i2c_error;
    res = i2c_smbus_read_byte_data(file, daddress);
    if (res < 0)
        goto i2c_error;

    res = (value & mask) | (res & ~mask);
    res = i2c_smbus_write_byte_data(file, daddress, res);
    if (res >= 0)
        goto i2c_cleanup;

i2c_error:
    ret = 1;
i2c_cleanup:
    // it's ok to close an invalid file descriptor
    close(file);
    return ret;
}

static int set_flag(int mask, int set) {
  // Active-low
  return set_i2c_flag(mask, set ? 0 : mask);
}

