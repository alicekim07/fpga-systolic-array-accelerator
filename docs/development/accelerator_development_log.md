# FPGA AI Accelerator Development Log

This document serves as an engineering development log for the FPGA-based AI accelerator project.

This document summarizes the major engineering challenges encountered during the development of an FPGA-based INT8 AI accelerator and the solutions implemented to resolve them.

The accelerator was implemented on a **PYNQ-Z2 (Xilinx Zynq-7020)** platform and targets matrix-multiplication-like workloads derived from neural network layers.

Throughout the development process, several architectural, numerical, and system-level issues were encountered.  
Each issue required investigation across multiple layers of the system, including hardware architecture, controller logic, memory mapping, and software–hardware interaction.

---

## 1. Initial Goal

The initial objective of this project was to implement a **Fully Connected (FC) layer accelerator on FPGA**, and later extend the architecture toward **MobileNetV2 inference acceleration**.

Future work includes platform-level performance comparison between:

- CPU
- FPGA (PYNQ-Z2)
- Jetson platform

At the current stage, the **FPGA accelerator implementation is complete**, while cross-platform benchmarking is planned as future work.

---

## 2. Accelerator Architecture Implementation

The accelerator architecture was implemented using a **systolic-array-based compute core** with on-chip SRAM buffers.

The memory hierarchy consists of:

- **ISRAM (Input SRAM)**
- **WSRAM (Weight SRAM)**
- **PSRAM (Partial Sum SRAM)**

These buffers enable tiled execution of matrix multiplication workloads.

Major architectural components include:

- Systolic array compute engine
- On-chip SRAM buffer management
- Tile scheduling controller
- AXI-based host communication interface

---

## 3. AXI4-Lite Hardware Interface

A hardware interface based on **AXI4-Lite** was implemented to allow communication between the Processing System (PS) and the Programmable Logic (PL).

This interface supports:

- parameter configuration
- memory base address setup
- accelerator execution control
- execution status monitoring

This mechanism allowed host software to configure and launch accelerator operations.

---

## 4. Controller FSM Design

A dedicated **controller FSM** was implemented to coordinate the execution flow of the accelerator.

The controller manages:

- systolic array scheduling
- SRAM read/write control
- DMA execution sequencing
- write-back operations

The write-back logic enables computed results to be transferred back to system memory and accessed by host software.

---

## 5. Fully Connected Layer Weight Mapping

Weight data for fully connected layers was mapped into **WSRAM** based on the systolic array dataflow.

The mapping strategy ensured:

- efficient weight streaming
- SRAM reuse
- compatibility with tiled matrix multiplication execution

This enabled efficient acceleration of FC layers using the systolic architecture.

---

## 6. Stateful Hardware Register Bug

### Problem

During iterative inference execution, inconsistent results were observed.

The first inference run occasionally produced unstable outputs.

### Investigation

Tracing the execution flow revealed that the hardware register:
```
BASE_WSRAM_WH
```

was **not reset between iterations**.

As a result, the weight base address configured for a previous layer remained active in the next iteration.

This caused the FC1 layer to reference incorrect weight memory locations.

### Solution

The HW–SW interface protocol was redesigned so that the following registers are **explicitly initialized before each layer execution**:

- `BASE_WSRAM`
- `BASE_WSRAM_WH`

### Result

This modification eliminated **state leakage across iterations**, restoring deterministic inference behavior.

### Engineering Insight

Stateful hardware components can introduce subtle bugs when iterative execution is involved.  
Explicit reset and initialization policies are essential for reliable HW–SW interaction.

---

## 7. Hidden State Leakage Across Iterations

Following the previous issue, the accelerator was audited for **hidden hardware states persisting between inference iterations**.

Additional reset procedures were introduced to ensure that:

- internal buffers
- base address registers
- controller state variables

were consistently reinitialized before execution.

This eliminated non-deterministic behavior during repeated inference runs.

---

## 8. HW–SW Contract Redesign

To reduce debugging complexity and improve system reliability, the interaction protocol between software and hardware was formalized.

The new HW–SW contract clearly defined:

- parameter initialization order
- execution trigger mechanism
- memory buffer layout
- completion signaling

This formalization significantly improved debugging efficiency and reproducibility.

---

## 9. Simulation-Based Debugging

A Verilog testbench environment was developed to verify accelerator functionality before deployment on hardware.

The testbench enabled:

- controlled input stimulus
- cycle-level debugging
- waveform inspection
- controller logic validation

Simulation played a critical role in identifying controller logic issues and verifying memory access behavior.

---

## 10. Quantization Mismatch Issue (Activation Signedness)

### Problem

During INT8 inference validation, hardware results did not match the reference Python implementation.

### Investigation

Detailed analysis revealed that **activation signedness** was incorrectly interpreted in hardware.

Negative INT8 activation values were treated as large unsigned integers, causing inference outputs to diverge from the reference model.

### Solution

Proper **sign-extension logic** was implemented in the hardware datapath.

### Result

After correcting the signed interpretation of activation values, hardware inference results matched the software reference implementation.

### Engineering Insight

When implementing quantized neural networks in hardware, **numerical consistency between software and hardware implementations is critical**.

Small mismatches in signedness or scaling can completely break inference behavior.

---

## 11. Matrix Scaling Issue (Controller Valid Timing)

### Problem

Initial verification used small matrices such as:
```
(4×5) × (5×23)
```
These worked correctly.

However, when scaling to neural network workloads such as:
```
(1×784) × (784×128)
(1×128) × (128×10)
```
incorrect outputs appeared.

### Root Cause

The controller logic that generated the `systolic_valid_p` signal assumed that:
```
S ≥ PE_COL
```

or implicitly assumed a fixed value:
```
S = 4
```

This caused invalid timing windows when the input row dimension became small (e.g., `S = 1`).

### Solution

The controller logic was redesigned using a **sliding-window-based valid generation scheme**.

Key improvements:

- Valid window defined independently of matrix size
- Removal of hardcoded assumptions about `S`
- Output channel masking introduced

### Result

The controller now supports all cases:
```
S = 1
S < PE_COL
S ≥ PE_COL
```

### Engineering Insight

Controller logic must be designed **independently of specific matrix sizes** to ensure architectural scalability.

---

## 12. Data Transfer Architecture Redesign

### Problem

Initially, all communication between PS and PL was implemented using **AXI4-Lite**.

This created severe bottlenecks when transferring large tensors.

### Observation

Using `top.mmio` calls for bulk data transfer introduced significant software overhead.

### Solution

The architecture was redesigned to separate:

```
Parameter configuration: AXI4-Lite

Bulk data transfer: AXI4-Stream + DMA
```

Final architecture:

| Operation | Interface |
|----------|----------|
Parameter configuration | AXI4-Lite |
Input tensor transfer | AXI4-Stream |
Weight transfer | AXI4-Stream |
Bias transfer | AXI4-Stream |
Output transfer | AXI4-Stream |

### Result

This significantly reduced software overhead and improved data transfer efficiency.

### Engineering Insight

Separating **control path** and **data path** is essential for achieving high-throughput accelerator systems.

---

## 13. Timing Closure Optimization

### Problem

The initial design operated at:
```
25 MHz
```

When attempting to increase the clock frequency to **100 MHz**, Vivado reported **setup time violations**.

### Root Cause

Critical path analysis showed that the address generation logic performed:

- multiplication
- addition

within a single clock cycle, producing excessive combinational delay.

### Solution

The address generation pipeline was redesigned:

- MAC-style arithmetic operations split across two cycles
- pipeline registers introduced
- arithmetic paths separated from SRAM control logic
- FSM timing reorganized

### Result

The design achieved timing closure at:
```
100 MHz
```

Clock frequency improved:
```
25 MHz → 100 MHz
```

(4× increase)

### Hardware Validation

The optimized design was verified on the **PYNQ-Z2 board**.

To ensure synchronization between PS and PL:
```
PS–PL FCLK frequencies were aligned.
```

### Engineering Insight

Achieving high clock frequencies on FPGA often requires **architectural-level pipeline redesign**, not merely local logic optimization.

Further frequency scaling was intentionally avoided to balance:

- performance
- stability
- verification complexity.

The final design operates at **100 MHz**.