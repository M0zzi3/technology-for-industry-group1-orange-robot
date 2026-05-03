MODULE MainModule
    ! --- TARGETS ---
    !! TODO: Measure the real points
    CONST robtarget pGrid_Ref := [[359.127,0,188.4615],[0,0,0.9999999,0],[0,0,0,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST robtarget pSensor_Measure := [[359.1269,236.1245,188.4613],[8.42937E-08,-5.596081E-08,-0.9999999,3.015708E-08],[0,0,0,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST robtarget pHome := [[275.9205,0.02080205,667.3802],[0.7115182,-0.1236367,0.6797782,-0.1278957],[-1,0,-1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
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
        ! Step 1: Wait for operator (Simona/Ivan will add WaitDI here later)
        
        TPWrite "Moving to safe Home position...";
        ! 1. Always start the cycle from Home
        MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
        
        TPWrite "Processing the first grid block...";
        ! 2. Feed our first grid point into the procedure.
        ! (This will automatically approach, pretend to grip, 
        ! fly to the sensor, and return the block!)
        ProcessBlock(pGrid_Ref);
        
        TPWrite "Cycle complete. Returning Home...";
        ! 3. Park the robot safely when the job is done
        MoveJ pHome, v200, fine, t_grijper1\WObj:=wobj0;
        
        ! 4. Output the final statistics
        ShowResults;
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