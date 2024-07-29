---
layout: post
title: Run OPTEE on QEMU ArmV8
author: sfeng
date: 2024-07-22 18:11 +0000
categories: [Blogging, OPTEE]
tags: [optee, qemu]
lang: zh
---

## Preface

&emsp;&emsp;在嵌入式开发过程中，博主发现有部分问题涉及到上板子调试就会变复杂了，image怎么生成和打包，怎么输出debug信息，用什么方法调试，怎么调试最方便。这样QEMU就有了用武之地。但QEMU也是有适用范围的，比如只是软件逻辑的调试，比如如果QEMU很好的模拟了硬件特性也可以用来调试硬件相关问题。OPTEE官方提供了QEMU调试方法，值得去setup一套这样的环境。  
&emsp;&emsp;官方文档在这里[**OPTEE QEMU**](https://optee.readthedocs.io/en/latest/building/devices/qemu.html)。安装过程并不是那么一帆风顺，所以记录下来供后来者参考。  
&emsp;&emsp;另外如果有对QEMU开发很熟，其实可以定制或者部分定制一个和所开发SoC类似的QEMU，不同于硬件emulator受到诸如clock之类的限制，QEMU可以充分利用宿主资源，极大的提高工作效率。  

## Prerequisite

1. 带GUI的Linux开发环境（博主用的ubuntu 22.04 Desktop版）  
2. 安装基础开发包装  
   ```shell
   sudo apt install build-essential
   sudo apt install repo
   sudo apt install curl
   sudo apt install python3-pyelftools
   ```

## Get repo and build

&emsp;&emsp;Follow官方文档的步骤来：  

```shell
$ repo init -u https://github.com/OP-TEE/manifest.git -m qemu_v8.xml
$ repo sync
$ cd build
$ make toolchains
$ make run
```

&emsp;&emsp;即便如此，中间也会遇到很多编译问题。大多数是需要额外安装工具的。遇到的问题及解决方法如下：  


```bash
bash: line 1: dtc: command not found
========
sudo apt  install device-tree-compiler
```

```bash
/bin/sh: 1: bison: not found
========
sudo apt install bison
```

```bash
/bin/sh: 1: flex: not found
========
sudo apt install flex
```

```bash
include/image.h:1395:12: fatal error: openssl/evp.h: No such file or directory
 1395 | #  include <openssl/evp.h>
      |            ^~~~~~~~~~~~~~~
compilation terminated.
========
sudo apt install libssh-dev
```

```bash
python determined to be '/usr/bin/python3'
python version: Python 3.10.12

*** Ouch! ***
Python's ensurepip module is not found.
......
ERROR: python venv creation failed
========
sudo apt install python3-venv
```

```bash
ERROR: Cannot find Ninja
========
sudo apt install ninja-build
```

```bash
ERROR: meson setup failed
========
sudo apt install meson
```

```bash
bash: line 4: ./config.status: No such file or directory
make[2]: *** No rule to make target 'config-host.mak', needed by 'Makefile.prereqs'.  Stop.
========
rm [optee path]/qemu/build/config-host.mak
```

```bash
Did not find pkg-config by name 'pkg-config'
Found pkg-config: NO
Run-time dependency glib-2.0 found: NO
========
sudo apt install libglib2.0-dev
```

```bash
../meson.build:840:11: ERROR: Dependency "pixman-1" not found, tried pkgconfig
========
sudo apt install libpixman-1-dev
```

## Get Passed
&emsp;&emsp;终于编译通过。根据提示在qemu的console里输入c，弹出的“Normal World”和“Secure World”两个console显示各自world的log（这点也很赞，不会混淆或者交错在一起）。其中Normal World可以输入Linux command，比如运行xtest。  

以下是Normal Wrold的log：  

```bash
NOTICE:  Booting Trusted Firmware
NOTICE:  BL1: v2.10.0	(release):v2.10
NOTICE:  BL1: Built : 15:55:31, Jul 23 2024
WARNING: Firmware Image Package header check failed.
NOTICE:  BL1: Booting BL2
NOTICE:  BL2: v2.10.0	(release):v2.10
NOTICE:  BL2: Built : 15:55:38, Jul 23 2024
WARNING: Firmware Image Package header check failed.
WARNING: Firmware Image Package header check failed.
WARNING: Firmware Image Package header check failed.
WARNING: Firmware Image Package header check failed.
NOTICE:  BL1: Booting BL31
NOTICE:  BL31: v2.10.0	(release):v2.10
NOTICE:  BL31: Built : 15:55:48, Jul 23 2024

U-Boot 2023.07.02 (Jul 23 2024 - 18:04:06 +0800)

DRAM:  1 GiB
Core:  51 devices, 14 uclasses, devicetree: board
Flash: 32 MiB
Loading Environment from Flash... *** Warning - bad CRC, using default environment

In:    pl011@9000000
Out:   pl011@9000000
Err:   pl011@9000000
Net:   eth0: virtio-net#31
Hit any key to stop autoboot:  0 
41724480 bytes read in 75 ms (530.6 MiB/s)
11673026 bytes read in 10 ms (1.1 GiB/s)
## Booting kernel from Legacy Image at 42200000 ...
   Image Name:   Linux kernel
   Created:      2024-07-23  10:18:53 UTC
   Image Type:   AArch64 Linux Kernel Image (uncompressed)
   Data Size:    41724416 Bytes = 39.8 MiB
   Load Address: 42200000
   Entry Point:  42200000
   Verifying Checksum ... OK
## Loading init Ramdisk from Legacy Image at 45000000 ...
   Image Name:   Root file system
   Created:      2024-07-23  10:18:54 UTC
   Image Type:   AArch64 Linux RAMDisk Image (gzip compressed)
   Data Size:    11672962 Bytes = 11.1 MiB
   Load Address: 45000000
   Entry Point:  45000000
   Verifying Checksum ... OK
## Flattened Device Tree blob at 40000000
   Booting using the fdt blob at 0x40000000
Working FDT set to 40000000
   Loading Kernel Image
   Loading Ramdisk to 7ee79000, end 7f99ad82 ... OK
   Loading Device Tree to 000000007ee73000, end 000000007ee783ca ... OK
Working FDT set to 7ee73000

Starting kernel ...

[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x000f0510]
......
......
Welcome to Buildroot, type root or test to login
buildroot login:

```

这是Secure World的log：  

```bash
......
I/TC: OP-TEE version: 4.3.0-19-g39f965c20 (gcc version 11.3.1 20220712 (Arm GNU Toolchain 11.3.Rel1)) #1 Tue Jul 23 07:48:03 UTC 2024 aarch64
I/TC: WARNING: This OP-TEE configuration might be insecure!
I/TC: WARNING: Please check https://optee.readthedocs.io/en/latest/architecture/porting_guidelines.html
I/TC: Primary CPU initializing
......
```

&emsp;&emsp;通过log可以看到，从bl1(ROM code)，bl2(RAM/DRAM init code)，到bl31(Secure Monitor)，bl32(TEE OS), bl33(bootloader)再到Linux Kernel(REE OS)，整个路径上的东西都全了，也就是除了debug OPTEE，其他模块的software logic和部分hardware feature都有可能在QEMU上debug。  

## Reference
[**OPTEE QEMU**](https://optee.readthedocs.io/en/latest/building/devices/qemu.html)


