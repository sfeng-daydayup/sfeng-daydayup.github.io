---
layout: post
title: Plugin of TEE-Supplicant
date: 2024-10-01 11:30 +0800
author: sfeng
categories: [OPTEE]
tags: [optee, tee-supplicant]
lang: zh
---

## Preface
&emsp;&emsp;OPTEE（TEE OS）在某种程度上可以认为是REE OS在TEE环境下的投影，REE OS来统筹安排non-secure resources，而OPTEE来管理secure-resources。当然TEE OS有权限去access non-secure的resources，但两个OS之间如果没有一些同步机制（hardware or software），都去访问同一个资源，必然会产生问题。另外，秉持TEE只提供security相关的service，代码越少，提供的服务越少，则安全性越好，如果可以在REE world做的，那就应该在REE端做，在硬件设计的时候也要呼应这一需求，毕竟软件是run在硬件基础上的。为了调用REE端的service，OPTEE提供了rpc机制从TEE回到REE side，然后由Linux Kernel或者TEE-supplicant来完成相应的回调需求。TA通过调用GPD internal APIs，然后rpc回到REE完成回调。Kernel和TEE-supplicant提供了一些common的[**RPC Command**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/include/optee_rpc_cmd.h)，如果TEE端需要的功能不在列表里，应该怎么办呢？这里就要用到plugin了。  

## Main Implementation
&emsp;&emsp;plugin功能实现比较简单，主要有以下几个点。  
### System PTA
&emsp;&emsp;与TA调用GPD internal API（实际上是syscall）不同的是，TA调用plugin function要通过system pta的[**PTA_SYSTEM_SUPP_PLUGIN_INVOKE**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/pta/system.c#L393) command。  
```
static TEE_Result system_supp_plugin_invoke(uint32_t param_types,
					    TEE_Param params[TEE_NUM_PARAMS])
{
	uint32_t exp_pt = TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
					  TEE_PARAM_TYPE_VALUE_INPUT,
					  TEE_PARAM_TYPE_MEMREF_INOUT,
					  TEE_PARAM_TYPE_VALUE_OUTPUT);
	TEE_Result res = TEE_ERROR_GENERIC;
	size_t outlen = 0;
	TEE_UUID uuid = { };

	if (exp_pt != param_types)
		return TEE_ERROR_BAD_PARAMETERS;

	if (!params[0].memref.buffer || params[0].memref.size != sizeof(uuid))
		return TEE_ERROR_BAD_PARAMETERS;

	res = copy_from_user(&uuid, params[0].memref.buffer, sizeof(uuid));
	if (res)
		return res;

	res = tee_invoke_supp_plugin_rpc(&uuid,
					 params[1].value.a, /* cmd */
					 params[1].value.b, /* sub_cmd */
					 NULL,
					 params[2].memref.buffer, /* data */
					 params[2].memref.size, /* in len */
					 &outlen);
	params[3].value.a = (uint32_t)outlen;

	return res;
}
```  
&emsp;&emsp;system PTA则调用[**tee_invoke_supp_plugin_rpc**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/tee/tee_supp_plugin_rpc.c#L19)返回REE。实际上最终还是OPTEE的RPC机制，使用的RPC command为OPTEE_RPC_CMD_SUPP_PLUGIN。最终转发给TEE-Supplicant的Plugin模块处理。  
&emsp;&emsp;另外system PTA由宏CFG_SYSTEM_PTA控制是否enable，一般是默认打开的。  

### Plugin Module of TEE-supplicant
&emsp;&emsp;Plugin Module也是由一个宏CFG_TEE_SUPP_PLUGINS控制，默认也是打开的。主要实现在[**plugin.c**](https://github.com/OP-TEE/optee_client/blob/4.0.0/tee-supplicant/src/plugin.c)里。主要包含两个函数：  
1. [plugin_load_all](https://github.com/OP-TEE/optee_client/blob/4.0.0/tee-supplicant/src/plugin.c#L110)  
   &emsp;&emsp;该函数从文件系统指定目录中（默认路径在/usr/lib/tee-supplicant/plugins/）把所有的plugin.so（命名为UUID）都用dl load进来并在一个链表里以供查找。如果该plugin有init函数，就调用该函数做初始化。  

2. [plugin_process](https://github.com/OP-TEE/optee_client/blob/4.0.0/tee-supplicant/src/plugin.c#L185)  
   &emsp;&emsp;当TEE-Supplicant收到由kernel转发过来的plugin RPC请求，根据UUID找到plugin，并调用invoke函数。  

### Implementation of Custom Command
&emsp;&emsp;如上所说，plugin其实是一个动态链接库，由TEE-supplicant在启动时调用plugin_load_all函数load进来。它的开发要遵循一定的规则。  
1. 分配一个UUID给该plugin，生成的.so要以UUID命名
2. 申明struct plugin_method。该结构定义如下：
   ```
   struct plugin_method {
   	const char *name; /* short friendly name of the plugin */
   	TEEC_UUID uuid;
   	TEEC_Result (*init)(void);
   	TEEC_Result (*invoke)(unsigned int cmd, unsigned int sub_cmd,
   			      void *data, size_t in_len, size_t *out_len);
   };
   ```  
3. 实现init函数（如果需要的话）
4. 实现invoke函数（必须实现）
   
   invoke函数解析cmd和sub_cmd，并实现相应的处理函数。  

## How to Use Plugin
&emsp;&emsp;Plugin主要用于TA，OPTEE为此在[tee_internal_api_extensions.h](https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/include/tee_internal_api_extensions.h#L77)实现了以下函数：  
```
/*
 * tee_invoke_supp_plugin() - invoke a tee-supplicant's plugin
 * @uuid:       uuid of the plugin
 * @cmd:        command for the plugin
 * @sub_cmd:    subcommand for the plugin
 * @buf:        data [for/from] the plugin [in/out]
 * @len:        length of the input buf
 * @outlen:     pointer to length of the output data (if they will be used)
 *
 * Return TEE_SUCCESS on success or TEE_ERRROR_* on failure.
 */
TEE_Result tee_invoke_supp_plugin(const TEE_UUID *uuid, uint32_t cmd,
				  uint32_t sub_cmd, void *buf, size_t len,
				  size_t *outlen);
```  
&emsp;&emsp;该函数被link进libutee中，TA可以直接调用。如前所述，这里并没有用syscall的方式，而是通过TEE_OpenTAsession和TEE_InvokeTACommand调用system PTA来完成。具体参看[lib/libutee/tee_system_pta.c](https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/tee_system_pta.c#L81)的实现。  

## Reference
[**Loadable plugins framework**](https://optee.readthedocs.io/en/latest/architecture/globalplatform_api.html#loadable-plugins-framework)  
[**OPTEE Example - Plugin**](https://github.com/linaro-swg/optee_examples/tree/master/plugins)  
[**Loadable plugins in tee-supplicant**](https://github.com/OP-TEE/optee_client/issues/219)  