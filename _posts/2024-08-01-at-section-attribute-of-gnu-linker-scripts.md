---
layout: post
title: AT - Section Attribute of GNU Linker Scripts
date: 2024-08-01 12:02 +0800
author: sfeng
categories: [GNU Linker]
tags: [lds, rom, bl1]
lang: zh
---
## Preface
&emsp;&emsp;最近解决了一个小MCU系统里memory分配的问题。这个小系统本身memory有限，而且还是非连续的两块，原本是把binary(.text，.rodata，.data)放在第一块，其他的(.bss，.stack，.heap)放第二块，现在feature增加，binary超出了第一块的大小，应该怎么办？

## Content
&emsp;&emsp;这个问题其实有个很常用的场景就是ROM code。细节上稍有不同，原理一致。众所周知ROM code是在芯片tape out前就准备好放在netlist里的，是固化在芯片内部read only的code。但代码中有一个段叫.data section，它保存了默认值为非0的全局或者局部变量的值，这些值在运行过程中极大可能会被改变，而ROM code在芯片里是read only的，这部分是如何处理的呢？ATF里的BL1给了很好的例子。  

> Note:  
>     本文中分析的ATF代码版本为v2.11。  
>     示例中引用的编译结果为编译QEMU ARMv8的输出。  
{: .prompt-tip }

&emsp;&emsp;一般来讲，ATF的BL1是用来做ROM code的，这在官方文档[**AP_BL1**](https://trustedfirmware-a.readthedocs.io/en/latest/getting_started/image-terminology.html#ap-boot-rom-ap-bl1)里有介绍。BL1里关于本文提出的问题主要有两个方面，一个是如何pack，另一个是如何load。  

### Pack

&emsp;&emsp;没有看ATF BL1这段之前，博主通过objcopy的功能也可以处理.data section的问题。具体有下面几个步骤：  
1. ld script文件里把.data section的位置设置为最终要run的VMA[^VMA]  
   注：ROM code中，这里的VMA一定是可修改的RAM或者DRAM。  
2. 根据生成的elf文件，用下面命令生成不带.data的binary，如xx.code.bin  
   
   ```shell
   objcopy -O binary -R .data xx.elf xx.code.bin
   ```

3. 根据生成的elf文件，用下面命令生成只有.data的binary，如xx.data.bin  
   
   ```shell
   objcopy -O binary -j .data xx.elf xx.data.bin
   ```

4. 把xx.code.bin做一定的alignment，把xx.code.bin和xx.data.bin cat在一起  
   
&emsp;&emsp;如果直接objcopy -O binary xx.elf xx.bin，中间不连续的地址部分也会被填充。比如.data段的VMA和.text的结尾有2M的空间，那么最终生成的bin文件也会多出2M的填充数据。  

&emsp;&emsp;ATF BL1里的处理太简单了，看如下代码([**bl1.ld.S**](https://github.com/TrustedFirmware-A/trusted-firmware-a/blob/v2.11/bl1/bl1.ld.S#L121))：  

```shell
DATA_SECTION >RAM AT>ROM
```

&emsp;&emsp;一行搞定。其中“>RAM”定义里VMA[^VMA]，而“AT>ROM”则定义了LMA[^LMA]。这里就是AT这个关键字的功劳。  
&emsp;&emsp;有点抽象，来看下展开是什么样子的。  

```
......

.data . : ALIGN(16) {
    __DATA_START__ = .;
    *(SORT_BY_ALIGNMENT(.data*)) __DATA_END__ = .; 
} >RAM AT>ROM
__DATA_RAM_START__ = __DATA_START__;
__DATA_RAM_END__ = __DATA_END__;

......

__DATA_ROM_START__ = LOADADDR(.data);

......
```
&emsp;&emsp;在dump文件中看下其中几个变量的值：  

```
000000000e0ee000 g       .data  0000000000000000 __DATA_RAM_START__
000000000e0ee105 g       .data  0000000000000000 __DATA_RAM_END__
0000000000006b00 g       *ABS*  0000000000000000 __DATA_ROM_START__
```

&emsp;&emsp;它们分别对应VMA的开始和结束和LMA的开始。  

&emsp;&emsp;再来看下build好的BL1 for QEMU ARMv8的section table：  

```
Sections:
Idx Name          Size      VMA               LMA               File off  Algn
  0 .text         00005000  0000000000000000  0000000000000000  00001000  2**11
                  CONTENTS, ALLOC, LOAD, READONLY, CODE
  1 .rodata       00001b00  0000000000005000  0000000000005000  00006000  2**3
                  CONTENTS, ALLOC, LOAD, READONLY, DATA
  2 .data         00000105  000000000e0ee000  0000000000006b00  00008000  2**4
                  CONTENTS, ALLOC, LOAD, DATA
  3 .stacks       00001000  000000000e0ee140  0000000000006c05  00008140  2**6
                  ALLOC
  4 .bss          00000860  000000000e0ef140  0000000000006c10  00008140  2**5
                  ALLOC
```

&emsp;&emsp;主要看属性里有LOAD的部分，其中.text和.rodata的VMA和LMA是一样的，而.data的VMA在0xe0ee000，LMA则是0x6b00。这些值和上面lds里的几个值是符合的。  

### Load

&emsp;&emsp;Load部分直接看ATF里怎么处理的。这段code在[**el3_common_macros.S**](https://github.com/TrustedFirmware-A/trusted-firmware-a/blob/v2.11/include/arch/aarch64/el3_common_macros.S#L388)里。  

```shell
#if defined(IMAGE_BL1) ||	\
	(defined(IMAGE_BL2) && RESET_TO_BL2 && BL2_IN_XIP_MEM)
		adrp	x0, __DATA_RAM_START__
		add	x0, x0, :lo12:__DATA_RAM_START__    /* set x0 to start of VMA */
		adrp	x1, __DATA_ROM_START__
		add	x1, x1, :lo12:__DATA_ROM_START__    /* set x1 to start of LMA */
		adrp	x2, __DATA_RAM_END__
		add	x2, x2, :lo12:__DATA_RAM_END__      /* set x2 to end of VMA  */
		sub	x2, x2, x0                          /* set x2 to the size of data section */
		bl	memcpy16                            /* copy data section from LMA to VMA */
#endif
```

## Recap
&emsp;&emsp;通过pack和load这两个步骤，ROM code自己就把原本放在ROM里的.data section放在了RAM或者DRAM里。回到本文开头的问题，把.data section分离出来，从第一块memory挪到第二块memory，是不是就释放出一定大小的memory给.text！  

## Reference
[**GNU Linker Doc**](https://ftp.gnu.org/old-gnu/Manuals/ld-2.9.1/html_chapter/ld_toc.html)  
[**GNU Linker Doc2**](https://sourceware.org/binutils/docs/ld/index.html#SEC_Contents)  
[**TFA doc**](https://trustedfirmware-a.readthedocs.io/en/latest/index.html)  


[^VMA]: Virtual Memory Address.  This is the address the section will have when the output file is run.  
[^LMA]: Load Memory Address. This is the address at which the section will be loaded.  