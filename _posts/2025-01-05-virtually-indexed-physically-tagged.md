---
layout: post
title: Virtually Indexed Physically Tagged
date: 2025-01-05 15:35 +0800
author: sfeng
categories: [ARM, Cache]
tags: [cache]
lang: zh
---

## Background

&emsp;&emsp;Cache的组织形式有多种，如VIVT，VIPT，PIPT等，每个都有各自的优缺点。本文主要研究下现代CPU中比较常用的VIPT。  

&emsp;&emsp;VIPT的优点如下：  
- 减少地址转换开销‌：VIPT缓存使用虚拟地址作为索引，物理地址作为标签。这意味着在进行缓存查找时，不需要进行虚拟地址到物理地址的转换，从而减少了地址转换的开销，提高了缓存查找的效率‌  
- 减少cache失效‌：当虚拟地址到物理地址的映射关系发生变化时，使用物理地址作为标签可以避免需要清理和无效化缓存的情况，这对于多任务系统尤其有利，因为它减少了因页表映射更改而导致的性能损失‌  
- 适用于多任务系统‌：在多任务系统中，频繁修改页表映射是常见的操作。VIPT缓存的设计使得在这种环境下能够保持较高的性能，因为它避免了因页表修改而导致的cache失效问题‌  

&emsp;&emsp;缺点就是有Aliasing问题，就是同一块物理地址映射到了多个虚拟地址上。通过不同的虚拟地址都可以访问这块物理地址，这样有可能在cache中因为不同的虚拟地址会同时存在多份该地址数据的备份，从而出现数据同步的问题。  

&emsp;&emsp;而解决办法就是增加alias avoidance logic。在Arm Cortex-A系列芯片中，有部分使用了PIPT。鉴于VIPT的的优势，也有不少芯片选择了VIPT。比如以下芯片的的TRM中做了这样的描述。  

> A55:  
> The L1 data cache is organized as a Virtually Indexed Physically Tagged (VIPT) cache, with alias avoidance logic so that it appears to software as if it were physically indexed.  
{: .prompt-info }  

> A73:  
> A Virtually Indexed Physically Tagged (VIPT) Level-1 (L1) data cache, which behaves as either an eight-way set associative cache (for 32KB configurations) or a 16-way set associative PIPT cache (for 64KB configurations).  
{: .prompt-info }  

> A78:  
> Virtually Indexed, Physically Tagged (VIPT) 4-way set-associative L1 instruction cache, which behaves as a Physically Indexed, Physically Tagged (PIPT) cache  
> Virtually Indexed, Physically Tagged (VIPT), which behaves as a Physically Indexed, Physically Tagged (PIPT) 4-way set-associative L1 data cache
{: .prompt-info }  

## Experiment
&emsp;&emsp;正好手边有A55的板子，接下来做个实验来看下实际操作的结果。 
&emsp;&emsp;第一个实验现在单个CPU上操作，如下：  
![vipt_singlecpu](/assets/img/cache/vipt_singlecpu.jpg){: .normal }    

&emsp;&emsp;上面的实验中：  
1. 把物理0x6000000的地址分别映射到了虚拟地址的0x7000000和0x8000000  
2. 读出0x70000000和0x8000000的值均为0xd7e5ebd9  
3. 写0xa55a5aa5到0x7000000  
4. 读取0x8000000地址的值，读出为0xa55a5aa5  
&emsp;&emsp;符合预期  

&emsp;&emsp;第二个实验在多个CPU间进行：  
![vipt_multicpu](/assets/img/cache/vipt_multicpu.jpg){: .normal }   

1. CPU0: 把物理0x6000000的地址分别映射到了虚拟地址的0x7000000  
2. CPU1: 把物理0x6000000的地址分别映射到了虚拟地址的0x8000000  
3. 其中enable CPU0和CPU1的MMU，而保持CPU2的MMU disabled  
4. 通过CPU2写0xdeadbeaf到0x6000000
5. 在CPU0和CPU1上分别读0x7000000和0x8000000的值，均为0xdeadbeaf，该值已保存在cache中  
6. 切换到CPU0，写0xa55a5aa5到0x7000000，读取验证写成功  
7. 切至CPU1，读取0x8000000，读取值为0xa55a5aa5，证明alias问题在多CPU间也解决了，符合预期  
8. 再切至CPU2，读取0x6000000，值仍然为0xdeadbeaf，证明cache没有被刷回DDR，也符合预期  

## Conclusion
&emsp;&emsp;通过上述实验可知，Arm虽然使用了VIPT，但通过增加alias avoidance logic解决了alias问题，同时利用了VIPT的优势。特别是在经常跑多任务的Cortex-A系列芯片中，可以很大的提高性能。  

## Reference
[**VIPT**](https://www.geeksforgeeks.org/virtually-indexed-physically-tagged-vipt-cache/)  
[**What is VIPT behaves as PIPT**](https://community.arm.com/support-forums/f/architectures-and-processors-forum/48758/what-is-vipt-behaves-as-pipt)  