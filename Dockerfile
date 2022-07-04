# SPDX-License-Identifier: Apache-2.0
# With thanks to https://unix.stackexchange.com/a/629494 for showing that mtools is not just for floppy images :)
FROM ghcr.io/volkertb/cicd-qemu-dos-docker:v1.3
ARG WATCOM_C_DOWNLOAD_SHA256=3798477fe361ed756bb809c615dd885fb3ef2e310af921767f0c3fdfee336473

RUN mkdir /tmp/drive_c \
    && cd /tmp/drive_c \
    && wget -nv -O OWC2INST.EXE https://github.com/open-watcom/open-watcom-v2/releases/download/2022-07-01-Build/open-watcom-2_0-c-dos.exe \
    && echo "$WATCOM_C_DOWNLOAD_SHA256  OWC2INST.EXE" | sha256sum -c - \
    && apk add mtools \
    && dd if=/dev/zero of=/tmp/watcom-installer.img bs=1M count=130 \
    && mformat -i /tmp/watcom-installer.img -v WATCOM_INST :: \
    && mcopy -i /tmp/watcom-installer.img OWC2INST.EXE ::OWC2INST.EXE \
    && rm OWC2INST.EXE \
    && dd if=/dev/zero of=/media/watcom-installation.img bs=1M count=64 \
    && mformat -i /media/watcom-installation.img -v WATCOM_DISK :: \
    && echo "ECHO Installing Open Watcom C installation in DOS... (This will take a while, without visual progress!)" > CICD_DOS.BAT \
    && echo "E:\\owc2inst.exe -dDstDir=D:\\WATCOM -s" >> CICD_DOS.BAT \
    && echo "ECHO Installation complete." >> CICD_DOS.BAT \
    && echo "$(date) : Proceeding with Open Watcom C installation in DOS. This will take a while, without visual progress!" \
    && qemu-system-i386 \
-nographic \
-blockdev driver=file,node-name=fd0,filename=/media/x86BOOT.img -device floppy,drive=fd0 \
-drive if=virtio,format=raw,file=fat:rw:/tmp/drive_c \
-drive if=virtio,format=raw,file=/media/watcom-installation.img \
-drive if=virtio,format=raw,file=/tmp/watcom-installer.img \
-boot order=a \
    && echo "$(date) : Open Watcom C installation in DOS complete." \
    && rm /tmp/watcom-installer.img \
    && mcopy -i /media/x86BOOT.img ::FDAUTO.BAT /tmp/FDAUTO.BAT \
    && mcopy -i /media/x86BOOT.img ::AUTOEXEC.BAT /tmp/AUTOEXEC.BAT \
    && echo "@ECHO OFF" > /tmp/FDAUTO.NEW \
    && cat /tmp/AUTOEXEC.BAT >> /tmp/FDAUTO.NEW \
    && grep -vi "ECHO OFF" /tmp/FDAUTO.BAT >> /tmp/FDAUTO.NEW \
    && mdel -i /media/x86BOOT.img ::AUTOEXEC.BAT \
    && mdel -i /media/x86BOOT.img ::AUTOEXEC.000 \
    && mdel -i /media/x86BOOT.img ::CONFIG.SYS \
    && mdel -i /media/x86BOOT.img ::CONFIG.000 \
    && unix2dos /tmp/FDAUTO.NEW \
    && mdel -i /media/x86BOOT.img ::FDAUTO.BAT \
    && mcopy -i /media/x86BOOT.img /tmp/FDAUTO.NEW ::FDAUTO.BAT \
    && rm /tmp/AUTOEXEC.BAT \
    && rm /tmp/FDAUTO.BAT \
    && rm /tmp/FDAUTO.NEW \
    && apk del mtools \
    && echo "#include <stdio.h>" > HELLO.C \
    && echo "" >> HELLO.C \
    && echo "int main() {" >> HELLO.C \
    && echo "  printf(\"Hello, World!\\n\");" >> HELLO.C \
    && echo "  return 0;" >> HELLO.C \
    && echo "}" >> HELLO.C \
    && unix2dos HELLO.C \
    && echo "WCC HELLO.C" >> CICD_DOS.BAT \
    && echo "WLINK SYS DOS FILE HELLO.OBJ" >> CICD_DOS.BAT \
    && echo "HELLO" >> CICD_DOS.BAT \
    && unix2dos CICD_DOS.BAT \
    && qemu-system-i386 \
-nographic \
-blockdev driver=file,node-name=fd0,filename=/media/x86BOOT.img -device floppy,drive=fd0 \
-drive if=virtio,format=raw,file=fat:rw:/tmp/drive_c \
-drive if=virtio,format=raw,file=/media/watcom-installation.img \
-boot order=a \
    && cd / \
    && rm -rf /tmp/* \
    && echo "End of Dockerfile build process."

ENTRYPOINT (qemu-system-i386 \
-nographic \
-blockdev driver=file,node-name=fd0,filename=/media/x86BOOT.img -device floppy,drive=fd0 \
-drive if=virtio,format=raw,file=fat:rw:$(pwd) \
-drive if=virtio,format=raw,file=/media/watcom-installation.img \
-boot order=a \
-audiodev wav,id=snd0,path=$(pwd)/ac97_out.wav -device AC97,audiodev=snd0 \
-audiodev wav,id=snd1,path=$(pwd)/adlib_out.wav -device adlib,audiodev=snd1 \
-audiodev wav,id=snd2,path=$(pwd)/sb16_out.wav -device sb16,audiodev=snd2 \
-audiodev wav,id=snd3,path=$(pwd)/pcspk_out.wav -machine pcspk-audiodev=snd3 \
| tee $(pwd)/qemu_stdout.log) 3>&1 1>&2 2>&3 | tee $(pwd)/qemu_stderr.log
