---
layout: post
title: Generate Link Script File From ld.S
date: 2025-02-08 18:32 +0800
author: sfeng
categories: [Dev]
tags: [lds]
lang: zh
---

## Background
> Every link is controlled by a linker script. This script is written in the linker command language.  
> The main purpose of the linker script is to describe how the sections in the input files should be mapped into the output file, and to control the memory layout of the output file.   
{: .prompt-tip }  
&emsp;&emsp;在现代编译系统中，当编译器产生一个目标文件（包括可执行文件或者是libary）时，都需要用link script的参与来做link。主要作用在于如何在空间上安排其中的汇编代码，包括诸如入口函数，text段位置，rodata/data段位置，bss，stack，heap甚至还有开发者自定义的段等等。某些情况下即便没有指定link file，编译器也会使用默认的script来产生目标文件。  
&emsp;&emsp;回到嵌入式SoC的开发中，由于芯片项目会有前后继承关系，某阶段代码大约是类似的，可能会根据芯片型号或者项目做微调，关联到本文提到的LDS文件，有可能会对空间布局稍作改动，如果为每次改动都重新写一个LDS文件，免不了会变得混乱，Makefile也会多很多分支。本文参照ATF和Linux的编译系统，对它们使用编译器的预处理功能把.ld.S转化为.ld文件做了一个总结。  

- ATF的ld.S文件  
[bl1/bl1.ld.S](https://github.com/TrustedFirmware-A/trusted-firmware-a/blob/v2.9.0/bl1/bl1.ld.S)  
[bl31/bl31.ld.S](https://github.com/TrustedFirmware-A/trusted-firmware-a/blob/v2.9.0/bl31/bl31.ld.S)  
- Linux的ld.S文件  
[arch/arm64/kernel/vmlinux.lds.S](https://github.com/torvalds/linux/blob/v5.15/arch/arm64/kernel/vmlinux.lds.S)  

## Compile Option of GCC
&emsp;&emsp;在从汇编文件ld.S转换为lds的过程中，会用到以下一些Preprocessor的options。  
> -P  
> Inhibit generation of linemarkers in the output from the preprocessor. This might be useful when running the preprocessor on something that is not C code, and will be sent to a program which might be confused by the linemarkers.
{: .prompt-tip }  

&emsp;&emsp;关于Line Marker，有下面两个purposes：  
> 1. If the compiler encounters an error, it uses the most recent line number directive to determine what file and line to reference in the error message.  
> (The #line directive can even be used in generated code to allow error messages to point directly to the original source file, rather than to an intermediate C source file.)  
> 2. If debugging information (-g) is turned on, line number data is included in debug sections of the generated object file.  
{: .prompt-info }  

&emsp;&emsp;因为这里要生成lds文件，所以加-P不在输出中假如Line Marker。  

> -x assembler-with-cpp  
> Use the -x assembler-with-cpp option to tell armclang that the assembly source file requires preprocessing. This option is useful when you have existing source files with the lowercase extension .s.
{: .prompt-tip }  

&emsp;&emsp;汇编文件会以.s或者.S标识，这里用Arm GNU compiler试了下，感觉没区别。Arm的文档里有提到armclang，为了保险，加上这个option，反正也没啥影响。  

> -o
> Specify the output file.
{: .prompt-tip }  

&emsp;&emsp;这个大家都知道，指定输出文件。  

&emsp;&emsp;其实还可以用其他的Option，如-MD，-MT，-MP等等，不过上面这几个也足够了。  

## Example
&emsp;&emsp;举个栗子吧。有以下几个文件：  
```sass
#include "platform.h"

OUTPUT_FORMAT(PLATFORM_LINKER_FORMAT)
OUTPUT_ARCH(PLATFORM_LINKER_ARCH)

ENTRY(_start)

MEMORY
{
  RAM0     (rwx) : ORIGIN = RAM0_START, LENGTH = ROM0_SIZE
  RAM1     (rw) : ORIGIN = RAM1_START, LENGTH = ROM1_SIZE
}

SECTIONS
{
  .text :
  {
    *(.text*)
    . = ALIGN(32);
    *(.rodata*)
    . = ALIGN(32);
    *(.data*)
  } > RAM0

 #ifdef CORTEX_M_TZ
  .gnu.sgstubs :
  {
    . = ALIGN(32);
    *(.gnu.sgstubs*)
    . = ALIGN(32);
  } > RAM0
 #endif

  .bss :
  {
    . = ALIGN(4);
    __bss_start = .;
    *(.bss*)
    . = ALIGN(4);
    __bss_end = .;

    . = ALIGN(32);

    __StackSeal = .;
    __StackLimitm = .;
    . = . + 0x1000;
    __StackTopm = .;
  } > RAM1
}
```
{: file='test.ld.S'}  

```sass
#ifndef __PLATFORM_H
#define __PLATFORM_H

#define PLATFORM_LINKER_FORMAT          "elf64-littleaarch64"
#define PLATFORM_LINKER_ARCH            "aarch64"

#define RAM0_START                      0x20000000
#define ROM0_SIZE                       0x100000
#define RAM1_START                      0x30000000
#define ROM1_SIZE                       0x80000

#endif /* __PLATFORM_H */
```
{: file='platform1/platform.h'}  

```sass
#ifndef __PLATFORM_H
#define __PLATFORM_H

#define PLATFORM_LINKER_FORMAT          "elf32-littlearm"
#define PLATFORM_LINKER_ARCH            "arm"

#define RAM0_START                      0x50000000
#define ROM0_SIZE                       0x80000
#define RAM1_START                      0x60000000
#define ROM1_SIZE                       0x100000

#endif /* __PLATFORM_H */
```
{: file='platform2/platform.h'}  

&emsp;&emsp;生成platform1的lds的命令如下：  
```shell
cpp -Iplatform1 -P -x assembler-with-cpp -o output/platform1/test.ld test.ld.S
```  
&emsp;&emsp;生成的lds为：  
```sass
OUTPUT_FORMAT("elf64-littleaarch64")
OUTPUT_ARCH("aarch64")
ENTRY(_start)
MEMORY
{
  RAM0 (rwx) : ORIGIN = 0x20000000, LENGTH = 0x100000
  RAM1 (rw) : ORIGIN = 0x30000000, LENGTH = 0x80000
}
SECTIONS
{
  .text :
  {
    *(.text*)
    . = ALIGN(32);
    *(.rodata*)
    . = ALIGN(32);
    *(.data*)
  } > RAM0
  .bss :
  {
    . = ALIGN(4);
    __bss_start = .;
    *(.bss*)
    . = ALIGN(4);
    __bss_end = .;
    . = ALIGN(32);
    __StackSeal = .;
    __StackLimitm = .;
    . = . + 0x1000;
    __StackTopm = .;
  } > RAM1
}
```
{: file='output/platform1/test.ld'}  

&emsp;&emsp;生成platform2的lds的命令如下：  
```shell
cpp -Iplatform2 -DCORTEX_M_TZ -P -x assembler-with-cpp -o output/platform2/test.ld test.ld.S
```  
&emsp;&emsp;生成lds为：  
```sass
OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH("arm")
ENTRY(_start)
MEMORY
{
  RAM0 (rwx) : ORIGIN = 0x50000000, LENGTH = 0x80000
  RAM1 (rw) : ORIGIN = 0x60000000, LENGTH = 0x100000
}
SECTIONS
{
  .text :
  {
    *(.text*)
    . = ALIGN(32);
    *(.rodata*)
    . = ALIGN(32);
    *(.data*)
  } > RAM0
  .gnu.sgstubs :
  {
    . = ALIGN(32);
    *(.gnu.sgstubs*)
    . = ALIGN(32);
  } > RAM0
  .bss :
  {
    . = ALIGN(4);
    __bss_start = .;
    *(.bss*)
    . = ALIGN(4);
    __bss_end = .;
    . = ALIGN(32);
    __StackSeal = .;
    __StackLimitm = .;
    . = . + 0x1000;
    __StackTopm = .;
  } > RAM1
}
```
{: file='output/platform2/test.ld'}  

&emsp;&emsp;然后该lds文件就可以在link的时候用了。  

## How to Use It in Cmake
&emsp;&emsp;怎么把它集成进cmake呢？以下是个example。  

```sass
cmake_minimum_required(VERSION 3.10)
project(ldtest)

SET(TEST_SRC
        ${CMAKE_CURRENT_SOURCE_DIR}/main.c
)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_C_COMPILER arm-none-eabi-gcc)
set(CMAKE_ASM_COMPILER arm-none-eabi-gcc)
set(CMAKE_CPP_COMPILER arm-none-eabi-cpp)

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/test.ld
    COMMAND ${CMAKE_CPP_COMPILER} -I${CMAKE_CURRENT_SOURCE_DIR}/platform2 -DCORTEX_M_TZ -P -x assembler-with-cpp -o ${CMAKE_CURRENT_BINARY_DIR}/test.ld ${CMAKE_CURRENT_SOURCE_DIR}/test.ld.S
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/test.ld.S
)

add_custom_target(gen_ld DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/test.ld)

add_executable(ldtest ${TEST_SRC})
add_dependencies(ldtest gen_ld)

target_link_options(romlib_test PRIVATE
        -nostdlib
        -T ${CMAKE_CURRENT_BINARY_DIR}/test.ld
)

```
{: file='CMakeLists.txt'}  

## Reference
[**Link Script File**](https://sourceware.org/binutils/docs/ld/Scripts.html)  
[**GCC Common Options**](https://markrepo.github.io/tools/2018/06/25/gcc/)  
[**Preprocessor Options**](https://gcc.gnu.org/onlinedocs/gcc-14.2.0/gcc/Preprocessor-Options.html#Preprocessor-Options)  
[**Line Marker**](https://stackoverflow.com/questions/53999485/are-line-markers-in-c-preprocessor-output-used-by-compiler)  
[**Preprocessing Assembly Code**](https://developer.arm.com/documentation/100066/latest/assembling-assembly-code/preprocessing-assembly-code)  
