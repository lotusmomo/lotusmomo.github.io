---
title: 基于 PYNQ-Z2 的 HDMI 开发系列 01 - 输出测试图
date: 2025-03-11 23:11:25
tags: []
categories: FPGA 入门
---

本系列为 ZYNQ7000 视频处理的第一篇博客。该系列准备介绍一下 FPGA 上的视频处理流程。

<!--more-->

# 创建 Block Design

![block-design](block-design.svg)

双击 ZYNQ7 处理器系统 IP 进行配置。在“Clock Configuration”部分的“PL Fabric Clocks”下,启用 FCLK_CLK1 并将其时钟频率设置为 40 MHz。

添加 Video Timing Controller (VTC) IP 并双击打开其配置 GUI。
在“Detection/Generation”标签中，单击“Include AXI4-Lite Interface”并取消单击“Enable Detection”。
在“Default/Constant”标签中，将视频模式设定为 1280x720p。

双击 rgb2dvi IP 进行配置。将 TMDS 的时钟范围更改为“<80 MHz (720p)”，然后单击“OK”。

# 管脚约束
略。官网有文档：https://www.tulembedded.com/FPGA/ProductsPYNQ-Z2.html

然后生成 Bitstream, 导出包含 Bitstream 的工程。

# 软件部分

从 Vivado 启动 Vitis, 并选择我们刚刚导出的工程，创建一个 Helloworld。

修改代码

```c
#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xv_tpg.h"

XV_tpg tpg_inst;
int Status;

int main()
{
    init_platform();

    print("Hello World\n\r");

    /* TPG Initialization */
    Status = XV_tpg_Initialize(&tpg_inst, XPAR_V_TPG_0_DEVICE_ID);
    if(Status!= XST_SUCCESS)
    {
    	xil_printf("TPG configuration failed\r\n");
        return(XST_FAILURE);
    }

    // Set Resolution to 1280x720
    XV_tpg_Set_height(&tpg_inst, 720);
    XV_tpg_Set_width(&tpg_inst, 1280);

    // Set Color Space to RGB
    XV_tpg_Set_colorFormat(&tpg_inst, 0x0);

    //Set pattern to color bar
    XV_tpg_Set_bckgndId(&tpg_inst, XTPG_BKGND_COLOR_BARS);

    //Start the TPG
    XV_tpg_EnableAutoRestart(&tpg_inst);
    XV_tpg_Start(&tpg_inst);
    xil_printf("TPG started!\r\n");
    /* End of TPG code*/

    cleanup_platform();
    return 0;
}
```

编译并运行，此时会把 Bitstream 下载到 FPGA。

# 观察现象

串口会输出，此时显示器会显示彩条的 Test Pattern。

![output](output.png)