MODULE MainModule
    ! --- TARGETS ---
    CONST robtarget pPickGrid_Ref := [[359.127,0,188.4615],[0,0,0.9999999,0],[0,0,0,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST robtarget pDestGrid_Ref := [[-128.7875,-530.1699,303.2513],[0.01374067,0.5698823,0.8214142,-0.01799957],[-2,0,-1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]]; 
    
    CONST robtarget P_Color_ict:=[[266.90,275.43,180.12],[9.3566E-05,-0.709263,-0.704944,0.000120329],[0,0,1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST robtarget pHome := [[275.9205,0.02080205,667.3802],[0.7115182,-0.1236367,0.6797782,-0.1278957],[-1,0,-1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! --- GRID CONSTANTS ---
    CONST num GRID_ROWS := 4;
    CONST num GRID_COLS := 4;
    CONST num OFFSET_X := 58; 
    CONST num OFFSET_Y := 58; 

    ! --- STATISTICS ---
    VAR num count_total := 0;
    VAR num count_correct := 0;
    VAR num count_wrong := 0;
    VAR num count_empty := 0;

     ! --- ERROR FLAGS ---
    VAR bool Error_NoPart := FALSE;
    VAR bool Error_GripperFault := FALSE;
    VAR bool System_ResetRequired := FALSE;
    
    
    
   ! --- MAIN PROGRAM ---
    PROC main()
        VAR robtarget current_pos;  ! Current calculated grid position
        VAR num row;                ! Current row number
        VAR num col;                ! Current column number
        VAR num x_offset;           ! Calculated X offset
        VAR num y_offset;           ! Calculated Y offset
        InitProgram; ! Maks's Feature: Wipes screen and zeros stats

        TPWrite "Place workpieces and press start switch";
        
        ! ==========================================
        ! @IVAN - TASK 1: Wait for Operator
        ! INSTRUCTIONS: Use 'WaitDI' to wait for the Start_Cycle signal here.
        ! ==========================================
        
        TPWrite "Moving to safe Home position...";
        MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
        
        ! ==========================================
        ! @SIMONA - TASK 1: The Snake Loop
        ! INSTRUCTIONS: Delete the single ProcessBlock line below. 
        ! Create nested FOR loops. Calculate the X and Y offsets.
        ! pick_target := Offs(pPickGrid_Ref, x, y, 0);
        ! drop_target := Offs(pDestGrid_Ref, x, y, 0);
        ! Call ProcessBlock(pick_target, drop_target);
        ! ==========================================
        
        TPWrite "Processing the grid...";
        FOR row FROM 0 TO GRID_ROWS - 1 DO              ! Go through all rows
            FOR col FROM 0 TO GRID_COLS - 1 DO          ! Go through all columns
                y_offset := row * OFFSET_Y;             ! Calculate row distance from first point
        
                IF row MOD 2 = 0 THEN                               ! Even rows go left to right
                    x_offset := col * OFFSET_X;                     ! Normal column direction
                ELSE                                                ! Odd rows go right to left
                    x_offset := (GRID_COLS - 1 - col) * OFFSET_X;   ! Reverse direction for snake movement
                ENDIF
        
                current_pos := Offs(pGrid_Ref, x_offset, y_offset, 0); ! Create current grid point from reference point
        
                ProcessBlock(current_pos);              ! Go down, pick/check/sensor/return through ProcessBlock
        
            ENDFOR                                      ! End column loop
        
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

    PROC ProcessBlock(robtarget pick_pos, robtarget drop_pos)
        VAR robtarget approach_pick;
        VAR robtarget approach_drop;
        
        approach_pick := Offs(pick_pos, 0, 0, 50); 
        approach_drop := Offs(drop_pos, 0, 0, 50);
        
        ! Approach and descend to right platform
        MoveJ approach_pick, v200, z10, t_grijper1\WObj:=wobj0;
        MoveL pick_pos, v50, fine, t_grijper1\WObj:=wobj0;
    
        ! ==========================================
        ! @IVAN - TASK 2: Close the Gripper
        ! ==========================================

      ! --- GRIPPER AND EMPTY POSITION ERROR HANDLING (bea) ---

                    ! --- EMPTY POSITION / GRIP CHECK LOGIC ---
                    ! The gripper is closed before checking the feedback signal.
                    ! After a short delay, DI_GripperClose is checked to determine whether a block was actually gripped.
                    ! If DI_GripperClose = 0, the position is considered empty.
                    ! Empty positions are not fatal errors: the robot stores the result, opens the gripper,
                    ! returns to the safe approach position, and continues with the next grid position.
                    ! RETURN is used to skip the color measurement because there is no block to inspect.

        SetDO DO_Gripper, 1;
        WaitTime 1;

        IF DI_GripperClose = 0 THEN
            Error_NoPart := TRUE;
            count_empty := count_empty + 1;

            TPWrite "Empty position detected";
            
            ! Open the gripper for safety before leaving the position.
            SetDO DO_Gripper, 0;
            WaitTime 0.5;

            MoveL approach_pos, v100, z10, t_grijper1\WObj:=wobj0;

            ! Stop processing this position.
            ! This prevents the robot from going to the color sensor without a block.
            RETURN;
        ENDIF

        ! A block was detected, so the program continues with the normal process.
        ! The object counter is updated and the block will be sent to the color sensor.
        Error_NoPart := FALSE;
        count_total := count_total + 1;
        TPWrite "Object detected";
        
        ! If we grabbed a block, go measure it
        MeasureColor;
    
        ! Take block to the LEFT platform
        MoveJ approach_drop, v200, z10, t_grijper1\WObj:=wobj0;
        MoveL drop_pos, v50, fine, t_grijper1\WObj:=wobj0;
    
        ! ==========================================
        ! @IVAN - TASK 3: Open the Gripper
        ! ==========================================
    
        ! Open gripper after placing the block back
        SetDO DO_Gripper, 0;
        WaitTime 0.5;

        ! Retreat safely
        MoveL approach_drop, v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC

    PROC MeasureColor()
        ! Approach sensor safely
        MoveJ Offs(P_Color_ict, 0, 0, 50), v200, z10, t_grijper1\WObj:=wobj0;
        MoveL P_Color_ict, v50, fine, t_grijper1\WObj:=wobj0;
    
        ! ==========================================
        ! @BEA - TASK 2: Sensor Logic
        ! ==========================================
    
        ! Leave sensor safely
        MoveL Offs(P_Color_ict, 0, 0, 50), v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC

    PROC ShowResults()
        TPWrite "--- BATCH QUALITY REPORT ---";
        TPWrite "Amount of objects: " \Num:=count_total;
        TPWrite "Amount of correct colors: " \Num:=count_correct;
        TPWrite "Amount of incorrect colors: " \Num:=count_wrong;
        TPWrite "Amount of missing objects: " \Num:=count_empty;
        TPWrite "----------------------------";
    ENDPROC

ENDMODULE