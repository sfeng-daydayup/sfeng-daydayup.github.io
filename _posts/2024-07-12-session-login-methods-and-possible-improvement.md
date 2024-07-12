---
layout: post
title: Session Login Methods and Possible Improvement
author: sfeng
date: 2024-07-12 18:00 +0800
categories: [Blogging, OPTEE]
tags: [optee, security]
lang: zh
---

&emsp;&emsp;CA调用TA的secure service之前，首先要创建一个连接，这个连接叫session。由于这个连接是从REE发起的，对session的安全性有一定的担忧，比如有需求要求某个TA只服务于特定CA。OPTEE其实提供了方案，但整个代码看下来，实在是比较鸡肋。接下来先分析代码，然后看怎么改进比较合适。  

> Note：本文中引用的代码版本如下：  
> 
> OPTEE： 4.0.0  
> Linux： v5.15  
{: .prompt-tip }

&emsp;&emsp;OPTEE提供的方案叫做connection method。有以下几种：  
<https://github.com/OP-TEE/optee_client/blob/4.0.0/libteec/include/tee_client_api.h#L224>

```
/**
 * Session login methods, for use in TEEC_OpenSession() as parameter
 * connectionMethod. Type is uint32_t.
 *
 * TEEC_LOGIN_PUBLIC    	 No login data is provided.
 * TEEC_LOGIN_USER         	Login data about the user running the Client
 *                         	Application process is provided.
 * TEEC_LOGIN_GROUP        	Login data about the group running the Client
 *                         	Application process is provided.
 * TEEC_LOGIN_APPLICATION  	Login data about the running Client Application
 *                         	itself is provided.
 * TEEC_LOGIN_USER_APPLICATION  Login data about the user and the running
 *                          	Client Application itself is provided.
 * TEEC_LOGIN_GROUP_APPLICATION Login data about the group and the running
 *                          	Client Application itself is provided.
 */
#define TEEC_LOGIN_PUBLIC       0x00000000
#define TEEC_LOGIN_USER         0x00000001
#define TEEC_LOGIN_GROUP        0x00000002
#define TEEC_LOGIN_APPLICATION  0x00000004
#define TEEC_LOGIN_USER_APPLICATION  0x00000005
#define TEEC_LOGIN_GROUP_APPLICATION  0x00000006
```

&emsp;&emsp;Connection method是在open session的时候指定的。函数如下：  
<https://github.com/OP-TEE/optee_client/blob/4.0.0/libteec/include/tee_client_api.h#L468>  
  
```
  
  TEEC_Result TEEC_OpenSession(TEEC_Context *context,
                 TEEC_Session *session,
                 const TEEC_UUID *destination,
                 uint32_t connectionMethod,
                 const void *connectionData,
                 TEEC_Operation *operation,
                 uint32_t *returnOrigin);
```

&emsp;&emsp;来看这个connectionMethod传下去都做了什么处理。  
<https://github.com/OP-TEE/optee_client/blob/4.0.0/libteec/src/tee_client_api.c#L543>

```
static void setup_client_data(struct tee_ioctl_open_session_arg *arg,
			      uint32_t connection_method,
			      const void *connection_data)
{
	arg->clnt_login = connection_method;

	switch (connection_method) {
	case TEE_IOCTL_LOGIN_PUBLIC:
		/* No connection data to pass */
		break;
	case TEE_IOCTL_LOGIN_USER:
		/* Kernel auto-fills UID and forms client UUID */
		break;
	case TEE_IOCTL_LOGIN_GROUP:
		/*
		 * Connection data for group login is uint32_t and rest of
		 * clnt_uuid is set as zero.
		 *
		 * Kernel verifies group membership and then forms client UUID.
		 */
		memcpy(arg->clnt_uuid, connection_data, sizeof(gid_t));
		break;
	case TEE_IOCTL_LOGIN_APPLICATION:
		/*
		 * Kernel auto-fills application identifier and forms client
		 * UUID.
		 */
		break;
	case TEE_IOCTL_LOGIN_USER_APPLICATION:
		/*
		 * Kernel auto-fills application identifier, UID and forms
		 * client UUID.
		 */
		break;
	case TEE_IOCTL_LOGIN_GROUP_APPLICATION:
		/*
		 * Connection data for group login is uint32_t rest of
		 * clnt_uuid is set as zero.
		 *
		 * Kernel verifies group membership, auto-fills application
		 * identifier and then forms client UUID.
		 */
		memcpy(arg->clnt_uuid, connection_data, sizeof(gid_t));
		break;
	default:
		/*
		 * Unknown login method, don't pass any connection data as we
		 * don't know size.
		 */
		break;
	}
}
```  

&emsp;&emsp;这里TEE_IOCTL_LOGIN_XXXX和TEE_LOGIN_XXXX一一对应。  
&emsp;&emsp;connection method保存在arg->clnt_login里往后传。通过注释，TEE_IOCTL_LOGIN_PUBLIC是放弃security了:grin:，其他的都说kernel会form一个client UUID。其中TEE_IOCTL_LOGIN_GROUP和TEE_IOCTL_LOGIN_GROUP_APPLICATION还copy了connection_data到arg->clnt_uuid。这里比较费解，在TEEC_OpenSession对参数的注释里这样描述：  
<https://github.com/OP-TEE/optee_client/blob/4.0.0/libteec/include/tee_client_api.h#L453>

```
 * @param connectionData     Any data necessary to connect with the chosen
 *                           connection method. Not supported, should be set to
 *                           NULL.
```  

&emsp;&emsp;注释里说设成NULL，那memcpy岂不是会出错？去翻[**TEE_Client_API_Specification**](https://globalplatform.org/specs-library/tee-client-api-specification/)，这里有了正确的解释：  

```
connectionData MUST point to a uint32_t which contains the group which this Client 
Application wants to connect as. The Implementation is responsible for securely ensuring 
that the Client Application instance is actually a member of this group.
```

&emsp;&emsp;所以当connection method为TEEC_LOGIN_GROUP或TEEC_LOGIN_GROUP_APPLICATION时，connectionData不能为NULL，要指向一个32位的值，这个值包含了组信息。  
&emsp;&emsp;继续看，TEEC_OpenSession通过ioctl进入到了Linux Kernel里。Kernel在`driver/tee/tee_core.c`{: .filepath}里处理了这个ioctl。Linux给了两套处理函数，SMC ABI和FFA ABI，本文基于SMC ABI继续跟踪(取决于Linux DTS里OPTEE的method设定为smc)。这两者的区别以后有时间再写博文补课。ioctl在kernel里通过filp->private_data拿到tee_context, 获取到tee_device的desc中的ops，调用open_session函数，而这个函数指向optee_open_session(<https://github.com/torvalds/linux/blob/v5.15/drivers/tee/optee/call.c#L213>)。然后取出arg->clnt_login和arg->clnt_uuid，通过tee_session_calc_client_uuid生成client_uuid。  
<https://github.com/torvalds/linux/blob/v5.15/drivers/tee/tee_core.c#L194>  

```
int tee_session_calc_client_uuid(uuid_t *uuid, u32 connection_method,
				 const u8 connection_data[TEE_IOCTL_UUID_LEN])
{
	gid_t ns_grp = (gid_t)-1;
	kgid_t grp = INVALID_GID;
	char *name = NULL;
	int name_len;
	int rc;

	if (connection_method == TEE_IOCTL_LOGIN_PUBLIC ||
	    connection_method == TEE_IOCTL_LOGIN_REE_KERNEL) {
		/* Nil UUID to be passed to TEE environment */
		uuid_copy(uuid, &uuid_null);
		return 0;
	}

	/*
	 * In Linux environment client UUID is based on UUIDv5.
	 *
	 * Determine client UUID with following semantics for 'name':
	 *
	 * For TEEC_LOGIN_USER:
	 * uid=<uid>
	 *
	 * For TEEC_LOGIN_GROUP:
	 * gid=<gid>
	 *
	 */

	name = kzalloc(TEE_UUID_NS_NAME_SIZE, GFP_KERNEL);
	if (!name)
		return -ENOMEM;

	switch (connection_method) {
	case TEE_IOCTL_LOGIN_USER:
		name_len = snprintf(name, TEE_UUID_NS_NAME_SIZE, "uid=%x",
				    current_euid().val);
		if (name_len >= TEE_UUID_NS_NAME_SIZE) {
			rc = -E2BIG;
			goto out_free_name;
		}
		break;

	case TEE_IOCTL_LOGIN_GROUP:
		memcpy(&ns_grp, connection_data, sizeof(gid_t));
		grp = make_kgid(current_user_ns(), ns_grp);
		if (!gid_valid(grp) || !in_egroup_p(grp)) {
			rc = -EPERM;
			goto out_free_name;
		}

		name_len = snprintf(name, TEE_UUID_NS_NAME_SIZE, "gid=%x",
				    grp.val);
		if (name_len >= TEE_UUID_NS_NAME_SIZE) {
			rc = -E2BIG;
			goto out_free_name;
		}
		break;

	default:
		rc = -EINVAL;
		goto out_free_name;
	}

	rc = uuid_v5(uuid, &tee_client_uuid_ns, name, name_len);
out_free_name:
	kfree(name);

	return rc;
}
EXPORT_SYMBOL_GPL(tee_session_calc_client_uuid);
```

&emsp;&emsp;到这里忽然发现TEEC_LOGIN_APPLICATION，TEEC_LOGIN_USER_APPLICATION和TEEC_LOGIN_GROUP_APPLICATION都成default不处理了。这几个暂时还是不要用了。在TEE_IOCTL_LOGIN_USER的处理里拿到当前process的euid，而TEE_IOCTL_LOGIN_GROUP则是得到gid，把他们转换成uid=xxxx或gid=xxxx的string形式，送给uuid_v5[^uuid_v5]生成client uuid。打包在optee_msg_arg里，然后送给optee。  
>client uuid是在Linux kernel里生成的
&emsp;&emsp;中间经过secure monitor，world switch，optee std_smc_entry->std_entry_with_parg->call_entry_std->tee_entry_std->__tee_entry_std->entry_open_session这里就不细分析了。直接看client_uuid的处理。  
<https://github.com/OP-TEE/optee_os/blob/4.0.0/core/tee/entry_std.c#L315>

```
	tee_uuid_from_octets(uuid, (void *)&params[0].u.value);
	clnt_id->login = params[1].u.value.c;
	switch (clnt_id->login) {
	case TEE_LOGIN_PUBLIC:
	case TEE_LOGIN_REE_KERNEL:
		memset(&clnt_id->uuid, 0, sizeof(clnt_id->uuid));
		break;
	case TEE_LOGIN_USER:
	case TEE_LOGIN_GROUP:
	case TEE_LOGIN_APPLICATION:
	case TEE_LOGIN_APPLICATION_USER:
	case TEE_LOGIN_APPLICATION_GROUP:
		tee_uuid_from_octets(&clnt_id->uuid,
				     (void *)&params[1].u.value);
		break;
	default:
		return TEE_ERROR_BAD_PARAMETERS;
	}
```  

&emsp;&emsp;很直接，copy在TEE_Identity clnt_id里。然后在tee_ta_open_session里把它保存在TA session的数据结构里。  
<https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/tee_ta_manager.c#L677>  

```
....
struct tee_ta_session *s = NULL;
....
res = tee_ta_init_session(err, open_sessions, uuid, &s);
....
/* Save identity of the owner of the session */
s->clnt_id = *clnt_id;
```  

&emsp;&emsp;对于TEE_Identity clnt_id的应用，我们从OPTEE回溯到Linux和CA来看，为什么反着看，一会自然明白。  
&emsp;&emsp;OPTEE定义了一个function叫做check_client来检查client id(uuid)是否匹配。link放在下面，代码就不copy了。  
<https://github.com/OP-TEE/optee_os/blob/4.0.0/core/kernel/tee_ta_manager.c#L349>  

&emsp;&emsp;这个函数分别在tee_ta_invoke_command，tee_ta_cancel_command和tee_ta_close_session里调用。嗯，看到这里还不错，该有的检查都有。继续回溯，看作比较的两个值都从哪里得来。不看TA，只看从REE调用过来的function。三个函数的路径分别是(反着来)：  

```
tee_ta_invoke_command<-entry_invoke_command<-__tee_entry_std<-tee_entry_std<-call_entry_std<-std_entry_with_parg<-std_smc_entry<-__thread_std_smc_entry

tee_ta_cancel_command<-entry_cancel<-__tee_entry_std (the following is the same)

tee_ta_close_session<-entry_close_session<-__tee_entry_std (the following is the same)
```  

&emsp;&emsp;然而忽然发现TEE_Identity *clnt_id这个参数统一设为NSAPP_IDENTITY，即为NULL，并且在check_client函数里，NULL的情况竟然返回TEE_SUCCESS。真是大失所望！！！  

```
if (id == NSAPP_IDENTITY) {
	if (s->clnt_id.login == TEE_LOGIN_TRUSTED_APP) {
		DMSG("nsec tries to hijack TA session");
		return TEE_ERROR_ACCESS_DENIED;
	}
	return TEE_SUCCESS;
}
```

&emsp;&emsp;再去Linux Kernel里，发现uuid v5只有open session的时候调用了。然后就没了......。这......。  

&emsp;&emsp;在进行改造之前，首先明确需求，就是在第一次open session完成后，只允许该process或者该process所属group中所有的process和TA进行通讯。鉴于基本的结构已经有了，改进方法也比较简单。  
1. OPTEE OS中把TEE_Identity存在instance的ctx里，而非session里，这样multiple session的TA从ctx的TEE_Identity得到验证。
2. 如果是multiple session，此后再次open session应该用同样的connection method。OPTEE OS端如果已经有ctx存在，验证本次传过来的client uuid是否正确。不正确返回失败。
3. connection method应保存在session数据结构中。
4. invoke, cancel, close操作在Linux Kernel中同样需要根据session中method生成client uuid。OPTEE OS对该操作验证TEE_Identity。不成功返回失败。

### Reference：

[**Optee Client**](https://github.com/OP-TEE/optee_client)  
[**Optee OS**](https://github.com/OP-TEE/optee_os)  
[**Linux v5.4**](https://github.com/torvalds/linux/tree/v5.4)  
[**TEE_Client_API_Specification**](https://globalplatform.org/specs-library/tee-client-api-specification/)  


### Note：
[^uuid_v5]: UUID type5。Do SHA1 hash first and output a 20 bytes digest. Keep the first 16 bytes. Change the high-nibble of byte 6 to 5 and set upper two bits of byte 8 to 0b10.