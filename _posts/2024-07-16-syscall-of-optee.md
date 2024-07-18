---
layout: post
title: Syscall of OPTEE
date: 2024-07-16 18:19 +0800
author: sfeng
categories: [Blogging, GIT]
tags: [git]
lang: zh
---

## Preface
&emsp;&emsp;大家都知道Linux User Space调用Kernel Space的function需要用到Syscall，其实在Secure World也是一样。今天就追踪下TA是如何调用OPTEE OS的function的。  

> 注：因为博主用到的SoC都是基于ARM特别是ARMv8架构的，没有特别说明的话，博文也是基于ARMv8来做的解释和总结。比如这里Linux User Space运行的Exception Level为Non-Secure EL0, Linux Kernel Space运行在Non-Secure EL1，TA在Secure EL0和OPTEE OS在Secure EL1。  
> 另外，OPTEE version用的是4.0.0。
{: .prompt-info }

## Syscall Invoke Path
&emsp;&emsp;OPTEE的TA是遵循GPD的TEE Internal Core API来调用OPTEE OS的function。这些API定义在[**tee_internal_api.h**](https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/include/tee_internal_api.h)中，这些API会放在libutee.a中link到每个TA里。今天就选用其中的一个来追踪。  

```sass
void TEE_Panic(TEE_Result panicCode);
```
{: file='https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/include/tee_internal_api.h#L71'}

&emsp;&emsp;TEE_Panic的实现在这里：  
<https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/tee_api_panic.c#L22>

```
void TEE_Panic(TEE_Result panicCode)
{
	_utee_panic(panicCode);
#ifdef __COVERITY__
	__coverity_panic__();
#endif
}
```

&emsp;&emsp;找_utee_panic。还在libutee目录下。  
<https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/arch/arm/utee_syscalls_a64.S#L40>

```
	FUNC _utee_panic, :
	stp	x29, x30, [sp, #-16]!
	mov	x1, sp
	bl	__utee_panic
	/* Not reached */
	END_FUNC _utee_panic
```

&emsp;&emsp;继续找_utee_panic。只在一个头文件里找到。  
<https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/include/utee_syscalls_asm.S#L12>

```
UTEE_SYSCALL __utee_panic, TEE_SCN_PANIC, 2
```

&emsp;&emsp;TEE_SCN_PANIC和其他所有的syscall number都定义在[**tee_syscall_numbers.h**](https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/include/tee_syscall_numbers.h)里。这个number会用做index在tee_syscall_table里查找最终的调用函数。tee_syscall_table定义在[**scall.c**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/scall.c#L51)里。  

&emsp;&emsp;查找宏UTEE_SYSCALL。  
<https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/arch/arm/utee_syscalls_a64.S#L11>

```
        .macro UTEE_SYSCALL name, scn, num_args
	FUNC \name , :              /* define a function named "name" */

	.if \num_args > TEE_SVC_MAX_ARGS || \num_args > 8
	.error "Too many arguments for syscall"
	.endif                      /* check the number of args */
#if defined(CFG_SYSCALL_WRAPPERS_MCOUNT) && !defined(__LDELF__)
    /* ths part of code is used if developer want to display call graph profile data */
	.if \scn != TEE_SCN_RETURN
	stp	x29, x30, [sp, #-80]!
	mov	x29, sp
	stp	x0, x1, [sp, #16]
	stp	x2, x3, [sp, #32]
	stp	x4, x5, [sp, #48]
	stp	x6, x7, [sp, #64]
	mov	x0, x30
	bl	_mcount
	ldp	x0, x1, [sp, #16]
	ldp	x2, x3, [sp, #32]
	ldp	x4, x5, [sp, #48]
	ldp	x6, x7, [sp, #64]
	ldp	x29, x30, [sp], #80
	.endif
#endif
    mov     x8, #(\scn)    /* set syscall number to x8 */
    svc #0                 /* do supervisor call */
    ret
    END_FUNC \name
    .endm
```

&emsp;&emsp;通过对上面宏的解析知道，最终定义了一个function，把syscall number赋值给x8后调用svc进入到exception handler里。中间一堆代码暂时不理，它是做debug用的，后续有时间研究。  
&emsp;&emsp;OPTEE exception handler入口函数是从函数[**get_excp_vect**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/kernel/thread.c#L694)拿到的，这些入口函数基本定义在[**thread_a64.S**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/kernel/thread_a64.S)。

&emsp;&emsp;32位TA和64位TA的svc处理函数入口offset会不一样，但殊途同归，最终汇聚到了一个function el0_svc里。  
- [el0_sync_a64_finish](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/kernel/thread_a64.S#L685）  
  
  ```
  el0_sync_a64_finish:
	mrs	x2, esr_el1
	mrs	x3, sp_el0
	lsr	x2, x2, #ESR_EC_SHIFT
	cmp	x2, #ESR_EC_AARCH64_SVC
	b.eq	el0_svc
	b	el0_sync_abort
  ```

- [el0_sync_a32_finish](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/kernel/thread_a64.S#L693)  
  
  ```
  el0_sync_a32_finish:
	mrs	x2, esr_el1
	mrs	x3, sp_el0
	lsr	x2, x2, #ESR_EC_SHIFT
	cmp	x2, #ESR_EC_AARCH32_SVC
	b.eq	el0_svc
	b	el0_sync_abort
  ```

&emsp;&emsp;后续的调用路径为：el0_svc -> thread_scall_handler -> sess->handle_scall -> scall_handle_user_ta(user ta syscall handler) -> get_tee_syscall_func。最终找到前面提到的[**tee_syscall_table**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/scall.c#L51)中的function，调用[**scall_do_call**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/kernel/arch_scall_a64.S#L33)准备好参数，call syscall的function和拿到return value(如果有)。之后一路返回到svc exception handler里，最终[**eret_to_el0**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/arch/arm/kernel/thread_a64.S#L1108)，返回function __utee_panic中(EL0)。整个syscall过程就结束了。  

## Add a new Syscall
&emsp;&emsp;Developer如果想加自己的syscall，请follow下面的步骤：  
- 在OPTEE中实现自己的syscall function(.c 和 .h)并加入编译，这里假设function名字叫做syscall_test。  
  
  ```sass
  TEE_Result syscall_test(uint32_t value);
  ```
  {: file='syscall_test.h'}

  ```sass
  TEE_Result syscall_test(uint32_t value)
  {
      DMSG("get value %d\n", value);
  }
  ```
  {: file='syscall_test.c'}

- 在[**tee_syscall_numbers.h**](https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/include/tee_syscall_numbers.h)中定义syscall number，注意不能重复，同时记得更新TEE_SCN_MAX。  
  
  ~~#define TEE_SCN_MAX	70~~
  ```
  #define TEE_SCN_TEST	71
  #define TEE_SCN_MAX	71
  ```
 
- 在[**tee_syscall_table**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/scall.c#L51)相应的位置(对应syscall number)添加该函数。  
  
  ```
  static const struct syscall_entry tee_syscall_table[] = {
      ......
      SYSCALL_ENTRY(syscall_test),
  };
  ```

- 在[**utee_syscalls_asm.S**](https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/include/utee_syscalls_asm.S)中用UTEE_SYSCALL定义调用函数，并把函数原型定义在[**utee_syscalls.h**](https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/include/utee_syscalls.h)中。
  
  ```
  UTEE_SYSCALL _utee_test, TEE_SCN_TEST, 1
  ```

  ```
  TEE_Result _utee_test(uint32_t value);
  ```

## Reference

[**OPTEE OS Source Code**](https://github.com/OP-TEE/optee_os/tree/4.0.0)  
[**OPTEE Doc**](https://optee.readthedocs.io/en/latest/architecture/core.html)