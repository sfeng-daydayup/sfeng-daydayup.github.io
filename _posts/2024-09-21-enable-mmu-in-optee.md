---
layout: post
title: Enable MMU in OPTEE
date: 2024-09-21 11:43 +0800
author: sfeng
categories: [Blogging, OPTEE]
tags: [optee, mmu]
lang: zh
---

## Preface
&emsp;&emsp;最近在做OPTEE，作为一个完整的OS，OPTEE里也是保罗万象。同时OPTEE又是一个相对较小的系统，对于研究学习一些复杂的过程因为较少的包装会更容易去发掘。这篇博文就探索下OPTEE里的MMU是怎样完成的。另外既然写到了MMU，后面计划写一些关于Cache的基础知识，算是预告一下。  

> SoC Arch     : ARMv8  
> OPTEE version: 4.0.0  
> Platform     ：Qemu  
{: .prompt-info }

## Content
&emsp;&emsp;OPTEE是一个相对完整的OS，它是REE OS（比如Linux）在TEE环境下的映射，比如Linux Kernel运行在NS-EL1，而User space application运行在NS-EL0，映射到OPTEE就是OPTEE OS运行在S-EL1，TA运行在S-EL0。User space application/TA也一样运行在独立的虚拟地址空间中，那MMU是必然要有的。MMU设置本身并没有很复杂，按照spec一步步设就可以了。难度在于代码链接地址和运行地址以及虚拟地址不一致的时候如何处理，symobl如何查找，反而其他部分内存按规则映射就好了。OPTEE里不同的config会产生上述的不一致，先从简单的来。  

### CFG_CORE_ASLR = n && CFG_CORE_PHYS_RELOCATABLE =n
&emsp;&emsp;这种情况是最简单的一种，MMU的enable和大多数bare metal的code一样，是直接把VA和PA一一对应，也就是VA和PA是一致的（主要指可执行部分，其他部分可按规则映射到不同的虚拟地址）。Qemu上的dump log如下：  
```shell
D/TC:0   dump_mmap_table:850 type TEE_RAM_RX   va 0x0e100000..0x0e185fff pa 0x0e100000..0x0e185fff size 0x00086000 (smallpg)
D/TC:0   dump_mmap_table:850 type TEE_RAM_RW   va 0x0e186000..0x0e2fffff pa 0x0e186000..0x0e2fffff size 0x0017a000 (smallpg)
D/TC:0   dump_mmap_table:850 type TA_RAM       va 0x0e300000..0x0effffff pa 0x0e300000..0x0effffff size 0x00d00000 (smallpg)
D/TC:0   dump_mmap_table:850 type SHM_VASPACE  va 0x0f000000..0x10ffffff pa 0x00000000..0x01ffffff size 0x02000000 (pgdir)
D/TC:0   dump_mmap_table:850 type RES_VASPACE  va 0x11000000..0x119fffff pa 0x00000000..0x009fffff size 0x00a00000 (pgdir)
D/TC:0   dump_mmap_table:850 type IO_SEC       va 0x11a00000..0x129fffff pa 0x08000000..0x08ffffff size 0x01000000 (pgdir)
D/TC:0   dump_mmap_table:850 type IO_SEC       va 0x12a00000..0x12bfffff pa 0x09000000..0x091fffff size 0x00200000 (pgdir)
D/TC:0   dump_mmap_table:850 type NSEC_SHM     va 0x12c00000..0x12dfffff pa 0x42000000..0x421fffff size 0x00200000 (pgdir)
```  
&emsp;&emsp;在处理过程中会按照PA在两个组（smallpg和pgdir）中分别从小到大排序，smallpg group涉及到.text等可执行section，所以虚拟地址起始也从它开始。为了尽量少的分配page table，pgdir的VA会顺序递增。  

### CFG_CORE_ASLR = y || CFG_CORE_PHYS_RELOCATABLE = y
&emsp;&emsp;这两个config任一会导致前诉的不一致。其中CFG_CORE_PHYS_RELOCATABLE导致link address和load address不一致，.text、.data等各个段的起始地址需要runtime去调整，不影响其他地址空间。(CFG_CORE_PHYS_RELOCATABLE依赖于CFG_CORE_SEL2_SPMC，这里只做code分析)  
&emsp;&emsp;ASLR是Address Space Layout Randomization的缩写，这个宏则引起当前运行地址到虚拟地址的转变。它的作用主要是增强Security，当然也增加了复杂度。以下为ASLR的解释。  
> Address Space Layout Randomization (ASLR) is a security technique used in operating systems to randomize the memory addresses used by system and application processes. By doing so, it makes it significantly harder for an attacker to predict the location of specific processes and data, such as the stack, heap, and libraries, thereby mitigating certain types of exploits, particularly buffer overflows.
{: .prompt-info }

&emsp;&emsp;Security本身就是个加重overhead的东西，就比如国防开支，目前国际形势动荡，各国增加这项开支以保护本国利益不被它人窃取。电子世界里就是保护设备里的信息不被他人窃取。  

&emsp;&emsp;如上，CFG_CORE_PHYS_RELOCATABLE导致link address和load address的不一致，而CFG_CORE_ASLR更对虚拟地址进行了随机化，这里的问题在于：  
1. OPTEE在编译链接的地址是[**TEE_LOAD_ADDR**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/include/mm/generic_ram_layout.h#L114)，在runtime需要适应无论是物理运行地址还是虚拟地址的不一致。  
2. OPTEE的boot code是在MMU打开前就开始运行了，冒然打开MMU必然会因为address translation到不同的地址导致未知的错误。  
&emsp;&emsp;那OPTEE是怎么操作的呢？先看下CFG_CORE_ASLR打开后VA和PA的对应情况。  
```shell
D/TC:0   dump_mmap_table:850 type IDENTITY_MAP_RX va 0x0e100000..0x0e101fff pa 0x0e100000..0x0e101fff size 0x00002000 (smallpg)
D/TC:0   dump_mmap_table:850 type TEE_RAM_RX   va 0x6674a000..0x667cffff pa 0x0e100000..0x0e185fff size 0x00086000 (smallpg)
D/TC:0   dump_mmap_table:850 type TEE_RAM_RW   va 0x667d0000..0x66949fff pa 0x0e186000..0x0e2fffff size 0x0017a000 (smallpg)
D/TC:0   dump_mmap_table:850 type TA_RAM       va 0x66b00000..0x677fffff pa 0x0e300000..0x0effffff size 0x00d00000 (smallpg)
D/TC:0   dump_mmap_table:850 type SHM_VASPACE  va 0x67800000..0x697fffff pa 0x00000000..0x01ffffff size 0x02000000 (pgdir)
D/TC:0   dump_mmap_table:850 type RES_VASPACE  va 0x69800000..0x6a1fffff pa 0x00000000..0x009fffff size 0x00a00000 (pgdir)
D/TC:0   dump_mmap_table:850 type IO_SEC       va 0x6a200000..0x6b1fffff pa 0x08000000..0x08ffffff size 0x01000000 (pgdir)
D/TC:0   dump_mmap_table:850 type IO_SEC       va 0x6b200000..0x6b3fffff pa 0x09000000..0x091fffff size 0x00200000 (pgdir)
D/TC:0   dump_mmap_table:850 type NSEC_SHM     va 0x6b400000..0x6b5fffff pa 0x42000000..0x421fffff size 0x00200000 (pgdir)
```  

&emsp;&emsp;第一段空间有0x2000大小的地址VA和PA是一样的，其他地址段PA都映射到了不同的VA，而且，第二段包含第一段的空间，也就是（0x0e100000..0x0e101fff）重复映射到了不同的VA。下面分步骤来看OPTEE是怎样做的。  

#### Compile with PIE
&emsp;&emsp;当上面提到的两个宏任意一个设为y时，OPTEE在编译的时候就会加上-fpie选项，具体在[**arm.mk**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/arm.mk#L250)。PIE的作用就是生成GOT（Global Offset Table）和rel，这样程序可以更新这两张表从而进行重定位。  

#### Get Running Address
&emsp;&emsp;如上所述，由于CFG_CORE_PHYS_RELOCATABLE依赖于CFG_CORE_SEL2_SPMC，这里只做code分析。  
```shell
#if defined(CFG_CORE_PHYS_RELOCATABLE)
	/*
	 * Save the base physical address, it will not change after this
	 * point.
	 */
	adr_l	x2, core_mmu_tee_load_pa
	adr	x1, _start		/* Load address */  //拿到程序真正运行的地址
	str	x1, [x2]        //把这个地址存入core_mmu_tee_load_pa以备后用

	mov_imm	x0, TEE_LOAD_ADDR	/* Compiled load address */ //这是link address
	sub	x0, x1, x0		/* Relocatation offset */ // 做减法拿到偏移值

	cbz	x0, 1f     // 如果偏移值为0，跳过relocate
	bl	relocate   // 做relocate
1:
#endif
```  
&emsp;&emsp;具体代码在[**entry_a64.S**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/kernel/entry_a64.S#L276)里。代码本身已有些注释。关键在于adr指令的运用（其他系统里会结合ldr一起，这里link address有宏可以取到，就没有用ldr），“adr	x1, _start”这条指令把_start的真正地址设在了x1中。随后把这个地址存在core_mmu_tee_load_pa里以备后用。然后把TEE_LOAD_ADDR（link address）赋给x0，做x1和x0的减法拿到偏移。如果没有偏移就跳过。不然就做relocate。怎么做relocate后面分析。  

#### Generate Random VA
&emsp;&emsp;如果CFG_CORE_ASLR打开的话，会通过[**get_aslr_seed**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/kernel/boot.c#L1324)这个函数得到一个伪随机数（也可能是个真随机数）。这个随机数可以设在DTS里（如果有DTS的话），也可以通过plat_get_aslr_seed来拿到，这个函数本身是个weak的空函数，需要开发者根据自己的硬件做实现，如果硬件支持TRNG的话，这里就是个真随机数，也意味着安全性会更高。  

#### Init Memory Map
&emsp;&emsp;这个步骤则在core_init_mmu_map函数里完成（竟然也是个weak函数，意味着高级开发者可以自己定制mmu map和xlate table了）。这个函数有两个参数，第一个就是刚才的随机数，第二个参数是struct core_mmu_config *cfg结构存储该函数填充的数据。该结构内容如下（只保留了ARM64相关成员）：  
```
struct core_mmu_config {
	uint64_t tcr_el1;            // Translation Control Register
	uint64_t mair_el1;           // Memory Attribute Indirection Register
	uint64_t ttbr0_el1_base;     // Translation Table Base Register 0
	uint64_t ttbr0_core_offset;
	uint64_t map_offset;
};
```  
&emsp;&emsp;函数细节大家可以看[core/mm/core_mmu.c](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/mm/core_mmu.c#L1476)。地址分为两个部分，第一部分是OPTEE本身的.text、.data、.bss等各个段，另外一部分则是在main.c里通过register_phys_mem/register_phys_mem_pgdir，register_ddr和register_sdp_mem来定义的IO或者DDR地址空间。  
&emsp;&emsp;之前提到的最初始的init段映射了两次，一次按照其load address映射，第二次则按照新分配的虚拟地址映射。具体函数参看[**mem_map_add_id_map**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/mm/core_mmu.c#L1302)。博主其实没搞明白为啥要映射两次。于是做了个实验，把按load address映射的部分去掉，发现也能正常启动，跑了个TA也没问题，至少目前没发现有什么不妥，等以后有发现再来更新。  
&emsp;&emsp;这里把地址映射的变化列出来做个比较。  
初始数据：  
```
D/TC:0   dump_mmap_table:850 type TEE_RAM_RX   va 0x00000000..0x00085fff pa 0x0e100000..0x0e185fff size 0x00086000 (smallpg)
D/TC:0   dump_mmap_table:850 type TEE_RAM_RW   va 0x00000000..0x00179fff pa 0x0e186000..0x0e2fffff size 0x0017a000 (smallpg)
D/TC:0   dump_mmap_table:850 type TA_RAM       va 0x00000000..0x00cfffff pa 0x0e300000..0x0effffff size 0x00d00000 (smallpg)
D/TC:0   dump_mmap_table:850 type NSEC_SHM     va 0x00000000..0x001fffff pa 0x42000000..0x421fffff size 0x00200000 (pgdir)
D/TC:0   dump_mmap_table:850 type IO_SEC       va 0x00000000..0x00ffffff pa 0x08000000..0x08ffffff size 0x01000000 (pgdir)
D/TC:0   dump_mmap_table:850 type IO_SEC       va 0x00000000..0x001fffff pa 0x09000000..0x091fffff size 0x00200000 (pgdir)
D/TC:0   dump_mmap_table:850 type RES_VASPACE  va 0x00000000..0x009fffff pa 0x00000000..0x009fffff size 0x00a00000 (pgdir)
D/TC:0   dump_mmap_table:850 type SHM_VASPACE  va 0x00000000..0x01ffffff pa 0x00000000..0x01ffffff size 0x02000000 (pgdir)
```  
加了seed和分配虚拟地址后：  
```
D/TC:0   dump_mmap_table:850 type IDENTITY_MAP_RX va 0x0e100000..0x0e101fff pa 0x0e100000..0x0e101fff size 0x00002000 (smallpg)
D/TC:0   dump_mmap_table:850 type TEE_RAM_RX   va 0x6674a000..0x667cffff pa 0x0e100000..0x0e185fff size 0x00086000 (smallpg)
D/TC:0   dump_mmap_table:850 type TEE_RAM_RW   va 0x667d0000..0x66949fff pa 0x0e186000..0x0e2fffff size 0x0017a000 (smallpg)
D/TC:0   dump_mmap_table:850 type TA_RAM       va 0x66b00000..0x677fffff pa 0x0e300000..0x0effffff size 0x00d00000 (smallpg)
D/TC:0   dump_mmap_table:850 type SHM_VASPACE  va 0x67800000..0x697fffff pa 0x00000000..0x01ffffff size 0x02000000 (pgdir)
D/TC:0   dump_mmap_table:850 type RES_VASPACE  va 0x69800000..0x6a1fffff pa 0x00000000..0x009fffff size 0x00a00000 (pgdir)
D/TC:0   dump_mmap_table:850 type IO_SEC       va 0x6a200000..0x6b1fffff pa 0x08000000..0x08ffffff size 0x01000000 (pgdir)
D/TC:0   dump_mmap_table:850 type IO_SEC       va 0x6b200000..0x6b3fffff pa 0x09000000..0x091fffff size 0x00200000 (pgdir)
D/TC:0   dump_mmap_table:850 type NSEC_SHM     va 0x6b400000..0x6b5fffff pa 0x42000000..0x421fffff size 0x00200000 (pgdir)

```  
&emsp;&emsp;注意，由于每次启动seed有可能不同（依赖于seed的source），每次虚拟地址都会不同，另外虚拟地址需要防止overlap和越界，OPTEE在函数[**init_mem_map**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/mm/core_mmu.c#L1374)里也做了一些处理。  
&emsp;&emsp;最终struct core_mmu_config *cfg会被填充好，后面会用到。  

#### Update Relative Address Table
&emsp;&emsp;CFG_CORE_ASLR和CFG_CORE_PHYS_RELOCATABLE任一打开，都会做一次relocate。这部分OPTEE做了特殊处理，看注释：  
```
	/*
	 * Relocations are not formatted as Rela64, instead they are in a
	 * compressed format created by get_reloc_bin() in
	 * scripts/gen_tee_bin.py
	 *
	 * All the R_AARCH64_RELATIVE relocations are translated into a
	 * list of 32-bit offsets from TEE_LOAD_ADDR. At each address a
	 * 64-bit value pointed out which increased with the load offset.
	 */
```  
&emsp;&emsp;也就是OPTEE编译过程中通过gen_tee_bin.py中的[**get_reloc_bin**](https://github.com/OP-TEE/optee_os/blob/4.0.0/scripts/gen_tee_bin.py#L153)做了处理。  
```
    addrs = []
    for section in elffile.iter_sections():
        if not isinstance(section, RelocationSection):
            continue
        for rel in section.iter_relocations():
            if rel['r_info_type'] == 0:
                continue
            if rel['r_info_type'] != exp_rel_type:
                eprint("Unexpected relocation type 0x%x" %
                       rel['r_info_type'])
                sys.exit(1)
            addrs.append(rel['r_offset'] - link_address)
```  
&emsp;&emsp;通过分析上面脚本可知，这个函数把.rela里的Elf64_Rela结构（如下）简化为一个r_offset和link_address的差值，然后产生了一个相对地址的数组。  
```
typedef struct {
	Elf64_Addr	r_offset;	/* Location to be relocated. */
	Elf64_Xword	r_info;		/* Relocation type and symbol index. */
	Elf64_Sxword	r_addend;	/* Addend. */
} Elf64_Rela;
------>
array[] = {
	relative address 0,
	relative address 1,
	......
};
```  
&emsp;&emsp;.rela可以通过readelf -Wr命令读出来。其中offset是后面Symbol在.got表中的位置。以下为该命令执行的片段：  
```
    Offset             Info             Type               Symbol's Value  Symbol's Name + Addend
000000000e185058  0000000000000403 R_AARCH64_RELATIVE                        e1891c0
000000000e1852d0  0000000000000403 R_AARCH64_RELATIVE                        e1966a0
000000000e185108  0000000000000403 R_AARCH64_RELATIVE                        e1966b0
000000000e1850e8  0000000000000403 R_AARCH64_RELATIVE                        e189340
000000000e1852c0  0000000000000403 R_AARCH64_RELATIVE                        e102800
000000000e185228  0000000000000403 R_AARCH64_RELATIVE                        e102000
000000000e1850c8  0000000000000403 R_AARCH64_RELATIVE                        e103000
```  
&emsp;&emsp;处理后的表如下，其中前24个字节为结构struct boot_embdata。  
```
00089200: c011 0000 0200 0000 1800 0000 0000 0000
00089210: 1800 0000 a411 0000 8847 0800 9847 0800
00089220: a047 0800 b047 0800 c047 0800 d047 0800
00089230: d847 0800 e847 0800 f847 0800 0048 0800
00089240: 1048 0800 2048 0800 2848 0800 3848 0800
00089250: 4848 0800 5048 0800 6048 0800 7048 0800
00089260: 7848 0800 8848 0800 9848 0800 a048 0800
00089270: b048 0800 c048 0800 c848 0800 d848 0800
```  
```
struct boot_embdata {
	uint32_t total_len;
	uint32_t num_blobs;
	uint32_t hashes_offset;
	uint32_t hashes_len;
	uint32_t reloc_offset;
	uint32_t reloc_len;
};
```  
&emsp;&emsp;关于embdata_bin在[**Output of OPTEE Build**](https://sfeng-daydayup.github.io/posts/output-of-optee-build/)中稍有提及。  
&emsp;&emsp;OPTEE取到这个简化的数组后，在加上目前的load adderss（注意，这里不是link address了），就找到了.got表中这个Symbol的位置，然后根据目前的偏移逐项update位置信息。这样就完成了relocate。  
&emsp;&emsp;这里的偏移可能有两个，一个是因为CFG_CORE_PHYS_RELOCATABLE产生的物理地址位移，第二个是因为CFG_CORE_ASLR产生的虚拟地址和物理地址之间的位移。都需要update以后程序才能继续正常运行。  

#### Enable MMU
&emsp;&emsp;好了，终于到最后一步enable MMU了。[**enable_mmu**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/kernel/entry_a64.S#L545)的函数在这里。通过parse结构struct core_mmu_config *cfg后，得到的参数表如下：  
```
	/*
	 * x0 = core_pos
	 * x2 = tcr_el1
	 * x3 = mair_el1
	 * x4 = ttbr0_el1_base
	 * x5 = ttbr0_core_offset
	 * x6 = load_offset
	 */
```  
&emsp;&emsp;设置tcr_el1、mair_el1、ttbr0_el1和sctlr_el1很简单，都是一条msr搞定。这样MMU就enable了。后续几个步骤也很关键。
1. Update vbar。把vbar转换为虚拟地址。
2. Adjust stack pointers and return address。也是转换为虚拟地址。

&emsp;&emsp;这样整个步骤就结束了。最后顺便提一下，CFG_CORE_ASLR和CFG_CORE_PHYS_RELOCATABLE对debug都是不友好的，在做debug的时候务必把它们都关掉。  

## Reference
[**ASLR**](https://en.wikipedia.org/wiki/Address_space_layout_randomization)  
[**Position Independent Code**](https://en.wikipedia.org/wiki/Position-independent_code)  
[**ELF**](https://stevens.netmeister.org/631/elf.html)  
