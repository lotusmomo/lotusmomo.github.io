---
title: 反爬虫的极致手段——利用Gzip压缩炸弹
date: 2022-08-01 23:27:00
updated: 2022-08-02 00:07:35
tags: []
categories: 奇技淫巧
---

作为一个站长，你一定对爬虫恨之入骨。爬虫天天来爬，速度又快，频率又高，服务器的大量资源被白白浪费而不给你创造任何收益。本文假设你已经知道某个请求是爬虫发来的了，你不满足于单单屏蔽对方，而是想搞死对方。

<!--more-->

很多人的爬虫是使用Requests来写的，如果你阅读过Requests的文档，那么你可能在文档中的常见问题看到这样一段文字：
> Requests 自动解压缩的 `gzip` 编码的响应体，并在可能的情况下尽可能的将响应内容解码为 `unicode`。
>
> 如果需要的话，你可以直接访问原始响应内容（甚至是套接字）。

网站服务器可能会使用`gzip`压缩一些大资源，这些资源在网络上传输的时候，是压缩后的二进制格式。客户端收到返回以后，如果发现返回的`Headers`里面有一个字段叫做`Content-Encoding`，其中的值包含`gzip`，那么客户端就会先使用`gzip`对数据进行解压，解压完成以后再把它呈现到客户端上面。在浏览器上，这完全是一个自动化的过程，用户是感知不到这个事情发生的。而`Requests`，`Scrapy`这种网络请求库或者爬虫框架，也会帮你做这个事情，因此你不需要手动对网站返回的数据解压缩。这原本是帮助服务器节省流量开支的行为，但是利用这个特性，我们同样可以做到反爬虫。

我们首先写一个客户端，来测试一下返回`gzip`压缩数据的方法。
我首先在硬盘上创建一个文本文件`text.txt`，里面有两行内容，如下图所示：

![cat_test_txt.png](/legacy/imgs/2938691791.png)

然后使用`gzip`命令把它压缩成一个`.gz`文件：

```bash
cat test.txt| gzip > data.gz
```

接下来，我们使用`FastAPI`写一个HTTP服务器`server.py`

```python
#! /usr/bin/python3
# save-as: server.py
# Requirements:
# python3 -m pip install fastapi uvicorn
from fastapi import FastAPI, Response
from fastapi.responses import FileResponse
app = FastAPI()
@app.get('/')
def index():
    resp = FileResponse('data.gz')
    return resp
```

然后使用命令`uvicorn server:app`启动这个服务。
接下来，我们使用requests来请求这个接口，会发现返回的数据是乱码，如下图所示：

```python
#! /usr/bin/python3
# save-as req.py
import requests
res = requests.get('http://127.0.0.1:8000').text
print(res)
```

![cat_test_txt.png](/legacy/imgs/3430014703.png)

![fastapi_log_messy.png](/legacy/imgs/205120399.png)

返回的数据是乱码，这是因为服务器没有告诉客户端，这个数据是`gzip`压缩的，因此客户端只有原样展示。由于压缩后的数据是二进制内容，强行转成字符串就会变成乱码。
现在，我们稍微修改一下`server.py`的代码，通过`Headers`告诉客户端，这个数据是经过`gzip`压缩的：

```python
#! /usr/bin/python3
# save-as: server_gzip.py
# Requirements:
# python3 -m pip install fastapi uvicorn
from fastapi import FastAPI, Response
from fastapi.responses import FileResponse
app = FastAPI()
@app.get('/')
def index():
    resp = FileResponse('data.gz')
    resp.headers['Content-Encoding'] = 'gzip'  # 说明这是gzip压缩的数据
    return resp
```

再使用命令`uvicorn server_gzip:app`启动这个服务，再次使用requests请求，发现已经可以正常显示数据了：

![res_good.png](/legacy/imgs/2546853461.png)

![fastapi_log_good.png](/legacy/imgs/546238108.png)

这个功能已经展示完了，那么我们怎么利用它呢？这就不得不提到压缩文件的原理了。
文件之所以能压缩，是因为里面有大量重复的元素，这些元素可以通过一种更简单的方式来表示。压缩的算法有很多种，其中最常见的一种方式，我们用一个例子来解释。假设有一个字符串，它长成下面这样

```
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
0000000000000000
```

我们可以用5个字符来表示：`0*128`。这就相当于把128个字符压缩成了5个字符，压缩率高达96.1%。

> 这种利用信息熵极低的数据生成的压缩率极高且解压后数据量极大的压缩包被称为压缩炸弹(Zip Bomb)，比较著名的有`42.zip`，[下载地址](https://unforgettable.dk/)。大致内容如下：
> >
> > The file contains 16 zipped files, which again contains 16 zipped files, which again contains 16 zipped files, which again contains 16 zipped, which again contains 16 zipped files, which contain 1 file, with the size of 4.3GB.
> > So, if you extract all files, you will most likely run out of space :-)
> > 16 x 4294967295       = 68.719.476.720 (68GB)
> > 16 x 68719476720      = 1.099.511.627.520 (1TB)
> > 16 x 1099511627520    = 17.592.186.040.320 (17TB)
> > 16 x 17592186040320   = 281.474.976.645.120 (281TB)
> > 16 x 281474976645120  = 4.503.599.626.321.920 (4,5PB)
> >
> > Password: 42
> >
> 压缩文件本身大小`42KB`这个文件用密码42解压之后，会得到16个压缩文件，然后每个文件解压又会出现16个压缩文件，继续每个文件解压又会得到16个压缩文件，循环5次，最终得到1048576个文件，每个最终文件大小为`4.3GB`，总共`4.5PB`。
如果我们可以把一个1GB的文件压缩成1MB，那么对服务器来说，仅仅是返回了1MB的二进制数据，不会造成任何影响。但是对客户端或者爬虫来说，它拿到这个1MB的数据以后，就会在内存中把它解压成1GB的内容。
这样一瞬间爬虫占用的内存就增大了1GB。如果我们再进一步增大这个原始数据，那么很容易就可以把爬虫所在的服务器内存全部沾满，轻者服务器直接杀死爬虫进程，重则爬虫服务器直接死机。
这个压缩比听起来很夸张，其实我们使用很简单的一行命令就可以生成这样的压缩文件。

```bash
dd if=/dev/zero bs=1M count=1000 | gzip > boom.gz
```

![boom_gzip.png](/legacy/imgs/883190545.png)

生成的这个`boom.gz`文件只有994KB。但是如果我们使用`gzip -d boom.gz`对这个文件解压缩，就会发现生成了一个1GB的`boom`文件，如下图所示：

![real_boom.png](/legacy/imgs/3574187962.png)

只要大家把命令里面的`count=1000`改成一个更大的数字，就能得到更大的文件。
我现在把`count`改成10，给大家做一个实验。生成的`boom.gz`只有10KB：

![little_boom.png](/legacy/imgs/1400469115.png)

服务器返回一个10KB的二进制数据，没有任何问题。
现在我们用`requests`去请求这个接口，然后查看一下`res`这个对象占用的内存大小：

![size_of_boom.png](/legacy/imgs/1893723029.png)

由于`requests`自动会对返回的数据解压缩，因此最终获得的`res`对象竟然有10MB这么大。
如果大家想使用这个方法来反爬虫，一定要先确定这个请求是爬虫发的。否则被你干死的不是爬虫而是真实用户就麻烦了。
