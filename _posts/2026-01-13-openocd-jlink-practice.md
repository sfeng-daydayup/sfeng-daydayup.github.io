---
layout: post
title: OPENOCD Jlink Practice
date: 2026-01-13 18:58 +0800
author: sfeng
categories: [JTAG Debugging Fundamentals]
tags: [JTAG]
lang: en
---

## Introduction

&emsp;&emsp;JTAG系列主要使用ChatGPT(free version)生成的,毕竟现在AI火爆的一塌糊涂,然而AI并不是包办一切,提示词很重要,并且后期的核对更重要,因为AI越来越会编造“事实”了.但这并不妨碍使用AI来提高工作效率,是指数级提高.

&emsp;&emsp;回归主题,前面学习了JTAG,正好手边有Jlink和板子,可以实践下了.

---

## OPENOCD

&emsp;&emsp;因为要支持比较新的ARM架构,OPENOCD从github下载了最新版本.

<https://xpack.github.io/openocd/releases/>

## Jlink

&emsp;&emsp;这个的configure简单,如下:


```
# Use J-Link probe
adaptor driver jlink

# Select JTAG transport
transport select jtag

# JTAG clock (adjust if signal integrity is poor)
adapter speed 5000
```

Output like:

```
xPack Open On-Chip Debugger 0.12.0+dev-02228-ge5888bda3-dirty (2025-10-04-22:42)
Licensed under GNU GPL v2
For bug reports, read
        http://openocd.org/doc/doxygen/bugs.html
adapter speed: 5000 kHz
Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
Info : J-Link  V12 compiled Jun 5 2024 15:19:37
Info : Hardware version: 12.00
Info : VTarget = 1.857 V
Info : clock speed 5000 kHz
Warn : There are no enabled taps.  AUTO PROBING MIGHT NOT WORK!!
Info : JTAG tap: auto0.tap tap/device found: 0x4ba06477 (mfg: 0x23b (ARM Ltd), part: 0xba06, ver: 0x4)
Info : JTAG tap: auto1.tap tap/device found: 0x4ba06477 (mfg: 0x23b (ARM Ltd), part: 0xba06, ver: 0x4)
Warn : AUTO auto0.tap - use "jtag newtap auto0 tap -irlen 4 -expected-id 0x4ba06477"
Warn : AUTO auto1.tap - use "jtag newtap auto1 tap -irlen 4 -expected-id 0x4ba06477"
Warn : gdb services need one or more targets defined
```

&emsp;&emsp;输出的log中的auto probe找到两个TAP,接下来就去创建两个TAP出来.

---

## TAP

```
# JTAG TAP for ARM Debug Port
# IR length is typically 4 for ARM DPs
jtag newtap soc tap0 -irlen 4 -expected-id 0x4ba06477
jtag newtap soc tap1 -irlen 4 -expected-id 0x4ba06477

```

Output:

```
Info : JTAG tap: soc.tap0 tap/device found: 0x4ba06477 (mfg: 0x23b (ARM Ltd), part: 0xba06, ver: 0x4)
Info : JTAG tap: soc.tap1 tap/device found: 0x4ba06477 (mfg: 0x23b (ARM Ltd), part: 0xba06, ver: 0x4)
```

&emsp;&emsp;By the way, 为啥两个TAP ID Code是一样的? 答案在这里:

> The IDCODE 0x4ba06477 is the "fingerprint" for a standard ARM CoreSight Debug Port (DP).
>   0x4: Version/Revision
>   0xba06: Part Number (Standard ARM DP)
>   0x23b: Designer (ARM Ltd)
>   0x1: Always 1 for JTAG IDCODEs
{: .prompt-info } 

---

## DAP

&emsp;&emsp;根据前面文章的介绍,要继续创建DAP才能访问AP和devices.


```
# Create ARM Debug Access Port
dap create soc.dap0 -chain-position soc.tap0 -adiv6
dap create soc.dap1 -chain-position soc.tap1 -adiv6
```

&emsp;&emsp;这里需要注意"-adiv6" 这个选项,"ARMv8.2+ platforms often require ADIv6",而OPENOCD默认是-adiv5,如果不指定就会出现"Error: Invalid ACK (4) in DAP response"的错.

---

## ROM Table

&emsp;&emsp;在创建后面的节点之前,还需要一些信息,比如ap number, base address, debug address啥的.这些信息要从ROM Table中找到.通过"dap info"命令得到的信息如下:

```
> soc.dap0 info
AP # 0x0
                Peripheral ID 0x0000093261
                Designer is 0x013, xxxxxxxx
                Part is 0x261, Unrecognized 
                Component class is 0x9, CoreSight component
                Type is 0x00, Miscellaneous, other
                Dev Arch is 0x47700af7, ARM Ltd "CoreSight ROM architecture" rev.0
                Type is ROM table
                MEMTYPE system memory not present: dedicated debug bus
        ROMTABLE[0x0] = 0x00010003
                AP # 0x10000
                Peripheral ID 0x04004bb9e3
                Designer is 0x23b, ARM Ltd
                Part is 0x9e3, SoC-600 AHB-AP (AHB5 Memory Access Port)
                Component class is 0x9, CoreSight component
                Type is 0x00, Miscellaneous, other
                Dev Arch is 0x47700a17, ARM Ltd "Memory Access Port v2 architecture" rev.0
                AP ID register 0x44770008
                Type is MEM-AP AHB5 with enhanced HPROT
        [L01] MEM-AP BASE 0xe00fe003
                Valid ROM table present
                Component base address 0xe00fe000
                Peripheral ID 0x0a000f54d2
                Designer is 0x575, Arm Technology (China) Co Ltd
                Part is 0x4d2, Cortex-M52 ROM (ROM Table)
                Component class is 0x1, ROM table
                MEMTYPE system memory present on bus
        [L01] ROMTABLE[0x0] = 0x00001003
                Component base address 0xe00ff000
                Peripheral ID 0x0a000f54d2
                Designer is 0x575, Arm Technology (China) Co Ltd
                Part is 0x4d2, Cortex-M52 ROM (ROM Table)
                Component class is 0x1, ROM table
                MEMTYPE system memory present on bus
        [L02] ROMTABLE[0x0] = 0xfff0f003
                Component base address 0xe000e000
                Peripheral ID 0x0a000f5d24
                Designer is 0x575, Arm Technology (China) Co Ltd
                Part is 0xd24, Cortex-M52 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x00, Miscellaneous, other
                Dev Arch is 0x47702a04, ARM Ltd "Processor debug architecture (ARMv8-M)" rev.0
        [L02] ROMTABLE[0x4] = 0xfff02003
                Component base address 0xe0001000
                Peripheral ID 0x0a000f5d24
                Designer is 0x575, Arm Technology (China) Co Ltd
                Part is 0xd24, Cortex-M52 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x00, Miscellaneous, other
                Dev Arch is 0x47711a02, ARM Ltd "DWT architecture" rev.1
        [L02] ROMTABLE[0x8] = 0xfff03003
                Component base address 0xe0002000
                Peripheral ID 0x0a000f5d24
                Designer is 0x575, Arm Technology (China) Co Ltd
                Part is 0xd24, Cortex-M52 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x00, Miscellaneous, other
                Dev Arch is 0x47701a03, ARM Ltd "Flash Patch and Breakpoint unit (FPB) architecture" rev.0
        [L02] ROMTABLE[0xc] = 0xfff01003
                Component base address 0xe0000000
                Peripheral ID 0x0a000f5d24
                Designer is 0x575, Arm Technology (China) Co Ltd
                Part is 0xd24, Cortex-M52 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x43, Trace Source, Bus
                Dev Arch is 0x47701a01, ARM Ltd "Instrumentation Trace Macrocell (ITM) architecture" rev.0
        [L02] ROMTABLE[0x10] = 0xfff41002
                Component not present
        [L02] ROMTABLE[0x14] = 0xfff42002
                Component not present
        [L02] ROMTABLE[0x18] = 0xfff04003
                Component base address 0xe0003000
                Peripheral ID 0x0a000f5d24
                Designer is 0x575, Arm Technology (China) Co Ltd
                Part is 0xd24, Cortex-M52 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x16, Performance Monitor, Processor
                Dev Arch is 0x47700a06, ARM Ltd "unknown" rev.0
        [L02] ROMTABLE[0x1c] = 0xfff43003
                Component base address 0xe0042000
                Peripheral ID 0x0a000f5d24
                Designer is 0x575, Arm Technology (China) Co Ltd
                Part is 0xd24, Cortex-M52 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x14, Debug Control, Trigger Matrix
                Dev Arch is 0x47701a14, ARM Ltd "Cross Trigger Interface (CTI) architecture" rev.0
        [L02] ROMTABLE[0x20] = 0xfff47002
                Component not present
        [L02] ROMTABLE[0x24] = 0x00000000
        [L02]   End of ROM table
        [L01] ROMTABLE[0x4] = 0xfff42003
                Component base address 0xe0040000
                Peripheral ID 0x0a000f5d24
                Designer is 0x575, Arm Technology (China) Co Ltd
                Part is 0xd24, Cortex-M52 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x11, Trace Sink, Port
        [L01] ROMTABLE[0x8] = 0xfff47002
                Component not present
        [L01] ROMTABLE[0xc] = 0x1ff02002
                Component not present
        [L01] ROMTABLE[0x10] = 0x00000000
        [L01]   End of ROM table
        ROMTABLE[0x4] = 0x00020003
                AP # 0x20000
                Peripheral ID 0x04000bb9ef
                Designer is 0x23b, ARM Ltd
                Part is 0x9ef, Unrecognized 
                Component class is 0x9, CoreSight component
                Type is 0x00, Miscellaneous, other
                Dev Arch is 0x47700a57, ARM Ltd "unknown" rev.0
        ROMTABLE[0x8] = 0x00030003
                AP # 0x30000
                Peripheral ID 0x04004bb9e3
                Designer is 0x23b, ARM Ltd
                Part is 0x9e3, SoC-600 AHB-AP (AHB5 Memory Access Port)
                Component class is 0x9, CoreSight component
                Type is 0x00, Miscellaneous, other
                Dev Arch is 0x47700a17, ARM Ltd "Memory Access Port v2 architecture" rev.0
                AP ID register 0x44770008
                Type is MEM-AP AHB5 with enhanced HPROT
        [L01] MEM-AP BASE 0x00000002
                No ROM table present
        ROMTABLE[0xc] = 0x00000000
                End of ROM table

```

```
> soc.dap1 info
AP # 0x0
                Peripheral ID 0x0000093261
                Designer is 0x013, xxxxxxxx
                Part is 0x261, Unrecognized 
                Component class is 0x9, CoreSight component
                Type is 0x00, Miscellaneous, other
                Dev Arch is 0x47700af7, ARM Ltd "CoreSight ROM architecture" rev.0
                Type is ROM table
                MEMTYPE system memory not present: dedicated debug bus
        ROMTABLE[0x0] = 0x00010003
                AP # 0x10000
                Peripheral ID 0x04003bb9e2
                Designer is 0x23b, ARM Ltd
                Part is 0x9e2, SoC-600 APB-AP (APB4 Memory Access Port)
                Component class is 0x9, CoreSight component
                Type is 0x00, Miscellaneous, other
                Dev Arch is 0x47700a17, ARM Ltd "Memory Access Port v2 architecture" rev.0
                AP ID register 0x34770006
                Type is MEM-AP APB4
        [L01] MEM-AP BASE 0x00000003
                Valid ROM table present
                Component base address 0x00000000
                Peripheral ID 0x04007bb4e4
                Designer is 0x23b, ARM Ltd
                Part is 0x4e4, Cortex-A76 ROM (ROM Table)
                Component class is 0x9, CoreSight component
                Type is 0x00, Miscellaneous, other
                Dev Arch is 0x47700af7, ARM Ltd "CoreSight ROM architecture" rev.0
                Type is ROM table
                MEMTYPE system memory not present: dedicated debug bus
        [L01] ROMTABLE[0x0] = 0x00010003
                Component base address 0x00010000
                Peripheral ID 0x04003bbd05
                Designer is 0x23b, ARM Ltd
                Part is 0xd05, Cortex-A55 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x15, Debug Logic, Processor
                Dev Arch is 0x47708a15, ARM Ltd "Processor debug architecture (v8.2-A)" rev.0
        [L01] ROMTABLE[0x4] = 0x00020003
                Component base address 0x00020000
                Peripheral ID 0x04007bbd05
                Designer is 0x23b, ARM Ltd
                Part is 0xd05, Cortex-A55 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x14, Debug Control, Trigger Matrix
                Dev Arch is 0x47701a14, ARM Ltd "Cross Trigger Interface (CTI) architecture" rev.0
        [L01] ROMTABLE[0x8] = 0x00030003
                Component base address 0x00030000
                Peripheral ID 0x04003bbd05
                Designer is 0x23b, ARM Ltd
                Part is 0xd05, Cortex-A55 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x16, Performance Monitor, Processor
                Dev Arch is 0x47702a16, ARM Ltd "Processor Performance Monitor (PMU) architecture" rev.0
        [L01] ROMTABLE[0xc] = 0x00040003
                Component base address 0x00040000
                Peripheral ID 0x04003bbd05
                Designer is 0x23b, ARM Ltd
                Part is 0xd05, Cortex-A55 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x13, Trace Source, Processor
                Dev Arch is 0x47724a13, ARM Ltd "Embedded Trace Macrocell (ETM) architecture" rev.2
        [L01] ROMTABLE[0x10] = 0x000c0002
                Component not present
        [L01] ROMTABLE[0x14] = 0x000d0006
                Component not present
        [L01] ROMTABLE[0x18] = 0x000e0006
                Component not present
        [L01] ROMTABLE[0x1c] = 0x00110003
                Component base address 0x00110000
                Peripheral ID 0x04003bbd05
                Designer is 0x23b, ARM Ltd
                Part is 0xd05, Cortex-A55 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x15, Debug Logic, Processor
                Dev Arch is 0x47708a15, ARM Ltd "Processor debug architecture (v8.2-A)" rev.0
        [L01] ROMTABLE[0x20] = 0x00120003
                Component base address 0x00120000
                Peripheral ID 0x04007bbd05
                Designer is 0x23b, ARM Ltd
                Part is 0xd05, Cortex-A55 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x14, Debug Control, Trigger Matrix
                Dev Arch is 0x47701a14, ARM Ltd "Cross Trigger Interface (CTI) architecture" rev.0
        [L01] ROMTABLE[0x24] = 0x00130003
                Component base address 0x00130000
                Peripheral ID 0x04003bbd05
                Designer is 0x23b, ARM Ltd
                Part is 0xd05, Cortex-A55 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x16, Performance Monitor, Processor
                Dev Arch is 0x47702a16, ARM Ltd "Processor Performance Monitor (PMU) architecture" rev.0
        [L01] ROMTABLE[0x28] = 0x00140003
                Component base address 0x00140000
                Peripheral ID 0x04003bbd05
                Designer is 0x23b, ARM Ltd
                Part is 0xd05, Cortex-A55 Debug (Debug Unit)
                Component class is 0x9, CoreSight component
                Type is 0x13, Trace Source, Processor
                Dev Arch is 0x47724a13, ARM Ltd "Embedded Trace Macrocell (ETM) architecture" rev.2
        [L01] ROMTABLE[0x2c] = 0x001c0002
                Component not present
        [L01] ROMTABLE[0x30] = 0x00000000
        [L01]   End of ROM table
        ROMTABLE[0x4] = 0x00020003
                AP # 0x20000
                Peripheral ID 0x04004bb9e3
                Designer is 0x23b, ARM Ltd
                Part is 0x9e3, SoC-600 AHB-AP (AHB5 Memory Access Port)
                Component class is 0x9, CoreSight component
                Type is 0x00, Miscellaneous, other
                Dev Arch is 0x47700a17, ARM Ltd "Memory Access Port v2 architecture" rev.0
                AP ID register 0x44770008
                Type is MEM-AP AHB5 with enhanced HPROT
        [L01] MEM-AP BASE 0x00000002
                No ROM table present
        ROMTABLE[0x8] = 0x00000000
                End of ROM table
```

## CM52

&emsp;&emsp;从上面的ROM Table可以看到,有一个cortex-cm52挂在dap0下面,下面就创建一个cm52的target.

```
# Cortex-M52 via MEM-AP
target create m52 cortex_m -endian little -dap soc.dap0 -ap-num 0x10000
```

Output:

```
Info : [m52] Cortex-M52 r0p2 processor detected
Info : [m52] target has 8 breakpoints, 8 watchpoints
Info : [m52] Examination succeed
```


```
> targets
    TargetName         Type       Endian TapName            State       
--  ------------------ ---------- ------ ------------------ ------------
 0* cm52               cortex_m   little soc.tap0           running
> halt
[cm52] halted due to debug-request, current mode: Thread 
xPSR: 0x61000000 pc: 0x10000c0c psp: 0x30003350
> targets
    TargetName         Type       Endian TapName            State       
--  ------------------ ---------- ------ ------------------ ------------
 0* cm52               cortex_m   little soc.tap0           halted
> resume
> targets
    TargetName         Type       Endian TapName            State       
--  ------------------ ---------- ------ ------------------ ------------
 0* cm52               cortex_m   little soc.tap0           running
```

---

## CA55

&emsp;&emsp;A core则会复杂一些,除了前面提到的adiv6,因为SMP的缘故,还有CTI(Cross Trigger Interface)需要注意.CTI相关如下:

- Each CA55 has an associated CTI
- Required for:
  - Synchronous halt/resume
  - Debugging secondary cores
  - Bringing cores out of WFI/WFE

&emsp;&emsp;在Linux SMP的环境中用OPENOCD连接A Core的时候,因为有CTI,当halt一个CPU的时候,其他core也会同时halt,这样就避免了debug多任务系统时的sync问题.这样首先要创建CTI,然后再创建Processor.

```
# There are two CA55 cores. Each one associates a CTI.
cti create cti0 -dap soc.dap1 -baseaddr 0x020000 -ap-num 0x10000 
cti create cti1 -dap soc.dap1 -baseaddr 0x120000 -ap-num 0x10000

# Associate correspinding CTI to processor
target create ca55_0 aarch64 -endian little -dbgbase 0x10000 -dap soc.dap1 -ap-num 0x10000 -coreid 0 -cti cti0
target create ca55_1 aarch64 -endian little -dbgbase 0x110000 -dap soc.dap1 -ap-num 0x10000 -coreid 1 -cti cti1

# Bind core 0 and 1 together
target smp ca55_0 ca55_1
```

&emsp;&emsp;这样CA55有能认出来了.

```
> targets
    TargetName         Type       Endian TapName            State       
--  ------------------ ---------- ------ ------------------ ------------
 0  cm52               cortex_m   little soc.tap0           running
 1  ca55_0             aarch64    little soc.tap1           running
 2* ca55_1             aarch64    little soc.tap1           running
```

&emsp;&emsp;后面就可以通过openocd和gdb进行debug了.


---

## Reference
[**TAB Declaration**](https://openocd.org/doc/html/TAP-Declaration.html)  
[**Target Type**](https://openocd.org/doc/html/CPU-Configuration.html#index-target-type)  
[**CTI**](https://openocd.org/doc/html/Architecture-and-Core-Commands.html#index-CTI)  

