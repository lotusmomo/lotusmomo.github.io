---
title: 自适应遥感水印
date: 2022-09-23 18:02:00
updated: 2022-11-05 12:04:31
tags: []
categories: 日常
---
问题可以分成两部分解决：**自适应**与**水印**。

<!--more-->

## 自适应 (Adaptive)
由于处理的目标数据为遥感图像。典型的遥感图像如下：
![图片来自LEVIR-CD](/legacy/imgs/15d22b9217501fee6ad3531e235abb82.png)
### 共同要求
- #### 针对遥感图像自适应（主要创新点）
  > 要结合遥感图像的特征，如果简单的将遥感图当作普通图像来处理，那就没意思。
  >
  > 分为显式特征与隐式特征：
  >
  > - 显式：地物类型，地物特征；
  > - 隐式：在神经网络中引入上下文注意（Context Attention）。
- #### 水印要具有鲁棒性（Robustness）
  > 能抗多种攻击。
- #### 水印要有不可感知性
  > 评价指标：峰值信噪比（PSNR）。
### 方案1
#### 主要内容
修改地物的pattern，将水印携带的信息隐藏在生成的pattern中，或者pattern就是水印本身，且要求与原有的背景看起来不突兀。
> [Jia, X., Wei, X., Cao, X., and Han, X., “Adv-watermark: A Novel Watermark Perturbation for Adversarial Examples”, <i>arXiv e-prints</i>, 2020.](https://arxiv.org/abs/2008.01919)
对图像做一次**语义分割（Semantic segmentation）**或者**实例分割（Instance segmentation）**，用*某种算法（？）*挑选出最适合进行显式修改（explicit modification）的pattern，然后使用`Generative Networks`生成对应的pattern，但是这个pattern里面嵌了水印。这样做的好处就是肉眼几乎无法分辨，因为是`GAN`生成的pattern。一开始，我尝试了`DCGAN`，主要考虑到`DCGAN`所生成的模型是可线性叠加的，只要用不同类别的地物训练出不同的模型，再分别赋以不同的权重，即可生成具有不同风格的伪遥感图像；具体的权重应该可以通过对标的地块进行简单的地物分类得出，这类算法已相对成熟。这是我所设想出的一种自适应的方法。
#### 研究阻碍
对遥感数据的GAN极其难做，我首先尝试生成低分辨率的遥感图形。
> [Radford, A., Metz, L., and Chintala, S., “Unsupervised Representation Learning with Deep Convolutional Generative Adversarial Networks”, <i>arXiv e-prints</i>, 2015.](https://arxiv.org/abs/1511.06434)
`DCGAN`原论文使用的数据集是`ImageNet`，里面什么数据都有。我尝试将数据集替换为`AID`数据集中的操场进行训练，但是效果十分不理想。模型最后是收敛的，但是生成的都是噪声，说明模型实际上并没有学习到遥感图的任何特征。后来我换了一个分辨率较低的数据集，用了海岸线的数据集，生成的图像正常。这应该是由于特征太少导致的。
但是正如前面失败的实验，正常的遥感图不可能只要那么简单的特征。后来我上网搜索，几乎所有尝试复现的中文资料都表明遥感图的GAN实验结果是不理想的。我又尝试模仿`StyleGAN`（该模型是英伟达专为人脸的生成打造的，在人脸的生成方面数一数二），用全连接层替换了`DCGAN`中的卷积层，但是实验效果仍不理想（跟之前一样是噪声但是模型仍然收敛）。
> [Karras, T., Laine, S., Aittala, M., Hellsten, J., Lehtinen, J., and Aila, T., “Analyzing and Improving the Image Quality of StyleGAN”, <i>arXiv e-prints</i>, 2019.](https://arxiv.org/abs/1912.04958)
后来我改变了思路，推测出一种可能，那就是一般的卷积无法处理遥感图像这种具有复杂特征的数据。我将目光转向了`Transformer`，也就是注意力机制，它不依赖任何卷积，我期望它能够在我之后的实验中起到一个比较好的效果。但是由于我对注意力机制不太熟悉，有花了一段时间研究了一下`ViTGAN`和`TransGAN`，这两个都是将 `Transformer` 加入 `GAN` 的网络。
> [Lee, K., Chang, H., Jiang, L., Zhang, H., Tu, Z., and Liu, C., “ViTGAN: Training GANs with Vision Transformers”, <i>arXiv e-prints</i>, 2021.](https://arxiv.org/abs/2107.04589)
> [Jiang, Y., Chang, S., and Wang, Z., “TransGAN: Two Pure Transformers Can Make One Strong GAN, and That Can Scale Up”, <i>arXiv e-prints</i>, ](https://arxiv.org/abs/2102.07074)
*在这一步我们甚至可以大胆假设，能不能不光在`GAN`中引入注意力机制，甚至在整个对抗生成网络中都使用`Transformer`？*
### 方案2
#### 主要内容
将水印隐藏在噪声中，向图像叠加噪声，使人眼无法识别。
有文献提出，将水印识别单独置一个 `private network` ，与发布网络 `public network` 相隔离。这样我们在识别水印时只要调用 `private network` 即可。我认为相比起图像里包含的显式特征，想要学习噪声这种隐式特征是尤为困难的。这本质上类似于神经网络的特征过拟合。
为了使这种过拟合现象明显一些（这正是我们需要的），就不能使用普通的噪声。有一种噪声（包括但不限于噪声，可以是任何信号甚至pattern）专为实现这种目的而存在，即**对抗样本攻击**。我们只需要对遥感数据做一次对抗样本攻击，即可使图像分类的 `softmax` 产生较大的改变（即误分类）。我们这时就可以设置一个新的类，比如 `watermark` ，使所有经过对抗样本攻击的遥感图像被分类为 `watermark` 。
![](/legacy/imgs/6bc12d07df84d108676ed0d8dcc192c9.jpg)
> [Chen, L., Zhu, G., Li, Q., and Li, H., “Adversarial Example in Remote Sensing Image Recognition”, <i>arXiv e-prints</i>, 2019.](https://arxiv.org/abs/1910.13222)（遥感图像识别中的对抗性实例）
到这个地步，这个方向的目的已经十分明显了：这就是鲁棒性的对抗。
对于目标网络来说，要保证目标识别的鲁棒性（即`CNN`的鲁棒性）；作为隐藏信息，嵌入水印的一方，要保证自己水印的鲁棒性，要保证自己生成的对抗性样本能够抵御各种攻击。
*可能的防御手段：用魔法打败魔法。假如这里有若干张待识别的遥感图像，你不知道其中有没有对抗性样本，同时你对你的`CNN`网络不太自信，这时候只需要在前面加上一层`GAN`网络。因为高频的水印（噪声）信息不太可能被`GAN`所识别到，并且在生成的网络中复现。对于采用了注意力机制的`GAN`如上面提到的`TransGAN`与`ViTGAN`尤其如此。*
> 
#### 困难&疑惑
- 使用对抗样本攻击所生成的噪声为空间域噪声，鲁棒性不佳；
- 此方法致力于使判别网络产生误判，从而将图像置于*Watermark*类，只能起到标记的作用。
  假如仅仅是这样，为何不直接用加水印的照片与未加水印的照片训练一个*Network*专门由于分类加了水印的图片呢？
  > 忘了哪一篇了
- 此方法只能应用于地物分类模型
这个算自适应吗？他跟普通图像的处理流程有什么不同呢？步骤必须有意义，比方说遥感图加了一个处理步骤，或者用了一种新的处理方法后，比使用通用图像的处理方法处理后效果要好，etc。
#### 实验结果
> [基于FGSM的对抗样本实例](https://colab.research.google.com/drive/15l7f5sECpimhRFCaxXhgjowr3-cWTTsF)
## 水印（Watermark）
### 传统方法
+ 基于空间域的水印（鲁棒性不强）
+ 基于频率域，如傅里叶，小波，DCT的水印算法
> [W. Chen, C. Zhu, N. Ren, T. Seppänen and A. Keskinarkaus, "Screen-Cam Robust and Blind Watermarking for Tile Satellite Images," in IEEE Access, vol. 8, pp. 125274-125294, 2020, doi: 10.1109/ACCESS.2020.3007689.](https://ieeexplore.ieee.org/document/9136707)
### 攻击方法
+ 旋转
+ 裁剪，拼接
+ 重采样（缩放）
+ 滤波（中值，均值，高斯）
+ 噪声（椒盐，高斯）
+ 投影变换
+ Screen-Cam Robust
*必须有一种有效的定位手段，确认水印在图像的哪一部分。*
> 难道就没有一种水印他的信息是与其完整性无关的吗？即只要拿到水印的任意部分都能完整的还原出信息。
> 遥感图一般是以瓦片Tile的形式存在，当前的图像过大或者过小都会自动切换到上一级或下一级显示。
### 目前方向
#### 水印同步(Synchronization Watermark)
> 基于CNN定位精度，Robust
#### 水印提取(Watermark Extraction)
> 基于CNN/DNN的判读法
#### 水印嵌入
> Pattern + Image 基于感知与Robust
> [You, Zhengxin, et al. "Image Generation Network for Covert Transmission in Online Social Network." *Proceedings of the 30th ACM International Conference on Multimedia*. 2022.](https://dl.acm.org/doi/abs/10.1145/3503161.3548139) 将CelebA换成GID训练遥感地块的Pattern来生成水印。
## 遥感数据的图像生成
最近把**遥感数据GAN的实验结果**整理出来，现在做成什么样就什么样。要明确现在**实验数据**、GAN是否**调参**过，生成数据的结果，目前的最新的相关论文大概是什么样。
目前的图像生成方法主要有：
+ GANs: DCGAN, StyleGAN, WGAN
+ VAEs: VQ-VAE, Beta-VAE, FactorVAE
+ Augoregressive Models: PixelCNN
+ Diffusion Models: DDPM
目前对抗生成网络在遥感方面的应用
+ 遥感图超分辨率
+ 遥感图像分类
+ 伪遥感图的生成
DCGAN实验发现效果不理想
然后尝试使用Transformer模型代替传统卷积。
#### 实验结果
##### 2022年9月22日 22:28
![DCGAN in Remote Sense Images](/legacy/imgs/cd51eb3ad5daf1eb1e0f1d73839b204f.png)
>  *总结* ：
>
>  需加大Epoch数。但由于数据集过小，很难训练出一个很好的模型。实验证明，只要合理调整参数，`DCGAN`一样可以生成很好的伪遥感图......
>
>  至于为什么上学期的实验总是不成功，我觉得可能的原因有：
>
>  1. 上学期的实验主要使用了`Tensorflow`，而且本学期换用了`Pytorch`；
>  2. 上学期参数调得不好，训练了很多轮但是效果总是不好，误认为传统的`CNN`网络做不了遥感；
>  3. 玄学问题（大虚。
##### 2022年9月13日
![Generator and Discriminator Loss](/legacy/imgs/ce41fcdfc8bb49334e814c06e3d88eaf.png)
