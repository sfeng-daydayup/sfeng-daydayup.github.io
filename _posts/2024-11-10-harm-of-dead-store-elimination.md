---
layout: post
title: Harm of Dead Store Elimination
date: 2024-11-10 15:36 +0800
author: sfeng
categories: [Security]
tags: [security]
lang: zh
---

## BackGround
&emsp;&emsp;最近跟某大厂做code review，人家提出了用memzero_explicit代替memset来增加security，一试验，还真的是security issue。本文来展示一下试验的结果。  

## Concept of Dead Store
&emsp;&emsp;维基百科上这样定义Dead Store。
> In computer programming, a dead store is a local variable that is assigned a value but is read by no following instruction. Dead stores waste processor time and memory, and may be detected through the use of static program analysis, and removed by an optimizing compiler.
{: .prompt-info } 

&emsp;&emsp;以下是一个示例：  
```shell
void test_memset(void)
{
        unsigned char test[] = "hello_memzero_explicit";
        unsigned int length = strlen(test);

        printf("%s\n", test);
        memset(test, 0, length);
}
```
&emsp;&emsp;用大于等于O1的optimizaiotn option编译后objdump结果如下：  
```
0000000000400650 <test_memset>:
  400650:       90000001        adrp    x1, 400000 <__abi_tag-0x254>
  400654:       911be021        add     x1, x1, #0x6f8
  400658:       a9bd7bfd        stp     x29, x30, [sp, #-48]!
  40065c:       910003fd        mov     x29, sp
  400660:       a9400c22        ldp     x2, x3, [x1]
  400664:       a9018fe2        stp     x2, x3, [sp, #24]
  400668:       910063e0        add     x0, sp, #0x18
  40066c:       f840f021        ldur    x1, [x1, #15]
  400670:       f80273e1        stur    x1, [sp, #39]
  400674:       97ffff9f        bl      4004f0 <puts@plt>
  400678:       a8c37bfd        ldp     x29, x30, [sp], #48
  40067c:       d65f03c0        ret
```  
&emsp;&emsp;对比一下用O0的编译结果：  
```
0000000000400684 <test_memset>:
  400684:       a9bd7bfd        stp     x29, x30, [sp, #-48]!
  400688:       910003fd        mov     x29, sp
  40068c:       90000000        adrp    x0, 400000 <__abi_tag-0x254>
  400690:       911f0000        add     x0, x0, #0x7c0
  400694:       910043e2        add     x2, sp, #0x10
  400698:       aa0003e3        mov     x3, x0
  40069c:       a9400460        ldp     x0, x1, [x3]
  4006a0:       a9000440        stp     x0, x1, [x2]
  4006a4:       91003c61        add     x1, x3, #0xf
  4006a8:       91003c40        add     x0, x2, #0xf
  4006ac:       f9400021        ldr     x1, [x1]
  4006b0:       f9000001        str     x1, [x0]
  4006b4:       910043e0        add     x0, sp, #0x10
  4006b8:       97ffff92        bl      400500 <strlen@plt>
  4006bc:       b9002fe0        str     w0, [sp, #44]
  4006c0:       910043e0        add     x0, sp, #0x10
  4006c4:       97ffffa3        bl      400550 <puts@plt>
  4006c8:       b9402fe1        ldr     w1, [sp, #44]
  4006cc:       910043e0        add     x0, sp, #0x10
  4006d0:       aa0103e2        mov     x2, x1
  4006d4:       52800001        mov     w1, #0x0                        // #0
  4006d8:       97ffff92        bl      400520 <memset@plt>
  4006dc:       d503201f        nop
  4006e0:       a8c37bfd        ldp     x29, x30, [sp], #48
  4006e4:       d65f03c0        ret
```  
&emsp;&emsp;可以看到在用O1以上的优化选项的时候，memset操作被优化没了，也就是所谓的Dead Store Elimination。  

## Possible Consequence
&emsp;&emsp;想象一下，如果这段buff里保存的是一些sensitive data，比如password，本意是想清掉的，结果还留在内存的stack里，就有了泄露的风险。  

> Removing buffer scrubbing code is an example of what D’Silva et al. [30] call a “correctness-security gap.” From the perspective of the C standard, removing the memset above is allowed because the contents of unreachable memory are not considered part of the semantics of the C program. However, leaving sensitive data in memory increases the damage posed by memory disclosure vulnerabilities and direct attacks on physical memory. This leaves gap between what the standard considers correct and what a security developer might deem correct. Unfortunately, the C language does not provide a guaranteed way to achieve what the developer intends, and attempts to add a memory scrubbing function to the
C standard library have not seen mainstream adoption. Security-conscious developers have been left to devise their own means to keep the compiler from optimizing away their scrubbing functions, and this has led to a proliferation of “secure memset”   implementations of varying quality.
{: .prompt-info } 

## Solution
&emsp;&emsp;参考文档3提供了不少方法，开发者可以根据开发环境来选择，这里挑几条和C相关的方法实践下。  
### OpenBSD explicit_bzero
```
/* Set N bytes of S to 0.  The compiler will not delete a call to this
   function, even if S is dead after the call.  */
extern void explicit_bzero (void *__s, size_t __n) __THROW __nonnull ((1))
    __fortified_attr_access (__write_only__, 1, 2);
```  
### Disabling Optimization
&emsp;&emsp;这种方法虽然很保险，但是放弃了编译器的代码优化功能，代码执行效率会有降低，这个需要根据实际情况选用。  

###  Volatile Function Pointer
&emsp;&emsp;OPTEE里[memzero_explicit](https://github.com/OP-TEE/optee_os/blob/master/lib/libutils/ext/memzero_explicit.c)的implementation就用了这种方法。  
```
static volatile void * (*memset_func)(void *, int, size_t) =
	(volatile void * (*)(void *, int, size_t))&memset;

void memzero_explicit(void *s, size_t count)
{
	memset_func(s, 0, count);
}
```  
&emsp;&emsp;还有OPENSSL里[OPENSSL_cleanse](https://github.com/openssl/openssl/blob/master/crypto/mem_clr.c)的实现。  
```
typedef void *(*memset_t)(void *, int, size_t);

static volatile memset_t memset_func = memset;

void OPENSSL_cleanse(void *ptr, size_t len)
{
    memset_func(ptr, 0, len);
}
```  
### Volatile Data Pointer
&emsp;&emsp;博主把  例子中的buff申明为volatile，貌似并不起作用。  
```shell
void test_memset(void)
{
        volatile unsigned char test[] = "hello_memzero_explicit";
        unsigned int length = strlen(test);

        printf("%s\n", test);
        memset(test, 0, length);
}
```  
### Memory Barrier
&emsp;&emsp;代码改为：  
```
#define barrier_data(ptr) \
        __asm__ __volatile__("": :"r"(ptr) :"memory")

void test_memset(void)
{
        unsigned char test[] = "hello_memzero_explicit";
        unsigned int length = strlen(test);

        printf("%s\n", test);
        memset(test, 0, length);
        barrier_data(test);
}
```  
&emsp;&emsp;反汇编为：  
```
0000000000400650 <test_memset>:
  400650:       90000001        adrp    x1, 400000 <__abi_tag-0x254>
  400654:       911c6021        add     x1, x1, #0x718
  400658:       a9bc7bfd        stp     x29, x30, [sp, #-64]!
  40065c:       910003fd        mov     x29, sp
  400660:       a9400c22        ldp     x2, x3, [x1]
  400664:       f9000bf3        str     x19, [sp, #16]
  400668:       f840f021        ldur    x1, [x1, #15]
  40066c:       9100a3f3        add     x19, sp, #0x28
  400670:       a9028fe2        stp     x2, x3, [sp, #40]
  400674:       aa1303e0        mov     x0, x19
  400678:       f80373e1        stur    x1, [sp, #55]
  40067c:       97ffff9d        bl      4004f0 <puts@plt>
  400680:       a902ffff        stp     xzr, xzr, [sp, #40] //clear first 16 Bytes
  400684:       b9003bff        str     wzr, [sp, #56]      //clear 4 Bytes
  400688:       79007bff        strh    wzr, [sp, #60]      //clear 2 Bytes
  40068c:       f9400bf3        ldr     x19, [sp, #16]
  400690:       a8c47bfd        ldp     x29, x30, [sp], #64
  400694:       d65f03c0        ret
  400698:       d503201f        nop
  40069c:       d503201f        nop
```  
&emsp;&emsp;这里乍一看，没调用memset，确实没调用，但stp，str和strh几条语句把stack里分的buff清零了，strlen正好22字节。Linux里[memzero_explicit](https://github.com/torvalds/linux/blob/master/include/linux/string.h#L372)的实现用的是memory barrier的方案。  

## Performance
&emsp;&emsp;在Reference3中，作者做了详细的performance分析，主要关注Large block size情况下的performance吧。结论就是尽量使用原生的memset，不要让它被优化掉可以达到很好的performance，比如Volatile Function Pointer方式。从Linux使用的memroy barrier方式的反汇编看，它每次都尽可能把能力范围内最大的buffer清0，比如用neon一下清32Bytes，效率应该也不会差，只不过它没有用loop，博主会担心code size比较大。以下是memory barrier清buff size是161Bytes的反汇编。  
```
  4006f0:       4f000400        movi    v0.4s, #0x0
  4006f4:       3902827f        strb    wzr, [x19, #160]    // 1 Bytes
  4006f8:       ad000260        stp     q0, q0, [x19]       // 32 Bytes
  4006fc:       ad010260        stp     q0, q0, [x19, #32]  // 32 Bytes
  400700:       ad020260        stp     q0, q0, [x19, #64]  // 32 Bytes
  400704:       ad030260        stp     q0, q0, [x19, #96]  // 32 Bytes
  400708:       ad040260        stp     q0, q0, [x19, #128] // 32 Bytes
```  
&emsp;&emsp;对于small block size也一样，memset效果最好，不过size本身就小，也差不了多少。有兴趣的可以仔细读一下这个pdf。  

## Reference
[**Dead Store**](https://en.wikipedia.org/wiki/Dead_store)  
[**Dead Store Elimination**](https://cran.r-project.org/web/packages/rco/vignettes/opt-dead-store.html)  
[**Harm of DSE**](https://www.usenix.org/system/files/conference/usenixsecurity17/sec17-yang.pdf)  