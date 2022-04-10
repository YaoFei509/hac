--  Demo of many library-level packages.
--
--  HAC and GNAT figure out all source files that are needed for the build.
--
--  The X* packages are generated by Pkg_Demo_Gen (file pkg_demo_gen.adb).
--
--      X_Pkg_Test_S depends on X_Pkg_Test_S1, X_Pkg_Test_S2, ...
--      X_Pkg_Test_S1 depends on X_Pkg_Test_S11, X_Pkg_Test_S12, ...
--      ...

with HAL;

with X_Pkg_Demo_S,  --  Dependencies always declared in specs
     X_Pkg_Demo_M,  --  Dependencies declared in specs or bodies (randomly)
     X_Pkg_Demo_B;  --  Dependencies always declared in bodies

procedure Pkg_Demo is

  use HAL;

begin
  X_Pkg_Demo_S.Do_it; New_Line;
  X_Pkg_Demo_M.Do_it; New_Line;
  X_Pkg_Demo_B.Do_it; New_Line;
end Pkg_Demo;
