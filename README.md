# Project Overview: Robot Sorting (Orange Robot)

This project controls an **ABB IRB120 6-axis robot** to automatically process workpieces from a 4x4 grid (S1), inspect them for quality, and transfer them to a destination grid (S4) on a second platform.

## Features & Implementation
- **Snake-Wise Transfer:** The robot navigates the 4x4 pickup grid in a snake pattern to minimize travel distance. For every valid part found, it performs a transfer to the corresponding slot in the destination grid.
- **Grid Calibration:** Uses **58mm offsets** (X and Y) as specified by team measurements (Simona).
- **Interactive Start:** Uses FlexPendant `TPReadFK` prompts to synchronize with the operator (Ivan).
- **Intelligent Error Handling:** Detects empty slots via gripper feedback (`DI_GripperClose`) and skips measurement/transfer for that slot (Bea).
- **State Tracking:** Uses internal boolean flags (`operatorReady`, `blockPicked`, `Error_NoPart`) to track the process flow.

## Hardware Configuration
- **S1 (Pickup):** `pGrid_Pick_Ref` (Reference Point)
- **S4 (Destination):** `pGrid_Dest_Ref` (Reference Point)
- **S2 (Sensor):** `pSensor_Measure`
- **Signals:** `DO_Gripper`, `DI_GripperClose`

## Remaining Tasks (TODOs)
- [ ] **PLC Handshaking:** Implement physical `SetDO` signals for `Robot_Busy` and `Robot_Done`.
- [ ] **Color Sensor Mapping:** Replace the `MeasureColor` placeholder logic with real Digital Input checks for Blue, Green, and Yellow.
- [ ] **Final Point Teaching:** Verify the physical coordinates of `pGrid_Dest_Ref` in RobotStudio.

## Development Workflow
1. Edit `g1-code.mod` in VS Code.
2. Load module into RobotStudio (`T_ROB1`).
3. Set PP to `main` and run simulation.
4. Verify grid alignment and I/O feedback.
