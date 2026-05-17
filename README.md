# Project Overview: Laser-Guided Robot Sorting (Orange Robot)

This project controls an **ABB IRB120 6-axis robot** to automatically process workpieces from a 4x4 pickup grid (S1), inspect them for quality using a color sensor (S2), and transfer them to a destination grid (S4) on a second platform.

The system features **dynamic laser-guided picking**, allowing it to detect the presence and height of workpieces in real-time.

## 🛠 Features & Final Implementation

| Feature | Contributor | Description |
| :--- | :--- | :--- |
| **Laser-Guided Picking** | **Maks** | Uses a Sick distance sensor to detect parts and calculate dynamic Z-descent. |
| **Snake-Loop Transfer** | **Simona** | Optimized traversal logic for the 4x4 grid to minimize robot travel time. |
| **Interactive UI** | **Ivan** | FlexPendant `TPReadFK` dialogs for operator authorization and status tracking. |
| **Dual-Platform Logic** | **Maks** | Implements full transfer from Pickup (S1) to Destination (S4). |
| **Advanced Error Handling**| **Bea** | Detects empty slots, unstable gripper signals, and sensor failures. |
| **Real-Time Statistics** | **Bea** | Tracks Total, Approved (Blue/Green), Rejected (Yellow), and Unknown (Red). |

## 🚦 Logic & Error Handling (ABB RAPID)

### Laser Picking Logic (`ProcessTransfer`)
1.  **Measurement:** Robot approaches the grid cell; laser points directly at the piece.
2.  **Detection:** If `AI_SensorSick > -50`, the piece is present.
3.  **Alignment:** Robot shifts X/Y by `LASER_OFFSET_X/Y` to center the gripper over the piece.
4.  **Descent:** Robot descends to `block_height + GRIP_DEPTH` for a precise pick.

### Fault Responses
- **Error 1 (Empty Slot):** Laser detects `measured_val <= -50`. Slot is skipped.
- **Error 2 (Grip Fail):** Laser saw a block but `DI_GripperClose = 0` after closing. Cycle stops for safety.
- **Error 3 (Sensor Fail):** No color detected at S2. Cycle stops; return Home.
- **Error 4 (Invalid Color):** Red detected. Logged as "Unknown"; cycle continues.

## 📋 Team Roadmap (Next Session Checklist)

- [ ] **Ivan:** Implement PLC Handshake signals (`SetDO` for Busy/Done) - *Currently marked with TODO in code.*
- [ ] **Simona:** Verify if the **40mm offset** matches the physical grid in the lab.
- [ ] **Maks:** Re-teach the reference points (`pGrid_Pick_Ref`, `pGrid_Dest_Ref`) on the real controller.
- [ ] **Bea:** Calibrate the `-50` laser threshold with a real block and the table.

## 🚀 Development Workflow
1. **Pull:** `git pull origin feat/laser-measure`
2. **Load:** Sync `g1-code.mod` to the virtual or real controller.
3. **Run:** Set PP to `main` and monitor the FlexPendant for "READY".
