MODULE MainModule
    ! --- ROBOT TARGETSsss ---
    ! S1: Pickup Grid Reference
    CONST robtarget pGrid_Pick_Ref := [[366.55, -83.67,109.91],[4.42542E-06,6.16962E-05, -1, 1.16894E-05], [-1,-1, -1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! S4: Destination Grid Reference
    CONST robtarget pGrid_Dest_Ref := [[370.96, -347.85,118.52], [0.000146671,6.84201E-05, -1, -9.78187E-05]. [-1, -1, -1,0], [9+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! S2: Color Sensor Station
    CONST robtarget pSensor_Measure := [[266.90,275.43,180.12],[9.3566E-05,-0.709263,-0.704944,0.000120329],[0,0,1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! S0: Home Position
    CONST robtarget pHome := [[275.9205,0.02080205,667.3802],[0.7115182,-0.1236367,0.6797782,-0.1278957],[-1,0,-1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! --- GRID CONSTANTS (45mm offsets) ---
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

        ! @IVAN: Start Cycle Interaction
        TPWrite "Place workpieces on the Pickup Grid (S1).";
        TPReadFK answer, "Confirm workpieces are ready?", "READY", "", "", "", "";
        
        IF answer = 1 THEN
            operatorReady := TRUE;
            TPWrite "Cycle starting...";
        ELSE
            TPWrite "Operation aborted by user.";
            EXIT;
        ENDIF

        ! TODO: Implement PLC Handshake (SetDO Robot_Busy, 1)

        TPWrite "Moving to safe Home position...";
        MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
        
        ! @SIMONA: Snake Loop with Second Platform Logic
        TPWrite "Processing 4x4 Grid Transfer...";
        FOR row FROM 0 TO GRID_ROWS - 1 DO
            FOR col FROM 0 TO GRID_COLS - 1 DO
                y_offs := row * OFFSET_Y;
                
                ! Snake logic: Reverse direction for odd rows
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
        
        ! TODO: Implement PLC Handshake (SetDO Robot_Done, 1)
        
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

    PPROC ProcessTransfer(robtarget pick_pos, robtarget dest_pos)
        VAR robtarget approach_pick;
        VAR robtarget approach_dest;
        VAR robtarget actual_grip_pos;
        VAR robtarget actual_approach_pos;
        VAR num measured_dist;
        
        ! The laser approach point
        approach_pick := Offs(pick_pos, 0, 0, 50); 
        approach_dest := Offs(dest_pos, 0, 0, 50);
        
        ! LASER SENSOR PHASE
        ! Move above the piece so the laser points directly at it
        MoveJ approach_pick, v200, z10, t_grijper1\WObj:=wobj0;
        
        ! Wait a tiny moment for the analog signal to stabilize
        WaitTime 0.2; 
        
        ! Read the live data from the Sick sensor
        measured_dist := AI_SensorSick;
        
        ! Check if the spot is empty
        IF measured_dist <= -50 THEN
            count_empty := count_empty + 1;
            Error_NoPart := TRUE;
            TPWrite "Laser detected empty spot (Val: " \Num:=measured_dist;
            TPWrite "). Moving to next...";
            RETURN; ! Exit the procedure entirely and skip to the next loop
        ENDIF
        
        ! DYNAMIC PICKUP PHASE
        actual_grip_pos := Offs(pick_pos, LASER_OFFSET_X, LASER_OFFSET_Y, measured_dist);
        actual_approach_pos := Offs(actual_grip_pos, 0, 0, 50);
        
        ! Shift horizontally to align the gripper, then descend dynamically
        MoveL actual_approach_pos, v100, fine, t_grijper1\WObj:=wobj0;
        MoveL actual_grip_pos, v50, fine, t_grijper1\WObj:=wobj0;
    
        SetDO DO_Gripper, 1;
        WaitTime 1;
        
        ! --- ERROR 2: Gripper fault check ---
        ! Since the laser confirmed a block was there, if the gripper misses it now, 
        ! it is a mechanical error, not a standard empty spot.
        IF DI_GripperClose = 0 THEN
            Error_GripperFault := TRUE;
            System_ResetRequired := TRUE;
            TPWrite "ERROR 2: Laser saw block, but gripper missed!";
            SetDO DO_Gripper, 0;
            MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
            TPWrite "Check gripper and block position. Reset required.";
            STOP;
        ENDIF

        ! Block successfully gripped
        blockPicked := TRUE;
        Error_NoPart := FALSE;
        count_total := count_total + 1;
        
        ! 3. MEASUREMENT PHASE
        MoveL actual_approach_pos, v100, z10, t_grijper1\WObj:=wobj0;
        MeasureColor;
    
        ! 4. PLACEMENT PHASE (Second Platform)
        MoveJ approach_dest, v200, z10, t_grijper1\WObj:=wobj0;
        MoveL dest_pos, v50, fine, t_grijper1\WObj:=wobj0;
    
        SetDO DO_Gripper, 0;
        WaitTime 0.5;
        blockPicked := FALSE;
    
        MoveL approach_dest, v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC
    PROC MeasureColor()
    ! Move to sensor
    MoveJ Offs(pSensor_Measure, 0, 0, 50), v200, z10, t_grijper1\WObj:=wobj0;
    MoveL pSensor_Measure, v50, fine, t_grijper1\WObj:=wobj0;

    ! Wait for sensor to stabilize
    WaitTime 0.5;

    IF DI_Color_1 = 0 AND DI_Color_2 = 0 AND DI_Color_3 = 0 AND DI_Color_4 = 0 THEN
        Error_SensorFailure := TRUE;
        System_ResetRequired := TRUE;
        measurementValid := FALSE;
        TPWrite "ERROR 3: Colour sensor no response. Stopping cycle.";
        MoveL Offs(pSensor_Measure, 0, 0, 50), v100, z10, t_grijper1\WObj:=wobj0;
        MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
        TPWrite "Check sensor alignment and cable. Reset required.";
        STOP;
    ENDIF

    IF DI_Color_4 = 1 THEN
        count_correct := count_correct + 1;
        measurementValid := TRUE;
        TPWrite "Color: BLUE -> Approved";
    ELSEIF DI_Color_3 = 1 THEN
        count_correct := count_correct + 1;
        measurementValid := TRUE;
        TPWrite "Color: GREEN -> Approved";
    ELSEIF DI_Color_2 = 1 THEN
        count_wrong := count_wrong + 1;
        measurementValid := TRUE;
        TPWrite "Color: YELLOW -> Rejected";
    ELSEIF DI_Color_1 = 1 THEN
        Error_InvalidColour := TRUE;
        count_unknown := count_unknown + 1;
        measurementValid := FALSE;
        TPWrite "ERROR 4: RED detected -> Invalid colour. Logged.";
    ENDIF

    ! Leave sensor safely
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