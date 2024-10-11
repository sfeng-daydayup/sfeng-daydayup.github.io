---
layout: post
title: early TA of OPTEE
date: 2024-08-28 18:56 +0800
author: sfeng
categories: [OPTEE]
tags: [optee, ta]
lang: zh
---
## Preface  
&emsp;&emsp;昨天《[**Shared Libraries of TA**](https://sfeng-daydayup.github.io/posts/shared-libraries-of-ta/)》里提到了在使用shared library的时候一种可能的提高效率的方法，这篇博文先看early TA怎么用，然后看昨天提出的方法是否可行。  

> SoC Arch : ARMv8  
> OPTEE version: 4.0.0。
{: .prompt-info }

## Content  
### How to enable early TA
&emsp;&emsp;关于怎么enable early TA，官方文档里并没有详细说明，反而在[**mk/config.mk**](https://github.com/OP-TEE/optee_os/blob/4.0.0/mk/config.mk#L365)里讲的很清楚。  


```
#   $ make ... \
#     EARLY_TA_PATHS="path/to/8aaaf200-2450-11e4-abe2-0002a5d5c51b.stripped.elf \
#                     path/to/cb3e5ba0-adf1-11e0-998b-0002a5d5c51b.stripped.elf"
# Typical build steps:
#   $ make ta_dev_kit CFG_EARLY_TA=y # Create the dev kit (user mode libraries,
#                                    # headers, makefiles), ready to build TAs.
#                                    # CFG_EARLY_TA=y is optional, it prevents
#                                    # later library recompilations.
#   <build some TAs>
#   $ make EARLY_TA_PATHS=<paths>    # Build OP-TEE and embbed the TA(s)
```   
> 根据编译脚本，如果EARLY_TA_PATHS或者CFG_IN_TREE_EARLY_TAS一个不会空，则CFG_EARLY_TA会强制设为y。
{: .prompt-info }  

&emsp;&emsp;第一步就是"make ta_dev_kit"其实是为随后ta的编译准备环境，以及把in-tree的TA编译出来。在这步里，如果CFG_ULIBS_SHARED打开的话，就会在export-ta_arm64/lib下生成libutee.so、libutils.so、libmbedtls.so和libdl.so(在本文中用到的其实是libxxx.stripped.so)。  
&emsp;&emsp;有了ta_dev_kit，接着把想放在early TA里的TA编译出来，同样也是需要[uuid].stripped.so。  
&emsp;&emsp;在后面就是要把命名为[uuid].elf(mv *.stripped.so to [uuid].elf or [uuid].stripped.so)的文件路径放在宏EARLY_TA_PATHS里。这里以把shared libray放在early TA里为例，宏定义为：  
```
EARLY_TA_PATHS="early_ta/4b3d937e-d57e-418b-8673-1c04f2420226.elf early_ta/71855bba-6055-4293-a63f-b0963a737360.elf early_ta/87bb6ae8-4b1d-49fe-9986-2b966132c309.elf early_ta/be807bbd-81e1-4dc4-bd99-3d363f240ece.elf"
```

&emsp;&emsp;把EARLY_TA_PATHS作为编译OPTEE的command option，编译过程会通过脚本[**ts_bin_to_c.py**](https://github.com/OP-TEE/optee_os/blob/4.0.0/scripts/ts_bin_to_c.py)把每个elf转为early_ta_[uuid].c文件，具体内容如下：  
```shell
/* Generated from early_ta/4b3d937e-d57e-418b-8673-1c04f2420226.elf by ts_bin_to_c.py */
#include <kernel/embedded_ts.h>
#include <scattered_array.h>
const uint8_t ts_bin_4b3d937ed57e418b86731c04f2420226[] = {
    ......
    ......
};
SCATTERED_ARRAY_DEFINE_PG_ITEM(early_tas, struct                 embedded_ts) = {
        .flags = 0x0000,
        .uuid = {
                .timeLow = 0x4b3d937e,
                .timeMid = 0xd57e,
                .timeHiAndVersion = 0x418b,
                .clockSeqAndNode = {
                        0x86, 0x73, 0x1c, 0x04, 0xf2, 0x42, 0x02, 0x26
                },
        },
        .size = sizeof(ts_bin_4b3d937ed57e418b86731c04f2420226), /* 42084 */
        .ts = ts_bin_4b3d937ed57e418b86731c04f2420226,
        .uncompressed_size = 109784,
};
```
> OPTEE还提供了一个选项CFG_EARLY_TA_COMPRESS来做压缩，这样可以减小early TA在image里的size。不缺memory并且追求性能的可以设为n。
{: .prompt-info }  

&emsp;&emsp;通过SCATTERED_ARRAY_DEFINE_PG_ITEM定义的early TA的embedded_ts结构列表就是early TA store查找相应TA的依据。这样early TA就以数组的形式放在里OPTEE的binary里。

### Is it feasible to add shared libary into early TA?
&emsp;&emsp;答案是标准的OPTEE不可行。为什么？  
&emsp;&emsp;如上生成的.c文件里定义了一个embedded_ts结构，这个结构里的信息有flags，uuid，size，ts和uncompressed_size，其中uuid是从文件名中分解出来的，size和uncompressed_size也能直接拿到，ts则是指向数组的指针，直接赋值即可。  
&emsp;&emsp;关键在于这个flags，前面的文章[**How to Develop a TA**](https://sfeng-daydayup.github.io/posts/how-to-develop-a-ta/#ta_flags)里提到了TA_FLAGS的设置，这个设置最终会放在ta_head这个结构里(refer to [**user_ta_header.c**](https://github.com/OP-TEE/optee_os/blob/4.0.0/ta/user_ta_header.c#L105))，为了拿到这个flags，脚本[**ts_bin_to_c.py**](https://github.com/OP-TEE/optee_os/blob/4.0.0/scripts/ts_bin_to_c.py)为去parse输入的elf文件。然而，这里的shared library并不是TA，它只是一个包装成TA的库文件，没有ta_head这个结构，这样编译就会出错了。  
&emsp;&emsp;通过查看code会发现，这个结构里的flags是个鸡肋的东西，至少目前没有看到哪个module用它。ldelf在load_main的时候会重新parse elf文件找到ta_head结构，对shared library的加载就更不会有这个步骤。  

### Hack?
&emsp;&emsp;本文就是想看看这种方案是否可行，当然要hack，方法有以下几种：  
1. 既然flags无用，那就彻底把它拿掉；  
2. 找不到ta_head，则设置一个默认值；

&emsp;&emsp;这里博主选择了方法2，影响比较小，而且万一flags在哪个犄角旮旯被用了呢！改动比较简单，只涉及到一个python函数[**ta_get_flags**](https://github.com/OP-TEE/optee_os/blob/4.0.0/scripts/ts_bin_to_c.py#L65)。有兴趣的可以自己改改玩。

### Result
&emsp;&emsp;hack过后不出意料的可以编译通过并跑了，log如下：
```
# optee_example_hello_world
D/TC:? 00 tee_ta_init_pseudo_ta_session:297 Lookup pseudo TA 8aaaf200-2450-11e4-abe2-0002a5d5c51b
D/TC:? 00 ldelf_load_ldelf:110 ldelf load address 0x40007000
D/LD:   ldelf:142 Loading TS 8aaaf200-2450-11e4-abe2-0002a5d5c51b
D/TC:? 00 ldelf_syscall_open_bin:164 Lookup user TA ELF 8aaaf200-2450-11e4-abe2-0002a5d5c51b (early TA)
D/TC:? 00 ldelf_syscall_open_bin:167 res=0xffff0008
D/TC:? 00 ldelf_syscall_open_bin:164 Lookup user TA ELF 8aaaf200-2450-11e4-abe2-0002a5d5c51b (REE)
D/TC:? 00 ldelf_syscall_open_bin:167 res=0
D/TC:? 00 ldelf_syscall_open_bin:164 Lookup user TA ELF 71855bba-6055-4293-a63f-b0963a737360 (early TA)
D/TC:? 00 ldelf_syscall_open_bin:167 res=0
D/TC:? 00 ldelf_syscall_open_bin:164 Lookup user TA ELF 4b3d937e-d57e-418b-8673-1c04f2420226 (early TA)
D/TC:? 00 ldelf_syscall_open_bin:167 res=0
D/TC:? 00 ldelf_syscall_open_bin:164 Lookup user TA ELF 87bb6ae8-4b1d-49fe-9986-2b966132c309 (early TA)
D/TC:? 00 ldelf_syscall_open_bin:167 res=0
D/LD:   ldelf:177 ELF (8aaaf200-2450-11e4-abe2-0002a5d5c51b) at 0x40016000
D/LD:   ldelf:177 ELF (71855bba-6055-4293-a63f-b0963a737360) at 0x4005d000
D/LD:   ldelf:177 ELF (4b3d937e-d57e-418b-8673-1c04f2420226) at 0x4009f000
D/LD:   ldelf:177 ELF (87bb6ae8-4b1d-49fe-9986-2b966132c309) at 0x40114000
D/TA:   TA_CreateEntryPoint:40 has been called
D/TA:   __GP11_TA_OpenSessionEntryPoint:69 has been called
I/TA: Hello World!
Invoking TA to increment 42
D/TA:   inc_value:103 has been called
I/TA: Got value: 42 from NW
I/TA: Increase value to: 43
TA incremented value to 43
D/TC:? 00 tee_ta_close_session:469 csess 0x126a580 id 1
D/TC:? 00 tee_ta_close_session:487 Destroy session
I/TA: Goodbye!
D/TA:   TA_DestroyEntryPoint:51 has been called
D/TC:? 00 destroy_context:326 Destroy TA ctx (0x126a4f0)
```  

&emsp;&emsp;其中hello world TA(8aaaf200-2450-11e4-abe2-0002a5d5c51b)先尝试从early TA load，没找到然后从REE拿到，其他有几个dependence的TA(shared library)都从early TA找到并加载。  

&emsp;&emsp;注：这里选择对early TA进行compress，OPTEE的binary size只增加200KB，压缩率大概40%。  

&emsp;&emsp;收工！！！

## Reference  
[**OPTEE-Arch-Early-TA**](https://optee.readthedocs.io/en/latest/architecture/trusted_applications.html#early-ta)  
[**Early TA Commit**](https://github.com/OP-TEE/optee_os/commit/d0c636148b3a)  
