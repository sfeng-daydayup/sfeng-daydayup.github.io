---
layout: post
title: Some Tips of Armv8-M
date: 2025-01-12 19:32 +0800
author: sfeng
categories: [ARM, Cortex-M]
tags: [cortex-m]
lang: zh
---

## Background

&emsp;&emsp;最近研究了把Armv8-M，实践了下从SPE启动把FreeRTOS跑在CM52的NSPE上，并且FreeRTOS的thread可以call SPE的secure service。过程中遇到了不少坑，记录一下，以备后查。  

## Some Tips

### Secure and Non-secure address space
&emsp;&emsp;查阅了不少关于Armv8 Cortex-M的实现，比如MPS AN505（可查看reference中的spec），在它们的实现中，地址空间被分为了S和NS两部分，需要注意的是：SPE只能访问S的address，NSPE只能访问NS的address。交叉访问会出bus fault。  

### SAU/IDAU
&emsp;&emsp;SAU或者IDAU掌控了整个memory space的访问权限，前面已经写了一篇关于[SA and SAU](https://sfeng-daydayup.github.io/posts/sa-and-sau/)的博文。不设置的话，默认都是secure的空间。通过SAU可以把一个region设置为non-secure或者secure, non-secure callable。这里需要结合上面提到的Secure and Non-secure address space。Non-secure的space， SPE是不能访问的，同样通过SAU把Secure的address设成non-secure，NSPE也照样不能访问。这样的话SAU设的空间只能是non-secure的space。  
&emsp;&emsp;另外SAU可设的region数目是有限的，要通盘考虑好memory的安排。  

### PPC
&emsp;&emsp;PPC是在上面两个的基础上控制peripheral的访问权限。  
1. 每个peripheral的地址也分S和NS。  
2. 当用PPC设置成S时，NSPE不能访问该模块NS的地址。  
3. 同理，当用PPC设置成NS时，SPE不能访问该模块S的地址。  
4. PPC的设置中还有关于privileged和non-previleged访问的设置，也是需要注意的点。  

### TGU
&emsp;&emsp;TGU在SAU的基础上进一步配置TCM的访问权限。又分为ITGU和DTGU分别控制ITCM和DTCM。  
&emsp;&emsp;从M52开始，后面M55，M85都有这个模块。逻辑很简单，只有3个寄存器，可以翻阅DRM查看用法。    

### MPC
&emsp;&emsp;MPC则是在SAU的基础上配置ROM和RAM的访问权限。每个芯片的实现可能会不一样，要查阅芯片的spec去看MPC保护的范围。  

## Issues
### Jump Address from Secure to Non-Secure

> The ARMv8-M Security Extensions also allow a Secure program to call Non-secure software. In such a case, the Secure program uses a BLXNS instruction to call a Non-secure program. During the state transition, the return address and some processor state information are pushed onto the Secure stack, while the return address on the Link Register (LR) is set to a special value called FNC_RETURN. The Least Significant Bit (LSB) of the function address must be 0.
{: .prompt-info }  

&emsp;&emsp;关于LSB一定是0，CMSE提供了函数cmse_nsfptr_create来create NS fucntion pointer，另外还有cmse_is_nsfptr()来检查地址的是否有效。  

### Interrupt
&emsp;&emsp;Interrupt一定要enable，不然像systick，pendsv都不会相应，SVC还会导致hardfault。  
&emsp;&emsp;注： both secure and non-secure interrupt shall be enabled。  

### Non-Secure Callable Table
&emsp;&emsp;NSC Table是在SPE image生成的时候导出的，地址一般在secure space，而最终要被NSPE调用，因而要把这个NSC Table里的地址对应到相应的non-secure space。否则也是busfault。  

### PSP
1. 当NSPE在privileged thread mode调用NSC table里的函数，SPE那边MSP要提前准备好。  
2. 当NSPE在task里，也就是non-privileged thread mode调用NSC table里函数时， 要为每一个task主备好PSP设置。  

&emsp;&emsp;记录结束，希望可以帮助做同样事情的同学少踩坑，早出坑。  

## Reference
[**Armv8-M Architecture Reference Manual**](https://developer.arm.com/documentation/ddi0553/latest)  
[**SVC causes Hardfault**](https://community.st.com/t5/stm32-mcus-security/svc-call-from-non-secure-code-does-not-trigger-non-secure-svc/td-p/195733)  
[**CMSIS 5**](https://github.com/ARM-software/CMSIS_5)  
[**CMSIS 6**](https://github.com/ARM-software/CMSIS_6/tree/v6.1.0)  
[**CMSIS FreeRTOS**](https://github.com/ARM-software/CMSIS-FreeRTOS/tree/main)  
[**M Profile User Guide Example**](https://github.com/ARM-software/m-profile-user-guide-examples/tree/main)  
[**Application Note AN505**](https://documentation-service.arm.com/static/5ed11469ca06a95ce53f8ed7?token=)  
[**Switching between Secure and Non-secure states**](https://developer.arm.com/documentation/100690/0200/Switching-between-Secure-and-Non-secure-states)  
[**Secure software guidelines**](https://developer.arm.com/documentation/100720/0200/Secure-software-guidelines)  