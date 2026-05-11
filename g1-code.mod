MODULE MainModule
    ! --- ROBOT TARGETS ---
    ! S1: Pickup Grid Reference
    CONST robtarget pGrid_Pick_Ref := [[359.127,0,188.4615],[0,0,0.9999999,0],[0,0,0,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! S4: Destination Grid Reference
    CONST robtarget pGrid_Dest_Ref := [[-128.7875,-530.1699,303.2513],[0.01374067,0.5698823,0.8214142,-0.01799957],[-2,0,-1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]]; 
    
    ! S2: Color Sensor Station
    CONST robtarget pSensor_Measure := [[266.90,275.43,180.12],[9.3566E-05,-0.709263,-0.704944,0.000120329],[0,0,1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! S0: Home Position
    CONST robtarget pHome := [[275.9205,0.02080205,667.3802],[0.7115182,-0.1236367,0.6797782,-0.1278957],[-1,0,-1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! --- GRID CONSTANTS (58mm offsets) ---
    CONST num GRID_ROWS := 4;
    CONST num GRID_COLS := 4;
    CONST num OFFSET_X := 58; 
    CONST num OFFSET_Y := 58; 

    ! --- STATISTICS ---
    VAR num count_total := 0;
    VAR num count_correct := 0;
    VAR num count_wrong := 0;
    VAR num count_empty := 0;

    ! --- PROCESS STATE FLAGS ---
    VAR bool operatorReady := FALSE;
    VAR bool blockPicked := FALSE;
    VAR bool measurementValid := FALSE;
    VAR bool Error_NoPart := FALSE;
    
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
                
                ProcessTransfer(current_pick, current_dest);
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
        operatorReady := FALSE;
        blockPicked := FALSE;
        Error_NoPart := FALSE;
    ENDPROC

    PROC ProcessTransfer(robtarget pick_pos, robtarget dest_pos)
        VAR robtarget approach_pick;
        VAR robtarget approach_dest;
        
        approach_pick := Offs(pick_pos, 0, 0, 50); 
        approach_dest := Offs(dest_pos, 0, 0, 50);
        
        ! 1. PICKUP PHASE
        MoveJ approach_pick, v200, z10, t_grijper1\WObj:=wobj0;
        MoveL pick_pos, v50, fine, t_grijper1\WObj:=wobj0;
    
        SetDO DO_Gripper, 1;
        
        ! @BEA: Gripper Feedback Logic
        WaitTime 1; 
        IF DI_GripperClose = 0 THEN
            ! Error handling: Slot is empty
            count_empty := count_empty + 1;
            Error_NoPart := TRUE;
            TPWrite "S1 Position Empty. Moving to next...";
            SetDO DO_Gripper, 0; 
            MoveL approach_pick, v100, z10, t_grijper1\WObj:=wobj0;
            RETURN;
        ENDIF

        ! Block successfully gripped
        blockPicked := TRUE;
        Error_NoPart := FALSE;
        count_total := count_total + 1;
        
        ! 2. MEASUREMENT PHASE
        MoveL approach_pick, v100, z10, t_grijper1\WObj:=wobj0;
        MeasureColor;
    
        ! 3. PLACEMENT PHASE (Second Platform)
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
    
        ! @BEA: Color Evaluation
        ! TODO: Replace with real DI signals (e.g., DI_Color_Blue, DI_Color_Yellow)
        ! Requirements: Approved = Blue/Green, Rejected = Yellow
        
        WaitTime 0.5; ! Simulating sensor read
        
        ! Placeholder logic - Update with real signals when hardware is verified
        ! IF DI_Color_Blue = 1 THEN
        !     count_correct := count_correct + 1;
        !     measurementValid := TRUE;
        ! ENDIF
        
        TPWrite "Measurement complete.";
        
        MoveL Offs(pSensor_Measure, 0, 0, 50), v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC

    PROC ShowResults()
        TPWrite "--- FINAL BATCH REPORT ---";
        TPWrite "Total Parts Processed: " \Num:=count_total;
        TPWrite "Approved (Blue/Green): " \Num:=count_correct;
        TPWrite "Rejected (Yellow):     " \Num:=count_wrong;
        TPWrite "Empty Slots Detected:  " \Num:=count_empty;
        TPWrite "--------------------------";
    ENDPROC

ENDMODULE