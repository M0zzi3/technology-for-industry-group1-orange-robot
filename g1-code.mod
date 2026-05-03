MODULE MainModule
    ! --- TARGETS ---
    !! TODO: Measure the real points
    CONST robtarget pGrid_Ref := [[359.127,0,188.4615],[0,0,0.9999999,0],[0,0,0,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST robtarget pSensor_Measure := [[359.1269,236.1245,188.4613],[8.42937E-08,-5.596081E-08,-0.9999999,3.015708E-08],[0,0,0,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST robtarget pHome := [[-166.3462,21.82911,455.9365],[0.5664985,0.1725782,-0.7928951,-0.1435742],[-2,-1,2,4],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    ! --- GRID CONSTANTS (Simona's offset math) ---
    CONST num GRID_ROWS := 4;
    CONST num GRID_COLS := 4;
    CONST num OFFSET_X := 40; ! Change this to your actual mm spacing
    CONST num OFFSET_Y := 40; ! Change this to your actual mm spacing

    ! --- STATISTICS (For final reporting) ---
    VAR num count_total := 0;
    VAR num count_correct := 0;
    VAR num count_wrong := 0;
    VAR num count_empty := 0;
    
    
    ! --- MAIN PROGRAM ---
    PROC main()
        TPWrite "Place workpieces and press start switch";
        
        ! Step 1: Wait for operator (Simona/Ivan will add logic here)
        
        ! Step 2: Test Movement to the first point
        TPWrite "Moving to start point...";
        MoveJ Offs(pGrid_Ref, 0, 0, 50), v100, fine, t_grijper1\WObj:=wobj0;
        MoveL pGrid_Ref, v50, fine, t_grijper1\WObj:=wobj0;
        MoveL Offs(pGrid_Ref, 0, 0, 50), v50, fine, t_grijper1\WObj:=wobj0;
        
        ! Step 3: Scan the Grid (The snake-loop)
        
        TPWrite "Test finished";
    ENDPROC

    ! --- SUB-PROCEDURES FOR THE TEAM ---
    
    PROC ProcessBlock(robtarget target_pos)
        VAR robtarget approach_pos;
        approach_pos := Offs(target_pos, 0, 0, 50); ! 50mm for safe height
        
        ! Approach and descend
        MoveJ approach_pos, v200, z10, t_grijper1\WObj:=wobj0;
        MoveL target_pos, v50, fine, t_grijper1\WObj:=wobj0;
    
        ! --- IVAN & BEA'S GRIP LOGIC GOES HERE ---
        ! TODO: SetDO gripper close
        ! TODO: WaitTime 1s
        ! TODO: Check DIGripperClose (If empty -> handle error, return early)
    
        ! If we grabbed a block, go measure it
        MeasureColor;
    
        ! Return block to grid
        MoveJ approach_pos, v200, z10, t_grijper1\WObj:=wobj0;
        MoveL target_pos, v50, fine, t_grijper1\WObj:=wobj0;
    
        ! --- IVAN'S RELEASE LOGIC GOES HERE ---
        ! TODO: SetDO gripper open
    
        ! Retreat safely
        MoveL approach_pos, v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC
    
    PROC MeasureColor()
        ! Approach sensor safely
        MoveJ Offs(pSensor_Measure, 0, 0, 50), v200, z10, t_grijper1\WObj:=wobj0;
        MoveL pSensor_Measure, v50, fine, t_grijper1\WObj:=wobj0;
    
        ! --- BEA'S SENSOR LOGIC GOES HERE ---
        ! TODO: Wait for sensor reading
        ! TODO: Check if Blue/Green (Correct) or Yellow (Wrong)
        ! TODO: Update statistics counters
    
        ! Leave sensor safely
        MoveL Offs(pSensor_Measure, 0, 0, 50), v100, z10, t_grijper1\WObj:=wobj0;
    ENDPROC

    PROC ShowResults()
        TPWrite "--- BATCH FINISHED ---";
        ! TODO: Add more TPWrite lines to show count_correct, count_wrong, etc.
    ENDPROC

ENDMODULE