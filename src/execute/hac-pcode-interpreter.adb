with HAC.PCode.Interpreter.In_Defs,
     HAC.PCode.Interpreter.Operators,
     HAC.PCode.Interpreter.Tasking;

with HAC_Pack;

with Ada.Calendar;                      use Ada.Calendar;
with Ada.Command_Line;
with Ada.Environment_Variables;

package body HAC.PCode.Interpreter is

  --  Post Mortem Dump of the task stack causing the exception
  --
  procedure Post_Mortem_Dump (CD: Compiler_Data; ND: In_Defs.Interpreter_Data) is
    use In_Defs, Ada.Text_IO, Defs.IIO, Defs.RIO;
    BLKCNT : Integer;
    H1, H2, H3 : Defs.HAC_Integer;
  begin
      New_Line;
      Put_Line ("HAC - PCode - Post Mortem Dump");
      New_Line;
      Put_Line ("Processor state: " & Processor_State'Image (ND.PS));
      New_Line;
      Put_Line (
        "Stack Variables of Task " &
        Defs.To_String (CD.IdTab (CD.Tasks_Definitions_Table (ND.CurTask)).Name)
      );
      H1 := ND.TCB (ND.CurTask).B;   --  current bottom of stack
      BLKCNT := 10;
      loop
        New_Line;
        BLKCNT := BLKCNT - 1;
        if BLKCNT = 0 then
          H1 := 0;
        end if;
        H2 := ND.S (H1 + 4).I;  --  index into HAC.Data.IdTab for this process
        if H1 /= 0 then
          Put (Defs.To_String (CD.IdTab (H2).Name));
          Put (" CALLED AT");
          Put (ND.S (H1 + 1).I, 5);
          New_Line;
        else
          Put_Line ("Task Variables");
        end if;
        H2 := CD.Blocks_Table (CD.IdTab (H2).Block_Ref).Last_Id_Idx;
        while H2 /= 0 loop
          -- [P2Ada]: WITH instruction
          declare
            P2Ada_Var_7 : IdTabEntry renames CD.IdTab (H2);
            use Defs;
          begin
            if P2Ada_Var_7.Obj = Variable then
              if Defs.Standard_or_Enum_Typ (P2Ada_Var_7.xTyp.TYP) then
                if P2Ada_Var_7.Normal then
                  H3 := H1 + P2Ada_Var_7.Adr_or_Sz;
                else
                  H3 := ND.S (H1 + P2Ada_Var_7.Adr_or_Sz).I;
                end if;
                Put ("  " & To_String (P2Ada_Var_7.Name) & " = ");
                case P2Ada_Var_7.xTyp.TYP is
                  when Defs.Enums | Defs.Ints =>
                    Put (ND.S (H3).I);
                    New_Line;
                  when Defs.Bools =>
                    BIO.Put (Boolean'Val (ND.S (H3).I));
                    New_Line;
                  when Defs.Floats =>
                    Put (ND.S (H3).R);
                    New_Line;
                  when Defs.Chars =>
                    Put (ND.S (H3).I);
                    Put_Line (" (ASCII)");
                  when others =>
                    null;  -- [P2Ada]: no otherwise / else in Pascal
                end case;
              end if;
            end if;
            H2 := P2Ada_Var_7.Link;
          end; -- [P2Ada]: end of WITH

        end loop;
        H1 := ND.S (H1 + 3).I;
        exit when H1 < 0;
      end loop;
  end Post_Mortem_Dump;

  procedure Interpret (CD : Compiler_Data)
  is
    use In_Defs;
    ND : Interpreter_Data;

    H1, H2, H3, H4, H5 : Defs.HAC_Integer;  --  Internal integer registers
    F1     : Defs.HAC_Float;                --  Internal float registers

    --  $I sched.pas
    --  This file contains the different scheduling strategies

    procedure ShowTime is null;
    procedure SnapShot is null;

    procedure Pop (Amount : Positive := 1) is  begin Pop (ND, Amount); end;
    procedure Push (Amount : Positive := 1) is begin Push (ND, Amount); end;

    procedure Do_Standard_Function is
      Curr_TCB : Task_Control_Block renames ND.TCB (ND.CurTask);
      Top_Item : GRegister renames ND.S (Curr_TCB.T);
      Arg : Integer;
      Code : constant SF_Code := SF_Code'Val (ND.IR.Y);
      use Defs, Defs.VStrings_Pkg;
    begin
      case Code is
        when SF_File_Information =>
          if ND.IR.X = 0 then  --  Niladic File info function -> abstract console
            Push;
            case SF_File_Information (Code) is
              when SF_EOF  => ND.S (Curr_TCB.T).I := Boolean'Pos (End_Of_File_Console);
              when SF_EOLN => ND.S (Curr_TCB.T).I := Boolean'Pos (End_Of_Line_Console);
            end case;
          else
            case SF_File_Information (Code) is
              when SF_EOF =>
                ND.S (Curr_TCB.T).I := Boolean'Pos (Ada.Text_IO.End_Of_File (ND.S (Curr_TCB.T).Txt.all));
              when SF_EOLN =>
                ND.S (Curr_TCB.T).I := Boolean'Pos (Ada.Text_IO.End_Of_Line (ND.S (Curr_TCB.T).Txt.all));
            end case;
          end if;
        when SF_Argument =>
          Arg := Top_Item.I;
          --  The stack top item may change its type here (if register has discriminant).
          Top_Item.V := To_VString (Argument (Arg));
        when SF_Shell_Execute =>
          Top_Item.I := Shell_Execute (To_String (Top_Item.V));
        when SF_Argument_Count =>
          Push;  --  Niladic function, needs to push a new item (their own result).
          ND.S (Curr_TCB.T).I := Argument_Count;
        when SF_Directory_Separator =>
          Push;  --  Niladic function, needs to push a new item (their own result).
          ND.S (Curr_TCB.T).I := Character'Pos (Directory_Separator);
        when SF_Get_Needs_Skip_Line =>
          Push;  --  Niladic function, needs to push a new item (their own result).
          ND.S (Curr_TCB.T).I := Boolean'Pos (Get_Needs_Skip_Line);
        when others =>
          Operators.Do_SF_Operator (CD, ND);  --  Doesn't need generic stuff.
      end case;
    end Do_Standard_Function;

    procedure Do_Text_Read (Code : SP_Code) is
      CH : Character;
      Curr_TCB : Task_Control_Block renames ND.TCB (ND.CurTask);
      use Defs;
      Out_Param : Index renames ND.S (Curr_TCB.T).I;
      Typ : constant Typen := Typen'Val (ND.IR.Y);
      Immediate : constant Boolean := Code = SP_Get_Immediate;
      FP : File_Ptr;
    begin
      if Code in SP_Get .. SP_Get_Line then
        --  The End_Of_File_Console check is skipped here (disturbs GNAT's run-time).
        case Typ is
          when Ints     => Get_Console (ND.S (Out_Param).I);
          when Floats   => Get_Console (ND.S (Out_Param).R);
          when VStrings => ND.S (Out_Param).V := To_VString (Get_Line_Console);
          when Chars    =>
            if Immediate then
              Get_Immediate_Console (CH);
            else
              Get_Console (CH);
            end if;
            ND.S (Out_Param).I := Character'Pos (CH);
          when others =>
            null;
        end case;
        if Code = SP_Get_Line and Typ /= VStrings then
          Skip_Line_Console;
        end if;
        Pop;
      else
        FP := ND.S (Curr_TCB.T - 1).Txt;
        if Ada.Text_IO.End_Of_File (FP.all) then
          ND.PS := REDCHK;
        else
          case Typ is
            when Ints =>
              Defs.IIO.Get (FP.all, ND.S (Out_Param).I);
            when Floats =>
              Defs.RIO.Get (FP.all, ND.S (Out_Param).R);
            when Chars =>
              Ada.Text_IO.Get (FP.all, CH);
              ND.S (Out_Param).I := Character'Pos (CH);
            when VStrings =>
              ND.S (Out_Param).V := To_VString (Ada.Text_IO.Get_Line (FP.all));
            when others =>
              null;
          end case;
        end if;
        if Code = SP_Get_Line_F and Typ /= VStrings then
          Ada.Text_IO.Skip_Line (FP.all);
        end if;
        Pop (2);
      end if;
      ND.SWITCH := True;  --  give up control when doing I/O
    end Do_Text_Read;

    procedure Do_Write_Formatted (Code : SP_Code) is
      Curr_TCB : Task_Control_Block renames   ND.TCB (ND.CurTask);
      FP       : File_Ptr;
      Item     : GRegister renames            ND.S (Curr_TCB.T - 3);
      Format_1 : constant Defs.HAC_Integer := ND.S (Curr_TCB.T - 2).I;
      Format_2 : constant Defs.HAC_Integer := ND.S (Curr_TCB.T - 1).I;
      Format_3 : constant Defs.HAC_Integer := ND.S (Curr_TCB.T    ).I;
      --  Valid parameters used: see def_param in HAC.Parser.Standard_Procedures.
      use Defs, Defs.VStrings_Pkg;
    begin
      if Code in SP_Put .. SP_Put_Line then
        case Typen'Val (ND.IR.Y) is
          when Ints            => Put_Console (Item.I, Format_1, Format_2);
          when Floats          => Put_Console (Item.R, Format_1, Format_2, Format_3);
          when Bools           => Put_Console (Boolean'Val (Item.I), Format_1);
          when Chars           => Put_Console (Character'Val (Item.I));
          when VStrings        => Put_Console (To_String (Item.V));
          when String_Literals => Put_Console (
              CD.Strings_Constants_Table (Format_1 .. Format_1 + Item.I - 1)
            );
          when Arrays          => Put_Console (Get_String_from_Stack (ND, Item.I, Format_1));
          when others =>
            null;
        end case;
        if Code = SP_Put_Line then
          New_Line_Console;
        end if;
        Pop (4);
      else
        FP := ND.S (Curr_TCB.T - 4).Txt;
        case Typen'Val (ND.IR.Y) is
          when Ints            => IIO.Put         (FP.all, Item.I, Format_1, Format_2);
          when Floats          => RIO.Put         (FP.all, Item.R, Format_1, Format_2, Format_3);
          when Bools           => BIO.Put         (FP.all, Boolean'Val (Item.I), Format_1);
          when Chars           => Ada.Text_IO.Put (FP.all, Character'Val (Item.I));
          when VStrings        => Ada.Text_IO.Put (FP.all, To_String (Item.V));
          when String_Literals => Ada.Text_IO.Put (FP.all,
              CD.Strings_Constants_Table (Format_1 .. Format_1 + Item.I - 1)
            );
          when Arrays          => Ada.Text_IO.Put (FP.all,
              Get_String_from_Stack (ND, Item.I, Format_1));
          when others =>
            null;
        end case;
        if Code = SP_Put_Line_F then
          Ada.Text_IO.New_Line (FP.all);
        end if;
        Pop (5);
      end if;
      ND.SWITCH := True;  --  give up control when doing I/O
    end Do_Write_Formatted;

    procedure Do_Code_for_Automatic_Initialization is
      Curr_TCB : Task_Control_Block renames ND.TCB (ND.CurTask);
      use Defs;
      Var_Addr : constant HAC_Integer := ND.S (Curr_TCB.T).I;
    begin
      case Typen'Val (ND.IR.Y) is
        when VStrings   => ND.S (Var_Addr).V := Null_VString;
        when Text_Files => Allocate_Text_File (ND, ND.S (Var_Addr));
        when others     => null;
      end case;
      Pop;
    end Do_Code_for_Automatic_Initialization;

    procedure Do_File_IO is
      Code : constant SP_Code := SP_Code'Val (ND.IR.X);
      Curr_TCB : Task_Control_Block renames ND.TCB (ND.CurTask);
    begin
      case Code is
        when SP_Open =>
          Ada.Text_IO.Open (
            ND.S (Curr_TCB.T - 1).Txt.all,
            Ada.Text_IO.In_File,
            Defs.VStrings_Pkg.To_String (ND.S (Curr_TCB.T).V)
          );
          Pop (2);
        when SP_Create =>
          Ada.Text_IO.Create (
            ND.S (Curr_TCB.T - 1).Txt.all,
            Ada.Text_IO.Out_File,
            Defs.VStrings_Pkg.To_String (ND.S (Curr_TCB.T).V)
          );
          Pop (2);
        when SP_Close =>
          Ada.Text_IO.Close (ND.S (Curr_TCB.T).Txt.all);
          Pop;
        when SP_Set_Env =>
          Ada.Environment_Variables.Set (
            Defs.VStrings_Pkg.To_String (ND.S (Curr_TCB.T - 1).V),
            Defs.VStrings_Pkg.To_String (ND.S (Curr_TCB.T).V)
          );
          Pop (2);
        when SP_Push_Abstract_Console =>
          Push;
          ND.S (Curr_TCB.T).Txt := Abstract_Console;
        when SP_Get | SP_Get_Immediate | SP_Get_Line | SP_Get_F | SP_Get_Line_F =>
          Do_Text_Read (Code);
        when SP_Put |SP_Put_Line | SP_Put_F | SP_Put_Line_F =>
          Do_Write_Formatted (Code);
        when SP_New_Line =>
          if ND.S (Curr_TCB.T).Txt = Abstract_Console then
            New_Line_Console;
          else
            Ada.Text_IO.New_Line (ND.S (Curr_TCB.T).Txt.all);
          end if;
          Pop;
        when SP_Skip_Line =>
          if ND.S (Curr_TCB.T).Txt = Abstract_Console then
            --  The End_Of_File_Console check is skipped here (disturbs GNAT's run-time).
            Skip_Line_Console;
          elsif Ada.Text_IO.End_Of_File (ND.S (Curr_TCB.T).Txt.all) then
            ND.PS := REDCHK;
          else
            Ada.Text_IO.Skip_Line (ND.S (Curr_TCB.T).Txt.all);
          end if;
          Pop;
        when others =>
          null;
      end case;
      ND.SWITCH := True;  --  give up control when doing I/O
    end Do_File_IO;

    procedure Fetch_Instruction is
      Curr_TCB : Task_Control_Block renames ND.TCB (ND.CurTask);
    begin
      ND.IR := CD.ObjCode (Curr_TCB.PC);
      Curr_TCB.PC := Curr_TCB.PC + 1;
    end Fetch_Instruction;

    procedure Execute_Current_Instruction is
      Curr_TCB : Task_Control_Block renames ND.TCB (ND.CurTask);
      IR : Order renames ND.IR;
    begin
      case ND.IR.F is

        when k_Push_Address =>  --  Push "v'Access" of variable v
          Push;
          ND.S (Curr_TCB.T).I := Curr_TCB.DISPLAY (Nesting_level (IR.X)) + IR.Y;

        when k_Push_Value =>  --  Push variable v's value.
          Push;
          ND.S (Curr_TCB.T) := ND.S (Curr_TCB.DISPLAY (Nesting_level (IR.X)) + IR.Y);

        when k_Push_Indirect_Value =>  --  Push "v.all" (v is an access).
          Push;
          ND.S (Curr_TCB.T) := ND.S (ND.S (Curr_TCB.DISPLAY (Nesting_level (IR.X)) + IR.Y).I);

        when k_Variable_Initialization => Do_Code_for_Automatic_Initialization;

        when k_Update_Display_Vector =>
          --  Emitted at the end of Subprogram_or_Entry_Call, when the
          --  called's nesting level is *lower* than the caller's.
          declare
            Low_Level, High_Level : Nesting_level;
          begin
            High_Level := Nesting_level (IR.Y);  --  Current nesting level.
            Low_Level  := Nesting_level (IR.X);  --  Called subprogram nesting level.
            H3 := Curr_TCB.B;
            for L in reverse Low_Level + 1 .. High_Level loop
              Curr_TCB.DISPLAY (L) := H3;
              H3 := ND.S (H3 + 2).I;
            end loop;
          end;

        when k_File_I_O           => Do_File_IO;
        when k_Standard_Functions => Do_Standard_Function;

        when k_Record_Field_Offset =>
          ND.S (Curr_TCB.T).I := ND.S (Curr_TCB.T).I + IR.Y;

        when k_Jump => Curr_TCB.PC := IR.Y;

        when k_Conditional_Jump =>
          if ND.S (Curr_TCB.T).I = 0 then  --  if False, then ...
            Curr_TCB.PC := IR.Y;           --  ... Jump.
          end if;
          Pop;

        when k_CASE_Switch_1 =>  --  SWTC - switch (in a CASE instruction)
          H1 := ND.S (Curr_TCB.T).I;
          Pop;
          H2 := IR.Y;
          --
          --  Now we loop over a bunch of k_CASE_Switch_2 instruction pairs that covers all cases.
          --
          loop
            if CD.ObjCode (H2).F /= k_CASE_Switch_2 then
              ND.PS := Case_Check_Error;  --  Value or OTHERS not found. This situation should not...
              exit;                       --  ...happen: compiler should check it before run-time.
            elsif CD.ObjCode (H2).Y = H1    --  either: - value is matching
                  or CD.ObjCode (H2).X < 0  --      or: - "WHEN OTHERS =>" case
            then
              Curr_TCB.PC := CD.ObjCode (H2 + 1).Y;  --  Execute instructions after "=>".
              exit;
            else
              H2 := H2 + 2;  --  Check the next k_CASE_Switch_2 instruction pair.
            end if;
          end loop;

        when k_CASE_Switch_2 =>
          --  This instruction appears only in a special object code block, see k_CASE_Switch_1.
          null;

        when k_FOR_Forward_Begin =>  --  Start of a FOR loop, forward direction
          H1 := ND.S (Curr_TCB.T - 1).I;
          if H1 <= ND.S (Curr_TCB.T).I then
            ND.S (ND.S (Curr_TCB.T - 2).I).I := H1;
          else
            Curr_TCB.T  := Curr_TCB.T - 3;
            Curr_TCB.PC := IR.Y;
          end if;

        when k_FOR_Forward_End =>  --  End of a FOR loop, forward direction
          H2 := ND.S (Curr_TCB.T - 2).I;
          H1 := ND.S (H2).I + 1;
          if H1 <= ND.S (Curr_TCB.T).I then
            ND.S (H2).I    := H1;
            Curr_TCB.PC := IR.Y;
          else
            Pop (3);
          end if;

        when k_FOR_Reverse_Begin =>  --  Start of a FOR loop, reverse direction
          H1 := ND.S (Curr_TCB.T).I;
          if H1 >= ND.S (Curr_TCB.T - 1).I then
            ND.S (ND.S (Curr_TCB.T - 2).I).I := H1;
          else
            Curr_TCB.PC := IR.Y;
            Curr_TCB.T  := Curr_TCB.T - 3;
          end if;

        when k_FOR_Reverse_End =>  --  End of a FOR loop, reverse direction
          H2 := ND.S (Curr_TCB.T - 2).I;
          H1 := ND.S (H2).I - 1;
          if H1 >= ND.S (Curr_TCB.T - 1).I then
            ND.S (H2).I    := H1;
            Curr_TCB.PC := IR.Y;
          else
            Pop (3);
          end if;

        when k_Mark_Stack =>
          H1 := CD.Blocks_Table (CD.IdTab (IR.Y).Block_Ref).VSize;
          if Curr_TCB.T + H1 > Curr_TCB.STACKSIZE then
            ND.PS := STKCHK;  --  Stack overflow
          else
            Curr_TCB.T := Curr_TCB.T + 5;   --  make room for fixed area
            ND.S (Curr_TCB.T - 1).I := H1 - 1; --  vsize-1
            ND.S (Curr_TCB.T).I := IR.Y;       --  HAC.Data.IdTab index of called procedure/entry
          end if;

        when k_Call =>
          --  procedure and task entry CALL
          --  Cramer
          if IR.X = Defs.Timed_Entry_Call then
            --  Timed entry call
            F1 := ND.S (Curr_TCB.T).R;  --  Pop delay time
            Pop;
          end if;
          H1 := Curr_TCB.T - IR.Y;     --  base of activation record
          H2 := ND.S (H1 + 4).I;          --  CD.IdTab index of called procedure/entry
          H3 := Integer (CD.IdTab (H2).LEV);
          Curr_TCB.DISPLAY (Nesting_level (H3 + 1)) := H1;
          ND.S (H1 + 1).I := Curr_TCB.PC;  --  return address
          H4 := ND.S (H1 + 3).I + H1;  --  new top of stack
          ND.S (H1 + 2).I := Curr_TCB.DISPLAY (Nesting_level (H3));  --  static link
          ND.S (H1 + 3).I := Curr_TCB.B;  --  dynamic link
          Curr_TCB.B := H1;
          Curr_TCB.T := H4;
          case IR.X is  --  Call type
            when Defs.Standard_Procedure_Call =>
              Curr_TCB.PC := CD.IdTab (H2).Adr_or_Sz;

            when Defs.Standard_Entry_Call =>
              Tasking.Queue (CD, ND, H2, ND.CurTask);  --  put self on entry queue
              Curr_TCB.TS := WaitRendzv;
              H5          := CD.IdTab (H2).Adr_or_Sz;  --  Task being entered
              if ((ND.TCB (H5).TS = WaitRendzv) and (ND.TCB (H5).SUSPEND = H2)) or
                 (ND.TCB (H5).TS = TimedWait)
              then
                --  wake accepting task if necessary
                ND.TCB (H5).TS      := Ready;
                ND.TCB (H5).SUSPEND := 0;
              end if;
              ND.SWITCH := True;                 --  give up control

            when Defs.Timed_Entry_Call =>
              Tasking.Queue (CD, ND, H2, ND.CurTask);  --  put self on entry queue
              H5 := CD.IdTab (H2).Adr_or_Sz;  --  Task being entered
              --
              if ((ND.TCB (H5).TS = WaitRendzv) and (ND.TCB (H5).SUSPEND = H2)) or
                 (ND.TCB (H5).TS = TimedWait)
              then
                --  wake accepting task if necessary
                Curr_TCB.TS := WaitRendzv;     --  suspend self
                ND.TCB (H5).TS := Ready;       --  wake accepting task
                ND.TCB (H5).SUSPEND := 0;
              else
                Curr_TCB.TS := TimedRendz;     --  Timed Wait For Rendezvous
                Curr_TCB.R1.I := 1;            --  Init R1 to specify NO timeout
                Curr_TCB.R2.I := H2;           --  Save address of queue for purge
                ND.SYSCLOCK := GetClock; --  update System Clock
                Curr_TCB.WAKETIME := ND.SYSCLOCK + Duration (F1);
              end if;
              ND.SWITCH := True;       --  give up control

            when Defs.Conditional_Entry_Call =>
              H5 := CD.IdTab (H2).Adr_or_Sz;              --  Task being entered
              if ((ND.TCB (H5).TS = WaitRendzv) and (ND.TCB (H5).SUSPEND = H2)) or
                 (ND.TCB (H5).TS = TimedWait)
              then
                Tasking.Queue (CD, ND, H2, ND.CurTask);  --  put self on entry queue
                Curr_TCB.R1.I := 1;        --  Indicate entry successful
                Curr_TCB.TS := WaitRendzv;
                ND.TCB (H5).TS      := Ready;  --  wake accepting task if required
                ND.TCB (H5).SUSPEND := 0;
                ND.SWITCH              := True;   --  give up control
              else
                --  can't wait, forget about entry call
                Curr_TCB.R1.I := 0;   --  Indicate entry failed in R1 1
                --  failure will be acknowledged by next instruction, 32
              end if;
            when others =>
              null;  -- [P2Ada]: no otherwise / else in Pascal
          end case;

        when k_Array_Index_Element_Size_1 =>
          H1 := IR.Y;     --  H1 points to HAC.Data.Arrays_Table
          H2 := CD.Arrays_Table (H1).Low;
          H3 := ND.S (Curr_TCB.T).I;
          if H3 not in H2 .. CD.Arrays_Table (H1).High then
            ND.PS := INXCHK;  --  Out-of-range state
          else
            Pop;
            ND.S (Curr_TCB.T).I := ND.S (Curr_TCB.T).I + (H3 - H2);
          end if;

        when k_Array_Index =>
          H1 := IR.Y;      --  H1 POINTS TO HAC.Data.Arrays_Table
          H2 := CD.Arrays_Table (H1).Low;
          H3 := ND.S (Curr_TCB.T).I;
          if H3 not in H2 .. CD.Arrays_Table (H1).High then
            ND.PS := INXCHK;  --  Out-of-range state
          else
            Pop;
            ND.S (Curr_TCB.T).I := ND.S (Curr_TCB.T).I +
                                   (H3 - H2) * CD.Arrays_Table (H1).Element_Size;
          end if;

        when k_Load_Block =>
          H1 := ND.S (Curr_TCB.T).I;   --  Pull source address
          Pop;
          H2 := IR.Y + Curr_TCB.T;  --  Stack top after pushing block
          if H2 > Curr_TCB.STACKSIZE then
            ND.PS := STKCHK;  --  Stack overflow
          else
            while Curr_TCB.T < H2 loop
              Curr_TCB.T     := Curr_TCB.T + 1;
              ND.S (Curr_TCB.T) := ND.S (H1);
              H1             := H1 + 1;
            end loop;
          end if;

        when k_Copy_Block =>
          H1 := ND.S (Curr_TCB.T - 1).I;   --  Destination address
          H2 := ND.S (Curr_TCB.T).I;       --  Source address
          H3 := H1 + IR.Y;                 --  IR.Y = block length
          while H1 < H3 loop
            ND.S (H1) := ND.S (H2);
            H1     := H1 + 1;
            H2     := H2 + 1;
          end loop;
          Pop (2);

        when k_Store =>  --  [T-1].all := [T]
          ND.S (ND.S (Curr_TCB.T - 1).I) := ND.S (Curr_TCB.T);
          Pop (2);

        when k_Load_Discrete_Literal =>  --  Literal: discrete value (Integer, Character, Boolean, Enum)
          Push;
          ND.S (Curr_TCB.T).I := IR.Y;

        when k_Load_Float_Literal =>
          Push;
          ND.S (Curr_TCB.T).R := CD.Float_Constants_Table (IR.Y);

        when k_String_Literal_Assignment =>  --  Hathorn
          H1 := ND.S (Curr_TCB.T - 2).I;  --  address of array
          H2 := ND.S (Curr_TCB.T).I;      --  index to string table
          H3 := IR.Y;                     --  size of array
          H4 := ND.S (Curr_TCB.T - 1).I;  --  length of string
          if H3 < H4 then
            H5 := H1 + H3;    --  H5 is H1 + min of H3, H4
          else
            H5 := H1 + H4;
          end if;
          while H1 < H5 loop
            --  Copy H5-H1 characters to the stack
            ND.S (H1).I := Character'Pos (CD.Strings_Constants_Table (H2));
            H1       := H1 + 1;
            H2       := H2 + 1;
          end loop;
          --  Padding (!! will be removed)
          H5 := ND.S (Curr_TCB.T - 2).I + H3;              --  H5 = H1 + H3
          while H1 < H5 loop
            --  fill with blanks if req'd
            ND.S (H1).I := Character'Pos (' ');
            H1       := H1 + 1;
          end loop;
          Pop (3);

        when k_Exit_Call =>  --  EXIT entry call or procedure call
          --  Cramer
          Curr_TCB.T := Curr_TCB.B - 1;
          if IR.Y = Defs.Standard_Procedure_Call then
            Curr_TCB.PC := ND.S (Curr_TCB.B + 1).I;  --  Standard proc call return
          end if;
          if Curr_TCB.PC /= 0 then
            Curr_TCB.B := ND.S (Curr_TCB.B + 3).I;
            if IR.Y = Defs.Timed_Entry_Call or IR.Y = Defs.Conditional_Entry_Call then
              if IR.Y = Defs.Timed_Entry_Call and Curr_TCB.R1.I = 0 then
                Push;
              end if;
              --  A JMPC instruction always follows (?)
              --  timed and conditional entry call
              --  returns (32).  Push entry call
              ND.S (Curr_TCB.T).I := Curr_TCB.R1.I;    --  success indicator for JMPC.
            end if;
          else
            ND.TActive  := ND.TActive - 1;
            Curr_TCB.TS := Completed;
            ND.SWITCH   := True;
          end if;

        when k_Exit_Function =>
          Curr_TCB.T  := Curr_TCB.B;
          Curr_TCB.PC := ND.S (Curr_TCB.B + 1).I;
          Curr_TCB.B  := ND.S (Curr_TCB.B + 3).I;
          if IR.Y = Defs.End_Function_without_Return then
            ND.PS := ProgErr;  --  !! with message "End function reached without ""return"" statement".
          end if;

        when Unary_Operator_Opcode  => Operators.Do_Unary_Operator (ND);
        when Binary_Operator_Opcode => Operators.Do_Binary_Operator (ND);
        when Tasking_Opcode         => Tasking.Do_Tasking_Operation (CD, ND);
      end case;
    exception
      when Stack_Overflow | Stack_Underflow =>
        ND.PS := STKCHK;  --  Stack overflow
    end Execute_Current_Instruction;

    Result_Tasks_to_wake : Boolean;

  begin  --  Interpret
    ND.Start_Time := Clock;
    ND.Snap     := False;
    ND.SWITCH   := False;           --  invoke scheduler on next cycle flag
    ND.SYSCLOCK := ND.Start_Time;
    ND.TIMER    := ND.SYSCLOCK;     --  set to end of current task's time slice
    HAC.PCode.Interpreter.Tasking.Init_main_task (CD, ND);
    HAC.PCode.Interpreter.Tasking.Init_other_tasks (CD, ND);

    Running_State:
    loop  --  until Processor state /= RUN
      ND.SYSCLOCK := GetClock;
      if ND.Snap then
        ShowTime;
      end if;
      if ND.TCB (ND.CurTask).TS = Critical then
        if ND.Snap then
          SnapShot;
        end if;
      else
        HAC.PCode.Interpreter.Tasking.Tasks_to_wake (CD, ND, Result_Tasks_to_wake);
        if ND.SWITCH or  --  ------------> Voluntary release of control
           ND.SYSCLOCK >= ND.TIMER or   --  ---> Time slice exceeded
           Result_Tasks_to_wake
        then --  ------> Awakened task causes switch
          if ND.CurTask >= 0 then
            ND.TCB (ND.CurTask).LASTRUN := ND.SYSCLOCK;
            if ND.TCB (ND.CurTask).TS = Running then
              ND.TCB (ND.CurTask).TS := Ready;
              --  SWITCH PROCCESS
            end if;
          end if;
          loop --  Call Main Scheduler
            --  Schedule(Scheduler,CurTask, PS);
            ND.PS := RUN;  --  !! Should call the task scheduler instead !!
            ND.SYSCLOCK := GetClock;
            if ND.Snap then
              ShowTime;
            end if;
            if ND.Snap then
              SnapShot;
            end if;
            exit when ND.PS /= WAIT;
          end loop;
          --
          exit Running_State when ND.PS = DEADLOCK or ND.PS = FIN;
          --
          ND.TIMER:= ND.SYSCLOCK + ND.TCB (ND.CurTask).QUANTUM;
          ND.TCB (ND.CurTask).TS := Running;
          ND.SWITCH := False;
          if ND.Snap then
            SnapShot;
          end if;
        end if;
      end if;

      Fetch_Instruction;

      --  HERE IS THE POINT WHERE THE TASK MONITORING IS CALLED
      --  (removed)

      Execute_Current_Instruction;

      exit when ND.PS /= RUN;
    end loop Running_State;
    --
    if ND.PS /= FIN then
      Post_Mortem_Dump (CD, ND);
    end if;
    --
    Free_Allocated_Contents (ND);
  end Interpret;

  procedure Interpret_on_Current_IO (
    CD_CIO         : Compiler_Data;
    Argument_Shift : Natural := 0    --  Number of arguments to be skipped
  )
  is
    function Shifted_Argument_Count return Natural is
    begin
      return Ada.Command_Line.Argument_Count - Argument_Shift;
    end;

    function Shifted_Argument (Number : Positive) return String is
    begin
      return Ada.Command_Line.Argument (Number + Argument_Shift);
    end;

    function Get_Needs_Skip_Line return Boolean is
    begin
      return True;  --  The input is buffered with Ada.Text_IO.Get (not Get_Immediate).
    end Get_Needs_Skip_Line;

    procedure Interpret_on_Current_IO_Instance is new Interpret
      ( Ada.Text_IO.End_Of_File,
        Ada.Text_IO.End_Of_Line,
        Get_Needs_Skip_Line,
        Defs.IIO.Get,
        Defs.RIO.Get,
        Ada.Text_IO.Get,
        Ada.Text_IO.Get_Immediate,
        Ada.Text_IO.Get_Line,
        Ada.Text_IO.Skip_Line,
        Defs.IIO.Put,
        Defs.RIO.Put,
        Defs.BIO.Put,
        Ada.Text_IO.Put,
        Ada.Text_IO.Put,
        Ada.Text_IO.New_Line,
        Shifted_Argument_Count,
        Shifted_Argument,
        HAC_Pack.Shell_Execute,
        HAC_Pack.Directory_Separator
      );

  begin
    Interpret_on_Current_IO_Instance (CD_CIO);
  end Interpret_on_Current_IO;

end HAC.PCode.Interpreter;
