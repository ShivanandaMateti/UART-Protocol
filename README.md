# High-Speed UART Protocol with Hardware Retransmission & Parity Verification

A high-performance, parameterizable Universal Asynchronous Receiver-Transmitter (UART) design implemented in Verilog. This architecture is designed for a custom baud rate of **3.90625 Mbps** using asymmetric clock domains, featuring a dual-stage metastability synchronizer, an internal packet-framing matrix, hardware-driven retransmission via a prioritized `load` mechanism, and strict midpoint validation.

---

## Technical Design Specifications

* **Baud Rate**: $3,906,250 \text{ bps}$ ($3.9 \text{ MHz}$)
* **Frame Configuration**: 11-bit custom packet structure:
  * `1 Start Bit` (Driven `LOW`)
  * `8 Data Bits` (LSB first)
  * `1 Parity Bit` (Odd Parity: $P = \sim\left(^{\wedge}\text{data\_in}\right)$)
  * `1 Stop Bit` (Driven `HIGH`)
* **Clock Domains**:
  * **Transmitter Clock (`t_clk`)**: $16 \text{ ns}$ cycle duration ($62.5 \text{ MHz}$ base).
  * **Receiver Clock (`r_clk`)**: $5 \text{ ns}$ cycle duration ($200 \text{ MHz}$ base).

---

### 1. Top Module Core (`UART_Protocol`)
Located in `UART.v`, this top-level module encapsulates both the transmitter and receiver subsystems into a full-duplex core. It includes a hardware **metastability barrier (`stage2_sync`)** composed of two cascaded D-Flip-Flops (`d_ff`) to safely capture and stabilize the raw external serial line `Tx` into the receiver's clock domain.

### 2. Transmitter Subsystem
* **`baud_gen.v`**: Implements an explicit down-counter that divides the transmitter clock frequency down by a factor of 16 to generate synchronous periodic `baud_tick` assertions every $256 \text{ ns}$ ($\approx 260 \text{ ns}$ target baud rate window).
* **`frame_data` Module**: Automatically aggregates incoming 8-bit broadside data arrays with an embedded odd parity bit generated via reduction routing logic alongside static packet boundaries:
  $$\text{packet} = \{1'\text{b1}, \text{Parity}, \text{data\_in}[7:0], 1'\text{b0}\}$$
* **`transmitter` Engine**: Governed by sequential control shifting structures:
  * Prioritizes the `load` input signal over `send`. If `load` asserts, the system forces a retransmission of the previously shadowed internal cache register (`packet_load_ready`) to clear line collision errors.
  * Serially shifts out the data structure over the physical `Tx` wire via `packet_temp[0]` and maintains tracking up to bit window frame counter $b = 10$.

### 3. Receiver Subsystem
* **`Sample_gen.v`**: A clock dividing mechanism utilizing a 3-bit register to slice the receiver's master $5 \text{ ns}$ input clock down by a factor of 4. This produces a steady $20 \text{ ns}$ interval oversampling tick (`Sample_tick`), ensuring an exact $16\times$ oversampling matrix resolution per serial bit period.
* **`receiver` Core Engine**: Implements an algorithmic Finite State Machine (FSM) backed by a midpoint noise filter counter (`count_s`). 
  * Midpoint checks occur exactly when `count_s == SamplingWidth / 2` (Sample tick count index 8).
  * **FSM States**:
    * `idle`: Senses the initial falling edge transition of the serial `rx` wire.
    * `start`: Confirms valid entry condition if `rx` is still verified `LOW` at mid-bit phase.
    * `data`: Sweeps serial line values directly into intermediate array segments (`data_temp`).
    * `parity`: Re-evaluates incoming streams using odd parity check reduction: `rx == ~(^data_temp)`.
    * `stop`: Samples line for a valid trailing high termination. If successful, shifts data out to `data_correct` and moves to the `correct` terminal state.
    * `correct`: To give a confirmation on data received.Immedietely moves to the idle state to detect the falling edge. 
    * `error`: Asserts a recovery mode that fires the external `load` flag high to request immediate frame packet transmission corrections.

---

## Verification Suite and Test Sequences

The project features a highly thorough simulation matrix split across separate specialized environment setups (`Uart_transmitter_tb.v`, `Uart_receiver_tb.v`, and `UART_tb.v`).

### Automated Test Cases Executed:
1. **T-1: Ideal Packet Phase Validation**: Confirms completely flawless parallel processing throughput without internal anomalies.
2. **T-2: Suppressed Strobe Rejection**: Verifies that raw shifts applied to `data_in` without asserting a valid `send` enable trigger are ignored by the FSM pipeline.
3. **T-3: Asynchronous Mid-Frame Reset**: Confirms correct line release behavior and structural initialization safety boundaries when a global hardware reset occurs mid-transaction.
4. **T-4: Zero-Gap Back-to-Back Pipelines**: Floods the transmission link sequentially with continuous byte values (`0x00`, `0x01`, `0x80`, `0xFF`) to confirm zero-cycle stalls between stop and start boundaries.
5. **T-5: Deep Line Idle Saturation**: Pushes extended high-state intervals ($1280 \text{ ns}$) onto the wire to prove the line remains quiescent and error-free when silent.
6. **T-6: Frame Break Integrity Testing**: Intentionally drops a packet's stop frame bit to verify the FSM transitions directly to the recovery `error` branch and suppresses invalid outputs.
7. **T-7: Dynamic Multi-Pattern Stress Testing**: Alternates between complex high-frequency bit patterns (`0x55` [01010101] and `0xAA` [10101010]) to rule out inter-symbol interference and clock-skew errors.
8. **T-8: Clock Drift & Buffer Tolerances**: Artificially shifts sampling clock edges from an interval of 320 to 324 time units to evaluate and confirm mid-bit phase error margin tracking tolerance.

---
