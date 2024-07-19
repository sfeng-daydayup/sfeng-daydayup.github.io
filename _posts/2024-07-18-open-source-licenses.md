---
layout: post
title: Open Source Licenses
date: 2024-07-18 18:30 +0800
author: sfeng
categories: [Blogging, Misc]
tags: [license]
lang: zh
---

## Preface

&emsp;&emsp;Open Source真是个好东西，减少重复开发，快速应用，有的还有社区支持。好处网上罗列了一大堆，比如[**10 Biggest Advantages**](https://www.rocket.chat/blog/open-source-software-advantages)。Open Source的项目在各大开源网站一大堆，但有句话讲“天下没有免费的午餐”，如果不认真甄别其使用的Open Source License，有可能会出大问题。比较有名的case如：[FSF vs Cisco](https://en.wikipedia.org/wiki/Free_Software_Foundation,_Inc._v._Cisco_Systems,_Inc.)和[MySQL vs NuSphere](https://www.theregister.com/2002/11/21/mysql_nusphere_settle_gpl_contract/)。所以在使用Open Source之前，有必要了解下Open Source License。

## Introduction

### Definition
&emsp;&emsp;开源是相对闭源来讲的，开源就是放在公共区域人人可以拿到，修改，改进和分发。当然都会附加一份版权来说明在何种情况下开源项目可以用于何种用途。

### Category
&emsp;&emsp;有两个主要的Open Source License Categories：  
- Copyleft  
  > Everyone will be permitted to modify and redistribute, but no distributor will be allowed to restrict its further redistribution. 
  {: .prompt-info }

  &emsp;&emsp;上面这段话很好的描述了Copyleft是怎样一个概念。  
  - Strong Copyleft  
    > If a source code is protected by a strong copyleft license, then the derivative software needs to be publicly available under that license as well. This includes all linked libraries and components within the software.
    {: .prompt-danger }

    &emsp;&emsp;如果用了声明为Strong Copyleft的Open Source Code，那从它衍生出来的东西不管以什么形式发布，都需要声明为同样的License且开源出来。就是常说的传染性，典型的代表就是GPL。Linux就是使用了GPL的License，才能发展到今天的规模。  
  - Weak Copyleft  
    > The requirements of a weak copyleft license are similar to those of a strong one, but they apply to a limited set of codes. This open-source license only requires that the source code of the original or modified work is made publicly available, while the rest of the code used together with the work doesn't have to be published under the same license.
    {: .prompt-info }

    &emsp;&emsp;而使用了声明为Weak Copyleft的Open Source Code，可以把这部分内容做成libary的形式，该libary是需要声明为同样的License，而link这个libary的entity则不用这样声明。LGPL和Mozilla Public License就属于这种类型。Glibc就是声明LGPL的C标准库。  
- Permissive  
  &emsp;&emsp;声明为Permissive License的Open Source使用起来就自由多了，可以任意使用且不强制开源和不强制声明为同类型的License。甚至为了商业目的可以闭源。听起来是不是有点自私！:mask:  
  &emsp;&emsp;典型的Permissive的License有Apache，BSD，MIT等等。  


&emsp;&emsp;这里澄清下，当今世界上有如此多的License，没有好坏之分，只有适合和不适合，甚至可以根据个人或者组织的需求起草一个全新的License。  

## Popular Open-Source Licenses and Comparision
&emsp;&emsp;这里用一张表来列下常见的Open Source License和它们的一些特性。  

|  License  |       类型      | 商用 | 强制开源 | 保留原声明 | 同类型License | 修改声明 | 传染性 | 免责声明 |
|:---------:|:---------------:|:----:|:--------:|:----------:|:-------------:|----------|:------:|:--------:|
|    GPL    | Strong Copyleft |   Y  |     Y    |      Y     |       Y       |     Y    |    Y   |     Y    |
|    LGPL   |  Weak Copyleft  |   Y  |     Y    |      Y     |       Y       |     Y    |    N   |     Y    |
|  Mozilla  |  Weak Copyleft  |   Y  |     Y    |      Y     |       Y       |     N    |    N   |     Y    |
| Microsoft |  Weak Copyleft  |   Y  |     N    |      Y     |       N       |     N    |    N   |     Y    |
|   Apache  |    Permissive   |   Y  |     N    |      Y     |       N       |     Y    |    N   |     Y    |
|    MIT    |    Permissive   |   Y  |     N    |      Y     |       N       |     N    |    N   |     Y    |
|    BSD    |    Permissive   |   Y  |     N    |      Y     |       N       |     N    |    N   |     Y    |

注意：
1. 传染性是指只是使用的开源部分还是整个项目都开源
2. 免责声明是指使用该开源code造成损失作者是否承担责任(话说如果承担责任谁还敢开源！)

&emsp;&emsp;这里只比较了常关注的几项，如果需要更详细的请看这个[pdf](https://www.cmu.edu/cttec/forms/opensourcelicensegridv1.pdf)或者阅读声明文档。  

## Reference

<https://solutionshub.epam.com/blog/post/open-source-licenses-definition-types-and-comparison>  
<https://choosealicense.com/licenses/>  
<https://en.wikipedia.org/wiki/Copyleft>  
<https://www.mend.io/blog/top-open-source-licenses-explained/>  
<https://www.cmu.edu/cttec/forms/opensourcelicensegridv1.pdf>  
<https://opensource.org/licenses>