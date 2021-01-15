with HAC_Sys.Co_Defs,
     HAC_Sys.PCode.Interpreter.In_Defs;

private package HAC_Sys.PCode.Interpreter.Multi_Statement is
  use Co_Defs, In_Defs;

  -----------------------
  --  VM Instructions  --
  -----------------------

  --  Execute instruction stored as Opcode in ND.IR.F.
  --  ND.IR.F is in the Multi_Statement_Opcode subtype range.
  procedure Do_Multi_Statement_Operation (CD : Compiler_Data; ND : in out Interpreter_Data);

end HAC_Sys.PCode.Interpreter.Multi_Statement;
