MODULE MainModule
    ! --- TARGETS ---
    VAR robtarget pGrid_Ref; 
    VAR robtarget pSensor_Measure;
    VAR robtarget pHome;

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
        MoveJ Offs(start_point, 0, 0, 50), v100, fine, t_grijper1\WObj:=wobj0;
        MoveL start_point, v50, fine, t_grijper1\WObj:=wobj0;
        MoveL Offs(start_point, 0, 0, 50), v50, fine, t_grijper1\WObj:=wobj0;
        
        ! Step 3: Scan the Grid (The snake-loop goes here later)
        
        TPWrite "Test finished";
    ENDPROC

    ! --- SUB-PROCEDURES FOR THE TEAM ---
    
    PROC ProcessPosition()
        ! Bea and Ivan will add the Gripper and Empty/Full logic here
    ENDPROC
    
    PROC MeasureColor()
        ! Logic to move to the sensor and check color goes here
    ENDPROC

    PROC ShowResults()
        ! Logic to calculate and display final stats goes here
    ENDPROC

ENDMODULE