---
layout: post
title: Git Commands
date: 2024-07-15 10:27 +0800
author: sfeng
categories: [Blogging, GIT]
tags: [git]
lang: zh
---

&emsp;&emsp;最近IT搞了件很不专业的事情，在没有做备份的情况下，把AWS的service给terminate了，导致几个git repo都**没了**，是的**没了**。作为大头兵，只能默默的把git操作好好熟练下。  

## Introduction
&emsp;&emsp;git是当今世界上使用最广泛的版本控制系统。在写这篇博文前，博主竟然不知道它竟然是Linus本尊开发的，那它是open sourced就很合理了。之前也用过不少其他的version control system，比如早期时用IBM的clearcase，后来用CVS和SVN，特别是用完clearcase后用CVS，当时就觉得clearcase虽然贵，但是好用啊。再后来切换到git，那还是免费的好啊，感谢Linus！！！  
> By far, the most widely used modern version control system in the world today is Git. Git is a mature, actively maintained open source project originally developed in 2005 by Linus Torvalds, the famous creator of the Linux operating system kernel.
{: .prompt-tip }

&emsp;&emsp;当然git有很多好处：  
- 分布式版本控制  
  每个开发者本地的备份都是包含了所有改动的全部历史的仓库(所以只要本地曾经更新到最新，服务器端挂了也能找回所有，但能recovery最好，重新提交历史记录都对不上了)  
- 开源  
- 性能  
  这点应该也是相对而言。曾经遇到过codebase大到一定程度的时候遇到过需要增加DDR，定期清缓存来加快速度  
- 安全性和完整性  
  每一次提交的commit ID就是一个20字节的sha1 hash值  
- 分支的设计模型  
  不管本地还是服务器端都可以有多个独立的分支来记录不同的改动  
- 协同工作  
  支持多人同时工作在一个文件上，并提供了解决冲突的方案，虽然大多数时候还需要手动解决冲突:blush:  
- 钩子和自动化  
  例如gerrit可以做code review/merge，做自动化测试  

## Frequently Used Commands
&emsp;&emsp;只给常用例子吧
- clone  
  git clone https://github.com/OP-TEE/optee_os.git //从远端clone整个仓库  
  git clone [path of local database] //clone本地仓库  
- config  
  git config --global --add core.editor vim //设置编辑器，主要用于编辑commit message  
  git config --global user.name [user name] //设置用户名    
  git config --global user.email [email address] //设置email  
- add  
  git add [modified file] //commit前加修改的文件  
- status  
  git status //查看当前仓库中所有改动的文件，包括不在track的文件  
  git status --untracked-files=no //查看当前在仓库的所有改动的文件  
- diff  
  git diff //仓库当前改动内容  
  git diff --cached //git add后仓库改动内容  
  git diff [commit id1] [commid id2] //对比两个commit之间的变化  
- commit  
  git commit -s -m "commit message" //改动提交到本地  
  git commit --amend //增加改动到本地提交  
- rm  
  git rm [file name] //删除仓库中文件  
- mv  
  git mv [path/origin name] [new path/new name] //改名或者改路径  
- branch  
  git branch -r //查看远端branch  
  git branch -D [local branch] //删除本地branch  
  git branch -M [origin branch] [new branch] //改变本地branch name  
  git branch -a //列出所有本地和远端branch(需要fetch到最新)  
  git branch --list [partern] //只列出符合partern的branch  
- checkout  
  git checkout [branch name] //切换到某个branch上  
  git checkout -b [new branch name] //在本地head上新建一个branch  
- log  
  git log //查看commit相关信息，如message，date，author，etc.  
  git log --oneline //用一行显示commit id和commit message  
  git log -[number displayed] //只显示最近几次的log信息  
- tag  
  git tag [tag name] -m "tag description" //创建一个tag  
  git tag --delete [local tag name] //删除一个本地tag  
- fetch  
  git fetch --all //拿取远端更新   
- push  
  git push origin main //把本地改动推送到远端main branch  
  git push origin :[delete remote branch or tag name] //删除远端branch或者tag  
  git push origin [local name]:[remote name] //推送本地branch到远端  
  git push origin --tags //把本地tag推送到远端  
- show  
  git show   (equals to git log -p -1)  
- apply  
  git apply [patch set] //打patch  
- cherry-pick  
  git cherry-pick [commit id] //拿某个commit到当前head  
- rebase  
  git rebase [branch name] //把当前未merge的commits放在某个branch上  
  git rebase -i [branch name] //同上，但是更灵活，可以改变顺序，合并某几个commit或者丢弃commit  
- revert  
  git revert [commit id] //新建一个commit把之前某个commit的改动去掉  
- clean  
  git clean -dxf //清除本地untrack的文件  
- reset  
  git reset --hard //清楚本地改动  
- whatchanged  
  git whatchanged -[number] //某个或某几个commit都改了哪些文件  
- reflog
  git reflog //列出所有的以前在过HEAD的commit，不管远端有没有，很有用

## Solution to Recover Repo
&emsp;&emsp;这里推荐几个recover丢失的git repo的方案，当然首要条件是本地存有clone好的完整的repo，这就是git分布式版本控制的好处了。  
### 方案一
1. 新建一个repo
2. git clone [url of new repo]
3. git fetch [path of local copy]
4. git checkout [the branch or commit of local copy]
5. git push origin [remote branch name]

### 方案二
1. 新建一个repo
2. go to the local repo
3. git checkout [the branch or commit of local copy]
4. make sure the branch is created in remote side
5. git push url://new_repo.git HEAD:[remote branch]

### 方案三
1. 直接import整个保存的database到一个新的repo。

### 实际操作和脚本
&emsp;&emsp;第三个方案因为不是administor，没有实践，理论上应该可行。前两个通过github上实践验证，所有的history都保留完好，并且commit message和commit id都与原先一样。:satisfied:   
&emsp;&emsp;其中第一种方案适用于从remote repo cherry-pick一些CL到当前repo。比如需要从up-stream升级自己的code到相应版本，只是把checkout变成cherry-pick就好。  
&emsp;&emsp;另外还有不少已经push到gerrit但没有merge到仓库的CL，只能在git reflog找了，上面讲了，这个命令很有用。  

&emsp;&emsp;附方案二脚本:   

```bash
#!/bin/bash

# url of remote git
remoteurl=$1

# get all branchs
branchs=`git branch -r`

i=0

for branch in $branchs
do
  if [[ i -lt 3 ]]
  then
    # ignore the first three line. it's "origin/HEAD -> origin/master"
    i=$i+1
  else
    # push branch one by one
    git checkout $branch
    git branch
    remotebranch=${branch:7}
    echo "git push $remoteurl HEAD:$remotebranch"
    git push $remoteurl HEAD:$remotebranch
  fi
done
```

&emsp;&emsp;检查脚本：  
```bash
#!/bin/bash

#the local path of the updated database
dbb=$1

branchs=`git branch -r`

i=0

#update to the latest
pushd $dbb
git fetch --all
popd

for branch in $branchs
do
  if [[ i -lt 3 ]]
  then
    i=$i+1
  else
    # compare head of branch one by one
    echo $branch
    a=`git log --oneline -1 $branch`
    pushd $dbb > /dev/null
    b=`git log --oneline -1 $branch`
    popd > /dev/null
    echo $a
    echo $b
    if [ "$a" = "$b" ]; then
      echo "match"
    else
      echo "mismatch"
    fi
  fi
done
```

## Reference
[**Git Doc**](https://git-scm.com/doc)  
[**Atlassian Doc**](https://www.atlassian.com/git)