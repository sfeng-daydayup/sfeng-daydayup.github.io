---
layout: post
title: Execution Priority
date: 2024-12-27 19:04 +0800
author: sfeng
categories: [ARM, Cortex-M]
tags: [cortex-m, priority]
lang: zh
---

## Prface

&emsp;&emsp;Cortex-M系列CPU中有handler mode和thread mode，然后又定义了privileged和un-privileged execution，Armv8-M中支持TZ又引入了secure state和non-secure state，再加上exception和interrupt，理解这些模式和了解它们的执行优先级，那么在Cortex-M系列芯片上开发项目的时候会更游刃有余。本文就来理清这些概念和关联。  

>  本文以Armv8-M为例。
{: .prompt-info }  

## PE Mode
&emsp;&emsp;Cortex-M有两种PE mode：  
- Thread Mode  
    - 类似Armv8 Cortex-A系列里的EL0，相当于user space，application运行在这个模式下。  
    - 系统reset后默认进入thread mode。  
- Handler Mode  
    - 同上，类似Armv8 Cortex-A系列里的EL1，主要运行OS kernel，管理系统的资源。  
    - 所有的exception都是在handler mode下执行。  

&emsp;&emsp;另外Cortex-M下提供了MSP和PSP（相当于Cortex-A系列中的SP_ELx）在不同场景下使用。  
![msp_psp](/assets/img/cortexm/msp_psp.jpg){: .normal }  

- 在handler mode下，PE always使用MSP（这样在exception发生的时候，保存context会更从容）。  
- 而在thread mode下，使用哪个SP则由CONTROL寄存器的SPSEL决定。  
- 系统reset后默认使用的是MSP，也就是vector table的第一项（不管是否有security extension）。  

## Privileged and unprivileged execution
&emsp;&emsp;有如下特性：  
- Handler mode永远是privileged execution。  
- Thread mode则可以运行在privileged或者unprivileged下，由CONTROL寄存器的nPRIV bit配置决定。  
- 一些资源只能在privileged下访问（比如设置priority的寄存器）。  

## Security States
&emsp;&emsp;当security extension在Cortex-M中被选用时，PE就有了secure state和non-secure state。  
- Secure和non-seucre state下分别都有thread mode和handler mode。如下图
    ![security_state](/assets/img/cortexm/security_state.jpg){: .normal }  
- 和Cortex-A一样，被mark成secure的资源只能在secure state下访问。  
- PE在cold reset或者warm reset后进入secure state。  
    - Warm reset可以通过设置AIRCR的SYSRESETREQ来请求一个system reset，这个bit的权限由SYSRESETREQS来控制是否可以在non-secure state下访问。  
    - 在做了Warm reset后，一些debug registers会保留reset前的值，其他的和cold reset一样。  
    - 设置AIRCR的SYSRESETREQ引起的warm reset并不保证立即发生。  
- 由于secure state的引入，一些registers就要banked。  
    - R13（SP） 前面提到，Cortex-M中为PE提供了MSP和PSP两个SP，现在PE分secure和non-secure state，自然为每个state标配一套。其中handler mode还是用MSP，thread mode通过CONTROL寄存器的SPSEL（the bit is banded by security state）选择。  
    ![secure_msp_psp](/assets/img/cortexm/secure_msp_psp.jpg){: .normal }  
    - Special-purpose registers
        - PRIMASK, BASEPRI, and FAULTMASK
        - CONTROL register
        - MSPLIM and PSPLIM
    - SCS（System Control Space） 
    The System Control Space (SCS) provides registers for control, configuration, and status reporting。   

    这些寄存器的命名规则如下：  
    - <register name>_S The Secure instance of the register  
    - <register name>_NS The Non-secure instance of the register
    - <register name> 访问当前security state的寄存器也可以不带后缀  
- Exception也有部分是banked  
    ![exception_bank](/assets/img/cortexm/exception_bank.jpg){: .normal }  

## Execution Priority
&emsp;&emsp;有了上面的概念，继续看priority是怎么定义的。下表是exception number和priority的对应（with cortex-m main extension）：  
![exception_number](/assets/img/cortexm/exception_number.jpg){: .normal }  

&emsp;&emsp;其中标记为Configurable的exception的priority由以下寄存器设置，当然，这些寄存器是privileged access only。  
![pri_reg](/assets/img/cortexm/pri_reg.jpg){: .normal }  
![pri_int](/assets/img/cortexm/pri_int.jpg){: .normal }  
&emsp;&emsp;以上皆为secure state下的寄存器，non-secure寄存器的地址则在secure寄存器地址上加一个offset 0x20000。  

&emsp;&emsp;当AIRCR的PRIS设为1的时候，则non-secure下的priority都要加0x80，意味着non-secure下部分interrupt的priority被降级了。下面是一个例子：  
![nspri_map](/assets/img/cortexm/nspri_map.jpg){: .normal }  
&emsp;&emsp;这里有个问题是由于priority bit总共8位，non-secure下0x80到0xFE的加0x80值不变。这个时候不管secure还是non-secure，建议priority设置范围位0到0x7E。这样就可以保证所有的secure下inerrupt的priority是高于non-secure的，当然有特殊场景需求也可以让secure的interrupt priority低于non-secure。  

&emsp;&emsp;关于exception和interrupt的execution priority都有了结论，那正常运行时候的execution priority是多少呢？Spec上有这样一句话：  
> When no exception is active and no priority boosting is active, the instruction stream that is executing has a priority number of (maximum supported priority number+1)
{: .prompt-info }   

&emsp;&emsp;也就是在没有exception和特别的priority boost的指令的时候，当前的的execution priority为最低（maximum priority + 1）。这样就保证了priority最低的exception/interrupt也可以执行。（priority boost可以通过设置BASEPRI和PRIMASK来实现。）  

### Priority Grouping
&emsp;&emsp;上文提到exception的priority，由于设置priority的寄存器是每8个bit对应一个exception或者interrupt，这样priority的值就是从0到255，数值越小priority越高。  
&emsp;&emsp;Priority grouping就是把这8bit分成两部分，分别为group priority和sub-priority。由寄存器AIRCR的PRIGROUP[10:8]来设置。分组如下：  
![prigroup](/assets/img/cortexm/prigroup.jpg){: .normal }  

&emsp;&emsp;分组的意义在于：  
- Group priority高的优先于group priority低的interrupt执行  
- Group priority高的可抢占正在执行的group priority低的interrupt  
- 在相同的group priority的情况下，subpriority高的interrupt优先执行  
- 在相同的group priority的情况下，subpriority高的不能抢占已经在执行的interrupt 

&emsp;&emsp;在一些芯片的实现里根据需求可能会设计更少的priority bit。比如有效位数为4，则低四位always是0。当分组决定group priority的位数大于等于4的时候，则只有group priority起作用。  

&emsp;&emsp;另外需要注意的是在一些实现中通过设置PRIMASK来enable和disable interrupt，根据spec描述该bit设为1时“Boosts execution priority to either 0 or 0x80.”，也就是把当前execution priority提高到最高的0或者080（non-secure），这时候interrupt还是会来的，只是处于pend状态，等把PRIMASK再次设为0的时候，之前pending的interrupt仍然会被处理。  
&emsp;&emsp;使用BASEPRI也是一样，它只是“changes the priority level required for exception preemption”，并没有真正禁止interrupt。  

## Execution Priority Transition
&emsp;&emsp;这节看下各种模式之间如何转换。  

### Handler mode and thread mode
> By default, the Cortex-M processors start in privileged Thread mode and in Thumb state. In many simple applications, there is no need to use the unprivileged Thread model and the banked SP at all.
{: .prompt-info }   
&emsp;&emsp;因为Cortex-M加电后首先进的是reset vector，博主一直以为是handler mode，然而从spec看，却是privileged thread mode。下面这张图更清晰的描述了它们之间的转换。  

![images_operation_states_modes](/assets/img/cortexm/images_operation_states_modes.png){: .normal }  

&emsp;&emsp;上文提到handler mode运行OS kernel，thread mode运行application，但从FreeRTOS的实现看来并非如此。Exception和interrupt运行在handler mode这个毫无疑问。FreeRTOS中OS Kernel则运行在privileged thread mode。这点在SVC call的进入[vSystemCallEnter](https://github.com/FreeRTOS/FreeRTOS-Kernel/blob/V11.1.0/portable/GCC/ARM_CM55/non_secure/port.c#L1285)和推出[vSystemCallExit](https://github.com/FreeRTOS/FreeRTOS-Kernel/blob/V11.1.0/portable/GCC/ARM_CM55/non_secure/port.c#L1413)两个函数的实现得到了体现。task则根据参数可运行在privileged thread mode和unprivileged mode。  

### Privileged and unprivileged
&emsp;&emsp;如前所述，Armv8 Cortex-M spec上虽然讲handler mode下运行“OS kernel and associated functions, that manage system resources. ”，然后从实际操作来看，其实是privileged mode运行OS kernel。它们之间的切换在上图中得到了体现。这里不做赘叙。  

### Secure state and non-secure state

&emsp;&emsp;Security state之间的切换则看这两张图。  
![security_state_transitions](/assets/img/cortexm/security_state_transitions.jpg){: .normal }  
![security_state_transitions](/assets/img/cortexm/security_state_transitions.png){: .normal }  

&emsp;&emsp;把exception和interrupt加进来就更复杂了。  
> State transitions can also happen due to exceptions and interrupts. Each interrupt can be configured as Secure or Non-secure, and is determined by the Interrupt Target Non-secure (NVIC_ITNS) register, which is only programmable in the Secure world. There are no restrictions regarding whether a Non-secure or Secure interrupt can take place when the processing is running Non-secure or Secure code.
{: .prompt-info }   

![transitions](/assets/img/cortexm/transitions.png){: .normal }  

&emsp;&emsp;各种模式之间的切换本质上都是execution priority的改变。关于这部分的实践，建议选取某个RTOS进行代码研读，以便加深理解。  

## Reference
[**Armv8-M Architecture Reference Manual**](https://developer.arm.com/documentation/ddi0553/latest)  
[**Exception priority level definitions**](https://developer.arm.com/documentation/107706/0100/Exceptions-and-interrupts-overview/Exception-priority-level-definitions)  
[**Priority grouping**](https://developer.arm.com/documentation/107706/0100/Exceptions-and-interrupts-overview/Exception-priority-level-definitions/Priority-grouping)  
[**Interrupt priority grouping**](https://www.ocfreaks.com/interrupt-priority-grouping-arm-cortex-m-nvic/)  
[**Operation Modes and States**](https://developer.arm.com/documentation/107656/0101/Operational-modes-and-states)  
[**Switching between Secure and Non-secure states**](https://developer.arm.com/documentation/100690/0200/Switching-between-Secure-and-Non-secure-states?lang=en)  