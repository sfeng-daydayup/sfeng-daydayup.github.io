---
layout: post
title: boot up of u-boot
date: 2024-11-02 15:21 +0800
author: sfeng
categories: [Boot]
tags: [boot, u-boot]
lang: zh
---

## Preface
> U-Boot (subtitled "the Universal Boot Loader" and often shortened to U-Boot) is an open-source boot loader used in embedded devices to perform various low-level hardware initialization tasks and boot the device's operating system kernel. It is available for a number of computer architectures, including M68000, ARM, Blackfin, MicroBlaze, AArch64, MIPS, Nios II, SuperH, PPC, RISC-V and x86.
{: .prompt-info }  

&emsp;&emsp;U-boot作为很流行的开源bootloader项目，它可以用作first stage bootloader（u-boot SPL），也可以做second stage bootloader。所谓first stage bootloader，是从ROM出来的第一段程序，一般运行在sram中，整体size比较小，用来做基本硬件的初始化，比如clock，DDR，等DDR初始化好了，还会把后面的binaries从flash上搬运到DDR上，在ARMv8以上的系统中一般会run在EL3。而second stage bootloader主要运行在DDR中，为操作系统的启动做准备。考虑到first stage bootloader一般都不开源（也会有二般情况），而U-boot是GPL license的，这种情况就要考虑其他的开源bootloader了。U-boot还提供了CLI和各种command，并提供了简单的方法添加自定义command，也可以用来做各种工具软件，比如diagnostic程序。   

## Boot of U-boot

> Board: QEMU  
> U-boot Version: v2023.07.02。  
{: .prompt-info } 

&emsp;&emsp;首先找到Entry Point，一般是定义在lds（Linker Description Script）中，ARMv8的lds就放在它的目录下arch/arm/cpu/armv8/u-boot.lds，它指定的entry为[_start](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/cpu/armv8/u-boot.lds#L15)。  
&emsp;&emsp;本来想找一个tool导出从入口函数的call graph的，试用了几个开源的都不大行，比如[callgragh-gen](https://github.com/kuopinghsu/callgraph-gen)，[cally](https://github.com/chaudron/cally)，[crabviz](https://github.com/chanhx/crabviz)啥的，它们在处理汇编和一些宏的时候都有问题，导致call graph联系不起来，很凌乱。手动整理的call graph及解析如下：  
- [_start](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/cpu/armv8/start.S#L20)  
  - [reset](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/cpu/armv8/start.S#L55)  
    - [save_boot_params](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/cpu/armv8/start.S#L372)  
      - [save_boot_params_ret](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/cpu/armv8/start.S#L59)  
        - pie fix up if CONFIG_POSITION_INDEPENDENT  
          这个选项打开的时候，只要放在4KB对齐的地址，都可以relocate跑起来。  
        - switch exception level  
          U-boot可以运行在ARM的各个exception level。  
        - set vbar if SPL  
        - initialize CNTFRQ if EL3 and CONFIG_COUNTER_FREQUENCY defined  
          如果U-boot之前没有设过generic timer，U-boot要设好frequency并enable  
      - [apply_core_errata](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/cpu/armv8/start.S#L200)  
      - [lowlevel_init](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/cpu/armv8/start.S#L289)  
        - gic_init (gic distributor and cpu interface)  
      - spin_table_secondary_jump (if SMP and spintable defined)  
      - select SP_ELx  
      - [_main](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/lib/crt0_64.S#L67)  
        - [board_init_f_alloc_reserve](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/init/board_init.c#L78)  
        - [board_init_f_init_reserve](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/init/board_init.c#L134)  
        - [board_init_f](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_f.c#L979)  
          - [initcall_run_list](https://github.com/u-boot/u-boot/blob/v2023.07.02/include/initcall.h#L22)  
            循环调用定义在[static const init_fnc_t init_sequence_f[]](https://github.com/u-boot/u-boot/tree/v2023.07.02/common#L834)中的函数。  
            - [setup_mon_len](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_f.c#L289)  
            - [fdtdec_setup](https://github.com/u-boot/u-boot/blob/v2023.07.02/lib/fdtdec.c#L1664)  
            - [initf_malloc](https://github.com/u-boot/u-boot/blob/master/common/dlmalloc.c#L2484)  
            - [log_init](https://github.com/u-boot/u-boot/blob/master/common/log.c#L437)  
            - [initf_bootstage](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_f.c#L767)  
            - [event_init](https://github.com/u-boot/u-boot/blob/master/common/event.c#L210)  
            - [arch_cpu_init](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/cpu/armv8/fsl-layerscape/cpu.c#L623)  
              默认是空函数，有的会在这里打开MMU（MPU for Cortex-M）增加performance。  
            - mach_cpu_init
            - [initf_dm](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_f.c#L792)  
              初始化U-boot driver model，DM是类Linux的driver model。  
            - board_early_init_f
              可以在这里设pinmux，设置GPIO状态，等等  
            - [timer_init](https://github.com/u-boot/u-boot/blob/master/arch/arm/cpu/armv8/fsl-layerscape/cpu.c#L1178)  
              之前提到的generic timer也可以在这里初始化，有些SoC还有特别的寄存器去enable timer（见link中的注释），也可以在这里执行。  
            - [env_init](https://github.com/u-boot/u-boot/blob/master/env/env.c#L318)  
            - [init_baud_rate](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_f.c#L116)  
              一般用uart做console，baud rate默认为115200。  
            - [serial_init](https://github.com/u-boot/u-boot/blob/master/drivers/serial/serial-uclass.c#L190)  
              用DM的情况下，从fdt中拿到baud rate的值，更新gd和env(上面那步看来只在非DM下有用)。
            - [console_init_f](https://github.com/u-boot/u-boot/blob/master/common/console.c#L1017)  
            - [display_options](https://github.com/u-boot/u-boot/blob/master/lib/display_options.c#L46)  
              打印version_string和build tag
              Example:
              ```
              U-Boot 2023.07.02 (Nov 02 2024 - 16:40:26 +0800)
              ```
            - [dram_init](https://github.com/u-boot/u-boot/blob/v2023.07.02/board/emulation/qemu-arm/qemu-arm.c#L120)  
              这个函数比较重要，是必须实现的函数，主要是从dtb或者其他地方拿到可用的DRAM的region，最好是连续的，然后赋值给gd->ram_size和gd_rambase。  
            - [post_init_f](https://github.com/u-boot/u-boot/blob/v2023.07.02/post/post.c#L29)  
              这个函数很少用，但看了下，发现它做了很多test，如果遇到问题，可以打开它来test一下。主要test函数定义在[](https://github.com/u-boot/u-boot/blob/v2023.07.02/post/tests.c#L46)。  
            - testdram  
              U-boot还单独定义一个宏和函数做dram test，为啥不合并到上一步？  
            - [setup_dest_addr](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_f.c#L355)  
              这个函数里设定gd里的ram_base，ram_top啥的，需要注意的是，get_effective_memsize和board_get_usable_ram_top都是weak function，通过override这两个函数可以重新界定U-boot运行所在内存区域，而dram_init里拿到的全部memory可以看作需要设MMU做map的memory。那多出来map的memory有啥用？其他硬件有可能用啊。  
            - reserve_xxxxxx
              接下来一堆reserve啥啥的函数，除了计算U-boot relocate的地址，还预留出诸如new_gd，heap，stack，trace buffer等等的memory。以qemu为例，大致的memory layout如下：  
              ```
              end       0x82100000 -------
                                   | TLB table from 0x81ae0000 to 0x820f2000
              TLB addr  0x81ae0000 -------
                                   | 1138k for U-boot at: 0x819c3000
              relocaddr 0x819c3000 -------
                                   | 16640k for malloc() at: 0x80983000
              malloc    0x80983000 -------
                                   | 13b Bytes for Board Info at: 0x80982f70
              bd_info   0x80982f70 -------
                                   | 448 Bytes for Global Data at: 0x80982db0
              gd        0x80982db0 -------
                                   | 9184 Bytes for FDT at: 0x809809d0
              fdt_blob  0x809809d0 -------
                                   |
              sp start  0x809809c0 -------
                                   | 
              start     0x40000000 -------
              ```  
            - [reloc_fdt](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_f.c#L633)  
              把fdt copy到新的位置。  
            - [setup_reloc](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_f.c#L692)  
              更新gd和copy gd。  
        - [relocate_code](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/lib/relocate_64.S#L22)  
          把U-boot的code copy到新的地址，这里就是0x819c3000。这里用的是b，没有用bl，但这个函数最后用了ret，这是因为lr在调用这个函数之前经过计算已经设为relocate过后的地址了，汇编如下。  
          ```
          	adr	lr, relocation_return
          	/* Add in link-vs-runtime offset */
            adrp	x0, _start		/* x0 <- Runtime value of _start */
            add	x0, x0, #:lo12:_start
            ldr	x9, _TEXT_BASE		/* x9 <- Linked value of _start */
            sub	x9, x9, x0		/* x9 <- Run-vs-link offset */
            add	lr, lr, x9
            ......
            /* Add in link-vs-relocation offset */
            ldr	x9, [x18, #GD_RELOC_OFF]	/* x9 <- gd->reloc_off */
            add	lr, lr, x9	/* new return address after relocation */
          ```
          ret回来就已经运行在新地址上了。  
        - [clear_bss](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/lib/crt0_64.S#L163)  
        - [board_init_r](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_r.c#L787)  
          它也和board_init_f一样定义了[init_sequence_r](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_r.c#L590)。
          - initr_trace
          - [initr_caches](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_r.c#L111)  
            cache在这里enable了。  
            - [enable_caches](https://github.com/u-boot/u-boot/blob/v2023.07.02/board/emulation/qemu-arm/qemu-arm.c#L142)  
              - [icache_enable](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/cpu/armv8/cache_v8.c#L806)  
              - [dcache_enable](https://github.com/u-boot/u-boot/blob/v2023.07.02/arch/arm/cpu/armv8/cache_v8.c#L563)  
                在create page table阶段，就用到了前面设置的mem_map[]。  
          - [initr_malloc](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_r.c#L197)  
            调用mem_malloc_init把heap pool创建好。  
          - [log_init](https://github.com/u-boot/u-boot/blob/master/common/log.c#L437)  
          - [initr_dm](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_r.c#L233)  
          - board_init  
            可以做些board specific的初始化操作。  
          - initr_binman  
          - initr_dm_devices  
          - stdio_init_tables  
          - serial_initialize  
          - arch_early_init_r  
          - power_init_board  
          - initr_xxx    各种device的init，如flash，mmc等等。  
          - console_init_r  /* fully init console as a device */  
          - interrupt_init  
          - board_late_init  
            注意，early和late init都有宏控制。  
          - [run_main_loop](https://github.com/u-boot/u-boot/blob/v2023.07.02/common/board_r.c#L570)  
            - main_loop
              - cli_init
              - run_preboot_environment_command
                跑定义的preboot command。  
              - process_button_cmds  
                跑定义的button command。注意，这里只能跑一个就退出了。  
              - bootdelay_process
              - [autoboot_command](https://github.com/u-boot/u-boot/blob/master/common/autoboot.c#L491)  
              - cli_loop
                - cli_simple_loop
                  如果前面没有进入到特定的flow，最终就进入command line模式了。  

&emsp;&emsp;嗯，U-boot的boot过程基本就是上面的步骤，中间省略了一些无关紧要的调用。  

## Reference
[**Das U-boot**](https://en.wikipedia.org/wiki/Das_U-Boot)  
[**u-boot github**](https://github.com/u-boot/u-boot/tree/master)  