# Project Overview: Laser-Guided Robot Sorting (Orange Robot)

This project controls an ABB IRB120 6-axis robot to automatically process workpieces from a 4x4 pickup grid (S1), inspect them for quality using a color sensor (S2), and transfer them to a destination grid (S4) on a second platform.

The system features dynamic laser-guided picking, enabling the robot to handle workpieces of varying heights by calculating a dynamic Z-descent in real-time.

## Features and Implementation

| Feature | Contributor | Implementation Detail |
| :--- | :--- | :--- |
| **Laser-Guided Picking** | **Maks** | Uses a Sick distance sensor to detect presence and calculate dynamic Z-descent. |
| **Snake-Loop Transfer** | **Simona** | Optimized traversal logic for the grids to minimize robot travel time. |
| **Interactive UI** | **Ivan** | FlexPendant prompts for operator authorization and status tracking. |
| **Dual-Platform Logic** | **Maks** | Implements the transfer of parts from Pickup (S1) to Destination (S4). |
| **Advanced Error Handling**| **Bea** | Detects empty slots, unstable signals, and sensor failures. |
| **Real-Time Statistics** | **Bea** | Tracks Total, Approved (Blue/Green), Rejected (Yellow), and Unknown (Red). |

## Logic and Error Handling (ABB RAPID)

### Laser Picking Logic (ProcessTransfer)
1. **Measurement:** Robot approaches the grid cell with the laser centered.
2. **Detection:** If AI_SensorSick > -50, the piece is present.
3. **Alignment:** Robot shifts X/Y by LASER_OFFSET_X/Y to center the gripper over the piece.
4. **Descent:** Dynamic Z-offset based on measured distance + GRIP_DEPTH.

### Fault Responses
- **Error 1 (Empty Slot):** Laser detects measured_val <= -50. Slot is skipped.
- **Error 2 (Grip Fail):** Laser saw a block but DI_GripperClose = 0 after closing. Emergency stop.
- **Error 3 (Sensor Fail):** No color detected at S2. Return Home and stop.
- **Error 4 (Invalid Color):** Red detected. Logged as "Unknown"; cycle continues.

## Final Calibration Checklist (Lab Tasks)

The following parameters must be verified on the physical hardware:

1. **Laser Hardware Offset:** Measure and update `LASER_OFFSET_X` and `LASER_OFFSET_Y` (current placeholder is 25mm).
2. **Reference Points:** Fine-tune `pGrid_Pick_Ref` and `pGrid_Dest_Ref` coordinates on the real controller.
3. **Sensor Thresholds:** Verify that the -50mm threshold accurately detects the table surface.

## Development Workflow
1. Sync the latest `feat/laser-measure` branch.
2. Load `g1-code.mod` and verify tool data (`t_grijper1`).
3. Set PP to `main` and run.

---
*Note: Advanced industrial PLC hardware handshaking and robot timeouts were removed from scope as FlexPendant handshaking fulfilled requirements.*
