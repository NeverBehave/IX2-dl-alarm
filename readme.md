# Install alarm on Lenovo IX2-DL

> Based on https://kiljan.org/2021/04/22/installing-arch-linux-arm-on-an-iomega-ix2-200/

This guide uses a usb device as system disk. 

## Steps 

You may get all tools by enter `nix-shell` if you have nix installed.

### 1. Prepare the image

#### Get the device tree

> https://forum.doozan.com/read.php?3,19216,page=3

It is also attached in this repo as reference.

#### Build device tree

```bash
dtc -O dtb -o kirkwood-lenovo-ix2-dl-full.dtb kirkwood-lenovo-ix2-dl-full.dts
```

#### Build uImage

```
mkdir linux
cd linux
wget http://mirror.archlinuxarm.org/arm/core/linux-kirkwood-dt-5.15.6-1-arm.pkg.tar.xz
bsdtar -xpf linux-kirkwood-dt-5.15.6-1-arm.pkg.tar.xz
cp boot/zImage boot/zImage-dtb
cat ../kirkwood-lenovo-ix2-dl-full.dtb >> boot/zImage-dtb
mkimage -A arm -O linux -T kernel -C none -a 0x02000000 -e 0x02000000 -n "Arch Linux ARM kernel" -d boot/zImage-dtb boot/uImage
```

The final image will be in `./linux/boot/uImage`


### 2. Partition your drive

Use fdisk to partition the disk:

```bash
fdisk -l # If you don't know your drive
fdisk /dev/sd{some letter here}
```

> Use o to create a clean DOS partition table.  
> Use n to create a new partition, type: primary, number: 1, first sector: default, last sector: +256M.  
> Use n to create a new partition, type: primary, number: 2, first sector: default, last sector: +8G (or the rest of the remaining free disk space if smaller).  
> Use p to see the new partition table.  
> If ID and Type are not ‘83 Linux’ for both partitions: Use t to change a partition’s type. Type must be 83.  
> Use w to write the changes to disk.  

#### Install Image

Replace `{}` with correct letter

```bash
mkfs.ext2 /dev/sd{}1
mkfs.ext4 /dev/sd{}2
e2label /dev/sd{}1 BOOT
e2label /dev/sd{}2 ROOT

mount /dev/sd{}2 /mnt
mkdir /mnt/boot
mount /dev/sd{}1 /mnt/boot

cd /mnt
wget http://os.archlinuxarm.org/os/ArchLinuxARM-kirkwood-latest.tar.gz
bsdtar -xpf ArchLinuxARM-kirkwood-latest.tar.gz
rm ArchLinuxARM-kirkwood-latest.tar.gz
```

#### Replace Image

```bash
cp ./linux/boot/uImage /mnt/boot
mkimage -A arm -O linux -T ramdisk -C gzip -a 0x00000000 -e 0x00000000 -n "Arch Linux ARM initrd" -d /mnt/boot/initramfs-linux.img /mnt/boot/uInitrd
```

Also, you will need to copy the file from `./linux/usr/lib/modules` to the `/mnt/usr/lib/modules`. Remove the previous one. 

```bash
rm -r /mnt/usr/lib/modules
cp -r ./linux/usr/lib/modules /mnt/usr/lib
```

For automatic update, copy the zImage and dtb to boot as well.

```bash
cp ./kirkwood-lenovo-ix2-dl-full.dtb /mnt/boot/
cp ./linux/boot/zImage /mnt/boot
```

### 3. Prepare your machine

#### Backup your current parameters

Choose either way to do this: 

##### SSH

First, enable ssh: visit `http://{IP}/manage/diagnostics.html`

- User: `root`
- Password: `soho{password you set}`

```bash
fw_printenv > /tmp/env
```

backup and set up the following so that your device will boot from usb first

```bash
fw_setenv ethaddr 'AA:00:00:00:00:01'
fw_setenv mainlineLinux 'yes'
fw_setenv arcNumber '1682'

fw_setenv bootargs_console 'console=ttyS0,115200'
fw_setenv bootargs_mtdparts 'mtdparts=orion_nand:640k(u-boot)ro,16k(u-boot-env),-(iomega-firmware)ro'
fw_setenv bootargs_root 'root=LABEL=ROOT rw'

fw_setenv memoffset_kernel '0x01000000'
fw_setenv memoffset_initrd '0x08004000'

fw_setenv bootargs_combine 'setenv bootargs ${bootargs_console} ${bootargs_mtdparts} ${bootargs_root}'
fw_setenv bootlinux 'bootm ${memoffset_kernel} ${memoffset_initrd}'

fw_setenv usb_load_firstdevice 'ext2load usb 0:1 ${memoffset_kernel} /uImage; ext2load usb 0:1 ${memoffset_initrd} /uInitrd'
fw_setenv usb_load 'run bootargs_combine; usb reset; run usb_load_firstdevice; run bootlinux'

fw_setenv sata_load_disk1 'ext2load ide 0:1 ${memoffset_kernel} /uImage; ext2load ide 0:1 ${memoffset_initrd} /uInitrd'
fw_setenv sata_load_disk2 'ext2load ide 1:1 ${memoffset_kernel} /uImage; ext2load ide 1:1 ${memoffset_initrd} /uInitrd'
fw_setenv sata_load 'run bootargs_combine; ide reset; run sata_load_disk1; run sata_load_disk2; run bootlinux'

fw_setenv bootcmd 'run usb_load; run sata_load'
```

##### UBoot

Tips: To access UART, removing the front panel (5 screws) is easier than back (need to remove cables)  

- The top three pin (JP1) with jump is for 3.3v/5v mode, by default is 3.3v.   
- Skip the first Pin (Which is the one from the right when you pointing the pin toward yourself, board facing up) and connect as following:  

> Pin 1: Do NOT connect. This pin provides +3.3V and is not required for USB UART serial adapters.  
> Pin 2: TxD. Connect to RxD of the serial adapter.  
> Pin 3: GND. Connect to GND of the serial adapter.  
> Pin 4: RxD. Connect to TxD of the serial adapter.  

Connect console:  

```
screen /dev/ttyUSB{varies} 115200
```

The following will show up:  

```
        |  \/  | __ _ _ ____   _____| | |
        | |\/| |/ _` | '__\ \ / / _ \ | |
        | |  | | (_| | |   \ V /  __/ | |
        |_|  |_|\__,_|_|    \_/ \___|_|_|
 _   _     ____              _
| | | |   | __ )  ___   ___ | |_
| | | |___|  _ \ / _ \ / _ \| __|
| |_| |___| |_) | (_) | (_) | |_
 \___/    |____/ \___/ \___/ \__|  ** ix2-spi ** ** uboot_ver:0.0.9 **
```

Tips: 

- In screen, you could use `ctrl+a`, then `esc` so you can scroll.
- How to check which dev is the usb? check dmesg. https://superuser.com/questions/361885/how-do-i-figure-out-which-dev-is-a-usb-flash-drive

```
printenv
```

backup then set vars, **Do NOT copy/paste all commands** since this will result in incomplete executed commands due to the lack of flow control on the serial interface in U-Boot. A copy/paste of each line separately should be OK.

```
setenv ethaddr 'AA:00:00:00:00:01'
setenv mainlineLinux 'yes'
setenv arcNumber '1682'

setenv bootargs_console 'console=ttyS0,115200'
setenv bootargs_mtdparts 'mtdparts=orion_nand:640k(u-boot)ro,16k(u-boot-env),-(iomega-firmware)ro'
setenv bootargs_root 'root=LABEL=ROOT rw'

setenv memoffset_kernel '0x01000000'
setenv memoffset_initrd '0x08004000'

setenv bootargs_combine 'setenv bootargs ${bootargs_console} ${bootargs_mtdparts} ${bootargs_root}'
setenv bootlinux 'bootm ${memoffset_kernel} ${memoffset_initrd}'

setenv usb_load_firstdevice 'ext2load usb 0:1 ${memoffset_kernel} /uImage; ext2load usb 0:1 ${memoffset_initrd} /uInitrd'
setenv usb_load 'run bootargs_combine; usb reset; run usb_load_firstdevice; run bootlinux'

setenv sata_load_disk1 'ext2load ide 0:1 ${memoffset_kernel} /uImage; ext2load ide 0:1 ${memoffset_initrd} /uInitrd'
setenv sata_load_disk2 'ext2load ide 1:1 ${memoffset_kernel} /uImage; ext2load ide 1:1 ${memoffset_initrd} /uInitrd'
setenv sata_load 'run bootargs_combine; ide reset; run sata_load_disk1; run sata_load_disk2; run bootlinux'

setenv bootcmd 'run usb_load; run sata_load'
saveenv
```

### 4. Post Install

#### fstab

By default, the fstab is not set up properly. Check the fstab in this repo to mount your partitions  (e.g. boot) correctly. 

#### network

Set all DHCP

```
sed 's/eth0/e*/g' /mnt/etc/systemd/network/eth0.network > /mnt/etc/systemd/network/eth.network
rm /mnt/etc/systemd/network/eth0.network
```

#### Automatic uImage generate after upgrade

With your drive mounted:  

```bash
mkdir /mnt/etc/pacman.d/hooks
cp generate-ubootfiles.hook /mnt/etc/pacman.d/hooks
cp generate-ubootfiles /mnt/usr/local/sbin/
chmod +x /mnt/usr/local/sbin/generate-ubootfiles
```

Test the script by running on the machine

#### pacman

> https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-3

```bash
pacman-key --init
pacman-key --populate archlinuxarm
```

#### Swap

To relief the stress of Low RAM:

https://wiki.archlinux.org/title/swap#Swap_file