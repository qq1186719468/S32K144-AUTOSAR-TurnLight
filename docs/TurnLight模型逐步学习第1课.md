# TurnLight.slx 逐步学习（第 1 课）

本课只学习 `TurnLight.slx`，暂不修改模型。目标是看懂它如何把 `0x210` 的输入状态转换成送给 `TurnLightArb` 的服务请求。

## 1. 打开模型

在 MATLAB 命令窗口执行：

```matlab
addpath(genpath('G:\S32K144_Start_TurnLight_IAR_20260912\ModelSource'))
open_system('G:\S32K144_Start_TurnLight_IAR_20260912\ModelSource\TurnLight\TurnLight.slx')
```

模型中有一个 `TurnLight_Init` 初始化事件和一个周期 Runnable：

```text
TurnLight_Init                 上电初始化
TurnLight_Runnable_10ms        每 10 ms 执行一次
```

## 2. 顶层端口怎么读

打开顶层后，左侧是输入，右侧是输出。信号名称中的 `u8`/`u16` 是数据宽度：`uint8` 或 `uint16`；`Signal` 表示 AUTOSAR Sender/Receiver 数据元素。

| 顶层端口 | 来源/去向 | 现实含义 |
|---|---|---|
| `IGN_Status_u8_signal` | CAN 输入 | 点火状态，2/3 才允许转向 |
| `TurnLampSw_u8_Signal` | CAN 输入 | 0 回中，1 左转，2 右转 |
| `HazardSw_u8_Signal` | CAN 输入 | 双闪开关，0/1 |
| `EmergencyBrakeLight_u8_Signal` | CAN 输入 | 紧急制动灯请求 |
| `CrashIntensity_u8_Signal` | CAN 输入 | 碰撞触发输入 |
| `VehicleSpeed_u16_signal` | CAN 输入 | 车速原始值 |
| `VehicleSpeed_Valid_u8_Signal` | CAN 输入 | 车速有效标志 |
| `TurnLampFb_FL/FR/RL/RR` | CAN 输入 | 四路灯故障反馈，0正常、1短路、2开路 |
| `CountSignal_Left/Right` | TurnLightAct 回读 | 左/右闪烁计数，供短拨/长拨判断 |
| `TurnLampCtrlCmd_FL/FR/RL/RR` | TurnLightAct 回读 | 诊断使用的四路实际控制命令 |
| `TurnLightSwMode_u8_signa` | 本 SWC 输出 | 0无模式，1短闪，2长闪 |

顶层的 `TurnLampCtrlCmd_*` 和 `CountSignal_*` 是诊断闭环输入，不是本课的主要控制输入。第一次阅读时先看 `IGN_Status`、`TurnLampSw`、`HazardSw`、`VehicleSpeed`。

模型截图：

- [TurnLight 顶层](G:/S32K144_Start_TurnLight_IAR_20260912/ModelSource/TurnLight/TurnLight_top.png)
- [10 ms Runnable 内部](G:/S32K144_Start_TurnLight_IAR_20260912/ModelSource/TurnLight/TurnLight_runnable.png)

## 3. Runnable 内部的四个层次

双击顶层 `TurnLight_Runnable_10ms`，进入 `TurnLight_Runnable_10ms_sys`。里面从左到右可按四块理解：

```text
输入端口
  ↓
HazardCtrlLogic       判断双闪/碰撞/紧急制动
TurnLightCtrlLogic    判断左转/右转、短拨/长拨
TurnLightSelector     在 ALLOFF/LEFTON/RIGHTON/ALLON 之间仲裁
TurnLightDiag         根据反馈注入短路/开路诊断服务
  ↓
TurnLightService 调用、TurnLightSwMode 输出
```

图中的 `From/Goto/Data Store Memory` 用于同一个 Runnable 内的信号传递或保存状态。它们不是 CAN 报文，也不是新的 ECU 接口。

三个主要 Chart 的职责不同：

- `HazardCtrlLogic` 只产生内部 `HazardRqst`，决定是否请求四灯；
- `TurnLightCtrlLogic` 只产生 `TurnLampSWRst`（0/1/2）和 `TurnLampSWMode`（0/1/2）；
- `TurnLightSelector` 根据两个请求决定调用左、右、全亮或全灭服务。

## 4. 第一个 Chart：TurnLightCtrlLogic

在 `TurnLight_Runnable_10ms_sys` 双击 `TurnLightCtrlLogic`，先只看状态名字，不要一开始看所有连线。

核心状态：

```text
IDLE = 1
LEFT = 2
RIGHT = 3
```

左右状态内部又有：

```text
Check1 → Check2 → ShortFlash 或 LongFlash
```

每 10 ms 执行一次，所以 `TurnLapmCount` 大约代表经过了多少个 10 ms 周期。

### 4.1 从 IDLE 进入左右转

代码对应 `TurnLight.c` 第 286～302 行：

```text
IGN_Status=2 或 3 且 TurnLampSw=1 → LEFT
IGN_Status=2 或 3 且 TurnLampSw=2 → RIGHT
```

因此右转实验帧：

```text
00 20 00 00 02 00 00 00
```

对应 `IGN_Status=2、TurnLampSw=2`；左转帧：

```text
00 20 00 00 01 00 00 00
```

对应 `IGN_Status=2、TurnLampSw=1`。

如果 `IGN_Status=0`，即使 `TurnLampSw=1/2`，也不会进入左右转状态。

### 4.2 为什么有 Check1、Check2

模型把拨杆动作分为短拨和长拨：

1. `Check1` 等待输入保持或释放；
2. `TurnLapmCount > 10` 后进入 `Check2`；
3. 较短动作进入 `ShortFlash`；较长动作进入 `LongFlash`；
4. `TurnLampSw=0` 时返回 `IDLE`。

当前 TSMaster 实验持续发送左/右值，因此最容易观察到的是 `LongFlash`/普通闪烁路径；短拨需要按时间精确改变报文。

### 4.3 两个关键输出

```text
TurnLampSWRst
  0：无左右转请求
  1：左转请求
  2：右转请求

TurnLampSWMode
  0：无模式
  1：短闪
  2：长闪
```

`TurnLampSWRst` 会送给 `TurnLightSelector`；`TurnLampSWMode` 通过顶层输出写回 RTE，但不是直接驱动 GPIO。

## 5. 第二个 Chart：HazardCtrlLogic

双击 `HazardCtrlLogic`。它读取：

```text
HazardSw
CrashIntensity
EmergencyBrakeLight
VehicleSpeed
VehicleSpeed_Valid
```

主要状态：

```text
OFF
ON_SW                 双闪开关触发
ON_Crash              碰撞触发
On_EmergencyBrake     紧急制动触发
```

该 Chart 的输出是内部信号 `HazardRqst`：

```text
HazardRqst=0：不请求四灯
HazardRqst=1：请求四灯
```

### 5.1 双闪为什么是边沿触发

模型保存：

```text
HazardSw_prev
HazardSw_start
```

只有检测到：

```text
HazardSw_prev = 0 且 HazardSw_start = 1
```

才把状态从 `OFF` 切换到 `ON_SW`。在 `ON_SW` 状态再次检测到 0→1 时退出。因此测试双闪要模拟“按键释放、再次按下”：

```text
00 20 00 00 00 00 00 00   // HazardSw=0，释放
00 21 00 00 00 00 00 00   // HazardSw=1，按下/触发
```

关闭时再重复一次 0→1 边沿。仅停止 TSMaster 发送不会改变 ECU 内保存的最后状态。

### 5.2 当前项目的边界

`CrashIntensity` 的端到端 RTE 连接当前并不完整，首次实验不要用碰撞输入验证。`VehicleSpeed` 在 DBC 中有比例因子，但当前代码主要按原始值比较；首轮保持 0 即可。

## 6. 第三个 Chart：TurnLightSelector

这个 Chart 是本 SWC 内的请求仲裁器，主要状态：

```text
ALLOFF
LEFTON
RIGHTON
ALLON
```

输入：

```text
TurnLampSWRst
HazardRqst
```

核心转换：

```text
ALLOFF + TurnLampSWRst=1 → LEFTON
ALLOFF + TurnLampSWRst=2 → RIGHTON
ALLOFF + HazardRqst=1     → ALLON
LEFTON/RIGHTON + HazardRqst上升沿 → ALLON
LEFTON/RIGHTON + TurnLampSWRst=0  → ALLOFF
ALLON + HazardRqst=0      → ALLOFF
```

进入这些状态时，Chart 调用服务子系统：

```text
TurnLight_ALLOFF
TurnLight_ALLON
TurnLight_LeftShort / LeftLong
TurnLight_RightShort / RightLong
```

服务参数中的 `TurnLightPosition` 是位置枚举：`LEFT`、`RIGHT`、`ALL`；`TurnLightOnOff` 是 `ON/OFF`；`TurnLightCycle`、`TurnLightNumber`、`TurnLightPriority` 给下游仲裁器使用。

本模型中：

```text
LEFTON  → TurnLightService(Position=LEFT)
RIGHTON → TurnLightService(Position=RIGHT)
ALLON   → TurnLightService(Position=ALL)
ALLOFF  → TurnLightService(Position=ALL, OnOff=OFF)
```

## 7. 第四个 Chart：TurnLightDiag

它读取每路反馈和对应控制命令：

```text
反馈 0：NORMAL
反馈 1：SHORT
反馈 2：OPEN
```

反馈为 1/2 且该路控制命令有效时，会调用短路关闭或开路双闪服务。这里的反馈来自 `0x210` 的 Byte2/Byte3，是测试注入量，并不是本板 LED 自动测量回采。

因此首轮实验必须保持：

```text
TurnLampFb_FL = 0
TurnLampFb_FR = 0
TurnLampFb_RL = 0
TurnLampFb_RR = 0
```

## 8. 用一帧左转报文走完整条路径

输入：

```text
0x210: 00 20 00 00 01 00 00 00
```

按 10 ms 周期观察：

1. COM/RTE 读取 `IGN_Status=2`、`TurnLampSw=1`；
2. `TurnLightCtrlLogic` 从 `IDLE` 进入 `LEFT`，输出 `TurnLampSWRst=1`；
3. `TurnLightSelector` 进入 `LEFTON`，调用 `TurnLight_LeftLong` 或 `TurnLight_LeftShort`；
4. `TurnLightArb` 接收服务参数，将其分解为 `FL=1、RL=1、FR=0、RR=0`；
5. `TurnLightAct` 让 LED2、LED4 按 400 ms 亮/灭；
6. `TurnLightAct` 生成 `0x200` 左右状态信号。

第 6 步目前受 `TurnLightAct.slx` 右侧状态连接错误影响，后续课程会修复它；这不影响第 5 步的四路物理 LED 输出。

## 9. 在 IAR 中对照模型

调试时建议只设置以下断点，并在命中后立即禁用高频断点：

```text
TurnLight.c:280       读取 IGN/TurnLampSw
TurnLight.c:537       调用 ALLOFF
TurnLight.c:559       调用 ALLON
TurnLightArb.c:187    仲裁 Runnable
TurnLightAct.c:74     执行 Runnable
```

Watch 变量：

```text
TurnLight_B.TurnLampSWRst
TurnLight_B.TurnLampSWMode
TurnLight_B.TurnLight_Decide
TurnLight_DW.is_c2_TurnLight
TurnLight_DW.HazardLightRqst_start
TurnLightArb_B.TurnLight_FL_Out
TurnLightArb_B.TurnLight_FR_Out
TurnLightArb_B.TurnLight_RL_Out
TurnLightArb_B.TurnLight_RR_Out
```

左转理想观察值：

```text
TurnLampSWRst = 1
TurnLight_Decide = LEFTON（枚举值3）
HazardLightRqst_start = 0
FL=1，RL=1，FR=0，RR=0
```

## 10. 本课练习

只做观察，不改代码：

1. 在 MATLAB 打开 `TurnLight.slx` 顶层和 `TurnLight_Runnable_10ms_sys`；
2. 找到三个主 Chart，分别记下输入、输出和状态名；
3. 用 TSMaster 发中立帧、左转帧、右转帧；
4. 在 IAR 中观察 `TurnLampSWRst`、`TurnLight_Decide` 和四路 `TurnLightArb_B` 输出；
5. 用 0→1 的 `HazardSw` 边沿测试 `HazardRqst`；
6. 暂时不要改 `TurnLight.c` 或生成 C 文件。

完成这些观察后，下一课再打开 `TurnLightCtrlLogic` 的 Stateflow 图，逐条解释每条 transition 的 `[条件]`、`{动作}` 和状态入口/出口动作。
