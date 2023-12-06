--  This program runs a series of more than 70 regression tests to check
--  the correct operation of the HAC compiler.
--  The failures and success are accounted and the sums are shown at the end.
--
--  NB: the individual tests, or this program itself, can actually be used
--  for testing any Ada compiler. For that, all you have to do is to
--  customize the procedure Launch_HAC below.
--
--  For each test we launch, possibly from HAC itself, a new instance of
--  the HAC command-line tool (`hac` or `hac.exe`), which will build the
--  test sources as a virtual machine executable and run it.
--
--  Usage (if run from `hac` or `hac.exe`):  hac all_silent_tests.adb

with HAT;
with Testing_Utilities;

procedure All_Silent_Tests is

  use HAT;

  procedure Launch_Tests is

    procedure Shell (command : VString; echo : Boolean; success : out Boolean) is
      r : Integer;
    begin
      if echo then
        Put_Line ("Executing: [" & command & ']');
      end if;
      Shell_Execute (command, r);
      success := r = Testing_Utilities.OK_Code;
      if not success then
        Put_Line (+"*** Command: [" & command & "] FAILED ***. Return code: " & r);
      end if;
    end Shell;

    procedure Build_HAC (success : out Boolean) is
    begin
      if Get_Env ("hacbuild") = "done" then
        success := True;
        return;
      end if;
      Put_Line ("(Re-)building HAC, in case the present program isn't run from HAC...");
      Shell (+"gprbuild -P .." & Directory_Separator & "hac", True, success);
    end Build_HAC;

    successes, failures : Natural := 0;

    procedure Launch_HAC (Ada_file_name, args : VString; ups : Positive) is
      success : Boolean;
    begin
      Shell (
        ups * (+".." & Directory_Separator) & "hac " & Ada_file_name & ' ' & args,
        False,
        success
      );
      if success then
        successes := successes + 1;
      else
        failures := failures + 1;
      end if;
    end Launch_HAC;

    procedure Normal_Test (Ada_file_name : VString) is
      short : VString;
      sep : constant Natural := Index_Backward (Ada_file_name, Directory_Separator);
      spc : constant Natural := Index_Backward (Ada_file_name, ' ');
    begin
      if spc > 0 then
        short := Slice (Ada_file_name, sep + 1, spc - 1);
      else
        short := Slice (Ada_file_name, sep + 1, Length (Ada_file_name));
      end if;
      Put_Line (+"      " & short);
      Launch_HAC (Ada_file_name, +"", 1);
    end Normal_Test;

    --  Advent of Code

    procedure Launch_AoC (Year, Day, Solutions : VString) is
    begin
      if Index (Current_Directory, Year) = 0 then
        New_Line;
        Set_Directory (+".." & Directory_Separator & Year);
        Put_Line ("    Advent of Code " & Year & " in " & Current_Directory & ':');
        Put ("      ");
      end if;
      Put (Day & ' ');
      Launch_HAC (+"aoc_" & Year & '_' & Day & ".adb ", Solutions, 3);
    end Launch_AoC;

    hac_build_success : Boolean;

    examples_dir : constant VString :=
      +".." & Directory_Separator &
       "exm" & Directory_Separator;

    generate : constant VString :=
      +".." & Directory_Separator &
       "hac " & examples_dir & "pkg_demo_gen.adb";

  begin
    Put_Line ("    ___________      _____________________________________________");
    Put_Line ("   / *  HAC  * \    /  ""Silent tests"": when the failure count     \");
    Put_Line ("   |  Testing  |    |  is zero, then the test suite is all fine.  |");
    Put_Line ("   \___________/    \_____________________________________________/");
    New_Line;
    Build_HAC (hac_build_success);  --  Redundant if this program is itself run through HAC.
    if not hac_build_success then
      Put_Line ("--- HAC build failed (called from all_silent_tests.adb) ---");
      return;
    end if;
    --
    Put_Line ("----> Launching tests.");
    Put_Line ("  One instance of HAC is called each time, with compilation and execution...");
    New_Line;
    Put_Line (+"    Normal tests in " & Current_Directory & ':');
    Normal_Test (+"attributes_test.adb");
    Normal_Test (examples_dir & "barnes.adb 3816547290");
    Normal_Test (+"case_statement.adb");
    Normal_Test (+"constants.adb");
    Normal_Test (+"declarations.adb");
    Normal_Test (+"enumerations.adb");
    Normal_Test (+"floats.adb");
    Normal_Test (+"forward.adb");
    Normal_Test (+"integers.adb");
    Normal_Test (+"loops.adb");
    Normal_Test (+"object_init.adb");
    --  Create the X_* packages, run pkg_demo and finally delete the X_* packages .
    Shell_Execute (generate);
    Normal_Test (+"-I. .." & Directory_Separator & "exm" & Directory_Separator & "pkg_demo.adb test_mode");
    Shell_Execute (generate & " delete");
    --
    Normal_Test (+"recursion.adb");
    Normal_Test (+"sorting_tests.adb");
    Normal_Test (+"strings.adb");
    Normal_Test (examples_dir & "tasking" & Directory_Separator & "tasks_02.adb x");
    Normal_Test (+"type_conversion.adb");
    --
    Set_Directory (+".." & Directory_Separator &
                   "exm" & Directory_Separator &
                   "aoc" & Directory_Separator &
                   "2021");  --  <- We put on purpose the wrong starting year.
    --
    Launch_AoC (+"2020", +"02", +"607 321");                      --  Password Philosophy
    Launch_AoC (+"2020", +"03", +"218 3847183340");               --  Toboggan Trajectory
    Launch_AoC (+"2020", +"04", +"228 175");                      --  Passport Processing
    Launch_AoC (+"2020", +"05", +"835");                          --  Binary Boarding
    Launch_AoC (+"2020", +"06", +"6532 3427");                    --  Custom Customs
    Launch_AoC (+"2020", +"07", +"169 82372");                    --  Handy Haversacks
    Launch_AoC (+"2020", +"08", +"1394 1626");                    --  Handheld Halting
    Launch_AoC (+"2020", +"09", +"138879426 23761694");           --  Encoding Error
    Launch_AoC (+"2020", +"10", +"2277 37024595836928");          --  Adapter Array
    Launch_AoC (+"2020", +"11", +"37 26");                        --  Seating System
    Launch_AoC (+"2020", +"12", +"1631 58606");                   --  Rain Risk
    Launch_AoC (+"2020", +"13", +"222 408270049879073");          --  Shuttle Search
    Launch_AoC (+"2020", +"15", +"436 1 10 27 78 438 1836 249");  --  Rambunctious Recitation
    Launch_AoC (+"2020", +"16", +"23954 453459307723");           --  Ticket Translation
    Launch_AoC (+"2020", +"17", +"207");                          --  Conway Cubes
    Launch_AoC (+"2020", +"20", +"83775126454273");               --  Jurassic Jigsaw
    Launch_AoC (+"2020", +"22", +"31957");                        --  Crab Combat
    Launch_AoC (+"2020", +"23", +"67384529 49576328");            --  Crab Cups
    Launch_AoC (+"2020", +"24", +"341 285");                      --  Lobby Layout
    --
    Launch_AoC (+"2021", +"01", +"1154 1127");               --  Sonar Sweep
    Launch_AoC (+"2021", +"02", +"2187380 2086357770");      --  Dive!
    Launch_AoC (+"2021", +"03", +"3549854 3765399");         --  Binary Diagnostic
    Launch_AoC (+"2021", +"04", +"39984 8468");              --  Giant Squid
    Launch_AoC (+"2021", +"05", +"6225 22116");              --  Hydrothermal Venture
    Launch_AoC (+"2021", +"06", +"388419 1740449478328");    --  Lanternfish
    Launch_AoC (+"2021", +"07", +"340052 92948968");         --  The Treachery of Whales
    Launch_AoC (+"2021", +"08", +"440 1046281");             --  Seven Segment Search
    Launch_AoC (+"2021", +"09", +"423 1198704");             --  Smoke Basin
    Launch_AoC (+"2021", +"10", +"388713 3539961434");       --  Syntax Scoring
    Launch_AoC (+"2021", +"11", +"1679 519");                --  Dumbo Octopus
    Launch_AoC (+"2021", +"12", +"3497");                    --  Passage Pathing
    Launch_AoC (+"2021", +"13", +"602");                     --  Transparent Origami
    Launch_AoC (+"2021", +"14", +"2345 2432786807053");      --  Extended Polymerization
    Launch_AoC (+"2021", +"15", +"656");                     --  Chiton
    Launch_AoC (+"2021", +"16", +"927 1725277876501");       --  Packet Decoder
    Launch_AoC (+"2021", +"21", +"684495 152587196649184");  --  Dirac Dice
    --
    Launch_AoC (+"2022", +"01", +"68442 204837");                   --  Calorie Counting
    Launch_AoC (+"2022", +"02", +"14531 11258");                    --  Rock Paper Scissors
    Launch_AoC (+"2022", +"03", +"8185 2817");                      --  Rucksack Reorganization
    Launch_AoC (+"2022", +"04", +"657 938");                        --  Camp Cleanup
    Launch_AoC (+"2022", +"05", +"VQZNJMWTR NLCDCLVMQ");            --  Supply Stacks
    Launch_AoC (+"2022", +"06", +"1802 3551");                      --  Tuning Trouble
    Launch_AoC (+"2022", +"07", +"1749646 1498966");                --  No Space Left On Device
    Launch_AoC (+"2022", +"08", +"1843 180000");                    --  Treetop Tree House
    Launch_AoC (+"2022", +"09", +"6314 2504");                      --  Rope Bridge
    Launch_AoC (+"2022", +"10", +"12880");                          --  Cathode-Ray Tube
    Launch_AoC (+"2022", +"11", +"102399 23641658401");             --  Monkey in the Middle
    Launch_AoC (+"2022", +"12", +"440 439");                        --  Hill Climbing Algorithm
    Launch_AoC (+"2022", +"13", +"6568 19493");                     --  Distress Signal
    Launch_AoC (+"2022", +"14", +"964 32041");                      --  Regolith Reservoir
    Launch_AoC (+"2022", +"17", +"3193 1577650429835");             --  Pyroclastic Flow
    Launch_AoC (+"2022", +"18", +"3374 2010");                      --  Boiling Boulders
    Launch_AoC (+"2022", +"21", +"286698846151845 3759566892642");  --  Monkey Math
    Launch_AoC (+"2022", +"22", +"26558 110400");                   --  Monkey Map
    Launch_AoC (+"2022", +"23", +"3689 965");                       --  Unstable Diffusion
    --
    Launch_AoC (+"2023", +"01", +"52974 53340");                    --  Trebuchet?!
    Launch_AoC (+"2023", +"02", +"2176 63700");                     --  Cube Conundrum
    Launch_AoC (+"2023", +"03", +"539590 80703636");                --  Gear Ratios
    Launch_AoC (+"2023", +"04", +"23750 13261850");                 --  Scratchcards
    Launch_AoC (+"2023", +"05", +"261668924 24261545");             --  If You Give A Seed A Fertilizer
    Launch_AoC (+"2023", +"06", +"393120 36872656");                --  Wait For It
    --
    New_Line (2);
    New_Line;
    Put_Line ("----> Done.");
    New_Line;
    if failures = 0 then
      Put_Line ("All tests passed successfully.");
    else
      Put_Line (+"*** There are FAILED tests ***");
    end if;
    Put_Line ("Summary:");
    Put_Line (+"         " & successes & " successes");
    Put_Line (+"          " & failures & " failures");
    New_Line;
  end Launch_Tests;

begin
  Launch_Tests;
end All_Silent_Tests;
