MODULE MainModule
    ! --- ROBOT TARGETS (Global Coordinates) ---
    
    ! S1: Pickup Grid Reference. 
    ! This point is calibrated so the LASER beam points at the center of the first cell.
    CONST robtarget pGrid_Pick_Ref := [[369.55,-109.66,109.91],[2.62996E-05,7.84211E-05,-1,-9.95705E-06],[-1,0,-1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! S4: Destination Grid Reference.
    ! Base point for the second platform where workpieces are delivered.
    CONST robtarget pGrid_Dest_Ref := [[370.96, -347.85,118.52], [0.000146671,6.84201E-05, -1, -9.78187E-05], [-1, -1, -1,0], [9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! S2: Color Sensor Station.
    ! The exact position where the block is held for color inspection.
    CONST robtarget pSensor_Measure := [[266.90,275.43,180.12],[9.3566E-05,-0.709263,-0.704944,0.000120329],[0,0,1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! S0: Home Position.
    ! A safe resting point for the robot, clear of all grid platforms.
    CONST robtarget pHome := [[275.9205,0.02080205,667.3802],[0.7115182,-0.1236367,0.6797782,-0.1278957],[-1,0,-1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! --- SYSTEM CONSTANTS & CALIBRATION ---
    
    ! Physical offset (mm) between the laser beam and the center of the pneumatic gripper.
    CONST num LASER_OFFSET_X := 0; 
    CONST num LASER_OFFSET_Y := 27;  
    
    ! Calibration values for the Sick analog distance sensor.
    CONST num EMPTY_THRESHOLD := 24; 
    CONST num GRIP_DEPTH := 5; ! Extra descent for secure pneumatic contact.

    ! 4x4 Grid layout constants (standardized to 45mm spacing).
    CONST num GRID_ROWS := 3;
    CONST num GRID_COLS := 5;
    CONST num OFFSET_X := 39; 
    CONST num OFFSET_Y := 39; 

    ! --- GLOBAL BATCH STATISTICS ---
    VAR num count_total := 0;    ! Total blocks moved
    VAR num count_correct := 0;  ! Blue/Green (Approved)
    VAR num count_wrong := 0;    ! Yellow (Rejected)
    VAR num count_empty := 0;    ! Empty cells encountered
    VAR num count_unknown := 0;  ! Red/Undefined

    ! --- PROCESS STATE FLAGS ---
    VAR bool operatorReady := FALSE;
    VAR bool blockPicked := FALSE;
    VAR bool measurementValid := FALSE;
    
    ! Error handling flags
    VAR bool Error_NoPart := FALSE;
    VAR bool Error_GripperFault := FALSE;
    VAR bool Error_SensorFailure := FALSE;
    VAR bool Error_InvalidColour := FALSE;
    VAR bool System_ResetRequired := FALSE;
    
    VAR num answer; ! Dialog response holder

    ! ===========================================================================
    ! SYSTEM MAIN-PROGRAM
    ! ===========================================================================
    
    PROC main()
        VAR robtarget current_pick;
        VAR robtarget current_dest;
        VAR num row;
        VAR num col;
        VAR num x_offs;
        VAR num y_offs;

        ! Reset all counters and flags
        InitProgram; 

        ! --- STEP 1: OPERATOR AUTHORIZATION ---
        ! Interactive dialog on the FlexPendant to ensure safety before movement.
        TPWrite "SYSTEM: Place workpieces on the Pickup Grid (S1).";
        TPReadFK answer, "Confirm workpieces are ready?", "READY", "", "", "", "";
        
        IF answer = 1 THEN
            operatorReady := TRUE;
            TPWrite "SYSTEM: Cycle authorized. Starting...";
        ELSE
            TPWrite "SYSTEM: Operation aborted by operator.";
            RETURN;
        ENDIF

        ! Move to home to clear any manual workspace setup
        TPWrite "MOVING: Safe Home (S0)...";
        MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
        
        ! --- STEP 2: GRID PROCESSING LOOP ---
        ! Traverses the 4x4 grid using a Snake-wise pattern to optimize pathing.
        TPWrite "LOOP: Starting 4x4 Transfer Cycle...";
        FOR row FROM 0 TO GRID_ROWS - 1 DO
            FOR col FROM 0 TO GRID_COLS - 1 DO
                y_offs := row * OFFSET_Y;
                
                ! SNAKE LOGIC: Even rows move L->R, Odd rows move R->L
                IF row MOD 2 = 0 THEN
                    x_offs := col * OFFSET_X;
                ELSE
                    x_offs := (GRID_COLS - 1 - col) * OFFSET_X;
                ENDIF
                
                ! Calculate the base point for the current cell on both platforms
                current_pick := Offs(pGrid_Pick_Ref, x_offs, y_offs, 0);
                current_dest := Offs(pGrid_Dest_Ref, x_offs, y_offs, 0);
                
                ! Execute the complex Pick-Inspect-Place sequence
                ProcessTransfer current_pick, current_dest;
            ENDFOR
        ENDFOR
        
        ! --- STEP 3: FINALIZATION ---
        TPWrite "SYSTEM: Batch complete. Returning Home...";
        MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
        
        ! Output batch results to FlexPendant console
        ShowResults; 
    ENDPROC

    ! ===========================================================================
    ! SYSTEM SUB-PROCEDURES
    ! ===========================================================================
    
    ! Reset all variables to start a fresh batch.
    PROC InitProgram()
        TPErase;
        count_total := 0;
        count_correct := 0;
        count_wrong := 0;
        count_empty := 0;
        count_unknown := 0;
        operatorReady := FALSE;
        blockPicked := FALSE;
        measurementValid := FALSE;
        Error_NoPart := FALSE;
        Error_GripperFault := FALSE;
        Error_SensorFailure := FALSE;
        Error_InvalidColour := FALSE;
        System_ResetRequired := FALSE;
    ENDPROC

    ! Handles the entire lifecycle of a single workpiece transfer.
    PROC ProcessTransfer(robtarget pick_pos, robtarget dest_pos)
        VAR robtarget approach_pick;
        VAR robtarget approach_dest;
        VAR robtarget actual_grip_pos;
        VAR robtarget actual_approach_pos;
        VAR num measured_val;
        VAR num block_height;
        
        ! Safety approach heights (50mm above the target point)
        approach_pick := Offs(pick_pos, 0, 0, 50); 
        approach_dest := Offs(dest_pos, 0, 0, 50);
        
        ! --- SUB-STEP A: LASER SENSING ---
        ! Position the laser beam directly over the workpiece at the calibrated height
        MoveJ pick_pos, v200, fine, t_grijper1\WObj:=wobj0;
        WaitTime 0.2; ! Stabilize analog sensor signal
        
        measured_val := AI_SensorSick;
        
        ! Detection: If distance is at or near the table baseline (24), the slot is empty.
        ! We use a +/- 2 unit tolerance.
        IF measured_val >= (EMPTY_THRESHOLD - 2) AND measured_val <= (EMPTY_THRESHOLD + 2) THEN
            count_empty := count_empty + 1;
            Error_NoPart := TRUE;
            TPWrite "SENSING: S1 Position Empty. Skipping...";
            RETURN;
        ENDIF

        ! --- SUB-STEP B: DYNAMIC PICKUP ---
        ! Calculate workpiece height: 
        ! Empty(24) - Measured(-43) = 67mm height.
        block_height := EMPTY_THRESHOLD + measured_val;
        
        ! Shift target from Laser Center to Gripper Center using hardware offsets.
        ! Apply the dynamic Z-depth (negative move down) based on height.
        actual_grip_pos := Offs(pick_pos, LASER_OFFSET_X, LASER_OFFSET_Y, block_height + GRIP_DEPTH);
        actual_approach_pos := Offs(actual_grip_pos, 0, 0, 50);
        
        ! Singularity Handling: Prevent wrist locking during the dynamic X/Y shift
        SingArea\Wrist;
        ConfL\Off;

        MoveJ actual_approach_pos, v100, z10, t_grijper1\WObj:=wobj0;
        MoveL actual_grip_pos, v50, fine, t_grijper1\WObj:=wobj0;

        ConfL\On; ! Restore standard movement configuration

        SetDO DO_Gripper, 1;
        WaitTime 1; ! Physical settling time
        
        ! Verification: Ensure the block was actually picked via pneumatic feedback
        IF DI_GripperClose = 0 THEN
            Error_GripperFault := TRUE;
            System_ResetRequired := TRUE;
            TPWrite "ERROR: Gripper missed the block! Emergency Stop.";
            SetDO DO_Gripper, 0;
            MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
            STOP;
        ENDIF

        blockPicked := TRUE;
        count_total := count_total + 1;
        
        ! --- SUB-STEP C: INSPECTION & DELIVERY ---
        ! Ascend safely before moving to the sensor station
        MoveL actual_approach_pos, v100, z10, t_grijper1\WObj:=wobj0;
        
        ! Run the color measurement routine
        MeasureColor;
    
        ! Transfer to the second platform (S4)
        MoveJ approach_dest, v200, z10, t_grijper1\WObj:=wobj0;
        MoveL dest_pos, v50, fine, t_grijper1\WObj:=wobj0;
    
        SetDO DO_Gripper, 0; ! Release block
        WaitTime 0.5;
        blockPicked := FALSE;
    
        MoveL approach_dest, v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC
    
    ! Handles movement and logic at the color sensor station (S2).
    PROC MeasureColor()
        SingArea\Wrist;
        ConfL\Off;
        MoveJ Offs(pSensor_Measure, 0, 0, 50), v200, z10, t_grijper1\WObj:=wobj0;
        MoveL pSensor_Measure, v50, fine, t_grijper1\WObj:=wobj0;
        ConfL\On;
        WaitTime 0.5; ! Let color sensor stabilize

        ! Safety check: If no light/color is detected at all, sensor may be unplugged.
        IF DI_Color_1 = 0 AND DI_Color_2 = 0 AND DI_Color_3 = 0 AND DI_Color_4 = 0 THEN
            Error_SensorFailure := TRUE;
            System_ResetRequired := TRUE;
            TPWrite "ERROR: Color sensor signal lost! Emergency Stop.";
            MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
            STOP;
        ENDIF

        ! Map binary input signals to statistics
        IF DI_Color_4 = 1 OR DI_Color_3 = 1 THEN
            count_correct := count_correct + 1;
            measurementValid := TRUE;
            TPWrite "S2: Color APPROVED (Blue/Green)";
        ELSEIF DI_Color_2 = 1 THEN
            count_wrong := count_wrong + 1;
            measurementValid := TRUE;
            TPWrite "S2: Color REJECTED (Yellow)";
        ELSEIF DI_Color_1 = 1 THEN
            count_unknown := count_unknown + 1;
            measurementValid := FALSE;
            TPWrite "S2: Color INVALID (Red)";
        ENDIF

        MoveL Offs(pSensor_Measure, 0, 0, 50), v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC

    ! Prints a summary table of the batch to the FlexPendant.
    PROC ShowResults()
        TPWrite "==========================";
        TPWrite " FINAL BATCH REPORT ";
        TPWrite "==========================";
        TPWrite " Total Processed:   " \Num:=count_total;
        TPWrite " Approved (B/G):    " \Num:=count_correct;
        TPWrite " Rejected (Y):      " \Num:=count_wrong;
        TPWrite " Invalid (R):       " \Num:=count_unknown;
        TPWrite " Empty Cells:       " \Num:=count_empty;
        TPWrite "==========================";
    ENDPROC

ENDMODULE
