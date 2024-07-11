---
layout: post
title: How to Develop a TA
author: sfeng
date: 2024-07-10 16:25 +0800
categories: [Blogging, OPTEE]
tags: [optee, ta]
lang: zh
---
&emsp;&emsp;OPTEE OS提供TEE相关基础设施，TA(Trusted Application)则是Security需求具体实现的载体。如[**OPTEE Overview**](https://sfeng-daydayup.github.io/posts/optee-overview/)图中所示，OPTEE OS运行在Secure EL1，而TA则运行Secure EL0，ARM在TEE端和REE端(Linux OS运行在Kernel Space，Application运行在User Space)保持了一样的设计。关于TA的开发，OPTEE官方也提供了比较详细的文档，可以对照[**Trusted Applications**](https://optee.readthedocs.io/en/latest/building/trusted_applications.html)来看本篇博文，另外github上也有example来供大家参考（[**Hello World**](https://github.com/linaro-swg/hello_world/tree/master/ta)）。另外这里主要讲User TA。  
&emsp;&emsp;一个TA至少包含以下四个文件：  
- Makefile
  ```
  # log level from 0 - 4
  # 0: none; 1: error (EMSG); 2: info (IMSG); 3: debug (DMSG); 4: flow (FMSG)
  CFG_TEE_TA_LOG_LEVEL ?= 4
  CPPFLAGS += -DCFG_TEE_TA_LOG_LEVEL=$(CFG_TEE_TA_LOG_LEVEL)
  
  # Binary name shall be the UUID of the Trusted Application
  BINARY=8aaaf200-2450-11e4-abe2-0002a5d5c51b
  
  # TA_DEV_KIT_DIR shall be set as the dir of OPTEE TA development kit
  -include $(TA_DEV_KIT_DIR)/mk/ta_dev_kit.mk
  
  ifeq ($(wildcard $(TA_DEV_KIT_DIR)/mk/ta_dev_kit.mk), )
  clean:
  	@echo 'Note: $$(TA_DEV_KIT_DIR)/mk/ta_dev_kit.mk not found, cannot clean TA'
    @echo 'Note: TA_DEV_KIT_DIR=$(TA_DEV_KIT_DIR)'
    endif
  ```
- user_ta_header_defines.h
  ```
  #ifndef USER_TA_HEADER_DEFINES_H
  #define USER_TA_HEADER_DEFINES_H
  
  /* better to expose this head file to CA too so both TA and CA can get
   * UUID from it
   */
  #include <hello_world_ta.h> /* To get the TA_HELLO_WORLD_UUID define */
  
  #define TA_UUID TA_HELLO_WORLD_UUID
  
  /*
   * TA FLAGS:
   * TA_FLAG_SINGLE_INSTANCE: declare a single instance TA.
   * TA_FLAG_MULTI_SESSION: TA can have multiple session. It only is only applied
   *                        when TA is set to single instance.
   * TA_FLAG_INSTANCE_KEEP_ALIVE: still keep alive if no session is connected. Only
   *                        available when TA_FLAG_SINGLE_INSTANCE is set.
   * TA_FLAG_SECURE_DATA_PATH: it only takes effect when CFG_SECURE_DATA_PATH is set to y.
   * TA_FLAG_CACHE_MAINTENANCE: determine if TA can do cache maintainance operation.
   */
  #define TA_FLAGS                    (TA_FLAG_MULTI_SESSION | TA_FLAG_EXEC_DDR)
  /* the size of stack of a TA instance */
  #define TA_STACK_SIZE               (2 * 1024)
  /* the size of heap of a TA instance */
  #define TA_DATA_SIZE                (32 * 1024)
  
  /* set the externed TA properties and name must not start with gpd. */
  #define TA_CURRENT_TA_EXT_PROPERTIES \
      { "gp.ta.description", USER_TA_PROP_TYPE_STRING, \
        "Hello World TA" }, \
      { "gp.ta.version", USER_TA_PROP_TYPE_U32, &(const uint32_t){ 0x0010 } }
  #endif /*USER_TA_HEADER_DEFINES_H*/
  ```
- sub.mk
  ```
  #include path of header file
  global-incdirs-y += include
  #global-incdirs-y += ../host/include

  #add all source files into compile. here only one
  srcs-y += hello_world_ta.c
  
  # To remove a certain compiler flag, add a line like this
  #cflags-template_ta.c-y += -Wno-strict-prototypes
  ```
- [TA entry file].c
  ```
  /* TA entry points must be implemented */

  /* be called when an instance is created */
  TEE_Result TA_CreateEntryPoint(void) {}

  /* be called when an instance is destroied */
  void TA_DestroyEntryPoint(void) {}

  /* be called when a session is created */
  TEE_Result TA_OpenSessionEntryPoint(uint32_t param_types,
		TEE_Param __maybe_unused params[4],
		void __maybe_unused **sess_ctx)
  {return TEE_SUCCESS;}

  /* be called when a session is disconnected */
  void TA_CloseSessionEntryPoint(void __maybe_unused *sess_ctx) {}

  /* main function to handle user defined commands */
  TEE_Result TA_InvokeCommandEntryPoint(void __maybe_unused *sess_ctx,
			uint32_t cmd_id,
			uint32_t param_types, TEE_Param params[4])
  {return TEE_ERROR_BAD_PARAMETERS;}
  ```
&emsp;&emsp;上面就是开发一个TA必须要实现的4个文件，前三个名字是固定的，第四个开发者可以自己命名，最终体现在sub.mk里。这里需要注意的点还挺多的。  
## UUID
{: data-toc-skip='' .mt-4 .mb-0 }
&emsp;&emsp;UUID是TEE OS用来identify TA的唯一字段。在OPTEE里，从load TA，create instance到opensession，都需要用到UUID。在TA的四个文件里两个地方需要设置UUID。一个是Makefile里，用来命名生成的TA binary，拿hello world例子中UUID为例，生成的ta为**8aaaf200-2450-11e4-abe2-0002a5d5c51b.ta**。另一个是user_ta_header_defines.h，用于赋值ta head里的字段。  
&emsp;&emsp;关于UUID的生成，OPTEE官方文档给了几种方法，可以翻看[**TA Properties**](https://optee.readthedocs.io/en/latest/building/trusted_applications.html#ta-properties)这个章节。  

## TA_FLAGS
{: data-toc-skip='' .mt-4 .mb-0 }
&emsp;&emsp;TA_FLAGS的值对User TA的行为影响很大，上面加了些注释，这里还是与代码对照一下(依然以4.0.0为准)。  
&emsp;&emsp;第一次open session的时候，OPTEE OS会根据TA的类型来load TA并创建该TA的instance和context(这个时候context里有个变量叫ref_count会设为1)，这个过程并不受这些flag的影响。第二次open session的时候，首先会根据UUID找到之前创建的context，再之后的过程就要受TA_FLAG制约了。  
- TA_FLAG_SINGLE_INSTANCE  
  &emsp;&emsp;这个flag不设的话，该TA就是一个Multiple Instance TA，在tee_ta_init_session_with_context这个function里会返回TEE_ERROR_ITEM_NOT_FOUND。注意了，这个时候OPTEE OS会重新load这个TA的binary去创建一个新的instance和context。新的instance拥有独立的text, rodata, data, bss, stack和heap。也就是open session几次，它就占用这些空间几份。这对tee内存的消耗是巨大的，所以使用multiple instance TA的时候要特别注意memory的使用情况。  
  <https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/tee_ta_manager.c#L556>

  ```
    /*
	 * If TA isn't single instance it should be loaded as new
	 * instance instead of doing anything with this instance.
	 * So tell the caller that we didn't find the TA it the
	 * caller will load a new instance.
	 */
	if ((ctx->flags & TA_FLAG_SINGLE_INSTANCE) == 0)
		return TEE_ERROR_ITEM_NOT_FOUND;
  ```  
  &emsp;&emsp;那么设了这个flag，这个TA就是single instance的TA了，这就涉及到下面两个flag了。  
- TA_FLAG_MULTI_SESSION  
  &emsp;&emsp;继续看tee_ta_init_session_with_context这个function。  
  <https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/tee_ta_manager.c#L563>

  ```
  /*
	 * The TA is single instance, if it isn't multi session we
	 * can't create another session unless its reference is zero
	 */
	if (!(ctx->flags & TA_FLAG_MULTI_SESSION) && ctx->ref_count)
		return TEE_ERROR_BUSY;
    DMSG("Re-open TA %pUl", (void *)&ctx->ts_ctx.uuid);

	ctx->ref_count++;
	s->ts_sess.ctx = &ctx->ts_ctx;
	s->ts_sess.handle_scall = s->ts_sess.ctx->ops->handle_scall;
	return TEE_SUCCESS;
  ```  
  &emsp;&emsp;OPTEE首先check TA的flag是否是TA_FLAG_MULTI_SESSION。是的话ref_count++，并把找到的该TA的ctx赋值给本session。如果是single session，ref_count为0的话(这里注意ref_count什么情况下为0)，也继续走下去；ref_count不为0，表示已经有session存在，就不能open一个新的session了。  
  &emsp;&emsp;这里讲个事，linaro官方给的例子竟然出现了差错。具体位置在这里<https://github.com/linaro-swg/hello_world/blob/master/ta/user_ta_header_defines.h#L39>。例子里没有设TA_FLAG_SINGLE_INSTANCE这个flag说明TA是multiple instance的，那么单独设TA_FLAG_MULTI_SESSION是没有意义的。  
  ```
  #define TA_FLAGS                    (TA_FLAG_MULTI_SESSION | TA_FLAG_EXEC_DDR)
  ```  
- TA_FLAG_INSTANCE_KEEP_ALIVE  
  &emsp;&emsp;TA_FLAG_MULTI_SESSION是在open session的时候影响OPTEE的行为。而TA_FLAG_INSTANCE_KEEP_ALIVE则是在close session的时候起作用。直接上代码：  
  <https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/tee_ta_manager.c#L512>

  ```
  ctx->ref_count--;
	keep_alive = (ctx->flags & TA_FLAG_INSTANCE_KEEP_ALIVE) &&
			(ctx->flags & TA_FLAG_SINGLE_INSTANCE);
	if (!ctx->ref_count && (ctx->panicked || !keep_alive)) {
		if (!ctx->is_releasing) {
			TAILQ_REMOVE(&tee_ctxes, ctx, link);
			ctx->is_releasing = true;
		}
		mutex_unlock(&tee_ta_mutex);

		destroy_context(ctx);
	} else
		mutex_unlock(&tee_ta_mutex);
  ```  
  &emsp;&emsp;close session首先是把ref_count--。keep_alive这个值取决于两个flag，TA_FLAG_INSTANCE_KEEP_ALIVE和TA_FLAG_SINGLE_INSTANCE，两个有一个没有设则keep_alive既为false。  
  &emsp;&emsp;先说multiple instance的情况(TA_FLAG_SINGLE_INSTANCE没有设)，keep_alive一定为false，创建instance的时候ref_count设为1，multiple instance的TA每个instance只能对应一个session(如上解释，再次open session会新建一个instance)。ref_count--后其值为0.这样以下条件为true，destroy_context(ctx)被调用，该instance被destroy。

  ```
  if (!ctx->ref_count && (ctx->panicked || !keep_alive)) {
  ```  
  &emsp;&emsp;TA_FLAG_SINGLE_INSTANCE设了的情况下，keep_alive的值取决于TA_FLAG_INSTANCE_KEEP_ALIVE。如果设了，即便ref_count为0，keep_alive为true也不会进入if里面(不考虑panic的情况)，这是虽然ref_count减为0，TA的instance和context还能保住。  
  &emsp;&emsp;相反，没有设这个flag，keep_alive为false，就要看ref_count也就是还在open的session个数了，最后一个session close的时候，就是instance和context挂掉的时候。下次再open session会是一个全新的instance和context，context里所有的内容恢复为默认值。  

&emsp;&emsp;TA_FLAG_SECURE_DATA_PATH和TA_FLAG_CACHE_MAINTENANCE比较简单，前一个决定TA是否参与Secure Data Path，既能否访问定义为Secure Data的memory；后一个决定TA是否可以进行cache的flush，clean和invalidate，主要用于协调不在同一个cache coherent domain的master之间的数据访问。  

## TA Entry Points
{: data-toc-skip='' .mt-4 .mb-0 }
&emsp;&emsp;总共五个必须实现的entry point，前四个不必多讲，TA_InvokeCommandEntryPoint是日常CA请求TA的secure service的入口函数。Linaro的example给了很好的模板，开发者定义自己的command ID和相应处理函数，按模板填入即可。  
<https://github.com/linaro-swg/hello_world/blob/master/ta/hello_world_ta.c#L118>

```
TEE_Result TA_InvokeCommandEntryPoint(void __maybe_unused *sess_ctx,
			uint32_t cmd_id,
			uint32_t param_types, TEE_Param params[4])
{
	(void)&sess_ctx; /* Unused parameter */

	switch (cmd_id) {
	case TA_HELLO_WORLD_CMD_INC_VALUE:
		return inc_value(param_types, params);
#if 0
	case TA_HELLO_WORLD_CMD_XXX:
		return ...
		break;
	case TA_HELLO_WORLD_CMD_YYY:
		return ...
		break;
	case TA_HELLO_WORLD_CMD_ZZZ:
		return ...
		break;
	...
#endif
	default:
		return TEE_ERROR_BAD_PARAMETERS;
	}
}
```

## TEE Internal APIs
{: data-toc-skip='' .mt-4 .mb-0 }
&emsp;&emsp;前面有提过TA通过syscall来请求OPTEE OS提供的服务，而这些standard服务基本上上包装在GPD定义的TEE Internal API里。有以下几类：  
- Trusted Core Framework API  
  TEE_Malloc , TEE_Free, TEE_Panic, TEE_OpenTASession, TEE_InvokeTACommand, TEE_CloseTASession  
- Trusted Storage API for Data and Keys  
  TEE_CreatePersistentObject, TEE_OpenPersistentObject, TEE_ReadObjectData, TEE_WriteObjectData  
- Cryptographic Operations API  
  message digest, symmetric cipher, MAC, Authenticated encryption, asymmetric cipher, key derivation and RNG  
- Time API  
  TEE_Wait, TEE_GetSystemTime, TEE_GetREETime
- TEE Arithmetical API  
  TEE_BigIntConvertFromOctetString

&emsp;&emsp;这里列了一些主要函数，具体用法参看[**TEE Internal Core API Specification v1.3.1**](https://globalplatform.org/specs-library/tee-internal-core-api-specification/)。  

好了，又总结了一篇，开心。  

## References:
{: data-toc-skip='' .mt-4 .mb-0 }
[**Trusted Applications**](https://optee.readthedocs.io/en/latest/building/trusted_applications.html)  
[**Hello World**](https://github.com/linaro-swg/hello_world/tree/master/ta)  
[**TEE Internal Core API Specification v1.3.1**](https://globalplatform.org/specs-library/tee-internal-core-api-specification/)