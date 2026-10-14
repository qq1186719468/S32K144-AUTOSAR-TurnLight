# TSMaster + 周立功 CAN 盒子：转向灯实物联调指南

本指南针对 `S32K144_Start_new_IAR` 转向灯工程和 S32K144 V1.3 学习板。当前工程使用 FlexCAN0，外部 CAN 接口使用 J3，波特率为 500 kbit/s。

## 1. 导入哪一个 DBC

导入工程目录中的：

`G:\S32K144_Start_TurnLight_IAR_20260912\S32K144_Start_new_IAR\Inputfiles\CAN.dbc`

不要导入 `CAN_II.dbc`。后者是旧版门状态/室内灯报文定义，当前转向灯需要的 `0x210` 转向输入信号不在其中。

`CAN.dbc` 中与本实验有关的定义如下：

| 报文 | 十进制 ID | DLC | 方向 | 用途 |
|---|---:|---:|---|---|
| `msg_Receive` | 528 | 8 | TSMaster → ECU | 点火、危险警告、转向开关、灯反馈 |
| `msg_Transmit` | 512 | 2 | ECU → TSMaster | 左右转向灯输出状态 |

TSMaster 有的界面显示十进制 ID，有的显示十六进制。`528` 和 `0x210` 是同一个 ID；`512` 和 `0x200` 是同一个 ID。

## 2. 第一次建立 TSMaster 工程

不同版本的菜单名称可能略有区别，但功能名称基本相同。

1. 插入周立功 CAN 盒子，安装并打开其驱动/设备管理工具，确认设备在线。
2. 打开 TSMaster，使用 **新建工程/新建配置**，保存为例如 `S32K144_TurnLight`。工程文件放在不含中文和空格的目录，例如 `G:\TSMasterProjects\S32K144_TurnLight`。
3. 在 **硬件/设备/通道配置** 中选择周立功 CAN 盒子对应的 CAN 通道。先只启用一个通道，记下它在 TSMaster 中显示的逻辑通道号。
4. 打开该通道的 CAN 参数，将波特率设为 **500 kbit/s**，工作模式设为 **Normal/正常模式**。先不要启用回环模式。
5. 在 **数据库/Database** 面板选择 **添加数据库/导入 DBC**，导入：

   `G:\S32K144_Start_TurnLight_IAR_20260912\S32K144_Start_new_IAR\Inputfiles\CAN.dbc`

6. 将该数据库分配给刚才选择的 CAN 通道。导入后应能看到 `msg_Receive (0x210)` 和 `msg_Transmit (0x200)`；如果看到的 `0x210` DLC 是 1，说明导入了错误的 `CAN_II.dbc`。
7. 保存工程。此时先不要启动周期发送。

## 3. 硬件连接和启动检查

断电后检查开发板：

- 周立功盒子 `CANH` → 开发板 **J3-CANH**；
- 周立功盒子 `CANL` → 开发板 **J3-CANL**；
- 周立功盒子 `GND` → 开发板 `GND`；
- J1 至少安装 `PTE5—SBC_CAN_TX` 和 `PTE4—SBC_CAN_RX` 对应跳线；
- J2 安装 `3–4、5–6、7–8、9–10`，分别连接四路 GPIO 到 LED2~LED5；
- 开发板上电后，确认电源指示灯正常。

J3 对应 CAN0/UJA1169 路径；J6 对应 CAN1/TJA1050，当前工程不要把 CAN 线接到 J6。

在 IAR 中 **Download and Debug** 后按绿色运行按钮（Go）。如果 CPU 停在断点，先继续运行，否则 10 ms Runnable 和 CAN 接收任务不会持续执行。

## 4. 用原始字节发送第一帧

先使用 TSMaster 的 **发送面板/Tx Panel/Message Transmit**，不要一开始使用脚本。添加一条 CAN 周期发送项：

| 项目 | 值 |
|---|---|
| 通道 | 连接周立功盒子的 CAN 通道 |
| 帧类型 | Standard/标准帧 |
| ID | `0x210`（若界面按十进制填 `528`） |
| DLC | 8 |
| 周期 | 100 ms |
| 初始数据 | `00 20 00 00 00 00 00 00` |

先启动测量，再启动这条周期帧，保持约 1 秒。这个中立帧的含义是 IGN=2、无危险警告、转向开关关闭、四路反馈为正常。

然后将同一条帧的第 5 个字节改为 `02`，继续周期发送：

```text
ID   0x210    DLC 8
DATA 00 20 00 00 02 00 00 00
```

预期右前/右后 LED3、LED5 以约 400 ms 亮、400 ms 灭的节奏闪烁。左转使用：

```text
ID   0x210    DLC 8
DATA 00 20 00 00 01 00 00 00
```

预期 LED2、LED4 闪烁。危险警告使用：

```text
ID   0x210    DLC 8
DATA 00 21 00 00 00 00 00 00
```

危险警告是边沿触发：先发 `00 20 ...`，再发 `00 21 ...`；再次关闭时同样要先回 0，再发 1。

## 5. 用 DBC 信号发送

如果 TSMaster 的发送面板能展开 DBC 信号，添加 `msg_Receive` 后可直接填写信号：

| DBC 信号 | 中立 | 左转 | 右转 | 说明 |
|---|---:|---:|---:|---|
| `IGN_Status` | 2 | 2 | 2 | 必须为 2 或 3 才允许转向 |
| `TurnLampSw` | 0 | 1 | 2 | 转向开关 |
| `HazardSw` | 0 | 0 | 0 | 危险警告开关 |
| `TurnLampFb_FL/FR/RL/RR` | 0 | 0 | 0 | 0 表示无故障 |
| `VehicleSpeed_Valid` | 0 | 0 | 0 | 首轮实验可保持 0 |

设置这些信号后，让 TSMaster 自动计算数据字节。若计算结果与上面的原始数据不一致，优先检查 ID 是否选成 `0x210`、信号是否选成 `msg_Receive`，以及界面是否把 ID 当作十进制。

## 6. 每一步应观察什么

TSMaster 中同时打开 **Trace/报文监视** 和 CAN 错误统计：

1. 能看到 TSMaster 周期发出的 `0x210`，说明 CAN 盒子发送功能正常；
2. 没有 Error Frame、Bus-off、ACK 错误，说明物理层和终端电阻基本正常；
3. IAR 在 `TurnLightAct_Runnable_10ms()` 或 `Cdd_IoHwAb.c` 的四个 `Dio_WriteChannel()` 断点命中，说明报文已经过 Can → Com → RTE → SWC → IoHwAb；
4. 写入 DIO 的值为 `0` 时 LED 点亮，为 `1` 时 LED 熄灭，因为板上 LED 是低电平有效；
5. ECU 发出的 `0x200` 应在 Trace 中出现，DLC 为 2。DBC 中它包含左右灯状态。

断点验证完成后应禁用断点再继续测量；停在 10 ms 任务里会阻塞后续通信，容易把正常程序误判成 CAN 故障。

## 7. 无灯光时的定位顺序

按这个顺序排查，不要同时修改多个地方：

1. 电源灯是否正常；
2. J2 四组跳线是否安装；
3. IAR 是否已 Go、CPU 是否仍停在断点；
4. TSMaster Trace 是否有周期 `0x210`；
5. `0x210` 是否为标准帧、500 kbit/s、DLC 8；
6. IAR 是否进入 `TurnLightAct_Runnable_10ms()`；
7. `Dio_WriteChannel()` 是否写入 0；
8. 若已写 0 仍不亮，再检查 J2、LED 电源和 GPIO 电压。

当前工程的 UJA1169 代码主要周期读取寄存器，没有在 `CddSbc.c` 中看到完整的 CAN 正常模式切换。因此，如果 TSMaster 发送正常但 IAR 收不到报文，下一步应检查 SBC/UJA1169 的工作模式和 J1 的 SPI/片选跳线，而不是先改应用层算法。

## 8. 切换实验时的状态保留

`0x210` 是输入报文，里面的 `TurnLampSw` 只表示方向盘开关；左右灯的输出状态位于 ECU 返回的 `0x200`，即 `LA_St_DirectionLampL/R`。当前示例工程的 `TurnLightArb.c` 在接收到左/右侧 ON 命令时只更新被选中的一侧，没有在每次新模式下显式清零另一侧输出。因此在右转、双闪、左转连续切换时，可能短时间看到 `0x200` 左右均为 ON，这属于现有模型的状态保留问题，不是 `0x210` 同时包含左右转向命令。

切换方向前，先用中立帧发送 1~2 秒，确认 `0x200` 两侧均为 OFF；若仍保留旧状态，停止测量、重新下载或复位 ECU 后再开始下一项实验。每项实验最好从中立帧开始，避免把上一个场景的输出状态带入当前场景。

## 9. 推荐的后续实验顺序

完成右转后再依次做：左转、危险警告开关、输出 `0x200` 观察、四路反馈故障注入、CAN 断线/恢复、IAR 断点观察 10/100/300 ms Runnable。每次只改变一个输入，并记录 TSMaster 报文、IAR 断点变量和 LED 结果。

## 10. `0x200` 左右状态与物理 LED 不一致时

当前生成的 `TurnLightAct.c` 存在一个接口映射问题：右侧 CAN 状态 `Com_CAN_LA_St_DirectionLampR_u8_signal` 所在的执行图（`<S5>/TurnLampActuator`）读取的是 `TurnLamp_RL_Out_u8_Signal`，也就是左后灯 RL；左侧 CAN 状态则由 FL 执行图写入。于是左转时 `FL=1、RL=1、FR=0、RR=0`，物理 LED2/LED4 正确闪烁，但 `0x200` 可能同时报告左右 ON。正确的 CAN 状态应分别由 `FL OR RL` 和 `FR OR RR` 汇总。此问题需要在 Simulink 模型/RTE 映射中修复，或临时在 TurnLightAct 输出处重新计算左右汇总状态；不要据此判断物理灯接线错误。
