---
layout: post
title: Shared Libraries of TA
date: 2024-08-27 19:05 +0800
author: sfeng
categories: [OPTEE]
tags: [optee, ta]
lang: zh
---

## Preface
&emsp;&emsp;OPTEE里有个宏叫做"CFG_ULIBS_SHARED"，由此联想到主流OS里动态链接库，这篇文章主要看这个宏有什么作用，和动态链接库有什么关联区别。  
> SoC Arch : ARMv8  
> OPTEE version: 4.0.0。
{: .prompt-info }

## Content
### ldelf
&emsp;&emsp;OPTEE里有个module叫做ldelf，它的主要功能包括open ta，parse ELF，load dependency(if any)，map and relocate elf等。这个模块也挺有意思，它并不是link在OPTEE core里的，而是独立编译成可执行的elf文件，然后通过[**gen_ldelf_hex.py**](https://github.com/OP-TEE/optee_os/blob/4.0.0/scripts/gen_ldelf_hex.py)这个脚本生成ldelf_hex.c，然后以数组的形式编译进OPTEE core的。在做TA的open session的时候通过[**ldelf_load_ldelf**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/ldelf_loader.c#L54) load到tee memory中，然后通过function [**ldelf_init_with_ldelf**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/ldelf_loader.c#L115)进入user mode(SEL0 under ARMv8)把要load的TA准备好后返回OPTEE Core。今天提到的shared library就是在ldelf里处理的。ldelf可以单独作为一个话题写一篇文章了，先上张官网的图酝酿下。  
![Desktop View](/assets/img/prepare_ta.png){: .normal }

### Shared Libraries
&emsp;&emsp;OPTEE里的shared libraries主要是以下几个：  
- libutils  
  提供标准c库函数。例如strncmp()，qsort()等。  
  UUID：71855bba-6055-4293-a63f-b0963a737360  
- libutee  
  GPD TEE Internal Core API都包在这个库里。  
  UUID：4b3d937e-d57e-418b-8673-1c04f2420226  
- libmbedtls  
  提供Mbed TLS library的支持。主要是各种crypto操作。  
  UUID：87bb6ae8-4b1d-49fe-9986-2b966132c309  
- libdl  
  TA用这个库来支持动态链接库，类似于Linux中的dl module。 
  UUID：be807bbd-81e1-4dc4-bd99-3d363f240ece  

&emsp;&emsp;这些lib在“CFG_ULIBS_SHARED”打开后在准备TA编译的stuff的时候，在export-ta_arm64/lib下(只考虑64bit TA)生成了4个TA和.so文件。  

```
4b3d937e-d57e-418b-8673-1c04f2420226.elf -> libutee.so
4b3d937e-d57e-418b-8673-1c04f2420226.ta
71855bba-6055-4293-a63f-b0963a737360.elf -> libutils.so
71855bba-6055-4293-a63f-b0963a737360.ta
87bb6ae8-4b1d-49fe-9986-2b966132c309.elf -> libmbedtls.so
87bb6ae8-4b1d-49fe-9986-2b966132c309.ta
be807bbd-81e1-4dc4-bd99-3d363f240ece.elf -> libdl.so
be807bbd-81e1-4dc4-bd99-3d363f240ece.ta
libdl.a
libdl.so
libdl.stripped.so
libmbedtls.a
libmbedtls.so
libmbedtls.stripped.so
libutee.a
libutee.so
libutee.stripped.so
libutils.a
libutils.so
libutils.stripped.so
```  
&emsp;&emsp;当然libxxx.a也还在，developer可以决定编译TA的时候是static link还是dynamic link。从code看，OPTEE同时支持static link的TA和dynamic link的TA。注意，对于in-tree TA，OPTEE默认是static link的（[**build-user-ta.mk**](https://github.com/OP-TEE/optee_os/blob/4.0.0/ta/mk/build-user-ta.mk#L44)）。  

### TA compile
&emsp;&emsp;在编译环节，把link时候的command line打印出来如下（以编译[**hello_world**](https://github.com/linaro-swg/hello_world/tree/master/ta)为例）：  
```
aarch64-linux-gnu-ld.bfd -e__ta_entry -pie -T ./ta.lds -Map=./8aaaf200-2450-11e4-abe2-0002a5d5c51b.map --sort-section=alignment -z max-page-size=4096  --as-needed   --dynamic-list ./dyn_list  ./hello_world_ta.o ./user_ta_header.o  -L ./export-ta_arm64/lib --start-group -lutils -lutee -lmbedtls -ldl --end-group ./toolchain/aarch64/gcc-arm-aarch64-linux-gnu-8.3/bin/../lib/gcc/aarch64-linux-gnu/8.3.0/libgcc.a -lutils -o 8aaaf200-2450-11e4-abe2-0002a5d5c51b.elf
```
&emsp;&emsp;竟然发现link的command line竟然是一样的。哪developer究竟怎样决定编译TA的时候是static link还是dynamic link？感兴趣的从[**How to Make a Library**](https://sfeng-daydayup.github.io/posts/how-to-make-a-library/)中找答案吧。  

&emsp;&emsp;objdump下看需要动态链接哪些库文件。咦，这里又出问题了，上面的ld command里没有这几个库啊，这串数字是什么？嘿嘿，继续从[**How to Make a Library**](https://sfeng-daydayup.github.io/posts/how-to-make-a-library/)中找答案吧。  

```
Dynamic Section:
  NEEDED               71855bba-6055-4293-a63f-b0963a737360
  NEEDED               4b3d937e-d57e-418b-8673-1c04f2420226
```  

### TA loading
&emsp;&emsp;之前有提到TA主要由ldelf来load，它的入口函数从[**start_a64.S**](https://github.com/OP-TEE/optee_os/blob/4.0.0/ldelf/start_a64.S)开始。call stack如下（注释只加了和本文相关的部分）：  
- ldelf  
  - ta_elf_load_main  
    - load_main  
      - init_elf  
        - sys_open_ta_bin //ldelf的syscall到ta_stores的open函数，把binary从支持的storage里读取出来。  
        - sys_map_ta_bin  
      - map_segments  
      - populate_segments  
      - add_dependencies //从dynamic section里把依赖的库的UUID记在列表里  
      - copy_section_headers  
      - .......  
  - ta_elf_load_dependency  //依次把依赖的UUID对应的TA load进来，过程和load_main类似  
  - ta_elf_relocate  
  - ta_elf_finalize_mappings  
  - ta_elf_finalize_load_main  
  - sys_return_cleanup  

&emsp;&emsp;关于ELF部分和relocate部分不打算做细节的描述，网上有不少不错的文章，有兴趣的可以搜索学习下。  

### Result Analysis
#### Size of TA
&emsp;&emsp;众所周知，主流OS中动态链接库的最大好处之一就是节省空间。以hello world为例，看TA size的变化有多大。  

Static:  
```shell
-rw-rw-r-- 1 86664  8aaaf200-2450-11e4-abe2-0002a5d5c51b.ta
```  

Dynamic:  
```shell
-rw-r--r-- 1  12600  8aaaf200-2450-11e4-abe2-0002a5d5c51b.ta
```  
&emsp;&emsp;TA的size确实变小了，但来看下几个lib的大小：  
```shell
-rw-rw-r-- 1 110092 export-ta_arm64/lib/4b3d937e-d57e-418b-8673-1c04f2420226.ta //libutee
-rw-rw-r-- 1 34924  export-ta_arm64/lib/71855bba-6055-4293-a63f-b0963a737360.ta //libutil
-rw-rw-r-- 1 316212 export-ta_arm64/lib/87bb6ae8-4b1d-49fe-9986-2b966132c309.ta //libmbedtls
-rw-rw-r-- 1 5796   export-ta_arm64/lib/be807bbd-81e1-4dc4-bd99-3d363f240ece.ta //libdl
```  

&emsp;&emsp;这几个lib加起来有接近500KB，而hello_world TA只减小了70KB。不过hello_world TA只依赖libutee和libutil，减小的size不算显著，如果依赖libmbedtls，对size的影响会比较大，这里随机选了xtest里crypt TA做个比较。  

Static:  
```shell
-rw-rw-r-- 1 361816  optee_test/ta/crypt/cb3e5ba0-adf1-11e0-998b-0002a5d5c51b.ta
```  

Dynamic:  
```shell
-rw-r--r-- 1  78424  optee_test/ta/crypt/cb3e5ba0-adf1-11e0-998b-0002a5d5c51b.ta
```  

&emsp;&emsp;所以为了节省存储空间而打开这个宏的话，这个帐要仔细算一下。  

#### Loading Time
&emsp;&emsp;动态链接库的另一大可能的好处是减少loading的时间。application的size变小，loading时间减少，而动态链接库有可能已经loaded放在memory里了，这样总时间变少。但这对OPTEE TA有效吗？  
&emsp;&emsp;如上ldelf中TA loading的流程，ldelf并不会直接load TA，它会syscall回去调用ta store的open函数来拿到TA。最常用的TA store就是ree fs ta。来看下它会不会缓冲曾经加载过的TA。  

&emsp;&emsp;以下是ree fs ta store的注册[**REGISTER_TA_STORE**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/ree_fs_ta.c#L657)：  
```
REGISTER_TA_STORE(9) = {
	.description = "REE",
	.open = ree_fs_ta_open,
	.get_size = ree_fs_ta_get_size,
	.get_tag = ree_fs_ta_get_tag,
	.read = ree_fs_ta_read,
	.close = ree_fs_ta_close,
};
```  

&emsp;&emsp;查看函数[**ree_fs_ta_open**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/ree_fs_ta.c#L235)，它直接rpc回ree找tee_supplicant要binary，这里是没有缓冲的。但这里注意到有另外一个宏“CFG_REE_FS_TA_BUFFERED”，初始以为是把曾经加载过的TA缓冲起来，仔细阅读代码并不是。这里还找到了这个宏的说明，也确认不是这个功能。  
```
# - If CFG_REE_FS_TA_BUFFERED=y: load TA binary into a temporary buffer in the
#   "Secure DDR" pool, check the signature, then process the file only if it is
#   valid.
# - If disabled: hash the binaries as they are being processed and verify the
#   signature as a last step.
```  

&emsp;&emsp;如上，OPTEE的shared library这个功能有可能非但不会省时间，还会增加时间。

### Applicable Scenario
&emsp;&emsp;前面从size和loading time来分析了OPTEE的shared library功能，适用场景也还是以下两点：  
1. 节省存储空间。  
   想要达到节省存储空间的目的还需要精打细算，和TA的个数和依赖的库相关，毕竟application的体量不能和诸如Linux这样的OS比较。  
2. 提高性能。  
   对于追求性能，并且memory(特别是secure memory)资源比较宽裕的开发者，OPTEE original code并不能直接达到目的，还需要做一定的改造。下面章节提出了一种可能方法。  

### Possible Improvement
&emsp;&emsp;通过分析ree fs ta的[**ree_fs_ta_open**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/ree_fs_ta.c#L235)函数知道，它并不会对曾经load过的TA进行缓冲，而“CFG_REE_FS_TA_BUFFERED”增加的功能给了一定启示，可以申请一块buffer来存储TA，在调用ta store的open函数之前查找缓冲区，如果已经缓冲，则直接返回TA，如果没有，open函数读取ta，并添加在缓冲区。  
&emsp;&emsp;考虑到有些TA只load一次就不会在load，这里可以做进一步的优化，只缓冲shared library，可以节省一些memory。  
&emsp;&emsp;写到这里，忽然产生一个想法，把shared library（已经编译为TA）当成early TA来处理，这样还少了siganature check和decryption，岂不是更简单高效？这个想法实践过后再来update吧。  

### Update
&emsp;&emsp;Update来了，标准OPTEE不可行，稍做hack可行。[**Early TA of OPTEE**](https://sfeng-daydayup.github.io/posts/early-ta-of-optee/)

## Summary
&emsp;&emsp;OPTEE的shared library并不像Linux那样完备，适用场景也有一定的限制，看起来可用性不是很高。大家酌情使用吧。

## Reference  
[**OPTEE-Arch-Library**](https://optee.readthedocs.io/en/latest/architecture/libraries.html#)  
[**OPTEE-Arch-TA**](https://optee.readthedocs.io/en/latest/architecture/trusted_applications.html#loading-and-preparing-ta-for-execution)  