import common
import fnmatch

def FullOTA_InstallEnd(info):
    # Copy BOOT_EXTRA directory contents to output
    # BOOT_EXTRA/* --> [partition path]
    for filename in fnmatch.filter(info.input_zip.namelist(), "BOOT_EXTRA/*"):
        file = info.input_zip.read(filename)
        common.ZipWriteStr(info.output_zip, filename, file)
    info.script.AppendExtra( 'package_extract_dir("BOOT_EXTRA", "$BD1");' )
    info.script.AppendExtra( 'package_extract_dir("BOOT_EXTRA", "$BD2");' )

