---
layout: post
title: Definition of MACRO
date: 2024-12-16 18:30 +0800
author: sfeng
categories: [Dev, Dev Tip]
tags: [macro]
lang: zh
---

## Issues When Using MACRO
&emsp;&emsp;宏定义的使用在C里面很普遍，它通常用于给代码中的常量，简单的函数或者某些表达式一个简短或容易理解阅读的名字，以减少重复代码，提高开发效率。这里需要注意的是，宏定义在编译过程中是一个文本替换和展开的过程，语法错误会被编译器捕捉，但类型检查，逻辑错误却无法保证，所以宏定义也要小心。  

&emsp;&emsp;比如我们来看个最简单的例子：  
```shell
#define SQUARE(x) (x * x)
```  
&emsp;&emsp;看起来没问题对不对。但假如输入的x为一个表达式比如：6 + 8呢？展开为：  
```shell
6 + 8 * 6 + 8
```  
&emsp;&emsp;是否有些惊讶！而定义成下面则解决了这个问题。  
```shell
#define SQUARE(x) ((x) * (x))

SQUARE(6 + 8)  -> (6 + 8) * (6 + 8)
```  

&emsp;&emsp;再比如下面这个宏：  
```shell
#define ABS(a) (a) < 0 ? -(a) : (a)
```  
&emsp;&emsp;用它来计算下面两个结果：  
```shell
int a, b;
a = ABS(-5);
b = ABS(-5) + 1;
```  
&emsp;&emsp;猜下a，b的结果是多少？又要惊讶了，竟然都是5。正确的定义应该是：  
```shell
#define ABS(a) ((a) < 0 ? -(a) : (a))
```  

&emsp;&emsp;再来，还是上面的例子，但是输入参数变一下，猜猜b，c的值是多少，以及随后a的值是多少。  
```shell
int a = 5;
int b = ABS(a++);
int c = ABS(++a);
```  

## Conclusion
&emsp;&emsp;列下使用宏的一些注意点：  
1. 把宏里的每个参数都用括号括起来；  
2. 整个宏用括号括起来；  
3. 宏命名要清楚简单并有意义；  
4. 宏定义只用于定义常量和简单的逻辑，不要定义复杂的功能；  
5. 最好加些注释描述宏的作用；  
6. 最好不要使用诸如++，--这种带操作符的表达式作为宏的参数；  

## Reference
[**issues with using macros in C/C++**](https://www.quora.com/What-are-some-of-the-issues-with-using-macros-in-C-C)  
[**MACRO in c**](https://www.simplilearn.com/tutorials/c-tutorial/what-is-macros-in-c)  
[**What is the correct way to define this C macro**](https://stackoverflow.com/questions/31530325/what-is-the-correct-way-to-define-this-c-macro)  