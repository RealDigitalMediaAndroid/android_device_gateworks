import common
import fnmatch

def InstallBootAndRecovery(info):
    # Copy BOOT_EXTRA directory contents to output
    # BOOT_EXTRA/* --> [partition path]
    for filename in fnmatch.filter(info.input_zip.namelist(), "BOOT_EXTRA/*"):
        file = info.input_zip.read(filename)
        common.ZipWriteStr(info.output_zip, filename, file)
    # error: make_ext4fs_internal: cannot lookup security context for /boot/
    info.script.FormatPartition("/boot")
    info.script.Mount("/boot")
    info.script.UnpackPackageDir("BOOT_EXTRA", "/boot")
    info.script.AppendExtra('package_extract_file("boot.img", "/boot/boot.img");')
    # TODO: do this differently, the current process generates recovery.img
    # on the next boot. So, if boot.img is bad, we're screwed.
    info.script.FormatPartition("/recovery")
    info.script.Mount("/recovery")
    info.script.UnpackPackageDir("BOOT_EXTRA", "/recovery")
    info.script.AppendExtra('package_extract_file("recovery.img", "/recovery/recovery.img");')

def InstallBootloader(info):
    # Copy BOOTLOADER directory contents to output
    # BOOTLOADER/* --> [partition path]
    for filename in fnmatch.filter(info.input_zip.namelist(), "BOOTLOADER/*"):
        file = info.input_zip.read(filename)
        common.ZipWriteStr(info.output_zip, filename, file)
    # Install SPL, u-boot.img, and erase u-boot environment
    info.script.AppendExtra('package_extract_file("BOOTLOADER/SPL", "/SPL");')
    info.script.AppendExtra('package_extract_file("BOOTLOADER/u-boot.img", "/u-boot.img");')
    info.script.AppendExtra('run_program("/res/kobs-ng", "init", "-v", "-x", "--search_exponent=1", "--chip_0_size=0xe00000", "--chip_0_device_path=/dev/mtd/mtd0", "/SPL");')
    info.script.AppendExtra('run_program("/res/flash_erase", "/dev/mtd/mtd0", "0xe00000", "0");')
    info.script.AppendExtra('run_program("/res/nandwrite", "--start=0xe00000", "--pad", "/dev/mtd/mtd0", "/u-boot.img");')
    info.script.AppendExtra('run_program("/res/flash_erase", "/dev/mtd/mtd1", "0", "0");')

def InstallExtraSync(info):
    # Unmount doesn't work, so do this:
    info.script.AppendExtra('run_program("sync");')
    info.script.AppendExtra('run_program("sync");')
    info.script.AppendExtra('run_program("sleep", "10");')
    info.script.AppendExtra('run_program("sync");')

def FullOTA_InstallEnd(info):
    InstallBootAndRecovery(info)
    InstallBootloader(info)
    InstallExtraSync(info)
