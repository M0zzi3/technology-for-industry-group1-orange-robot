# ICT Technology for Industry - Robot Sorting Project

## Project Overview
This project controls an ABB IRB120 6-axis robot to automatically process workpieces from a 4x4 grid. The robot detects whether a block is present, moves it to a color sensor for quality inspection (Approved: Blue/Green, Rejected: Yellow), and returns the block to its original position. At the end of the batch, it outputs the operational statistics.

## 👥 Team Roles & Responsibilities
*   **Maks:** Core Architecture, Git Repository Master, RobotStudio Station Setup, and Point Teaching.
*   **Simona:** Grid Math, Snake-Loop Navigation, and Flowchart Logic.
*   **Ivan:** Digital I/O Signals, PLC/Robot Handshaking, and Gripper Actuation.
*   **Bea:** Error Handling (Missing Parts, Timeouts) and Color Sensor Logic.

## Code Structure
*   `PROC main()`: Handles the initialization, waits for the operator, and executes the 4x4 grid scan.
*   `PROC ProcessBlock(robtarget target_pos)`: Manages the safe approach, descent, gripping, and return of a single block.
*   `PROC MeasureColor()`: Transports a gripped block to the sensor station and updates quality statistics.
*   `PROC ShowResults()`: Outputs the final batch data (correct/wrong/empty counts) to the FlexPendant.

## How to Contribute (VS Code ↔ RobotStudio Workflow)
1. Pull the latest code from this repository.
2. Edit `MainModule.mod` in VS Code.
3. In RobotStudio, right-click `T_ROB1` > `Load Module...` and select the updated `.mod` file.
4. Click **Apply** in the RAPID tab.
5. Test in the Simulator.
6. Commit and Push your changes.