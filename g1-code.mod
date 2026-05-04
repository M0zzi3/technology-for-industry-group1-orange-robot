MODULE MainModule
    ! --- TARGETS ---
    CONST robtarget pGrid_Ref := [[359.127,0,188.4615],[0,0,0.9999999,0],[0,0,0,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST robtarget pSensor_Measure := [[359.1269,236.1245,188.4613],[8.42937E-08,-5.596081E-08,-0.9999999,3.015708E-08],[0,0,0,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
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
    
   ! --- MAIN PROGRAM ---
    PROC main()
        InitProgram; !  Wipes screen and zeros stats

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
        ! Create nested FOR loops (row and col). 
        ! Calculate the X and Y offsets.
        ! Use 'Offs(pGrid_Ref, x, y, 0)' to find the target.
        ! Call ProcessBlock(your_calculated_target);
        ! ==========================================
        
        TPWrite "Processing the grid...";
        ProcessBlock(pGrid_Ref); ! <-- SIMONA: REPLACE THIS WITH YOUR LOOPS
        
        TPWrite "Cycle complete. Returning Home...";
        MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
        
        ShowResults; ! Prints the final stats
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
    
        ! ==========================================
        ! @IVAN - TASK 2: Close the Gripper
        ! INSTRUCTIONS: Use 'SetDO' to turn on DO_Gripper.
        ! ==========================================

        ! ==========================================
        ! @BEA - TASK 1: Empty Grid Check (Error Handling)
        ! INSTRUCTIONS: 
        ! 1. Use 'WaitTime 1;'
        ! 2. Check if DIGripperClose is 0.
        ! 3. IF empty: Increment 'count_empty', open the gripper, move back to 'approach_pos', and type 'RETURN;' to exit early.
        ! ==========================================
    
        ! If we grabbed a block, go measure it
        MeasureColor;
    
        ! Return block to grid
        MoveJ approach_pos, v200, z10, t_grijper1\WObj:=wobj0;
        MoveL target_pos, v50, fine, t_grijper1\WObj:=wobj0;
    
        ! ==========================================
        ! @IVAN - TASK 3: Open the Gripper
        ! INSTRUCTIONS: Use 'SetDO' to turn off DO_Gripper.
        ! ==========================================
    
        ! Retreat safely
        MoveL approach_pos, v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC
    
    PROC MeasureColor()
        ! Approach sensor safely
        MoveJ Offs(pSensor_Measure, 0, 0, 50), v200, z10, t_grijper1\WObj:=wobj0;
        MoveL pSensor_Measure, v50, fine, t_grijper1\WObj:=wobj0;
    
        ! ==========================================
        ! @BEA - TASK 2: Sensor Logic
        ! INSTRUCTIONS: 
        ! 1. Read the color sensor signal here.
        ! 2. IF Blue/Green: Increment 'count_correct'
        ! 3. IF Yellow: Increment 'count_wrong'
        ! 4. Always increment 'count_total'
        ! ==========================================
    
        ! Leave sensor safely
        MoveL Offs(pSensor_Measure, 0, 0, 50), v100, z10, t_grijper1\WObj:=wobj0;
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