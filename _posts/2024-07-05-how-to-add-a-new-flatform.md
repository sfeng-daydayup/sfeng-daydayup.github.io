---
layout: post
title: How to Add a New Flatform
author: sfeng
date: 2024-07-05 11:48 +0800
categories: [Blogging, OPTEE]
tags: [optee]
lang: zh
---
&emsp;&emsp;OPTEE开发的第一步是增加所使用SoC的支持。这里分两种情况，一种是已经有同类SoC的支持，只是做一些差异化配置，OPTEE叫做platform flavor；一种则是一个全新的platform。学会怎么增加一个platform，platform flavor自然不在话下。  
&emsp;&emsp;增加一个全新的platform的支持，需要在[OPTEE root path]/core/arch/arm(riscv)/下新建一个以plat-作为prefix的文件夹，例如plat-my_soc_name，或者plat-my_orgnization_name。目录下的主要文件为：  
```
conf.mk  sub.mk  platform_config.h  main.c
```
- conf.mk  
  这个文件主要包含两个内容，一个是OPTEE的配置选项， 另一个是编译选项。  
  配置选项有两种写法，开发者可以根据需求选择方式。  
  1. CFG_SOMETHING ?= DEFAULT_VALUE               // may be overridden by external setup
  2. $(call force,CFG_SOMETHING,SPECIFIED_VALUE)  // can't be modified
  配置选项主要有下面这些：  
  ```
  PLATFORM_FLAVOR          // default platform flavor
  CFG_TEE_CORE_NB_CORE     // number of cores
  CFG_GENERIC_BOOT         // seems not used
  CFG_WITH_ARM_TRUSTED_FW  // shall be set to y if using armv8
  CFG_WITH_LPAE            // long descriptor translation format. shall be y if armv8
  CFG_NUM_THREADS          // shall >= CFG_TEE_CORE_NB_CORE for efficiency
  CFG_CRYPTO_WITH_CE       // set to y to use cropto-extention
  CFG_GIC                  // default use gic v2 if arm
  CFG_ARM_GICV3            // set to y to enable arm gic v3
  CFG_CORE_ASLR            // address space layout randomization
  CFG_CORE_PREALLOC_EL0_TBLS // set to y if you gonna map large amount of memory to TA
  CFG_CORE_RODATA_NOEXEC   // page aligned so system can easy set MMU properties to non-executable
  CFG_WITH_STACK_CANARIES  // add stack guards before/after stacks and periodically check them
  CFG_TZDRAM_START         // start of OPTEE Core seucre memory
  CFG_TZDRAM_SIZE          // size of OPTEE Core seucre memory
  CFG_SHMEM_START          // start of non-secure static SHM
  CFG_SHMEM_SIZE           // size of non-secure static SHM
  CFG_SECURE_DATA_PATH     // enable secure data path
  CFG_8250_UART
  CFG_16550_UART
  CFG_PL011                // choose one if your SoC use one of them. Otherwise, write a new one
  ```

  OPTEE还有很多optional的配置，作为基础配置，上面列的这些应该比较全了。  
  编译选项目前主要就是include core/arch/arm/cpu/xxx.mk。貌似没有更多选项。  
- platform_config.h  
  这个文件是创建一个platform必须的，可以拿现有项目中的作为参考。  比如core/arch/arm/plat-hikey中的一些选项。
  ```
  STACK_ALIGNMENT         // cache line aligned
  TEE_RAM_START           // set to CFG_TZDRAM_START
  DRAM0_BASE              // ddr base address which optee can access
  DRAM0_SIZE              // size of ddr which optee can access
  UART BASE ADDRESS
  UART BAUDRATE
  UART CLK IN HZ          // used to caculate the divider
  GIC BASE ADDRESS
  ```

  和platform flavor相关的一些配置也可以放在platform_config.h里，如果很多，建议分成另外一个文件，比如platform_config_flavor_xxx.h，然后在platform_config.h中include。  
- sub.mk  
  当OPTEE的编译脚本根据指定的PLATFORM=my_platform找到相应的core/arch/arm/plat-my_platform目录后，sub.mk就会被include。它里面一般包含以下内容：  
  - 编译当前PLATFORM和PLATFORM_FLAVOR需要的source file
  - 头文件路径
  - subdir，当然subdir下也要有相应的sub.mk  
- main.c  
  大概是OPTEE的开发者约定把该platform的入口函数定义在main.c中，因为该文件由sub.mk加入编译，其实可以命名为你想要的名字。该文件中需要实现的function可能如下：  
  - IO space, DDR space等的注册
  - GIC的初始化
  - UART初始化和注册
  - 其他相关硬件的初始化  

&emsp;&emsp;这样创建好目录，写好以上四个文件，OPTEE基本上就可以在SoC上运行了。