---
layout: post
title: Output of OPTEE Build
author: sfeng
date: 2024-07-02 11:56 +0800
categories: [Blogging, OPTEE]
tags: [optee]
lang: zh
---

&emsp;&emsp;关于OPTEE的build and run，官方文档写的很详细([**OPTEE OS Building**](https://optee.readthedocs.io/en/latest/building/gits/optee_os.html))。这里主要介绍输出的几个binary各有什么玄机。另外OPTEE OS的版本为4.0.0。  
&emsp;&emsp;OPTEE build输出的文件是由[**link.mk**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/kernel/link.mk#L185)决定的。当然在compile log里也有相应的体现，如下：  

> LD&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;out/arm/platform/platform_flavor/release/core/tee.elf  
> OBJDUMP&nbsp;out/arm/platform/platform_flavor/release/core/tee.dmp  
> GEN&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;out/arm/platform/platform_flavor/release/core/tee.bin  
> GEN&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;out/arm/platform/platform_flavor/release/core/tee-header_v2.bin  
> GEN&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;out/arm/platform/platform_flavor/release/core/tee-pager_v2.bin  
> GEN&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;out/arm/platform/platform_flavor/release/core/tee-pageable_v2.bin  
> GEN&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;out/arm/platform/platform_flavor/release/core/tee.symb_sizes  
> GEN&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;out/arm/platform/platform_flavor/release/core/tee-raw.bin

&emsp;&emsp;这里主要关注的*.bin。TEE OS属于Secure Boot中的一环，相应的TEE OS的binary也会放在Secure Boot的Package Layout里。了解各个binary包含的内容有助于做出对应的选择。  
&emsp;&emsp;OPTEE OS用一个Python脚本([**gen_tee_bin.py**](https://github.com/OP-TEE/optee_os/blob/4.0.0/scripts/gen_tee_bin.py#L383))来生成这些bin文件。官方文档([**Partition of The Binary**](https://optee.readthedocs.io/en/latest/architecture/core.html#partitioning-of-the-binary))有相应解释。但阅读这个Python脚本更加有助于深入了解其内容。官方文档里介绍了两种Image Packing Format：  
Header Structure of V1(文档中并未定义V1，V1为作者方便命名自定义):  
```
#define OPTEE_MAGIC             0x4554504f
#define OPTEE_VERSION           1
#define OPTEE_ARCH_ARM32        0
#define OPTEE_ARCH_ARM64        1

struct optee_header {
        uint32_t magic;
        uint8_t version;
        uint8_t arch;
        uint16_t flags;
        uint32_t init_size;
        uint32_t init_load_addr_hi;
        uint32_t init_load_addr_lo;
        uint32_t init_mem_usage;
        uint32_t paged_size;
};
```

Header Structure of V2:  
```
#define OPTEE_IMAGE_ID_PAGER    0
#define OPTEE_IMAGE_ID_PAGED    1

struct optee_image {
        uint32_t load_addr_hi;
        uint32_t load_addr_lo;
        uint32_t image_id;
        uint32_t size;
};

struct optee_header_v2 {
        uint32_t magic;
        uint8_t version;
        uint8_t arch;
        uint16_t flags;
        uint32_t nb_images;
        struct optee_image optee_image[];
};
```

&emsp;&emsp;初看到这段以为会有相应的选项以便让开发者选择使用V1还是V2 format，然而并没有，输出结果中两种format都存在。在找出image的format之前还需要理解一个会影响到Bianry Packing的选项叫CFG_WITH_PAGER。根据文档的描述，这个选项只有在能被OPTEE OS使用的Secure Memory(这里可以是Secure SRAM or Secure DDR)比较小的时候才会用到，但是关于它的处理却涉及到很多地方，本文仅关注影响Binary Packing的地方。最直接的影响体现在[**kern.ld.S**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/kernel/kern.ld.S#L283)。如果CFG_WITH_PAGER设为y的话，则OPTEE kern的lds会多生成几个以_init和_pageable结尾的section，其实是把CFG_WITH_PAGER为n的时候的section分成两半，一半是unpaged，一半是pageable的。  
- tee.bin  
  tee.bin是用V1 format来pack的。请看入口函数[**output_header_v1**](https://github.com/OP-TEE/optee_os/blob/4.0.0/scripts/gen_tee_bin.py#L392)。也就是它的整体格式为：  
  Header + Init + Hashes + Pageable  
  Init部分包含unpaged和pageable两部分，hash是pageable bin的sha256，pageable是不包含pageable init的另一部分。  
  由于笔者所用SoC还算比较高级，有足够的secure memory来run full function的OPTEE，所以CFG_WITH_PAGER设的是n，后面两部分其实为空，这样实际生成的格式为：  
  Header + Init
- tee-header_v2.bin  
  由于V2的Binary都是单独生成的，这里就是一个28B的follow V2 format的header。同样由于CFG_WITH_PAGER设的是n，nb_images这里为1，只有tee-page_v2.bin(文档里所谓Init)。  
  关于Header，官方文档里有句说明:  "**The header is only used by the loader of OP-TEE, not OP-TEE itself.**" 这应该也是它为什么要单独生成的原因，developer可以根据自己实际需求和其他Binary pack到一起。
- tee-pager_v2.bin  
  在CFG_WITH_PAGER为n时，它几乎和objcopy -O binary tee.elf tee.bin的输出结果一样，只是最后pack了一些长度信息，可以忽略。也即它就是最终的可执行文件。
- tee-pageable_v2.bin  
  如前所述，它是除了pageable init的其余部分,主要为.rodata_pageable和.text_pageable。当CFG_WITH_PAGER为n时，它为NULL。
- tee-raw.bin  
  它是V2 format image里除了header的其余部分。当CFG_WITH_PAGER为n时，它和tee-pager_v2.bin相同。

&emsp;&emsp;了解了每个Binary的内容，相信可以根据项目实际需求来使用相应的Binary。  

&emsp;&emsp;最后，参考的代码和文档都在文中加了相应的link，就不单独列Reference了。