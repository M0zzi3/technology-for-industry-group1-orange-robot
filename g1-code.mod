MODULE MainModule
    ! --- TARGETS ---
    CONST robtarget pGrid_Ref := [[359.127,0,188.4615],[0,0,0.9999999,0],[0,0,0,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST robtarget P_Color_ict := [[266.90,275.43,180.12],[9.3566E-05,-0.709263,-0.704944,0.000120329],[0,0,1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST robtarget pHome := [[275.9205,0.02080205,667.3802],[0.7115182,-0.1236367,0.6797782,-0.1278957],[-1,0,-1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! --- GRID CONSTANTS ---
    CONST num GRID_ROWS := 4;
    CONST num GRID_COLS := 4;
    CONST num OFFSET_X := 40; 
    CONST num OFFSET_Y := 40; 

    ! --- STATISTICS ---
    VAR num count_total := 0;
    VAR num count_correct := 0;
    VAR num count_wrong := 0;
    VAR num count_empty := 0;

    ! --- PROCESS VARIABLES ---
    VAR num answer;
    
   ! --- MAIN PROGRAM ---
    PROC main()
        VAR robtarget current_target;
        VAR num row;
        VAR num col;
        VAR num x_offs;
        VAR num y_offs;

        InitProgram; 

        ! @IVAN: Start Cycle Interaction (from feat/start-signal)
        TPWrite "Place workpieces on the grid.";
        TPReadFK answer, "Press START when ready", "START", "", "", "", "";
        
        IF answer <> 1 THEN
            TPWrite "Cycle cancelled.";
            EXIT;
        ENDIF

        TPWrite "Moving to safe Home position...";
        MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
        
        ! @SIMONA: Snake Loop Implementation (from feature/offsets)
        TPWrite "Processing the 4x4 grid...";
        FOR row FROM 0 TO GRID_ROWS - 1 DO
            FOR col FROM 0 TO GRID_COLS - 1 DO
                y_offs := row * OFFSET_Y;
                
                ! Snake logic: Reverse direction for odd rows
                IF row MOD 2 = 0 THEN
                    x_offs := col * OFFSET_X;
                ELSE
                    x_offs := (GRID_COLS - 1 - col) * OFFSET_X;
                ENDIF
                
                current_target := Offs(pGrid_Ref, x_offs, y_offs, 0);
                ProcessBlock(current_target);
            ENDFOR
        ENDFOR
        
        TPWrite "Cycle complete. Returning Home...";
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
    ENDPROC

    PROC ProcessBlock(robtarget target_pos)
        VAR robtarget approach_pos;
        approach_pos := Offs(target_pos, 0, 0, 50); 
        
        ! Approach and descend
        MoveJ approach_pos, v200, z10, t_grijper1\WObj:=wobj0;
        MoveL target_pos, v50, fine, t_grijper1\WObj:=wobj0;
    
        ! @IVAN: Gripper Action
        SetDO DO_Gripper, 1;
        
        ! @BEA: Empty Spot Detection (from feature/bea-error-handling)
        WaitTime 1; ! Requirement: Wait 1s
        IF DI_GripperClose = 0 THEN
            count_empty := count_empty + 1;
            TPWrite "Position empty. Skipping...";
            SetDO DO_Gripper, 0; ! Reset gripper
            MoveL approach_pos, v100, z10, t_grijper1\WObj:=wobj0;
            RETURN;
        ENDIF

        ! Block successfully gripped
        ! Transport to sensor
        MeasureColor;
    
        ! Return block to original grid position
        MoveJ approach_pos, v200, z10, t_grijper1\WObj:=wobj0;
        MoveL target_pos, v50, fine, t_grijper1\WObj:=wobj0;
    
        ! @IVAN: Release block
        SetDO DO_Gripper, 0;
        WaitTime 0.5;
    
        ! Retreat safely
        MoveL approach_pos, v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC
    
    PROC MeasureColor()
        ! Approach sensor safely
        MoveJ Offs(P_Color_ict, 0, 0, 50), v200, z10, t_grijper1\WObj:=wobj0;
        MoveL P_Color_ict, v50, fine, t_grijper1\WObj:=wobj0;
    
        ! @BEA: Sensor Logic (Partially implemented in feature/bea-color-sensor-logic)
        ! Requirement: Approve (Blue, Green), Reject (Yellow)
        
        ! Placeholder for actual DI reading (Signals need to be verified)
        ! For now, we increment total but color stats are pending real sensor integration
        count_total := count_total + 1;
        
        ! TODO: Implement real sensor signal checks here
        ! IF DI_Color_Blue = 1 OR DI_Color_Green = 1 THEN
        !     count_correct := count_correct + 1;
        ! ELSEIF DI_Color_Yellow = 1 THEN
        !     count_wrong := count_wrong + 1;
        ! ENDIF
        
        WaitTime 0.5; 
    
        ! Leave sensor safely
        MoveL Offs(P_Color_ict, 0, 0, 50), v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC

    PROC ShowResults()
        TPWrite "--- BATCH QUALITY REPORT ---";
        TPWrite "Total Objects: " \Num:=count_total;
        TPWrite "Correct Colors: " \Num:=count_correct;
        TPWrite "Incorrect Colors: " \Num:=count_wrong;
        TPWrite "Missing Objects: " \Num:=count_empty;
        TPWrite "----------------------------";
    ENDPROC

ENDMODULE