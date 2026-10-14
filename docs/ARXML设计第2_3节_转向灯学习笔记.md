# ARXML 设计第 2、3 节：转向灯工程复盘

## 0. 先区分两种 ARXML

课程第 2、3 节主要设计应用层 SWC 的 ARXML，描述“有哪些软件组件、端口、接口、数据和 Runnable”。它不直接配置 CAN 波特率、MCU 时钟或 PTD 引脚。

| 类型 | 工程目录 | 主要内容 |
|---|---|---|
| 应用设计 ARXML | `Config/Developer/` | DataType、PortInterface、SWC、Runnable、Composition |
| ECUC/底软配置 ARXML | `Config/ECUC/` | Mcu、Port、Dio、Can、CanIf、Com、OS、RTE 参数 |

应用设计完成后，才由 ECU 集成和 ECUC 配置把软件组件接到通信栈、OS、RTE 和硬件上。

## 1. 第 2 节：定义数据和接口

### 1.1 定义实现数据类型

文件：`Config/Developer/DataTypes.arxml`

转向灯工程中可以看到：

- `uint8` 等基础实现类型；
- `ComplexTurnLightONOFFType`：服务中的开关量；
- `ComplexTurnLightPositionType`：NOREQUEST、LEFT、RIGHT、ALL 等位置枚举；
- `TurnLightService`：包含位置、开关、占空比、周期、次数、编号、优先级的结构体。

这样做的目的，是先统一“接口上传递的数据长什么样”。例如 TurnLightService 不是一个普通的 uint8，而是一个具有多个字段的结构。

### 1.2 定义 Sender-Receiver 接口

文件：`Config/Developer/PortInterfaces.arxml`

一个 Sender-Receiver 接口通常包含：

```text
Sender-Receiver Interface
 └─ VariableDataPrototype
     ├─ SHORT-NAME：数据元素名
     └─ TYPE-TREF：数据类型
```

转向灯中的典型接口包括：

- `TurnLampSw`：转向开关输入；
- `IGN_Status`：点火状态；
- `HazardSw`：危险警告开关；
- `TurnLampFb_FL/FR/RL/RR`：四路反馈；
- `TurnLampCtrlCmd_FL/FR/RL/RR`：四路控制命令；
- `CountSignal_Left/Right`：左右计数反馈；
- `TurnLampSwMode`：转向灯模式输出。

这些接口表达的是“传递数据”，所以应用层使用 Rte_Read/Rte_Write 一类访问方式。

### 1.3 定义 Client-Server 接口

同一个 `PortInterfaces.arxml` 中还定义了：

```text
TurnLightService
 └─ TurnLightControl_Operation
```

该接口表达的是“调用服务”，不是简单读写信号。TurnLight SWC 作为客户端请求灯光服务，TurnLightArb SWC 作为服务器执行服务。

IoHwAb 的 `Operation` 也使用 Client-Server 方式，把 TurnLightAct 的控制命令交给硬件抽象层。

## 2. 第 3 节：创建 SWC 和内部行为

### 2.1 创建 TurnLight SWC

文件：`Config/Developer/ComponentTypes/TurnLight.arxml`

当前组件结构是：

```text
TurnLight
 ├─ P-Port：TurnLampSwMode
 ├─ R-Port：TurnLampSw、IGN_Status、HazardSw 等输入
 ├─ R-Port：TurnLightService 客户端服务端口
 └─ InternalBehavior
     └─ TurnLight_Runnable_10ms
```

端口的含义：

- `P-PORT-PROTOTYPE`：组件向外提供数据或服务；
- `R-PORT-PROTOTYPE`：组件从外部读取数据或请求服务；
- `PROVIDED-INTERFACE-TREF`：P 端口提供哪个接口；
- `REQUIRED-INTERFACE-TREF`：R 端口需要哪个接口；
- `INIT-VALUE`：启动时没有有效数据时使用的初值。

例如，`TurnLight` 的 `TurnLampSw` 是 R-PORT，引用 `/PortInterfaces/TurnLampSw`；`TurnLampSwMode` 是 P-PORT，引用 `/PortInterfaces/TurnLampSwMode`。

### 2.2 定义 TurnLight 的 Runnable

`TurnLight_InternalBehavior` 中包含：

```text
TIMING-EVENT：TMT_TurnLight_Runnable_10ms
PERIOD：0.01
RUNNABLE-ENTITY：TurnLight_Runnable_10ms
```

这表示 RTE 每 10 ms 触发一次 `TurnLight_Runnable_10ms`。

Runnable 内部还声明：

- `DATA-RECEIVE-POINT-BY-ARGUMENTS`：本次运行要读取哪些 R-PORT 数据；
- `DATA-SEND-POINTS`：本次运行要写入哪些 P-PORT 数据；
- `SERVER-CALL-POINTS`：本次运行要调用哪些 Client-Server 服务。

因此，ARXML 不描述 Stateflow 的具体算法，而是描述算法运行时需要哪些输入、输出和服务。

### 2.3 创建 TurnLightArb SWC

文件：`Config/Developer/ComponentTypes/TurnLightArb.arxml`

```text
TurnLightArb
 ├─ P-Port：TurnLightService 服务端口
 ├─ P-Port：TurnLamp_FL_Out、FR、RL、RR
 ├─ OperationInvokedEvent：TurnLightControl_Operation
 └─ TurnLightArb_Runnable_10ms
```

它有两个触发来源：

1. `TurnLightControl_Operation` 被 TurnLight 调用时，执行服务操作；
2. 10 ms Runnable 周期执行，更新四路输出。

这个组件相当于仲裁层，把 LEFT、RIGHT、ALL 等服务请求转换为四路执行命令。

### 2.4 创建 TurnLightAct SWC

文件：`Config/Developer/ComponentTypes/TurnLightAct.arxml`

```text
TurnLightAct
 ├─ R-Port：四路 Arb 输出
 ├─ P-Port：四路控制命令和 CAN 状态
 ├─ R-Port：四个 IoHwAb Client-Server 端口
 └─ TurnLightAct_Runnable_10ms
```

它完成两件事：

1. 把 Arb 的逻辑输出转换成 IoHwAb 操作，最终调用 DIO 控制 LED；
2. 汇总四路灯状态，提供给 CAN 状态输出。

当前硬件连接是：

```text
FL → PTD0 → LED2
FR → PTD1 → LED3
RL → PTD15 → LED4
RR → PTD16 → LED5
```

### 2.5 定义 SWC Implementation

每个组件后面都有：

```xml
<SWC-IMPLEMENTATION>
  <SHORT-NAME>TurnLight_Implementation</SHORT-NAME>
  <BEHAVIOR-REF>...</BEHAVIOR-REF>
</SWC-IMPLEMENTATION>
```

它把“组件实现”绑定到“内部行为”。没有这个引用，工具知道组件接口，却不知道该使用哪个 Runnable 行为。

## 3. 从组件到 ECU 组合

文件：`Config/Developer/ECUProjects/S32K144_Start.arxml`

这里把组件实例和端口连接起来。例如：

```text
TurnLight.TurnLampCtrlCmd_FL
        ↓ Assembly SW Connector
TurnLightAct.TurnLampCtrlCmd_FL
```

典型连接包括：

- TurnLight → TurnLightArb：TurnLightService；
- TurnLightArb → TurnLightAct：四路灯输出；
- TurnLightAct → CddIoHwAb：四路硬件操作；
- TurnLightAct → TurnLight：计数和反馈信号。

这一步解决的是“哪个组件的哪个端口连接到哪个组件的哪个端口”。

## 4. ARXML 设计完成后发生什么

应用设计 ARXML 会被导入 ECU 集成工具，之后再结合 ECUC 配置：

```text
DataTypes/PortInterfaces/ComponentTypes
        ↓
ECU Composition / System Description
        ↓
RTE 生成
        ↓
Rte_TurnLight.h、Rte_TurnLightArb.h 等
        ↓
TurnLight_Runnable_10ms()
        ↓
Com、IoHwAb、Dio、Can
```

当前工程中可以核对：

- `Appl/Source/TurnLight.c`：`TurnLight_Runnable_10ms()`；
- `Appl/Source/TurnLightArb.c`：仲裁 Runnable；
- `Appl/Source/TurnLightAct.c`：执行 Runnable；
- `Appl/Source/TurnLight*/Rte_*.h`：组件 RTE 接口；
- `Appl/GenData/Rte.c`：周期和事件调度。

## 5. 用左转请求走一遍

注意，CAN 的 `0x210`、`0x200` bit 位是在后续 ECUC/Com 配置中定义的，应用 ARXML 本身只定义接口名称和数据类型。

左转时的完整关系是：

```text
0x210 的 TurnLampSw
 → Com 解包
 → R-PORT TurnLampSw
 → TurnLight_Runnable_10ms
 → TurnLightService 请求 LEFT
 → TurnLightArb
 → TurnLamp_FL_Out / TurnLamp_RL_Out
 → TurnLightAct
 → IoHwAb Operation
 → Dio PTD0 / PTD15
 → LED2 / LED4
```

这就是“ARXML 接口设计”与“底软通信配置”和“Simulink 算法”之间的连接点。

## 6. 自己复盘时的操作顺序

## 6.1 一个必须核对的接口编码问题

当前生成代码显示，`TurnLightArb` 和 `TurnLightAct` 对模式值 2、3 的命名不一致：

| 数值 | TurnLightArb.c | TurnLightAct.c/模型 |
|---:|---|---|
| 0 | OFF | OFF |
| 1 | NORMAL_ON | NORMAL_ON |
| 2 | DOUBLE_ON | SHORT_ON |
| 3 | SHORT_ON | DOUBLE_ON |

这不是学习时可以忽略的命名差异，而是两个 SWC 之间的接口契约风险。它可能导致 Arb 认为是双闪的请求，在 Act 中按短闪执行，反之亦然。修改模型前应统一数据字典/枚举定义，重新生成两个 SWC，并用左、右、双闪和故障短闪回归验证。当前 `TurnLightAct_fixed.slx` 只修复右侧 CAN 状态汇总，没有修复这个模式编码问题，也没有烧录。

1. 用 VS Code 打开 `Config/Developer/DataTypes.arxml`，先找 `TurnLightService`；
2. 打开 `PortInterfaces.arxml`，找到 `TurnLampSw` 和 `TurnLightService`；
3. 打开 `ComponentTypes/TurnLight.arxml`，逐个核对 R-PORT、P-PORT；
4. 找到 `TMT_TurnLight_Runnable_10ms` 和 `TurnLight_Runnable_10ms`；
5. 核对 Runnable 的 Receive、Send、Server Call；
6. 用同样方法查看 `TurnLightArb.arxml` 和 `TurnLightAct.arxml`；
7. 打开 `ECUProjects/S32K144_Start.arxml`，查看 Assembly Connector；
8. 最后回到生成的 RTE 头文件和 C 文件，对照接口是否变成了函数和变量。

## 7. 面试表达

可以这样回答：

> 我先在应用设计层定义数据类型和 Sender-Receiver/Client-Server 接口，再创建 TurnLight、TurnLightArb、TurnLightAct 三个 SWC，配置各自的 P/R 端口、10 ms TimingEvent、Runnable 数据访问和服务调用点，最后在 ECU Composition 中建立端口连接。工具根据这些 ARXML 生成 RTE 接口，底软 ECUC 再把通信 PDU、OS 调度和硬件资源映射到这些接口上。
