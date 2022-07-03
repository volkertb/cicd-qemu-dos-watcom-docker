# SPDX-License-Identifier: Apache-2.0
FROM ghcr.io/volkertb/cicd-qemu-dos-docker:v1.2
ARG WATCOM_C_DOWNLOAD_SHA256=3798477fe361ed756bb809c615dd885fb3ef2e310af921767f0c3fdfee336473
RUN mkdir /tmp/drive_c
WORKDIR /tmp/drive_c

RUN wget -nv -O OWC2INST.EXE https://github.com/open-watcom/open-watcom-v2/releases/download/2022-07-01-Build/open-watcom-2_0-c-dos.exe
RUN echo "$WATCOM_C_DOWNLOAD_SHA256  OWC2INST.EXE" | sha256sum -c -

RUN apk add cdrkit
RUN mkisofs -o /tmp/open-watcom-2_0-c-dos.iso OWC2INST.EXE
RUN apk del cdrkit
RUN rm OWC2INST.EXE

ARG UHDD_SHA256=3b1ce2441e17adcd6aa80065b4181e5485e4f93a0ba87391d004741e43deb9d3
RUN wget -nv https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.2/repos/drivers/uhdd.zip
RUN echo "$UHDD_SHA256  uhdd.zip" | sha256sum -c -
RUN unzip uhdd.zip BIN/UHDD.SYS

ARG UDVD_SHA256=cbf2098961001cceffe834ff30b6fb71cdbcfee62c4f2767fa11fe4419c9202e
RUN wget -nv https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.2/repos/drivers/udvd2.zip
RUN echo "$UDVD_SHA256  udvd2.zip" | sha256sum -c -
RUN unzip udvd2.zip BIN/UDVD2.SYS
RUN rm udvd2.zip

ARG SHSUCDX_SHA256=2c611e1d026159e3b63f645bddcbb691fe8ec4363206427269a4f27592bcfe66
RUN wget -nv https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.2/repos/base/shsucdx.zip
RUN echo "$SHSUCDX_SHA256  shsucdx.zip" | sha256sum -c -
RUN unzip shsucdx.zip BIN/SHSUCDX.COM
RUN rm shsucdx.zip

ARG DEVLOAD_SHA256=dcc085e01f26ab97ac5ae052d485d3e323703922c64da691b90c9b1505bcfd76
RUN wget -nv https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.2/repos/base/devload.zip
RUN echo "$DEVLOAD_SHA256  devload.zip" | sha256sum -c -
RUN unzip devload.zip BIN/DEVLOAD.COM
RUN rm devload.zip

ARG FDISK_SHA256=5f6f84fab35132cc7928137e0f350660cb7ff06d23da18e1b5caceed15ea7b8f
RUN wget -nv https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.2/repos/base/fdisk.zip
RUN echo "$FDISK_SHA256  fdisk.zip" | sha256sum -c -
RUN unzip fdisk.zip BIN/FDISK.EXE
RUN rm fdisk.zip

ARG FORMAT_SHA256=dfb9ac68dff880a84e49affdb65fe5866e45b1b003414354479629b97ad33972
RUN wget -nv https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.2/repos/base/format.zip
RUN echo "$FORMAT_SHA256  format.zip" | sha256sum -c -
RUN unzip format.zip BIN/FORMAT.EXE
RUN rm format.zip

RUN qemu-img create -f qcow2 -o size=512M /tmp/watcom-installation.img

# Following part with thanks to https://unix.stackexchange.com/a/629494

# Create a 512 MB file
RUN dd if=/dev/zero of=/tmp/watcom-installation.img bs=1M count=512

RUN apk add mtools

# Put a FAT filesystem on it (use -F for FAT32, otherwise it's automatic)
RUN mformat -i /tmp/watcom-installation.img -v WATCOM_DISK ::

RUN echo "DIR A:" > CICD_DOS.BAT
RUN echo "DIR C:" >> CICD_DOS.BAT
RUN echo "DIR D:" >> CICD_DOS.BAT
RUN echo "DIR E:" >> CICD_DOS.BAT

RUN echo "BIN\\DEVLOAD /H BIN\\UHDD.SYS /S20 /H" > CICD_DOS.BAT
RUN echo "BIN\\DEVLOAD /H BIN\\UDVD2.SYS /H" >> CICD_DOS.BAT
RUN echo "BIN\\SHSUCDX.COM /D:UDVD1" >> CICD_DOS.BAT

RUN echo "ECHO Installing Open Watcom C installation in DOS... (This will take a while, without visual progress!)" >> CICD_DOS.BAT
RUN echo "E:\\owc2inst.exe -dDstDir=D:\\WATCOM -s" >> CICD_DOS.BAT
RUN echo "ECHO Installation complete." >> CICD_DOS.BAT

RUN mcopy -i /media/x86BOOT.img ::FDCONFIG.SYS /tmp/FDCONFIG.SYS
RUN echo "FILES=40" >> /tmp/FDCONFIG.SYS
RUN echo "BUFFERS=20" >> /tmp/FDCONFIG.SYS
RUN unix2dos /tmp/FDCONFIG.SYS
RUN mdel -i /media/x86BOOT.img ::FDCONFIG.SYS
RUN mcopy -i /media/x86BOOT.img /tmp/FDCONFIG.SYS ::FDCONFIG.SYS
RUN rm /tmp/FDCONFIG.SYS

RUN echo "$(date) : Proceeding with Open Watcom C installation in DOS. This will take a while, without visual progress!"

RUN (qemu-system-i386 \
-nographic \
-blockdev driver=file,node-name=fd0,filename=/media/x86BOOT.img -device floppy,drive=fd0 \
-drive if=virtio,format=raw,file=fat:rw:/tmp/drive_c \
-drive if=virtio,format=raw,file=/tmp/watcom-installation.img \
-cdrom /tmp/open-watcom-2_0-c-dos.iso \
-boot order=a \
-audiodev wav,id=snd0,path=$(pwd)/ac97_out.wav -device AC97,audiodev=snd0 \
-audiodev wav,id=snd1,path=$(pwd)/adlib_out.wav -device adlib,audiodev=snd1 \
-audiodev wav,id=snd2,path=$(pwd)/sb16_out.wav -device sb16,audiodev=snd2 \
-audiodev wav,id=snd3,path=$(pwd)/pcspk_out.wav -machine pcspk-audiodev=snd3 \
| tee $(pwd)/qemu_stdout.log) 3>&1 1>&2 2>&3 | tee /tmp/drive_c/qemu_stderr.log

RUN echo "$(date) : Open Watcom C installation in DOS complete."
RUN ls -lh /tmp/drive_c

RUN mcopy -i /media/x86BOOT.img ::FDAUTO.BAT /tmp/FDAUTO.BAT
RUN mcopy -i /media/x86BOOT.img ::AUTOEXEC.BAT /tmp/AUTOEXEC.BAT
RUN echo "@ECHO OFF" > /tmp/FDAUTO.NEW
RUN cat /tmp/AUTOEXEC.BAT >> /tmp/FDAUTO.NEW
RUN grep -vi "ECHO OFF" /tmp/FDAUTO.BAT >> /tmp/FDAUTO.NEW
RUN mdel -i /media/x86BOOT.img ::AUTOEXEC.BAT
RUN mdel -i /media/x86BOOT.img ::AUTOEXEC.000
RUN mdel -i /media/x86BOOT.img ::CONFIG.SYS
RUN mdel -i /media/x86BOOT.img ::CONFIG.000
RUN unix2dos /tmp/FDAUTO.NEW
RUN mdel -i /media/x86BOOT.img ::FDAUTO.BAT
RUN mcopy -i /media/x86BOOT.img /tmp/FDAUTO.NEW ::FDAUTO.BAT
RUN rm /tmp/AUTOEXEC.BAT
RUN rm /tmp/FDAUTO.BAT
RUN rm /tmp/FDAUTO.NEW

RUN apk del mtools

RUN echo "#include <stdio.h>" > HELLO.C
RUN echo "" >> HELLO.C
RUN echo "int main() {" >> HELLO.C
RUN echo "  printf(\"Hello, World!\\n\");" >> HELLO.C
RUN echo "  return 0;" >> HELLO.C
RUN echo "}" >> HELLO.C
RUN unix2dos HELLO.C

RUN ls -lh

RUN echo "BIN\\DEVLOAD /H BIN\\UHDD.SYS /S20 /H" > CICD_DOS.BAT # TODO: move UHDD install to the base ("FROM:") image
RUN echo "TYPE A:\\FDAUTO.BAT" >> CICD_DOS.BAT
RUN echo "PATH" >> CICD_DOS.BAT
RUN echo "WCC HELLO.C" >> CICD_DOS.BAT
RUN echo "WLINK SYS DOS FILE HELLO.OBJ" >> CICD_DOS.BAT
RUN echo "HELLO" >> CICD_DOS.BAT
RUN echo "DIR /P" >> CICD_DOS.BAT
RUN echo "DIR /P A:" >> CICD_DOS.BAT
RUN unix2dos CICD_DOS.BAT

RUN (qemu-system-i386 \
-nographic \
-blockdev driver=file,node-name=fd0,filename=/media/x86BOOT.img -device floppy,drive=fd0 \
-drive if=virtio,format=raw,file=fat:rw:/tmp/drive_c \
-drive if=virtio,format=raw,file=/tmp/watcom-installation.img \
-boot order=a \
-audiodev wav,id=snd0,path=$(pwd)/ac97_out.wav -device AC97,audiodev=snd0 \
-audiodev wav,id=snd1,path=$(pwd)/adlib_out.wav -device adlib,audiodev=snd1 \
-audiodev wav,id=snd2,path=$(pwd)/sb16_out.wav -device sb16,audiodev=snd2 \
-audiodev wav,id=snd3,path=$(pwd)/pcspk_out.wav -machine pcspk-audiodev=snd3 \
| tee $(pwd)/qemu_stdout.log) 3>&1 1>&2 2>&3 | tee /tmp/drive_c/qemu_stderr.log

RUN mv /tmp/watcom-installation.img /media/
WORKDIR /
RUN rm -rf /tmp/drive_c

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
