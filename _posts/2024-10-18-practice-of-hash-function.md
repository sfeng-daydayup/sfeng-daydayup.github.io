---
layout: post
title: Practice of Hash Function
date: 2024-10-18 18:41 +0800
author: sfeng
categories: [Security]
tags: [alg, security]
lang: zh
---

## Brief
&emsp;&emsp;在[Brief of Cryptography Algorithm](https://sfeng-daydayup.github.io/posts/brief-of-cryptography-algorithm/)里提到过，Hash function有以下特点：  
- 总是输出固定长度的摘要（For example: 256 bits for SHA256 and SM3）  
- 单向，不能从摘要反推数据  
- 相同消息使用相同的hash function得到的摘要总是一样  
- 不同的消息用hash function输出的摘要不同
- 计算效率高  

&emsp;&emsp;来看看在openssl中怎么用。  
 
## Use HASH in OPENSSL
&emsp;&emsp;只做hash，命令很简单，仍然选取两种来做例子，SHA256和SM3.  

### SHA256
```shell
openssl dgst -sha256 -binary -out random.sha256.data random.data
```

### SM3
```shell
openssl dgst -sm3 -binary -out random.sm3.data random.data
```

## Applicability
&emsp;&emsp;Hash的应用很广泛，下面列以下hash在cryptography里的应用。  

### Integrity Check
&emsp;&emsp;由于Hash function的特性里有相同的消息用相同的hash function总能得到相同的摘要，而不同的消息摘要总是不同。这样持有正确的hash值，再对数据重新计算hash，两相对比，就可以知道数据是否被篡改。  
![hash](/assets/img/hash.jpg){: .normal }   

### Key Derivation
&emsp;&emsp;基于Hash function的特性，它也广泛用于密钥衍生。如[NIST SP800-108](https://csrc.nist.gov/files/pubs/sp/800/108/final/docs/sp800-108-nov2008.pdf)中的KDF，感兴趣的可以去读下spec，这里就不赘絮了。  

### [Message Authentication Code](https://en.wikipedia.org/wiki/Message_authentication_code)
&emsp;&emsp;Hash function通过结合密钥产生的MAC，不仅可以验证数据的完整性，也可以验证数据的真实性。最典型的例子之一就是HMAC，比如RPMB中数据的验证就用到了HMAC。  
<https://github.com/OP-TEE/optee_os/blob/4.0.0/core/tee/tee_rpmb_fs.c#L370>  
&emsp;&emsp;再埋个坑，写一篇RPMB的文章。  

### Signature
&emsp;&emsp;在[Practice of Asymmetric Key Alg](https://sfeng-daydayup.github.io/posts/practice-of-asymmetric-key-alg/)中提到，非对称算法结合hash function可以用来签名。比如以下做签名的commands:  
```shell
openssl pkeyutl -sign -inkey rsa_4096_private.pem -in hash.txt -out hash.txt.rsa_4096_sha256.sign -rawin -digest sha256
openssl pkeyutl -sign -inkey sm2_private.pem -in hash.txt -out hash.txt.sm2.sign -rawin -digest sm3
```  

&emsp;&emsp;其中各自用到了hash function中的sha256和sm3。做签名也有不同的写法，如下：  
```shell
openssl dgst -sha256 -sign rsa_4096_private.pem -out hash.txt.sha256_rsa_4096.sign hash.txt
openssl dgst -sm3 -sign sm2_private.pem -out hash.txt.sm3_sm2.sign hash.txt
```

&emsp;&emsp;验签如下：  
```shell
openssl dgst -sha256 -verify rsa_4096_public.pem -signature hash.txt.sha256_rsa_4096.sign hash.txt
openssl dgst -sm3 -verify sm2_public.pem -signature hash.txt.sm3_rsa_4096.sign hash.txt
```

&emsp;&emsp;其中用sm3和sm2签名时两种方式生成的签名文件格式不同，但均可以交叉验签通过。  

&emsp;&emsp;其实做签名就是先对data进行hash，然后用私钥把hash加密，而验签就是把签名先decrypt，把data再做hash，比较decrypt的hash和新作的hash，如果匹配就验证通过了。另外，为了增加security，openssl在中间加了PKCS#1 v1.5的padding，所以手动分成这两步来做的时候，得到的签名会不同。  

## Reference
[**HASH**](https://en.wikipedia.org/wiki/Hash_function)  
[**NiST SP800 108**](https://csrc.nist.gov/fileopenssl dgst -sm3 -binary -outs/pubs/sp/800/108/final/docs/sp800-108-nov2008.pdf)  
[**HMAC**](https://en.wikipedia.org/wiki/HMAC)  
[**PKCS#1 v1.5 padding**](https://crypto.stackexchange.com/questions/66521/why-does-adding-pkcs1-v1-5-padding-make-rsa-encryption-non-deterministic)  