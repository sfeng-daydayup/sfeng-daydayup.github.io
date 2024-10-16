---
layout: post
title: Brief of Cryptography Algorithm
date: 2024-10-05 10:01 +0800
author: sfeng
categories: [Security]
tags: [alg, security]
lang: zh
---

## Preface

&emsp;&emsp;Security在Cambridge Dictionary里的解释是：
> protection of a person, building, organization, or country against threats such as crime or attacks by foreign countries
{: .prompt-info }

&emsp;&emsp;计算机世界里也同样适用，只是保护的对象变成了虚拟物品或者实体在计算机世界的投影。在虚拟世界里，保护的手段也不同于现实世界，一般是基于Cryptography的算法并由此衍生出各种应用或者部署。本篇总结下一些常用的密码学算法。因为网络上有很多很好的文章，这里主要把收集的文章的link都放上来，博主拿它当一个字典来用，当然也加了一些简单的说明。  

## Cryptography Introduction

&emsp;&emsp;常用的密码学算法可以分为三类，对称加密算法，非对称加密算法和散列算法。  

### Symmetric-key Algorithm

> Symmetric-key algorithms are algorithms for cryptography that use the same cryptographic keys for both the encryption of plaintext and the decryption of ciphertext. The keys may be identical, or there may be a simple transformation to go between the two keys.
{: .prompt-info }

&emsp;&emsp;对称密码算法又分为分组密码和流密码算法。这两种算法的[区别](https://www.geeksforgeeks.org/difference-between-block-cipher-and-stream-cipher/)主要在每次加密的数据量不同，分组密码算法每次都是固定块大小，不够一个块需要补全，而流密码算法则每次可以加密一个bit或者byte。  

#### [Block Cipher](https://en.wikipedia.org/wiki/Block_cipher)
> In cryptography, a block cipher is a deterministic algorithm that operates on fixed-length groups of bits, called blocks. Block ciphers are the elementary building blocks of many cryptographic protocols. They are ubiquitous in the storage and exchange of data, where such data is secured and authenticated via encryption.
{: .prompt-info }

- [DES](https://en.wikipedia.org/wiki/Data_Encryption_Standard)  
  DES是1977年公布的，它使用56位密码，在目前的计算机算力下已经很容易攻破，所以很少使用它，当然它还有一些变种来增加算法强度，如3DES。  
- [3DES](https://en.wikipedia.org/wiki/Triple_DES)  
  3DES如其名，就是做了三次DES操作，当然最多可以用三个K，加密操作为ciphertext = E_{K1}(D_{K2}(E_{K3}(plaintext)))，解密就是E变成D，D变成E。其中K2不能与左右两边的Key相同，所以密钥可以是112 bits（56*2）或者168 bits（56*3）。  
- [AES](https://en.wikipedia.org/wiki/Advanced_Encryption_Standard)  
  AES是目前应用几乎最广泛的分组密码算法了，它的分组长度固定为128 bits，密钥长度可以是128/192/256 bits，密钥长度越长，加密强度越大。  
- SM1  
  SM1是国密里的分组密码算法，它算法不公开，仅以IP的形式放在芯片中，用于政务和国计民生的各个领域。  
- [SM4](https://en.wikipedia.org/wiki/SM4_(cipher))  
  SM4是国密里对称加密算法。分组长度128 bits，密钥也是128 bits。与[AES相比](https://blog.csdn.net/archimekai/article/details/53096016)算法比较简单，加解密算法相同，只需要密钥顺序倒置。而AES的加解密则是不同的编码。强度方面，SM4只支持128 bits密钥，AES则是从128到256都支持。再说性能([对比1](https://blog.csdn.net/u013565163/article/details/128047911)，[对比2](https://medium.com/asecuritysite-when-bob-met-alice/whats-the-fastest-symmetric-cipher-and-mode-3d6e77841c2b))，单从轮数来说，SM4要32轮，而AES128只需要10轮，综合性能是差一些的，但考虑到是国密，一定要支持。  

&emsp;&emsp;另外，这次总结的一个收获是，原来ECB，CBC等工作模式可以应用于除了AES的其他分组加密算法，孤陋寡闻了，不过想想也是，这些策略与分组算法本身是隔离的。维基百科里以AES为例有很好的图示来解释这些工作模式的区别，copy过来看更直观。  

- ECB  
  ![AES-ECB](/assets/img/aes/aes-ecb.png){: .normal }  
- CTR  
  ![AES-CTR](/assets/img/aes/aes-ctr.png){: .normal }  
- CBC  
  ![AES-CBC](/assets/img/aes/aes-cbc.png){: .normal }  
- PCBC  
  ![AES-PCBC](/assets/img/aes/aes-pcbc.png){: .normal }  
- OFB  
  ![AES-OFB](/assets/img/aes/aes-ofb.png){: .normal }  
- CFB  
  ![AES-CFB](/assets/img/aes/aes-cfb.png){: .normal }  
- GCM  
  ![AES-GCM](/assets/img/aes/aes-gcm.png){: .normal }  

  
&emsp;&emsp;用上面的算法对数据进行处理时，主要有几个操作：encryption，decryption，random read。从上面的工作流程可以看出哪些操作可以并行处理，哪些只能串行。另外大部分工作模式下只能保证confidentiality，只有一个可以保证integrity。大家猜猜看！！！  

#### [Stream Cipher](https://en.wikipedia.org/wiki/Stream_cipher)
> A stream cipher is a symmetric key cipher where plaintext digits are combined with a pseudorandom cipher digit stream (keystream). In a stream cipher, each plaintext digit is encrypted one at a time with the corresponding digit of the keystream, to give a digit of the ciphertext stream.
{: .prompt-info }

&emsp;&emsp;Stream Cipher在嵌入式开发中使用较少，这里只列举其中几个。  

- [RC4](https://en.wikipedia.org/wiki/RC4)  
  用于web加密。  
- [A5](https://en.wikipedia.org/wiki/A5/2)  
  用于GSM cellular telephone系统。  

### Asymmetric-key Algorithm  

> Public-key cryptography, or asymmetric cryptography, is the field of cryptographic systems that use pairs of related keys. Each key pair consists of a public key and a corresponding private key.[1][2] Key pairs are generated with cryptographic algorithms based on mathematical problems termed one-way functions. Security of public-key cryptography depends on keeping the private key secret; the public key can be openly distributed without compromising security.
{: .prompt-info }  

&emsp;&emsp;既然有了对称密码算法，为啥还要非对称密码算法？在对称密码算法中，密钥只有一把（或者从这把密钥衍生出来），而加密数据的时候必须要持有密钥才能解密，这样密钥的分发和保密就成了问题，当持有密钥的对象增加的时候，密钥流出的风险也随之增大。而非对称密码算法就解决了这个问题。  非对称密码算法一般都有两个密钥，一个叫公钥，一个叫私钥，用任意一把钥匙加密数据，就可以用另外一把解密或者叫验证。当然非对称算法的性能并不好，主要用于签名验签。  

&emsp;&emsp;这里需要highlight的是，**非对称密码学算法在嵌入式系统中是RoT（Root of Trust）的必要条件**。后续博文中会写如何为构建嵌入式系统的RoT。  

&emsp;&emsp;非对称密码算法的理论基础主要有以下几种：  
- [RSA](https://en.wikipedia.org/wiki/RSA_(cryptosystem))  
  RSA算法的理论基础是极大整数的因数分解的困难程度（两个大素数的乘积很难分解为两个大素数），当然还有欧拉定理，辗转相除法和欧几里得算法等等。RSA也是目前很流行的签名算法，常用的如RSA1024，RSA2048和RSA4096等，数值越大，强度越大，当然相应的性能越差。  
- [Elliptic-Curve Cryptography](https://en.wikipedia.org/wiki/Elliptic-curve_cryptography)  
  [椭圆曲线公钥密钥算法](https://juejin.cn/post/6898987351867916301)被广泛认定为在给定密钥长度情况下最强大的非对称算法，比如ECC密钥长度256 bits就可以媲美RSA3072。它又有多种不同的实现：  
  - [ECDSA](https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm)  
    ECDSA是一种签名算法，它可以保证用户收到的由CA签发的证书的有效性。  
  - [ECDH](https://en.wikipedia.org/wiki/Elliptic-curve_Diffie%E2%80%93Hellman)  
    ECDH则是一种key交换协议，它可以在两个组织间通过非安全通道来传输保密信息。  
  - [EDDSA](https://en.wikipedia.org/wiki/EdDSA)  
    - [ED25519](https://en.wikipedia.org/wiki/EdDSA#Ed25519)  
      ED25519也是一种很流行的ECC算法，它具有[短密钥，高安全性，高性能](https://ed25519.cr.yp.to/)等等特点。  
    - [ED448](https://en.wikipedia.org/wiki/EdDSA#Ed448)  
  - ECDH/EDDH  
- [ElGamal](https://en.wikipedia.org/wiki/ElGamal_encryption)  
  算法的安全性是建立在离散对数难题上。  

&emsp;&emsp;国密SM2就是基于ECC，其设计主要是：  

1. 选择合适的领域参数，避免“弱曲线”，对抗已知的攻击手段  
2. 设计具体的密钥交换、数字签名、非对称加密的标准算法，即要保证安全，又要保证计算效率  

### Hash Algorithm
&emsp;&emsp;Hash function的主要特性是其单向性和唯一性，即通过hash值不能倒推出原文，不同的数据hash值不重复。Hash function其实也分几个类别，比如CRC，checksum和cryptographic hash function，本文主要涉及[Secure Hash Algorithms](https://en.wikipedia.org/wiki/Secure_Hash_Algorithms)。  

- [MD5](https://en.wikipedia.org/wiki/MD5)  
  md5最常用的是md5sum来查看数据的完整性。  
- SHA  
  其实还有SHA0，不过已经弃用了。  
  - [SHA1](https://en.wikipedia.org/wiki/SHA-1)  
  - [SHA2](https://en.wikipedia.org/wiki/SHA-2)  
    SHA224，SHA256，SHA384，SHA512都属于SHA2.  
  - [SHA3](https://en.wikipedia.org/wiki/SHA-3)  
    SHA3相对于SHA2有更高的安全性，目前看SHA2就可以满足绝大部分的需求。  
- [SM3](https://en.wikipedia.org/wiki/SM3_(hash_function))  
  SM3的强度大致和SHA256相当。  


&emsp;&emsp;这些算法还是很烧脑的，由于有很多商业或者开源的实现，大多数情况下了解它们的特性和用法应该就够用了。  

## Reference
[**Cryptography Types**](https://www.ibm.com/think/topics/cryptography-types)  
[**Nist Cryptography**](https://www.cryptomathic.com/news-events/blog/summary-of-cryptographic-algorithms-according-to-nist)  
[**Symmetric-key_algorithm**](https://en.wikipedia.org/wiki/Symmetric-key_algorithm)  
[**Block Cipher Work Mode**](https://en.wikipedia.org/wiki/Block_cipher_mode_of_operation)  
[**Asymmetric-key_algorithm**](https://en.wikipedia.org/wiki/Public-key_cryptography)  
[**Hash**](https://en.wikipedia.org/wiki/Hash_function)  