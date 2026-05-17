MODULE MainModule
    ! --- ROBOT TARGETS ---
    ! S1: Pickup Grid Reference (Pointed where the LASER centers on the workpiece)
    CONST robtarget pGrid_Pick_Ref := [[366.55, -83.67,109.91],[4.42542E-06,6.16962E-05, -1, 1.16894E-05], [-1,-1, -1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! S4: Destination Grid Reference (Second Platform)
    CONST robtarget pGrid_Dest_Ref := [[370.96, -347.85,118.52], [0.000146671,6.84201E-05, -1, -9.78187E-05], [-1, -1, -1,0], [9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! S2: Color Sensor Station
    CONST robtarget pSensor_Measure := [[266.90,275.43,180.12],[9.3566E-05,-0.709263,-0.704944,0.000120329],[0,0,1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! S0: Home Position
    CONST robtarget pHome := [[275.9205,0.02080205,667.3802],[0.7115182,-0.1236367,0.6797782,-0.1278957],[-1,0,-1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! --- SENSOR CONSTANTS ---
    ! Physical distance from the laser beam to the center of the gripper
    CONST num LASER_OFFSET_X := 25; 
    CONST num LASER_OFFSET_Y := 0;  
    
    ! Calibration values for the Sick distance sensor
    ! TABLE = -50 (Far), TALLEST = -47 (Closer), SMALLEST = -19 (Closest)
    CONST num EMPTY_THRESHOLD := -50; 
    CONST num GRIP_DEPTH := -5;       ! Additional mm to descend for a secure grip

    ! --- GRID CONSTANTS (45mm verified offsets) ---
    CONST num GRID_ROWS := 4;
    CONST num GRID_COLS := 4;
    CONST num OFFSET_X := 45; 
    CONST num OFFSET_Y := 45; 

    ! --- STATISTICS ---
    VAR num count_total := 0;
    VAR num count_correct := 0;
    VAR num count_wrong := 0;
    VAR num count_empty := 0;
    VAR num count_unknown := 0;

    ! --- PROCESS STATE FLAGS ---
    VAR bool operatorReady := FALSE;
    VAR bool blockPicked := FALSE;
    VAR bool measurementValid := FALSE;
    VAR bool Error_NoPart := FALSE;
    VAR bool Error_GripperFault := FALSE;
    VAR bool Error_SensorFailure := FALSE;
    VAR bool Error_InvalidColour := FALSE;
    VAR bool System_ResetRequired := FALSE;
    
    VAR num answer;
    
   ! --- MAIN PROGRAM ---
    PROC main()
        VAR robtarget current_pick;
        VAR robtarget current_dest;
        VAR num row;
        VAR num col;
        VAR num x_offs;
        VAR num y_offs;

        InitProgram; 

        ! Operator Handshake (FlexPendant based)
        TPWrite "Place workpieces on the Pickup Grid (S1).";
        TPReadFK answer, "Confirm workpieces are ready?", "READY", "", "", "", "";
        
        IF answer = 1 THEN
            operatorReady := TRUE;
            TPWrite "Cycle starting...";
        ELSE
            TPWrite "Operation aborted.";
            RETURN;
        ENDIF

        TPWrite "Moving to safe Home position...";
        MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
        
        ! Snake Loop Transfer Logic
        TPWrite "Processing 4x4 Laser-Guided Transfer...";
        FOR row FROM 0 TO GRID_ROWS - 1 DO
            FOR col FROM 0 TO GRID_COLS - 1 DO
                y_offs := row * OFFSET_Y;
                
                IF row MOD 2 = 0 THEN
                    x_offs := col * OFFSET_X;
                ELSE
                    x_offs := (GRID_COLS - 1 - col) * OFFSET_X;
                ENDIF
                
                ! Calculate points for both grids
                current_pick := Offs(pGrid_Pick_Ref, x_offs, y_offs, 0);
                current_dest := Offs(pGrid_Dest_Ref, x_offs, y_offs, 0);
                
                ProcessTransfer current_pick, current_dest;
            ENDFOR
        ENDFOR
        
        TPWrite "Batch complete. Returning Home...";
        MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
        
        ShowResults; 
    ENDPROC

    ! --- SUB-PROCEDURES ---
    
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

    PROC ProcessTransfer(robtarget pick_pos, robtarget dest_pos)
        VAR robtarget approach_pick;
        VAR robtarget approach_dest;
        VAR robtarget actual_grip_pos;
        VAR robtarget actual_approach_pos;
        VAR num measured_val;
        VAR num block_height;
        
        approach_pick := Offs(pick_pos, 0, 0, 50); 
        approach_dest := Offs(dest_pos, 0, 0, 50);
        
        ! 1. LASER MEASUREMENT PHASE
        MoveJ approach_pick, v200, z10, t_grijper1\WObj:=wobj0;
        WaitTime 0.2; 
        
        measured_val := AI_SensorSick;
        
        ! Presence Detection
        IF measured_val <= EMPTY_THRESHOLD THEN
            count_empty := count_empty + 1;
            Error_NoPart := TRUE;
            TPWrite "S1 Position Empty. Skipping...";
            RETURN;
        ENDIF

        ! 2. DYNAMIC PICKUP PHASE
        ! MATH FIX: 
        ! Nothing (Table) = -50
        ! Tallest = -47 (Distance = 3 units from table)
        ! Smallest = -19 (Distance = 31 units from table)
        ! Logic: Height is (Empty - Measured).
        block_height := EMPTY_THRESHOLD - measured_val;
        
        ! Resulting Math:
        ! Tallest: -50 - (-47) = -3mm (Robot descends 3mm from Ref point)
        ! Smallest: -50 - (-19) = -31mm (Robot descends 31mm from Ref point)
        actual_grip_pos := Offs(pick_pos, LASER_OFFSET_X, LASER_OFFSET_Y, block_height + GRIP_DEPTH);
        actual_approach_pos := Offs(actual_grip_pos, 0, 0, 50);
        
        SingArea\Wrist;
        ConfL\Off;

        MoveJ actual_approach_pos, v100, z10, t_grijper1\WObj:=wobj0;
        MoveL actual_grip_pos, v50, fine, t_grijper1\WObj:=wobj0;

        ConfL\On;

        SetDO DO_Gripper, 1;
        WaitTime 1;
        
        ! Error Handling: Grip Fail check
        IF DI_GripperClose = 0 THEN
            Error_GripperFault := TRUE;
            System_ResetRequired := TRUE;
            TPWrite "ERROR 2: Laser saw block, but grip failed!";
            SetDO DO_Gripper, 0;
            MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
            STOP;
        ENDIF

        blockPicked := TRUE;
        count_total := count_total + 1;
        
        ! 3. MEASUREMENT PHASE
        MoveL actual_approach_pos, v100, z10, t_grijper1\WObj:=wobj0;
        MeasureColor;
    
        ! 4. PLACEMENT PHASE
        MoveJ approach_dest, v200, z10, t_grijper1\WObj:=wobj0;
        MoveL dest_pos, v50, fine, t_grijper1\WObj:=wobj0;
    
        SetDO DO_Gripper, 0;
        WaitTime 0.5;
        blockPicked := FALSE;
    
        MoveL approach_dest, v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC
    
    PROC MeasureColor()
        SingArea\Wrist;
        ConfL\Off;
        MoveJ Offs(pSensor_Measure, 0, 0, 50), v200, z10, t_grijper1\WObj:=wobj0;
        MoveL pSensor_Measure, v50, fine, t_grijper1\WObj:=wobj0;
        ConfL\On;
        WaitTime 0.5;

        ! Color Sensor Evaluation
        IF DI_Color_1 = 0 AND DI_Color_2 = 0 AND DI_Color_3 = 0 AND DI_Color_4 = 0 THEN
            Error_SensorFailure := TRUE;
            System_ResetRequired := TRUE;
            TPWrite "ERROR 3: Sensor failure. Stopping.";
            MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
            STOP;
        ENDIF

        IF DI_Color_4 = 1 OR DI_Color_3 = 1 THEN
            count_correct := count_correct + 1;
            measurementValid := TRUE;
            TPWrite "Color: APPROVED";
        ELSEIF DI_Color_2 = 1 THEN
            count_wrong := count_wrong + 1;
            measurementValid := TRUE;
            TPWrite "Color: REJECTED (Yellow)";
        ELSEIF DI_Color_1 = 1 THEN
            count_unknown := count_unknown + 1;
            measurementValid := FALSE;
            TPWrite "ERROR 4: INVALID (Red)";
        ENDIF

        MoveL Offs(pSensor_Measure, 0, 0, 50), v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC

    PROC ShowResults()
        TPWrite "--- FINAL BATCH REPORT ---";
        TPWrite "Total Parts Processed: " \Num:=count_total;
        TPWrite "Approved (Blue/Green): " \Num:=count_correct;
        TPWrite "Rejected (Yellow):     " \Num:=count_wrong;
        TPWrite "Unknown/Invalid:       " \Num:=count_unknown;
        TPWrite "Empty Slots Detected:  " \Num:=count_empty;
        TPWrite "--------------------------";
    ENDPROC

ENDMODULE