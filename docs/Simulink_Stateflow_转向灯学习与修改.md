# Simulink/Stateflow 转向灯项目学习路线

## 先看清楚模型与工程的关系

当前 IAR 工程中的 `TurnLight.c`、`TurnLightArb.c`、`TurnLightAct.c` 是由 Simulink/Stateflow 模型生成的 C。工程目录原来没有保留 `.slx`，模型已从课程压缩包恢复到：

`G:\S32K144_Start_TurnLight_IAR_20260912\ModelSource`

其中包含 `TurnLight.slx`、`TurnLightArb.slx`、`TurnLightAct.slx` 以及 `TurnLightActLib.slx`。不要直接在 IAR 生成的 C 文件上长期修改；生成代码会在下次代码生成时被覆盖。

## 三个 SWC 的职责

```text
CAN 0x210
   │
   ▼
TurnLight.slx（输入解释、危险警告、左/右请求、优先级）
   │ TurnLightService
   ▼
TurnLightArb.slx（把 ALL/LEFT/RIGHT 和 ON/OFF 仲裁成 FL/FR/RL/RR 四路命令）
   │
   ▼
TurnLightAct.slx（每路 10 ms 节拍、400 ms 亮/灭、DIO 和 0x200 状态）
   │
   ├── IoHwAb → PTD0/PTD1/PTD15/PTD16 → LED2~LED5
   └── Com → 0x200 LA_St_DirectionLampL/R
```

三者都由 `Rte.c` 中同一个 10 ms 调度序列调用：`TurnLight` → `TurnLightArb` → `TurnLightAct`。因此 IAR 中看到的 Runnable 名称就是模型中的 Runnable。

## 如何打开模型

在 MATLAB 当前目录中执行：

```matlab
addpath(genpath('G:\S32K144_Start_TurnLight_IAR_20260912\ModelSource'))
open_system('G:\S32K144_Start_TurnLight_IAR_20260912\ModelSource\TurnLight\TurnLight.slx')
open_system('G:\S32K144_Start_TurnLight_IAR_20260912\ModelSource\TurnLightArb\TurnLightArb.slx')
open_system('G:\S32K144_Start_TurnLight_IAR_20260912\ModelSource\TurnLightAct\TurnLightAct.slx')
```

如果 MATLAB 提示找不到 `TurnLightActLib`，必须先执行上面的 `addpath(genpath(...))`，因为 `TurnLightAct.slx` 内部使用了 Stateflow 库 `TurnLightActLib.slx`。

打开后先不要改图。双击顶层的 `Runnable_10ms`，再进入 `Runnable_10ms_sys`，观察四组子系统：`FL_TurnLightActuator`、`FR_TurnLightActuator`、`RL_TurnLightActuator`、`RR_TurnLightActuator`。

## Stateflow 状态机阅读方法

阅读每个 Chart 时按四件事记录：状态、进入条件、状态动作、退出条件。例如 `TurnLight` 的控制图：

```text
IDLE
 ├─ IGN=2/3 且 TurnLampSw=1 → LEFT
 └─ IGN=2/3 且 TurnLampSw=2 → RIGHT

LEFT/RIGHT
 ├─ 短拨：进入 ShortFlash
 ├─ 长拨：进入 LongFlash
 └─ TurnLampSw=0 → IDLE
```

危险警告图用 `HazardSw` 上升沿产生 `HazardRqst`。选择器随后把请求转成：

```text
ALLOFF、LEFTON、RIGHTON、ALLON
```

`TurnLightArb` 的 truth table 再把这些服务请求映射为四路输出：

```text
LEFT + ON  → FL=1, RL=1
RIGHT + ON → FR=1, RR=1
ALL + ON   → FL=FR=RL=RR=1
ALL + OFF  → 四路=0
```

每个 `TurnLightAct` 子系统只负责自己的一路：输入 0/1/2/3 分别代表关闭、普通闪烁、短闪和双闪节拍；调用 IoHwAb 前还会转换为低有效 LED 所需的 DIO 电平。

## 这次实物实验对应的模型信号

```text
00 20 00 00 01 00 00 00
```

在 `TurnLight` 模型中对应：`IGN_Status=2`、`HazardSw=0`、`TurnLampSw=1`。应经过：

```text
TurnLight_B.TurnLampSWRst = 1
TurnLight_B.TurnLight_Decide = LEFTON
TurnLightArb: FL=1, RL=1, FR=0, RR=0
TurnLightAct: LED2/LED4 闪烁
```

## 已发现的模型问题

原始 `TurnLightAct.slx` 顶层中，`RL_TurnLightActuator` 的输出错误连接到 `Com_CAN_LA_St_DirectionLampR_u8_signal_write`。因此左转时 RL=1 会被错误当成右侧 CAN 状态，导致 `0x200` 可能报告左右都 ON；物理 LED 仍然正确，因为四个 IoHwAb 输出连接没有错。

我已生成一个学习用修正版副本：

`G:\S32K144_Start_TurnLight_IAR_20260912\ModelSource\TurnLightAct\TurnLightAct_fixed.slx`

修正版将左右 CAN 状态改为：

```text
LA_St_DirectionLampL = max(FL, RL)
LA_St_DirectionLampR = max(FR, RR)
```

这样左转时左状态为 ON、右状态为 OFF；右转时相反；双闪时两侧都为 ON。MATLAB 已成功加载并执行模型更新检查。原始模型和修正版都保留，不覆盖课程文件。

## 下一步修改流程

1. 先在 MATLAB 打开原始 `TurnLightAct.slx`，熟悉四个 actuator 子系统和每个 Stateflow Chart；
2. 打开 `TurnLightAct_fixed.slx`，对照顶层新增的两个 `max` 汇总块；
3. 在 Simulink 中执行 Model Update，确认没有红色未解析模块；
4. 用模型仿真或 MIL 测试确认三组输入：左转、右转、双闪；
5. 再研究 AUTOSAR 代码生成设置，把修正后的模型重新生成 `TurnLightAct.c`；
6. 最后复制生成代码到 IAR 工程并编译、下载、用 TSMaster 回归三个场景。

在重新生成代码以前，不要把 `TurnLightAct_fixed.slx` 直接替换现有 IAR 工程文件。该模型仍依赖课程中的 AUTOSAR/Stateflow 配置和 `TurnLightActLib`，应先完成模型级验证。
