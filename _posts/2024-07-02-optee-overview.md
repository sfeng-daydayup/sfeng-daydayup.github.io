---
layout: post
title: OPTEE Overview
date: 2024-07-02 11:56 +0800
categories: [Blogging, OPTEE]
tags: [optee]
lang: zh
---

&emsp;&emsp;前段时间刚好做了一个关于OPTEE的PPT，最近打算写一些关于OPTEE的文章，这篇先起个头。  
&emsp;&emsp;关于OPTEE的介绍，官方文档在这里([**About OPTEE**](https://optee.readthedocs.io/en/latest/general/about.html))。OPTEE主要是基于ARM TrustZone Technology基础上打造出的一个Trused Execution Environment，文档中虽然提及它已经兼容其他有isolation technology的SoC，比如RISC-V，但本篇主要内容都是以ARM的SoC为基础。  
![Desktop View](/assets/img/optee_common.png){: .normal }
&emsp;&emsp;上图显示了OPTEE包含的若干组件以及它们在runtime所运行的Exceptin Level。  
- OPTEE OS  
  OPTEE OS是核心组件，它不直接参与具体业务实现，它为业务实现提供各种基础设施，比如memory的management，interrupt的处理，thread的创建和上下文切换，TA的loading/initialization/destory，Secure Storage的实现，etc.  
- TA(Trusted Application)  
  TA是具体业务的载体。它通过自身逻辑配合调用TEE OS提供的syscall来实现具体业务。  
- TEE Libary  
  Libary中最基础的是libutee，它实现了GPD的TEE Internal APIs(大部分最终syscall到OPTEE OS里)。Link到TA后，TA通过调用这些API来实现自己的逻辑。 其他的如libutils提供了一些标准c函数实现，libmbedtls实现了很多cryptography的software implementation。 
  OPTEE还提供了动态加载libary的选项，有空可以实践对比下。  
- OPTEE Linux Driver  
  OPTEE Linux Driver则是作为REE端连接ATF和OPTEE OS的接口，所有的CA的请求都通过它转发给TEE端。
- CA(Client Application)  
  由于OPTEE OS没有scheduler，所以一个Secure Service总是由REE端的CA发起，而CA又由Linux OS调度。CA大多运行在User Space，但也可以在Kernel Space实现。  
- TEEC Libary  
  当CA运行在User Space的时候，TEEC提供了CA到OPTEE Linux Driver的接口。TEEC提供的接口同样要符合GPD的TEEC Client API的标准。  
- tee_supplicant  
  由于OPTEE运行在ARM CPU Secure State，一些本身由REE OS(Linux)管理的设备(比如storage)，OPTEE不能也没必要直接访问。这时候OPTEE就RPC callback回到REE通过tee_supplicant来实现操作。  
- xtest  
  xtest提供了TEE Sanity Test Suite。通过run xtest可以发现一些regression。当然developer也可以根据需求扩展更多的testcase。  

&emsp;&emsp;除了OPTEE OS还有一些其他的TEE OS，如Google家的trusty，也有不少公司有自己私有的TEE OS，但总体来说OPTEE是开源里面全面能打的一个，文档齐全，社区维护者众多，CVS补丁也更新及时，紧跟ARM脚步，最早支持ARM最新架构等等，认可度高，特别是过各种Security相关的认证，及早使用OPTEE是件省时省力的事情。