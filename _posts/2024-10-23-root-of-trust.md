---
layout: post
title: Root of Trust
date: 2024-10-23 18:50 +0800
author: sfeng
categories: [Security]
tags: [rot, security]
lang: zh
---

## Preface
> A RoT is an essential, foundational security component that provides a set of trustworthy functions that the rest of the device or system can use to establish strong levels of security. Often integrated as a chip, using a RoT gives devices a trusted source that can be relied upon within any cryptographic system.
{: .prompt-info }  

&emsp;&emsp;在Security越来越重要的今天，RoT作为Security的始端，是必不可少的基础组件。本文就聊聊它在嵌入式系统中的几个实现模型。  

## RoT
&emsp;&emsp;在嵌入式系统中，RoT的基础，也是重中之重，主要有两个：  
1. 最开始的code（一般是ROM code）一定要运行在物理上不可改变的介质或者加电后就WP（write protection）的介质上。  
2. 非对称算法。  

&emsp;&emsp;第一点很容易理解，第二点则是因为非对称算法的特性可以只分发公钥而始终保持密钥的非公开性，甚至发行者自己都不需要知道密钥是什么。这是对称密钥算法无法比拟的。当然由于对称密钥算法的高效，可以两者融合做出安全性更高的方案。  

### A Simple RoT
![rot](/assets/img/rot.png){: .normal }   

&emsp;&emsp;上图显示了一个最简的RoT系统。其中：  
1. ROM Code在芯片回片后不能改动  
2. Public Key的Hash值内嵌在ROM Code里或者放在OTP上。  
   放在OTP中的好处是可以用不同的Key做签名，只要相应的private key做签名，public key验签就可以了。  
3. BL1的binary包含真正要运行的程序，public key和signature。它由机密的sign server用private key对bootloader的data（也可以包含public key）做签名并pack生成。  

&emsp;&emsp;在该系统中，由于Public Key的Hash放在ROM或者OTP上不能被hack，可以用来验证public Key，有了public key又可以验证Signature的正确性，在之后的image也可以同样的做法，这样一条trusted chain就建立了。  

### RoT with Confidentiality
&emsp;&emsp;上节描述了一个最简RoT，缺点也很明显，就是所有的data都是明文，通过读取flash做反汇编等方式有可能会被hack（谁又敢保证自己的code没有漏洞呢？）。解决的方法就是把明文加密，这就用到了非对称和对称算法相结合的方式，如下图示意。  

![rot](/assets/img/rot_confidentiality.png){: .normal }   

&emsp;&emsp;在上图中引入了tee environment，这是因为Symmetirc Key不应被外界获得。其实这里的tee environment算是最低要求，security也需要分级，RoT应该对应在最高security level的运行环境中。另外key的注入也应该在绝对机密的环境中进行。  

&emsp;&emsp;上面的两个RoT系统都算是比较简单的，但却基本描述了基本要素。开发者可以基于上述模型衍变出更加可靠RoT系统。  

## Keys of RoT
&emsp;&emsp;这里忍不住要再强调以下，整个RoT的关键在于各种Keys的机密性。分类描述如下：  
- Factory Keys
  &emsp;&emsp;所谓factory key是在产品出厂时就生成的，又分为下面两类。  
  - external key  
    这里的外部key是指需要外部生成和注入的。  
    - Asymmetric Key  
      非对称的密钥保存在所谓的Security Server上，不能leak出去，最好开发者都不能拿到，Server只提供交互命令去做签名操作。  
    - Symmetric Key  
      对称密钥不仅要机密的保存在server上，同时也要inject到嵌入式设备RoT的secure storage中。注入过程要严格保密。比如只能在工厂操作。之后使用key的操作同上，Server只提供交互命令，保证使用者不能拿到key。  
  - internal key  
    内部key是只在嵌入式设备中使用，且只存在嵌入式设备的TEE环境中且不会应用于外部。最典型应用的比如secure storage。这类key可以从上述注入的key中衍生出来。但还是那句话，不能被人拿到的才是最安全的，能拿到的范围越小越安全。相比从注入key衍生，这个root key通过RoT中的TRNG在出厂时随机生成并保存在RoT的内部NVM中，在使用中通过它衍生出子密钥，博主认为这个安全级别算是很高的。  

- Runtime Keys  
  运行中使用的key如DRM的应用，可以利用Factory key通过各种密钥交换机制拿到，也需要保存在TEE的环境中。  

&emsp;&emsp;写在最后，本文是博主对RoT个人理解的总结，如有错漏，请指正！！！  

## Reference
[**What is RoT**](https://trustedcomputinggroup.org/about/what-is-a-root-of-trust-rot/)  
[**Hardware RoT**](https://www.rambus.com/blogs/hardware-root-of-trust/)  