---
layout: post
title: Shared Libraries of TA
date: 2024-08-27 12:05 +0800
author: sfeng
categories: [Blogging, OPTEE]
tags: [optee, ta]
lang: zh
---

## Preface
&emsp;&emsp;OPTEE里有个宏叫做"CFG_ULIBS_SHARED"，由此联想到主流OS里动态链接库，这篇文章主要看这个宏有什么作用，和动态链接库有什么关联。  
> SoC Arch : ARMv8
> OPTEE version: 4.0.0。
{: .prompt-info }

## Content
### ldelf
&emsp;&emsp;OPTEE里有个module叫做ldelf，它的主要功能包括open ta，parse ELF，load dependency(if any)，map and relocate elf等。这个模块也挺有意思，它并不是link在OPTEE core里的，而是独立编译成可执行的elf文件，然后通过[**gen_ldelf_hex.py**](https://github.com/OP-TEE/optee_os/blob/4.0.0/scripts/gen_ldelf_hex.py)这个脚本生成ldelf_hex.c，然后以数组的形式编译进OPTEE core的。在做TA的open session的时候通过[**ldelf_load_ldelf**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/ldelf_loader.c#L54) load到tee memory中，然后function [**ldelf_init_with_ldelf**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/ldelf_loader.c#L115)进入user mode(SEL0 under ARMv8)把要load的TA准备好后返回OPTEE Core。今天提到的shared library就是在ldelf里处理的。ldelf可以单独作为一个话题写一篇文章了，先上张官网的图酝酿下。  
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
  TA用这个库来支持动态链接库。（这个有点疑惑，等看明白了再来解释）  
  UUID：be807bbd-81e1-4dc4-bd99-3d363f240ece  

&emsp;&emsp;这些lib在“CFG_ULIBS_SHARED”打开后不再以static lib的形式link在TA里，而是在export-ta_arm64/lib下(只考虑64bit TA)生成了4个TA和.so文件。  

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
&emsp;&emsp;在编译环节，把link时候的command打印出来如下：  
```
aarch64-linux-gnu-ld.bfd -e__ta_entry -pie -T ./ta.lds -Map=./8aaaf200-2450-11e4-abe2-0002a5d5c51b.map --sort-section=alignment -z max-page-size=4096  --as-needed   --dynamic-list ./dyn_list  ./hello_world_ta.o ./user_ta_header.o  -L ./export-ta_arm64/lib --start-group -lutils -lutee -lmbedtls -ldl --end-group ./toolchain/aarch64/gcc-arm-aarch64-linux-gnu-8.3/bin/../lib/gcc/aarch64-linux-gnu/8.3.0/libgcc.a -lutils -o 8aaaf200-2450-11e4-abe2-0002a5d5c51b.elf
```
&emsp;&emsp;竟然发现link的command line竟然是一样的。哪developer究竟怎样决定编译TA的时候是static link还是dynamic link？感兴趣的从[**How to Make a Library**](https://sfeng-daydayup.github.io/posts/how-to-make-a-library/)中找答案吧。  

&emsp;&emsp;objdump下看需要动态链接哪些库文件。咦，这里又出问题了，上面的ld command里没有这几个库啊？嘿嘿，继续从[**How to Make a Library**](https://sfeng-daydayup.github.io/posts/how-to-make-a-library/)中找答案吧。  

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

&emsp;&emsp;关于ELF部分和relocate部分不打算做太细节的描述，网上有不少不错的文章，有兴趣的可以搜索学习下。  

## Reference  
[**OPTEE-Arch-Library**](https://optee.readthedocs.io/en/latest/architecture/libraries.html#)  
[**OPTEE-Arch-TA**](https://optee.readthedocs.io/en/latest/architecture/trusted_applications.html#loading-and-preparing-ta-for-execution)  