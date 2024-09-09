---
layout: post
title: Stack Protector
date: 2024-09-07 16:03 +0800
author: sfeng
categories: [Blogging, Dev]
tags: [stack]
lang: zh
---

## Preface
&emsp;&emsp;上次遇到一个heap overflow(《[**About "malloc(): corrupted top size"**](https://sfeng-daydayup.github.io/posts/about-malloc-corrupted-top-size/)》)的问题，其实到现在还没有好的解决办法，不过对stack 的overflow倒是有GCC的option做保护。在以前的项目中有用过，不过没有详细研究，这篇就来deepdive下。

## Content

### Basic
&emsp;&emsp;首先stack是做啥用的？嗯，stack很重要，比如刷leetcode的时候做树深度或者广度优先搜索的时候有两种方法，一种叫迭代法，一种叫递归法，其中迭代法很麻烦，需要自己记录我遍历了哪些节点，接下来要遍历哪些，而递归法则简单多了，在函数里设置好结束条件，依次递归访问树的页节点就完事了。为什么会这么简单？这里就是stack的作用，它帮你把中间结果，局部变量，要返回的上一层节点的LR都保存下来了。stack被破坏掉很可能引起程序的crash，还可能引起严重的security问题。  

### GCC Option of Stack protect
&emsp;&emsp;以下copy自gcc的man。  
```shell
       -fstack-protector
           Emit extra code to check for buffer overflows, such as stack smashing attacks.  This is done by adding a guard variable to functions with vulnerable objects.  This includes functions that call "alloca", and functions with buffers larger than 8 bytes.  The guards are initialized when a function is entered and then checked when the function exits.  If a guard check fails, an error message is printed and the program exits.

       -fstack-protector-all
           Like -fstack-protector except that all functions are protected.

       -fstack-protector-strong
           Like -fstack-protector but includes additional functions to be protected --- those that have local array definitions, or have references to local frame addresses.

       -fstack-protector-explicit
           Like -fstack-protector but only protects those functions which have the "stack_protect" attribute
```  
&emsp;&emsp;gcc的manual其实解释的很清楚，后边用例子对照一下。另stack-protector-explicit可以指定只对特定的函数做stack protect（但在博主的实验环境中看起来并不是Like -fstack-protector而是Like -fstack-protector-all），这里就不讨论了。  

### How does it protect stack
&emsp;&emsp;原理其实很简单，由于stack的特性是由高地址往低地址存贮诸如局部变量和LR，而我们程序中memory的增长方向则是由低地址到高地址。众所周知，局部变量是放在stack中的，当访问局部变量特别是array类型的变量时，有可能会越界访问，特别是写操作，会把stack中的内容改变，进而改变程序运行过程，造成某些不可预测的结果，这个时候反而crash是最好的结果了。gcc的stack protector是用一个canary的值把函数的LR和保存的变量隔离开，在离开本函数前调用__stack_chk_fail检查canary的值是否改变来判断是否有stack smashing发生。这里引用一张图：  
![Desktop View](/assets/img/stackprotector.png){: .normal }

### Example and analysis
> 以下代码编译运行环境如下：  
> Toolchain: GNU Toolchain for the A-profile Architecture 8.3-2019.02
> SoC: ARMv8 Corextex-A series CPU
{: .prompt-info }

&emsp;&emsp;准备的例子如下：  
```
void test_stackprotector(void)
{       
        unsigned char buff[16]; /* an array > 8 bytes */
        
        memset(buff, 0xde, 16);
}
```  

```
void test_stackprotector_strong(void)
{       
        unsigned char buff[4]; /* an array < 8 bytes */
        
        memset(buff, 0xbf, 4);
}
```  

```
void test_stackprotector_all(void)
{       
        unsigned char tmp; /* local variable not an array*/

        tmp = 0xbd;
}
```  

```
void test(void)
{
         test_stackprotector();

         test_stackprotector_strong();

         test_stackprotector_all();
}
```  

&emsp;&emsp;设置__stack_chk_guard为0xdeadbeafa55a5aa5，并依次用编译选项-fstack-protector、-fstack-protector-strong、-fstack-protector-all，一是看看编译出的汇编有什么差别，以及运行时的stack是怎样安排的。  

#### -fstack-protector
```
000000000000a828 <test_stackprotector>:
    a828:       a9bd7bfd        stp     x29, x30, [sp, #-48]!
    a82c:       910003fd        mov     x29, sp
    a830:       b0000040        adrp    x0, 13000 <switch_status>
    a834:       91012000        add     x0, x0, #0x48
    a838:       f9400001        ldr     x1, [x0]
    a83c:       f90017e1        str     x1, [sp, #40]
    a840:       d2800001        mov     x1, #0x0                        // #0
    a844:       910063e0        add     x0, sp, #0x18
    a848:       d2800202        mov     x2, #0x10                       // #16
    a84c:       52801bc1        mov     w1, #0xde                       // #222
    a850:       97ffea6e        bl      5208 <memset>
    a854:       d503201f        nop
    a858:       b0000040        adrp    x0, 13000 <switch_status>
    a85c:       91012000        add     x0, x0, #0x48
    a860:       f94017e1        ldr     x1, [sp, #40]
    a864:       f9400000        ldr     x0, [x0]
    a868:       ca000020        eor     x0, x1, x0
    a86c:       f100001f        cmp     x0, #0x0
    a870:       54000040        b.eq    a878 <test_stackprotector+0x50>  // b.none
    a874:       97ffffc2        bl      a77c <__stack_chk_fail>
    a878:       a8c37bfd        ldp     x29, x30, [sp], #48
    a87c:       d65f03c0        ret

000000000000a880 <test_stackprotector_strong>:
    a880:       a9be7bfd        stp     x29, x30, [sp, #-32]!
    a884:       910003fd        mov     x29, sp
    a888:       910063e0        add     x0, sp, #0x18
    a88c:       d2800082        mov     x2, #0x4                        // #4
    a890:       528017e1        mov     w1, #0xbf                       // #191
    a894:       97ffea5d        bl      5208 <memset>
    a898:       d503201f        nop
    a89c:       a8c27bfd        ldp     x29, x30, [sp], #32
    a8a0:       d65f03c0        ret

000000000000a8a4 <test_stackprotector_all>:
    a8a4:       d10043ff        sub     sp, sp, #0x10
    a8a8:       12800840        mov     w0, #0xffffffbd                 // #-67
    a8ac:       39003fe0        strb    w0, [sp, #15]
    a8b0:       b0000040        adrp    x0, 13000 <switch_status>
    a8b4:       91170000        add     x0, x0, #0x5c0
    a8b8:       39403fe1        ldrb    w1, [sp, #15]
    a8bc:       39000001        strb    w1, [x0]
    a8c0:       d503201f        nop
    a8c4:       910043ff        add     sp, sp, #0x10
    a8c8:       d65f03c0        ret
```  
&emsp;&emsp;从汇编里看只有test_stackprotector结尾调用了__stack_chk_fail，符合预期。  
&emsp;&emsp;另外这里发现了一个有趣的事情，就是在每个函数的第一行汇编保存FP和LR，它竟然不是保存在栈顶，而是又加了一个offset，这和上文图片里所示是有差别的，而这个预留出来的栈空间是给局部变量的，这样做至少避免了因为buffer overflow把本函数给高挂了，然而更可怕的是如果把之前栈数据给改了，那就不知道什么时候遇到不可预测的问题了。所以FP和LR这样放个人认为意义不大，有可能还增加了debug的难度。这是题外话。  

#### -fstack-protector-strong
```
000000000000acd4 <test_stackprotector>:
    acd4:       a9bd7bfd        stp     x29, x30, [sp, #-48]!
    acd8:       910003fd        mov     x29, sp
    acdc:       b0000040        adrp    x0, 13000 <__func__.5917+0x18>
    ace0:       91212000        add     x0, x0, #0x848
    ace4:       f9400001        ldr     x1, [x0]
    ace8:       f90017e1        str     x1, [sp, #40]
    acec:       d2800001        mov     x1, #0x0                        // #0
    acf0:       910063e0        add     x0, sp, #0x18
    acf4:       d2800202        mov     x2, #0x10                       // #16
    acf8:       52801bc1        mov     w1, #0xde                       // #222
    acfc:       97ffe9f9        bl      54e0 <memset>
    ad00:       d503201f        nop
    ad04:       b0000040        adrp    x0, 13000 <__func__.5917+0x18>
    ad08:       91212000        add     x0, x0, #0x848
    ad0c:       f94017e1        ldr     x1, [sp, #40]
    ad10:       f9400000        ldr     x0, [x0]
    ad14:       ca000020        eor     x0, x1, x0
    ad18:       f100001f        cmp     x0, #0x0
    ad1c:       54000040        b.eq    ad24 <test_stackprotector+0x50>  // b.none
    ad20:       97ffffc2        bl      ac28 <__stack_chk_fail>
    ad24:       a8c37bfd        ldp     x29, x30, [sp], #48
    ad28:       d65f03c0        ret

000000000000ad2c <test_stackprotector_strong>:
    ad2c:       a9be7bfd        stp     x29, x30, [sp, #-32]!
    ad30:       910003fd        mov     x29, sp
    ad34:       b0000040        adrp    x0, 13000 <__func__.5917+0x18>
    ad38:       91212000        add     x0, x0, #0x848
    ad3c:       f9400001        ldr     x1, [x0]
    ad40:       f9000fe1        str     x1, [sp, #24]
    ad44:       d2800001        mov     x1, #0x0                        // #0
    ad48:       910043e0        add     x0, sp, #0x10
    ad4c:       d2800082        mov     x2, #0x4                        // #4
    ad50:       528017e1        mov     w1, #0xbf                       // #191
    ad54:       97ffe9e3        bl      54e0 <memset>
    ad58:       d503201f        nop
    ad5c:       b0000040        adrp    x0, 13000 <__func__.5917+0x18>
    ad60:       91212000        add     x0, x0, #0x848
    ad64:       f9400fe1        ldr     x1, [sp, #24]
    ad68:       f9400000        ldr     x0, [x0]
    ad6c:       ca000020        eor     x0, x1, x0
    ad70:       f100001f        cmp     x0, #0x0
    ad74:       54000040        b.eq    ad7c <test_stackprotector_strong+0x50>  // b.none
    ad78:       97ffffac        bl      ac28 <__stack_chk_fail>
    ad7c:       a8c27bfd        ldp     x29, x30, [sp], #32
    ad80:       d65f03c0        ret

000000000000ad84 <test_stackprotector_all>:
    ad84:       d10043ff        sub     sp, sp, #0x10
    ad88:       12800840        mov     w0, #0xffffffbd                 // #-67
    ad8c:       39003fe0        strb    w0, [sp, #15]
    ad90:       b0000040        adrp    x0, 13000 <__func__.5917+0x18>
    ad94:       91370000        add     x0, x0, #0xdc0
    ad98:       39403fe1        ldrb    w1, [sp, #15]
    ad9c:       39000001        strb    w1, [x0]
    ada0:       d503201f        nop
    ada4:       910043ff        add     sp, sp, #0x10
    ada8:       d65f03c0        ret
```  
&emsp;&emsp;test_stackprotector和test_stackprotector_strong结尾都调用了__stack_chk_fail，符合预期。  

#### -fstack-protector-all
```
000000000000c580 <test_stackprotector>:
    c580:       a9bd7bfd        stp     x29, x30, [sp, #-48]!
    c584:       910003fd        mov     x29, sp
    c588:       d0000040        adrp    x0, 16000 <switch_status>
    c58c:       91012000        add     x0, x0, #0x48
    c590:       f9400001        ldr     x1, [x0]
    c594:       f90017e1        str     x1, [sp, #40]
    c598:       d2800001        mov     x1, #0x0                        // #0
    c59c:       910063e0        add     x0, sp, #0x18
    c5a0:       d2800202        mov     x2, #0x10                       // #16
    c5a4:       52801bc1        mov     w1, #0xde                       // #222
    c5a8:       97ffe67c        bl      5f98 <memset>
    c5ac:       d503201f        nop
    c5b0:       d0000040        adrp    x0, 16000 <switch_status>
    c5b4:       91012000        add     x0, x0, #0x48
    c5b8:       f94017e1        ldr     x1, [sp, #40]
    c5bc:       f9400000        ldr     x0, [x0]
    c5c0:       ca000020        eor     x0, x1, x0
    c5c4:       f100001f        cmp     x0, #0x0
    c5c8:       54000040        b.eq    c5d0 <test_stackprotector+0x50>  // b.none
    c5cc:       97ffffa8        bl      c46c <__stack_chk_fail>
    c5d0:       a8c37bfd        ldp     x29, x30, [sp], #48
    c5d4:       d65f03c0        ret

000000000000c5d8 <test_stackprotector_strong>:
    c5d8:       a9be7bfd        stp     x29, x30, [sp, #-32]!
    c5dc:       910003fd        mov     x29, sp
    c5e0:       d0000040        adrp    x0, 16000 <switch_status>
    c5e4:       91012000        add     x0, x0, #0x48
    c5e8:       f9400001        ldr     x1, [x0]
    c5ec:       f9000fe1        str     x1, [sp, #24]
    c5f0:       d2800001        mov     x1, #0x0                        // #0
    c5f4:       910043e0        add     x0, sp, #0x10
    c5f8:       d2800082        mov     x2, #0x4                        // #4
    c5fc:       528017e1        mov     w1, #0xbf                       // #191
    c600:       97ffe666        bl      5f98 <memset>
    c604:       d503201f        nop
    c608:       d0000040        adrp    x0, 16000 <switch_status>
    c60c:       91012000        add     x0, x0, #0x48
    c610:       f9400fe1        ldr     x1, [sp, #24]
    c614:       f9400000        ldr     x0, [x0]
    c618:       ca000020        eor     x0, x1, x0
    c61c:       f100001f        cmp     x0, #0x0
    c620:       54000040        b.eq    c628 <test_stackprotector_strong+0x50>  // b.none
    c624:       97ffff92        bl      c46c <__stack_chk_fail>
    c628:       a8c27bfd        ldp     x29, x30, [sp], #32
    c62c:       d65f03c0        ret

000000000000c630 <test_stackprotector_all>:
    c630:       a9be7bfd        stp     x29, x30, [sp, #-32]!
    c634:       910003fd        mov     x29, sp
    c638:       d0000040        adrp    x0, 16000 <switch_status>
    c63c:       91012000        add     x0, x0, #0x48
    c640:       f9400001        ldr     x1, [x0]
    c644:       f9000fe1        str     x1, [sp, #24]
    c648:       d2800001        mov     x1, #0x0                        // #0
    c64c:       12800840        mov     w0, #0xffffffbd                 // #-67
    c650:       39005fe0        strb    w0, [sp, #23]
    c654:       d0000040        adrp    x0, 16000 <switch_status>
    c658:       91170000        add     x0, x0, #0x5c0
    c65c:       39405fe1        ldrb    w1, [sp, #23]
    c660:       39000001        strb    w1, [x0]
    c664:       d503201f        nop
    c668:       d0000040        adrp    x0, 16000 <switch_status>
    c66c:       91012000        add     x0, x0, #0x48
    c670:       f9400fe1        ldr     x1, [sp, #24]
    c674:       f9400000        ldr     x0, [x0]
    c678:       ca000020        eor     x0, x1, x0
    c67c:       f100001f        cmp     x0, #0x0
    c680:       54000040        b.eq    c688 <test_stackprotector_all+0x58>  // b.none
    c684:       97ffff7a        bl      c46c <__stack_chk_fail>
    c688:       a8c27bfd        ldp     x29, x30, [sp], #32
    c68c:       d65f03c0        ret
```  
&emsp;&emsp;这下三个函数结尾都有调用__stack_chk_fail了。

#### Stack Analysis
&emsp;&emsp;以上三个option只决定哪些函数的要进行stack protect，stack的数据安排是类似的，这里选取一种情况分析。以下是stack数据的一个dump（仅截取当前函数为test_stackprotector的stack。另外为dump stack做了另外的操作，和上面汇编并非匹配。）：  
- no stack protector enabled  
```
00 00 00 00 00 00 00 00
f0 fe 0b 00 00 00 00 00  // stored FP
04 66 00 00 00 00 00 00  // stored LR
de de de de de de de de  // buf[16] and set to 0xde
de de de de de de de de
10 ff 0b 00 00 00 00 00  // FP of test()
5c 66 00 00 00 00 00 00  // LR of test()
00 00 00 00 00 00 00 00
```  

- with -fstack-protector  
```
00 00 00 00 00 00 00 00
f0 fe 0b 00 00 00 00 00  // stored FP
e0 66 00 00 00 00 00 00  // stored LR
00 00 00 00 00 00 00 00
7c 60 00 00 00 00 00 00
00 00 60 04 00 00 00 00
de de de de de de de de  // buf[16] and set to 0xde
de de de de de de de de
a5 5a 5a a5 af be ad de  // stack check guard
10 ff 0b 00 00 00 00 00  // FP of test()
38 67 00 00 00 00 00 00  // LR of test()
00 00 00 00 00 00 00 00
```  

### Conclusion

&emsp;&emsp;通过上面的介绍，可以看到gcc stack protector可以避免部分访问越界的错误，也有它的局限性：  
1. 只对写操作的overflow起作用，读不会引发错误；  
2. 只有写越界影响到canary时起作用，canary没变化不会引发错误；  
3. 空间上会占用更多的stack来保存canary；  
4. 时间上因为在相关函数结尾会多一个check canary的过程，也会影响performance；  

&emsp;&emsp;关于#1和#2，需要引入其他机制来加强。关于#3和#4，有两个方法来缓解：  
1. 使用stack-protector-strong，既可以比较全面的保护，相对stack-protector-all可以少用一些stack和少一些检查；  
2. 在开发过程中打开选项，而在production的时候关闭；  

&emsp;&emsp;关于利用stack进行hack，在bare metal程序中比较容易进行。但在应用了MMU的系统中，应用程序都只能运行在自己的virtual space中，不能访问kernel或者其他应用程序的空间，所以通过这种方法hack就不大容易了。  
&emsp;&emsp;一些流行的开源项目也都确实apply了stack protect，例如Linux Kernel和OPTEE。

&emsp;&emsp;总之，stack protector在一定程度上能够及早发现stack overflow并降低debug的难度，还是值得使用的。

## Reference
[**Stack Smashing Protection**](https://www.redhat.com/en/blog/security-technologies-stack-smashing-protection-stackguard)  
[**Local Variables on the Stack**](https://bob.cs.sonoma.edu/IntroCompOrg-RPi/sec-varstack.html)  
[**Stack Introduction**](https://en.wikipedia.org/wiki/Stack_(abstract_data_type))  