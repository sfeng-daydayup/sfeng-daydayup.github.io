---
layout: post
title: How to Check Memory Usage of OPTEE
date: 2024-09-03 18:22 +0800
author: sfeng
categories: [Blogging, OPTEE]
tags: [optee, memory]
lang: zh
---
## Preface
&emsp;&emsp;memory的使用和调试对各种系统都是个大话题，比如近期关于Rust for Linux项目内讧的新闻就引起了博主对Rust的兴趣。而Rust的内存安全特性也是为了帮助开发者避免因为内存问题出现安全漏洞。OPTEE虽然也有用Rust去开发User TA，但和Linux一样，都在尝试阶段。目前主流还是用c来实现Kernel和User TA，这篇主要看怎么查看OPTEE里的memory的使用情况。  

> OPTEE version: 4.0.0。
> 本文中log和数据均为QEMU模拟环境中得到。
{: .prompt-info }

## Content
### Underlying Implementation
&emsp;&emsp;OPTEE里memory allocator的底层实现用了BGET这个开源代码，它的实现最早可以追溯到1972年，够古老吧，但直到今天还在用，也确实好用。想当初自己吭哧吭哧实现了一个memory allocator，如果有如果，应该先看看开源代码的实现 ^V^。  
&emsp;&emsp;BGET实现的基本函数如下：  
```
/*  BPOOL  --  Add a region of memory to the buffer pool.  */
void bpool(void *buffer, bufsize len);
/*  BGET  --  Allocate a buffer.  */
void *bget(bufsize size);
/*  BGETZ  --  Allocate a buffer and clear its contents to zero.  We clear
	       the  entire  contents  of  the buffer to zero, not just the
	       region requested by the caller. */
void *bgetz(bufsize size);
/*  BGETR  --  Reallocate a buffer.  This is a minimal implementation,
	       simply in terms of brel()  and  bget().	 It  could  be
	       enhanced to allow the buffer to grow into adjacent free
	       blocks and to avoid moving data unnecessarily.  */
void *bgetr(void *buffer, bufsize newsize);
/*  BREL  --  Release a buffer.  */
void brel(void *buf);
```  
&emsp;&emsp;分配策略方面提供了两个选项分别是First Fit（default）和Best Fit，其中Best Fit只建议用在memory非常有限的情况下，而First Fit可以提供很好的性能。  

&emsp;&emsp;除了这些基本函数，还有一些扩展功能：  
```
#define BufDump     1		      /* Define this symbol to enable the
					 bpoold() function which dumps the
					 buffers in a buffer pool. */
#define BufValid    1		      /* Define this symbol to enable the
					 bpoolv() function for validating
					 a buffer pool. */ 
#define DumpData    1		      /* Define this symbol to enable the
					 bufdump() function which allows
					 dumping the contents of an allocated
					 or free buffer. */
#define BufStats    1		      /* Define this symbol to enable the
					 bstats() function which calculates
					 the total free space in the buffer
					 pool, the largest available
					 buffer, and the total space
					 currently allocated. */
```  
&emsp;&emsp;还有一些高级功能，不过今天主要聊下BufStats这个功能。它在runtime统计以下信息(不讨论BECtl enable的情况)：  
1. current allocated buffer  
   当前分出去多少bytes的buffer。这个数值会在bget和brel的时候进行加减  
2. max allocated buffer  
   目前为止分出的buffer的峰值是多少bytes。比较当前总共分配的buffer大小和曾经记录的最大值，大则覆盖原最大值。  
3. number of bget calls  
   调用过多少次bget。  
4. number of brel calls  
   调用过多少次brel。  
&emsp;&emsp;当然pool里总共有多少memory这个信息本来就存在poolset的结构里。  

### BGET Used in OPTEE
&emsp;&emsp;OPTEE在[bget_mallloc.c](https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutils/isoc/bget_malloc.c)里把BGET包装了一层。并用一个结构struct malloc_stats来保存这些信息，也多了几项统计信息。  
```
struct malloc_stats {
	char desc[TEE_ALLOCATOR_DESC_LENGTH];
	uint32_t allocated;               /* Bytes currently allocated */
	uint32_t max_allocated;           /* Tracks max value of allocated */
	uint32_t size;                    /* Total size for this allocator */
	uint32_t num_alloc_fail;          /* Number of failed alloc requests */
	uint32_t biggest_alloc_fail;      /* Size of biggest failed alloc */
	uint32_t biggest_alloc_fail_used; /* Alloc bytes when above occurred */
};
```  
&emsp;&emsp;关于这个结构有以下几点说明：  
1. size  
   /* 它是所有pool包含的memory的总和 */  
2. biggest_alloc_fail  
   /* 记录allocate失败的最大buffer size，也是allocate失败时会比较更新的一个值 */  
3. biggest_alloc_fail_used  
   /* 最大buffer失败时pool已经分配了多少memory出去 */  

&emsp;&emsp;通过这些数据可以分析：  
1. 跑完一套完整的testcase后，通过比较max_allocated和size可知pool的大小分配是否合理，是否存在浪费  
2. 结合biggest_alloc_fail，biggest_alloc_fail_used和size可以得知峰值memory的需求和目前已分memory的差距  

&emsp;&emsp;BGET_Malloc里还增加了一个功能选项叫做“ENABLE_MDBG”，可以用来detect memory leak。博主对它的原理还挺感兴趣的，就去看了下，但发现它其实只是malloc的时候在hdr里记录了调用端__FILE__和__LINE__两个值，当然在free的时候会把hdr无效，debug的时候把所有的没有free的buffer都打印出来，仍然需要开发者自己去查看每个buffer是否如期望的保留或者释放了。实现简单，也算是挺好的一个功能吧。  

&emsp;&emsp;再往上层还有不同形式的包装，但基本都是base在BGET和BGET_Malloc上的。  

### How to Enable Stats of Memory Usage in OPTEE?
&emsp;&emsp;OPTEE中Kernel，ldelf和TA都使用了BGET做为memory allocator。其中ldelf并没有给出选项来统计它的memory usage，大概ldelf场景比较单一，不大会出错。而Kernel和TA都有选项来打开memory usage的统计。  

#### CFG_WITH_STATS
&emsp;&emsp;CFG_WITH_STATS是OPTEE统计memory usage的开关，只有它设为y的时候，前面的BGET，wrap过的BGET_Malloc和更上层包装里的stats功能才会打开。同时OPTEE还提供了REE侧的查询接口，它包含：  
- 一个pseudo TA叫做[**stats.ta**](https://github.com/OP-TEE/optee_os/blob/4.0.0/core/pta/stats.c#L237)开发以下command：  
  ```
  static TEE_Result invoke_command(void *psess __unused,
  				 uint32_t cmd, uint32_t ptypes,
  				 TEE_Param params[TEE_NUM_PARAMS])
  {
  	switch (cmd) {
  	case STATS_CMD_PAGER_STATS:
  		return get_pager_stats(ptypes, params);
  	case STATS_CMD_ALLOC_STATS:
  		return get_alloc_stats(ptypes, params);
  	case STATS_CMD_MEMLEAK_STATS:
  		return get_memleak_stats(ptypes, params);
  	case STATS_CMD_TA_STATS:
  		return get_user_ta_stats(ptypes, params);
  	case STATS_CMD_GET_TIME:
  		return get_system_time(ptypes, params);
  	default:
  		break;
  	}
  	return TEE_ERROR_BAD_PARAMETERS;
  }
  ```
- REE端在xtest里有“--stats”选项对应stats ta中的command：  
  注：xtest本质上是一个CA，也可以实现自己的CA去invoke stats.ta的commands。
  ```shell
  # xtest --stats -h
  Usage: xtest --stats [OPTION]
  Displays statistics from OP-TEE
  Options:
   -h|--help      Print this help and exit
   --pager        Print pager statistics
   --alloc        Print allocation statistics
   --memleak      Dump memory leak data on secure console
   --ta           Print loaded TAs context
  ```  
  注：选项“--pager”这里不做讨论，它涉及到另外一个宏“CFG_TEE_PAGER”。  

&emsp;&emsp;“--alloc”主要统计Kernel的memory使用情况，运行结果如下：  
```shell
# xtest --stats --alloc
Pool:                Heap
Bytes allocated:                       20672
Max bytes allocated:                   20800
Size of pool:                          68672
Number of failed allocations:          0
Size of larges allocation failure:     0
Total bytes allocated at that failure: 0

Pool:
Bytes allocated:                       0
Max bytes allocated:                   0
Size of pool:                          0
Number of failed allocations:          0
Size of larges allocation failure:     0
Total bytes allocated at that failure: 0

Pool:                Secure DDR
Bytes allocated:                       217088
Max bytes allocated:                   217088
Size of pool:                          13631488
Number of failed allocations:          0
Size of larges allocation failure:     0
Total bytes allocated at that failure: 0

Pool:
Bytes allocated:                       0
Max bytes allocated:                   0
Size of pool:                          0
Number of failed allocations:          0
Size of larges allocation failure:     0
Total bytes allocated at that failure: 0
```  

#### CFG_TEE_CORE_MALLOC_DEBUG
&emsp;&emsp;前面有提到BGET_Malloc里有个简单的检测memory leak的功能，在“xtest --stats”中对应一个选项“--memleak”，宏CFG_TEE_CORE_MALLOC_DEBUG就是为了enable这个选项，它也统计的是Kernel的每个小buffer的信息。log如下：  
```shell
I/TC: buffer: 24 bytes core/mm/tee_mm.c:20
I/TC: buffer: 152 bytes core/kernel/tee_ta_manager.c:597
I/TC: buffer: 88 bytes core/kernel/pseudo_ta.c:316
I/TC: buffer: 56 bytes core/mm/vm.c:306
I/TC: buffer: 56 bytes core/mm/mobj.c:378
I/TC: buffer: 24 bytes core/mm/tee_mm.c:20
......
I/TC: buffer: 24 bytes core/mm/fobj.c:752
I/TC: buffer: 56 bytes core/mm/vm.c:306
I/TC: buffer: 56 bytes core/mm/vm.c:306
I/TC: buffer: 832 bytes core/kernel/user_ta.c:467
I/TC: buffer: 152 bytes core/kernel/tee_ta_manager.c:597
I/TC: buffer: 88 bytes core/kernel/pseudo_ta.c:316
I/TC: buffer: 80 bytes core/mm/mobj_dyn_shm.c:314   
I/TC: buffer: 56 bytes core/mm/mobj.c:165           
I/TC: buffer: 56 bytes core/mm/mobj.c:165           
I/TC: buffer: 56 bytes core/mm/mobj.c:165           
I/TC: buffer: 800 bytes core/lib/libtomcrypt/ecb.c:109
I/TC: buffer: 432 bytes core/lib/libtomcrypt/hash.c:117
I/TC: buffer: 432 bytes core/lib/libtomcrypt/hash.c:117
......
I/TC: buffer: 432 bytes core/lib/libtomcrypt/hash.c:117
I/TC: buffer: 64 bytes lib/libutils/ext/mempool.c:122
I/TC: buffer: 16 bytes core/drivers/gpio/gpio.c:20 
I/TC: buffer: 16 bytes core/drivers/gpio/gpio.c:20
I/TC: buffer: 48 bytes core/tests/notif_test_wd.c:150
I/TC: buffer: 24 bytes core/mm/tee_mm.c:28      
I/TC: buffer: 24 bytes core/mm/tee_mm.c:28
I/TC: buffer: 64 bytes core/mm/core_mmu.c:400
I/TC: buffer: 16 bytes lib/libutils/isoc/bget_malloc.c:936
```  

&emsp;&emsp;如前面分析的，这个功能只是把目前memory pool里分配出去的buffer大小及哪里分配的打印出来。

#### CFG_TA_STATS
&emsp;&emsp;当CFG_TA_STATS打开的时候，每个user ta在[**user_ta_entry.c**](https://github.com/OP-TEE/optee_os/blob/4.0.0/lib/libutee/user_ta_entry.c#L434)里就增加了一个entry：  
```sass
#if defined(CFG_TA_STATS)
static TEE_Result entry_dump_memstats(unsigned long session_id __unused,
				      struct utee_params *up)
{
	......
	malloc_get_stats(&stats);
	params[0].value.a = stats.allocated;
	params[0].value.b = stats.max_allocated;
	params[1].value.a = stats.size;
	params[1].value.b = stats.num_alloc_fail;
	params[2].value.a = stats.biggest_alloc_fail;
	params[2].value.b = stats.biggest_alloc_fail_used;
	to_utee_params(up, param_types, params);
	......
}
#endif
```
{: file='user_ta_entry.c'}  

&emsp;&emsp;当调用“xtest --stats --ta”的时候，stats.ta就会找到当前所有还在运行的TA的ctx，并依次调用新增的entry_dump_memstats拿到memory usage。  

> 注意，这里是所有正在运行的TA，如果TA的flags不是TA_FLAG_INSTANCE_KEEP_ALIVE，有可能运行完就退出了，不能被统计到。
{: .prompt-warning }

&emsp;&emsp;直接运行“xtest --stats --ta”，所得log为：  
```shell
# xtest --stats --ta
ta(f04a0fe7-1f5d-4b9b-abf7619b85b4ce8c)
        panicked(0) -- True if TA has panicked
        session number(1)
        Heap Status:
                Bytes allocated:                       256
                Max bytes allocated:                   432
                Size of pool:                          16368
                Number of failed allocations:          0
                Size of larges allocation failure:     0
                Total bytes allocated at that failure: 0
```  

&emsp;&emsp;找一个runtime的TA并统计它的实时memory usage：  
```shell
# xtest 4006 & sleep 1; xtest --stats --ta
ta(f04a0fe7-1f5d-4b9b-abf7619b85b4ce8c)
        panicked(0) -- True if TA has panicked
        session number(1)
        Heap Status:
                Bytes allocated:                       256
                Max bytes allocated:                   432
                Size of pool:                          16368
                Number of failed allocations:          0
                Size of larges allocation failure:     0
                Total bytes allocated at that failure: 0
ta(cb3e5ba0-adf1-11e0-998b0002a5d5c51b)
        panicked(0) -- True if TA has panicked
        session number(1)
        Heap Status:
                Bytes allocated:                       608
                Max bytes allocated:                   608
                Size of pool:                          32752
                Number of failed allocations:          0
                Size of larges allocation failure:     0
                Total bytes allocated at that failure: 0
```  

&emsp;&emsp;系统中正在运行的TA可能是实时变化的，如何精准的monitor某个TA某个时刻的memory usage也是一个问题。这里看看大家有没有什么方案？（博主已有一个腹稿）  

#### CFG_TEE_TA_MALLOC_DEBUG
&emsp;&emsp;与CFG_TEE_CORE_MALLOC_DEBUG一样，CFG_TEE_TA_MALLOC_DEBUG是enable TA里的memory leak功能。然后这个功能并没有像CFG_TA_STATS一样在user ta ops里专门添加一个entry，所以想使用这个功能的要不也加一个类似entry_dump_memleak，或者直接在需要debug的TA某个command里调用mdbg_check(1)更简单一些。  

## Reference
[**BGET**](https://www.fourmilab.ch/bget/)  
[**BGET Explained**](https://phi1010.github.io/2020-09-14-bget-exploitation/)  