import common
import fnmatch

def FullOTA_InstallEnd(info):
    # Copy BOOT_EXTRA directory contents to output
    # BOOT_EXTRA/* --> [partition path]
    for filename in fnmatch.filter(info.input_zip.namelist(), "BOOT_EXTRA/*"):
        file = info.input_zip.read(filename)
        common.ZipWriteStr(info.output_zip, filename, file)
    # error: make_ext4fs_internal: cannot lookup security context for /boot/
    # info.script.FormatPartition("/boot")
    info.script.Mount("/boot")
    info.script.UnpackPackageDir("BOOT_EXTRA", "/boot")
    info.script.AppendExtra('package_extract_file("boot.img", "/boot");')
    # TODO: do this differently, the current process generates recovery.img
    # on the next boot. So, if boot.img is bad, we're screwed.
    # info.script.FormatPartition("/recovery")
    info.script.Mount("/recovery")
    info.script.UnpackPackageDir("BOOT_EXTRA", "/recovery")

