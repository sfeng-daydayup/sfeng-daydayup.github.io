---
layout: post
title: Stack Frame
date: 2025-02-11 19:32 +0800
author: sfeng
categories: [Dev]
tags: [stack]
lang: zh
---

## Background
&emsp;&emsp;Linux在出错的时候，会把stack trace打出来，以帮助开发者快速定位到问题。而在绝大多数baremetal的程序中，甚至出了exception的时候很少有有用的打印信息，这里还是推荐把stack打出来，至于back trace可以人工硬解，当然也可以找一些工具来帮助解析，例如在OPTEE里就有script可以把地址转换为函数的调用（[symbolize.py](https://github.com/OP-TEE/optee_os/blob/4.0.0/scripts/symbolize.py) [usage](https://optee.readthedocs.io/en/latest/debug/abort_dumps.html)）。人工硬解的话，就需要对stack frame有一定的了解了。  

## Why Need Stack Frame
&emsp;&emsp;首先为什么要有stack，来看看AI是怎么回答的。  
> A stack is used in programming because it provides an efficient way to manage data that needs to be accessed and removed in a "Last In, First Out" (LIFO) order, making it ideal for scenarios like function calls, recursion, backtracking algorithms, and managing temporary data within a program where the most recent addition needs to be accessed first.   
{: .prompt-tip }  
&emsp;&emsp;其实stack的用途总结下来大概就是：  
1. 存储局部变量。  
&emsp;&emsp;众所周知，全局变量会放在bss或者data段。局部变量如它的名字所诉，只在局部使用，很可能用一次几次就不会再用了，如果象全局变量一样在bss或者data段分配一块memory给它，无疑会造成巨大的浪费，尤其现代的项目规模巨大，把内存撑爆都有可能。而使用stack可以随用随分配，生命周期结束就返还，节省资源，也能提高效率。  
2. 保存“犯罪”现场。  
&emsp;&emsp;对于函数调用，需要保存caller的使用现场，然后再跳转至callee，不然callee结束就回不去了。典型的比如递归调用就会使用大量的stack，在leetcode的一些题目中，使用递归调用会导致资源使用过多而不能通过，还需要做算法优化节省资源。所以使用stack其实是简化了程序设计，但也要注意stack资源是有限的。（某些面试题中要求用汇编写一段递归程序，my god！）  
&emsp;&emsp;除了函数调用还有exception，这个时候硬件会主动保存一些寄存器信息（Return address， LR， R0-R3 或者X0-X7，etc.），当然进入exception handler，开发者也要根据需要保存一些额外的寄存器到stack。  

&emsp;&emsp;说完stack就是stack frame了。一个stack frame就包含了上面说的函数的“犯罪”现场，通过这个stack frame要能恢复该程序以继续执行。  
&emsp;&emsp;下图展示了aarch64中stack frame的结构（出自DEN0024A_v8_architecture_PG.pdf）：  
![stack frame](/assets/img/stack/stack_frame.jpg){: .normal }   

&emsp;&emsp;其中（aarch32其实也大同小异。）：  
1. Frame pointer（x29）要指向前一个stack中的frame pointer  
2. LR（x30）也要一起存在stack  
3. 最后一个frame pointer则设为0，相当于整个程序入口处fp为0，因为也没有上一级返回了  
4. aarch64里frame pointer是16字节对齐的，而aarch32一般是8字节对齐  

&emsp;&emsp;那FP和LR各起什么作用呢。  
- FP（x29）  
  - 如果callee需要用到FP，要先把caller的FP存在stack里，然后再把当前sp赋值给FP  
  - 该callee里的local variable都是以FP为基准，通过加一个offset来找此变量  
  - 在callee返回caller的时候把FP从栈里恢复回来  
- LR（x30）  
  - LR里存的是从callee返回后，caller要运行的下一条指令地址  
  - 如果callee要修改LR，比如会调用下一个callee，则要把LR存在堆栈里  
  - callee返回caller时要从栈里恢复LR  

## Example
&emsp;&emsp;来看一个多重调用的例子。  
```sass
int callee2(int a, int b)
{
        int c_l3 = 0;

        c_l3 = a + b;

        return c_l3;
}

int callee1(int a, int b)
{
        int c_l2 = 0;

        c_l2 = callee2(a, b);

        return c_l2;
}

void _start(void)
{
        int c_l1 = 0;
        int a_l1 = 1;
        int b_l1 = 2;

        c_l1 = callee1(a_l1, b_l1);
}
```
{: file='test_stack.c'}  

&emsp;&emsp;直接反汇编看结果吧，这里是aarch64的。  
```sass
00000000004000e8 <callee2>:
  4000e8:       d10083ff        sub     sp, sp, #0x20          (9)
  4000ec:       b9000fe0        str     w0, [sp, #12]          (10)
  4000f0:       b9000be1        str     w1, [sp, #8]           (11)
  4000f4:       b9001fff        str     wzr, [sp, #28]         (12)
  4000f8:       b9400fe1        ldr     w1, [sp, #12]
  4000fc:       b9400be0        ldr     w0, [sp, #8]
  400100:       0b000020        add     w0, w1, w0
  400104:       b9001fe0        str     w0, [sp, #28]          (13)
  400108:       b9401fe0        ldr     w0, [sp, #28]
  40010c:       910083ff        add     sp, sp, #0x20
  400110:       d65f03c0        ret

0000000000400114 <callee1>:
  400114:       a9bd7bfd        stp     x29, x30, [sp, #-48]!   (5)
  400118:       910003fd        mov     x29, sp               //更新fp
  40011c:       b9001fe0        str     w0, [sp, #28]           (6)
  400120:       b9001be1        str     w1, [sp, #24]           (7)
  400124:       b9002fff        str     wzr, [sp, #44]          (8)
  400128:       b9401be1        ldr     w1, [sp, #24]
  40012c:       b9401fe0        ldr     w0, [sp, #28]
  400130:       97ffffee        bl      4000e8 <callee2>
  400134:       b9002fe0        str     w0, [sp, #44]
  400138:       b9402fe0        ldr     w0, [sp, #44]
  40013c:       a8c37bfd        ldp     x29, x30, [sp], #48
  400140:       d65f03c0        ret

0000000000400144 <_start>:
  400144:       a9be7bfd        stp     x29, x30, [sp, #-32]!   (1)
  400148:       910003fd        mov     x29, sp               // 更新fp
  40014c:       b9001fff        str     wzr, [sp, #28]          (2)
  400150:       52800020        mov     w0, #0x1                        // #1
  400154:       b9001be0        str     w0, [sp, #24]           (3)
  400158:       52800040        mov     w0, #0x2                        // #2
  40015c:       b90017e0        str     w0, [sp, #20]           (4)
  400160:       b94017e1        ldr     w1, [sp, #20]
  400164:       b9401be0        ldr     w0, [sp, #24]
  400168:       97ffffeb        bl      400114 <callee1>
  40016c:       b9001fe0        str     w0, [sp, #28]
  400170:       d503201f        nop
  400174:       a8c27bfd        ldp     x29, x30, [sp], #32
  400178:       d65f03c0        ret
```
{: file='test_stack_aarch64.dump'}  

&emsp;&emsp;可以根据上面的汇编来反推出调用到callee2时候这部分stack的内容。假设进入_start时sp为0x1000，则如下：  
```sass
!!!!!!          由于callee2为调用的最后一个环节，lr不会变不用存，而sp则函数内自己维护
0x0f90          (9). sub     sp, sp, #0x20  //更新sp为0xf90（注：返回前又加了0x20恢复回来了）
0x0f94
0x0f98  #2      (11).str     w1, [sp, #8]   //存参数1
0x0f9c  #1      (10).str     w0, [sp, #12]  //存参数0
0x0fa0
0x0fa4
0x0fa8
0x0fac  #0      (12).str     wzr, [sp, #28] //清0 c_l3
        #3      (13).str     w0, [sp, #28]  //把计算结果存在此位置
!!!!!!          callee1的stack frame，跳至callee2时sp为0x0fb0
0x0fb0  x29_l   (5). stp     x29, x30, [sp, #-48]!  //存_start的fp，lr，sp变为0x0fb0
0x0fb4  x29_h
0x0fb8  x30_l
0x0fbc  x30_h
0x0fc0
0x0fc4
0x0fc8  #2      (7). str     w1, [sp, #24]  //参数1存在该地址
0x0fcc  #1      (6). str     w0, [sp, #28]  //参数0存在该地址
0x0fd0
0x0fd4
0x0fd8
0x0fdc  #0      (8). str     wzr, [sp, #44] //清0，c_l2
!!!!!!          _start的stack frame，跳至callee1时sp为0x0fe0
0x0fe0  x29_l   (1). stp     x29, x30, [sp, #-32]!  //存上一个caller的fp,lr sp变为0x0fe0
0x0fe4  x29_h
0x0fe8  x30_l
0x0fec  x30_h
0x0ff0
0x0ff4  #2      (4). mov     w0, #0x2
                   str     w0, [sp, #20]  //设2，b_l1
0x0ff8  #1      (3). mov     w0, #0x1
                   str     w0, [sp, #24]  //设1，a_l1
0x0ffc  #0      (2). str     wzr, [sp, #28] //清0，对应c中的变量c_l1
0x1000
!!!!!!
```  

&emsp;&emsp;最终的结果如上。这里还有一些细节如下：  
1. 上面每个stack frame最多分为三个块，fp，lr一个，本地变量一个，参数一个  
2. 这几个块都会根据自身大小申请16B对齐的一个空间，具体看callee1为啥占用了48B  
3. 每个块都按照stack的习惯，先从高地址开始存数据  
4. 这几个块都有对齐要求（16B in aarch64），会有一些空间浪费  

注1：上面的x29_l，x29_h，x30_l，x30_h只表示它占用8B，具体排布要看大小端设定。  
注2：stack中填充步骤加了圆括号+数字对应汇编中的顺序。  

&emsp;&emsp;aarch32的汇编也贴出来做个比较，有兴趣的可以自己还原下。  
```sass
00010074 <callee2>:
   10074:       b480            push    {r7}
   10076:       b085            sub     sp, #20
   10078:       af00            add     r7, sp, #0
   1007a:       6078            str     r0, [r7, #4]
   1007c:       6039            str     r1, [r7, #0]
   1007e:       2300            movs    r3, #0
   10080:       60fb            str     r3, [r7, #12]
   10082:       687a            ldr     r2, [r7, #4]
   10084:       683b            ldr     r3, [r7, #0]
   10086:       4413            add     r3, r2
   10088:       60fb            str     r3, [r7, #12]
   1008a:       68fb            ldr     r3, [r7, #12]
   1008c:       4618            mov     r0, r3
   1008e:       3714            adds    r7, #20
   10090:       46bd            mov     sp, r7
   10092:       f85d 7b04       ldr.w   r7, [sp], #4
   10096:       4770            bx      lr

00010098 <callee1>:
   10098:       b580            push    {r7, lr}
   1009a:       b084            sub     sp, #16
   1009c:       af00            add     r7, sp, #0
   1009e:       6078            str     r0, [r7, #4]
   100a0:       6039            str     r1, [r7, #0]
   100a2:       2300            movs    r3, #0
   100a4:       60fb            str     r3, [r7, #12]
   100a6:       6839            ldr     r1, [r7, #0]
   100a8:       6878            ldr     r0, [r7, #4]
   100aa:       f7ff ffe3       bl      10074 <callee2>
   100ae:       60f8            str     r0, [r7, #12]
   100b0:       68fb            ldr     r3, [r7, #12]
   100b2:       4618            mov     r0, r3
   100b4:       3710            adds    r7, #16
   100b6:       46bd            mov     sp, r7
   100b8:       bd80            pop     {r7, pc}

000100ba <_start>:
   100ba:       b580            push    {r7, lr}
   100bc:       b084            sub     sp, #16
   100be:       af00            add     r7, sp, #0
   100c0:       2300            movs    r3, #0
   100c2:       60fb            str     r3, [r7, #12]
   100c4:       2301            movs    r3, #1
   100c6:       60bb            str     r3, [r7, #8]
   100c8:       2302            movs    r3, #2
   100ca:       607b            str     r3, [r7, #4]
   100cc:       6879            ldr     r1, [r7, #4]
   100ce:       68b8            ldr     r0, [r7, #8]
   100d0:       f7ff ffe2       bl      10098 <callee1>
   100d4:       60f8            str     r0, [r7, #12]
   100d6:       bf00            nop
   100d8:       3710            adds    r7, #16
   100da:       46bd            mov     sp, r7
   100dc:       bd80            pop     {r7, pc}
```
{: file='test_stack_aarch32.dump'}  

## Debug
&emsp;&emsp;总结这篇是因为在ATF里踩了个坑。看这个函数[memcpy_s](https://github.com/TrustedFirmware-A/trusted-firmware-a/blob/v2.12/lib/libc/memcpy_s.c#L12)。  
&emsp;&emsp;大家注意s和d的类型，它们可是32bit的unsigned int，如果和memcpy一样用，不可避免的会造成stack破坏。该函数不会出错，但一返回指针就飞。  
&emsp;&emsp;嘿嘿， 最可笑的是，ATF里已经经过review，merge了的代码也有用错的地方。  
<https://github.com/TrustedFirmware-A/trusted-firmware-a/blob/v2.12/plat/intel/soc/common/socfpga_ros.c#L102>  

&emsp;&emsp;总之，了解了stack的结构，debug这类问题的时候会容易一些。  

## Reference
[**Call Stack**](https://en.wikipedia.org/wiki/Call_stack)  
[**Concept of Stack Frame**](https://stackoverflow.com/questions/10057443/explain-the-concept-of-a-stack-frame-in-a-nutshell)  
[**Understand Stack Frame**](https://softwareengineering.stackexchange.com/questions/195385/understanding-stack-frame-of-function-call-in-c-c)  
[**Stack Frame Arm**](https://lloydrochester.com/post/c/stack-of-frames-arm/)  
[**Stack Frame**](https://www.sciencedirect.com/topics/engineering/stack-frame)  