with Ada.Calendar,
     Ada.Characters.Handling,
     Ada.Environment_Variables,
     Ada.Numerics.Float_Random,
     Ada.Strings;

package body HAC.PCode.Interpreter.Operators is

  procedure Do_Binary_Operator (ND : in out Interpreter_Data) is
    Curr_TCB_Top : Integer renames ND.TCB (ND.CurTask).T;
    X : GRegister renames ND.S (Curr_TCB_Top - 1);
    Y : GRegister renames ND.S (Curr_TCB_Top);
    use Defs.VStrings_Pkg, Defs.REF;
    use type Defs.HAC_Float;
  begin
    --  We do  [T] <- ([T-1] operator [T])  and pop later.
    case Binary_Operator_Opcode (ND.IR.F) is
      when k_EQL_Float =>   X.I := Boolean'Pos (X.R =  Y.R);
      when k_NEQ_Float =>   X.I := Boolean'Pos (X.R /= Y.R);
      when k_LSS_Float =>   X.I := Boolean'Pos (X.R <  Y.R);
      when k_LEQ_Float =>   X.I := Boolean'Pos (X.R <= Y.R);
      when k_GTR_Float =>   X.I := Boolean'Pos (X.R >  Y.R);
      when k_GEQ_Float =>   X.I := Boolean'Pos (X.R >= Y.R);
      --
      when k_EQL_Integer => X.I := Boolean'Pos (X.I =  Y.I);
      when k_NEQ_Integer => X.I := Boolean'Pos (X.I /= Y.I);
      when k_LSS_Integer => X.I := Boolean'Pos (X.I <  Y.I);
      when k_LEQ_Integer => X.I := Boolean'Pos (X.I <= Y.I);
      when k_GTR_Integer => X.I := Boolean'Pos (X.I >  Y.I);
      when k_GEQ_Integer => X.I := Boolean'Pos (X.I >= Y.I);
      --
      when k_EQL_VString => X.I := Boolean'Pos (X.V =  Y.V);
      when k_NEQ_VString => X.I := Boolean'Pos (X.V /= Y.V);
      when k_LSS_VString => X.I := Boolean'Pos (X.V <  Y.V);
      when k_LEQ_VString => X.I := Boolean'Pos (X.V <= Y.V);
      when k_GTR_VString => X.I := Boolean'Pos (X.V >  Y.V);
      when k_GEQ_VString => X.I := Boolean'Pos (X.V >= Y.V);
      --
      when k_AND_Boolean => X.I := Boolean'Pos (Boolean'Val (X.I) and Boolean'Val (Y.I));
      when k_OR_Boolean  => X.I := Boolean'Pos (Boolean'Val (X.I) or  Boolean'Val (Y.I));
      when k_XOR_Boolean => X.I := Boolean'Pos (Boolean'Val (X.I) xor Boolean'Val (Y.I));
      --
      when k_ADD_Integer      => X.I := X.I + Y.I;
      when k_SUBTRACT_Integer => X.I := X.I - Y.I;
      when k_MULT_Integer     => X.I := X.I * Y.I;
      when k_DIV_Integer      => if Y.I = 0 then ND.PS := DIVCHK; else X.I := X.I / Y.I; end if;
      when k_MOD_Integer      => if Y.I = 0 then ND.PS := DIVCHK; else X.I := X.I mod Y.I; end if;
      when k_Power_Integer    => X.I := X.I ** Y.I;
      --
      when k_ADD_Float           => X.R := X.R + Y.R;
      when k_SUBTRACT_Float      => X.R := X.R - Y.R;
      when k_MULT_Float          => X.R := X.R * Y.R;
      when k_DIV_Float           => X.R := X.R / Y.R;
      when k_Power_Float         => X.R := X.R ** Y.R;
      when k_Power_Float_Integer => X.R := X.R ** Y.I;
    end case;
    Pop (ND);
  end Do_Binary_Operator;

  procedure Do_SF_Operator (CD : Compiler_Data; ND : in out Interpreter_Data) is
      Curr_TCB : Task_Control_Block renames ND.TCB (ND.CurTask);
      Top_Item : GRegister renames ND.S (Curr_TCB.T);
      temp : Defs.HAC_Float;
      Idx, Len, From, To : Integer;
      C : Character;
      Code : constant SF_Code := SF_Code'Val (ND.IR.Y);
      use Defs, Defs.VStrings_Pkg, Defs.REF,
          Ada.Calendar, Ada.Characters.Handling,
          Ada.Numerics.Float_Random, Ada.Strings;
    begin
      case Code is
        when SF_Abs_Int   => Top_Item.I := abs (Top_Item.I);
        when SF_Abs_Float => Top_Item.R := abs (Top_Item.R);
        when SF_T_Val =>   --  S'Val : RM 3.5.5 (5)
          if (Top_Item.I < Defs.OrdMinChar) or
            (Top_Item.I > Defs.OrdMaxChar)  --  !! Character range
          then
            ND.PS := INXCHK;  --  Seems an out-of-range
          end if;
        when SF_T_Pos =>   --  S'Pos : RM 3.5.5 (2)
          null;
        when SF_T_Succ => Top_Item.I := Top_Item.I + 1;  --  S'Succ : RM 3.5 (22)
        when SF_T_Pred => Top_Item.I := Top_Item.I - 1;  --  S'Pred : RM 3.5 (25)
        when SF_Round_Float_to_Int =>
          --  The stack top may change its type here (if register has discriminant).
          Top_Item.I := Integer (Top_Item.R);
        when SF_Trunc_Float_to_Int =>
          --  The stack top may change its type here (if register has discriminant).
          Top_Item.I := Integer (Defs.HAC_Float'Floor (Top_Item.R));
        when SF_Sin =>    Top_Item.R := Sin (Top_Item.R);
        when SF_Cos =>    Top_Item.R := Cos (Top_Item.R);
        when SF_Exp =>    Top_Item.R := Exp (Top_Item.R);
        when SF_Log =>    Top_Item.R := Log (Top_Item.R);
        when SF_Sqrt =>   Top_Item.R := Sqrt (Top_Item.R);
        when SF_Arctan => Top_Item.R := Arctan (Top_Item.R);
        when SF_Random_Int =>
          temp := Defs.HAC_Float (Random (ND.Gen)) *
                  Defs.HAC_Float ((Top_Item.I + 1));
          Top_Item.I := Integer (Defs.HAC_Float'Floor (temp));
        when SF_String_to_VString =>   --  Unary "+"
          Pop (ND);
          Idx := ND.S (Curr_TCB.T).I;      --  Index in the stack
          Len := ND.S (Curr_TCB.T + 1).I;  --  Length of string
          ND.S (Curr_TCB.T).V :=
            To_VString (Get_String_from_Stack (ND, Idx, Len));
        when SF_Literal_to_VString =>  --  Unary "+"
          Pop (ND);
          Len := ND.S (Curr_TCB.T).I;      --  Length of string
          Idx := ND.S (Curr_TCB.T + 1).I;  --  Index to string table
          ND.S (Curr_TCB.T).V :=
            To_VString (CD.Strings_Constants_Table (Idx .. Idx + Len - 1));
        when SF_Two_VStrings_Concat =>
          Pop (ND);
          --  [T] := [T] & [T+1] :
          ND.S (Curr_TCB.T).V := ND.S (Curr_TCB.T).V & ND.S (Curr_TCB.T + 1).V;
        when SF_VString_Char_Concat =>
          Pop (ND);
          ND.S (Curr_TCB.T).V := ND.S (Curr_TCB.T).V & Character'Val (ND.S (Curr_TCB.T + 1).I);
        when SF_Char_VString_Concat =>
          Pop (ND);
          ND.S (Curr_TCB.T).V := Character'Val (ND.S (Curr_TCB.T).I) & ND.S (Curr_TCB.T + 1).V;
        when SF_LStr_VString_Concat =>
          --  Literal: 2 items, VString: 1 item. Total, 3 items folded into 1 item.
          Pop (ND, 2);
          Len := ND.S (Curr_TCB.T).I;      --  Length of string
          Idx := ND.S (Curr_TCB.T + 1).I;  --  Index to string table
          ND.S (Curr_TCB.T).V :=
            CD.Strings_Constants_Table (Idx .. Idx + Len - 1) & ND.S (Curr_TCB.T + 2).V;
        when SF_VString_Int_Concat =>
          Pop (ND);
          ND.S (Curr_TCB.T).V := ND.S (Curr_TCB.T).V & To_VString (HAC_Image (ND.S (Curr_TCB.T + 1).I));
        when SF_Int_VString_Concat =>
          Pop (ND);
          ND.S (Curr_TCB.T).V := To_VString (HAC_Image (ND.S (Curr_TCB.T).I)) & ND.S (Curr_TCB.T + 1).V;
        when SF_VString_Float_Concat =>
          Pop (ND);
          ND.S (Curr_TCB.T).V := ND.S (Curr_TCB.T).V & To_VString (HAC_Image (ND.S (Curr_TCB.T + 1).R));
        when SF_Float_VString_Concat =>
          Pop (ND);
          ND.S (Curr_TCB.T).V := To_VString (HAC_Image (ND.S (Curr_TCB.T).R)) & ND.S (Curr_TCB.T + 1).V;
        when SF_Element =>
          Pop (ND);
          --  [T] := Element ([T], [T+1]) :
          C := Element (ND.S (Curr_TCB.T).V, ND.S (Curr_TCB.T + 1).I);
          --  The stack top may change its type here (if register has discriminant).
          ND.S (Curr_TCB.T).I := Character'Pos (C);
        when SF_Length =>
          --  [T] := Length ([T]) :
          Len := Length (Top_Item.V);
          --  !! Here: bound checking !!
          --  The stack top item may change its type here (if register has discriminant).
          Top_Item.I := Len;
        when SF_Slice =>
          Pop (ND, 2);
          From := ND.S (Curr_TCB.T + 1).I;
          To   := ND.S (Curr_TCB.T + 2).I;
          --  !! Here: bound checking !!
          --  [T] := Slice ([T], [T+1], [T+2]) :
          ND.S (Curr_TCB.T).V := To_VString (Slice (ND.S (Curr_TCB.T).V, From, To));
        when SF_To_Lower_Char =>
          Top_Item.I := Character'Pos (To_Lower (Character'Val (Top_Item.I)));
        when SF_To_Upper_Char =>
          Top_Item.I := Character'Pos (To_Upper (Character'Val (Top_Item.I)));
        when SF_To_Lower_VStr =>
          Top_Item.V := To_VString (To_Lower (To_String (Top_Item.V)));
        when SF_To_Upper_VStr =>
          Top_Item.V := To_VString (To_Upper (To_String (Top_Item.V)));
        when SF_Index =>
          Pop (ND);
          --  [T] := Index ([T], [T+1]) :
          ND.S (Curr_TCB.T).I :=
            VStrings_Pkg.Index (ND.S (Curr_TCB.T).V, To_String (ND.S (Curr_TCB.T + 1).V));
        when SF_Int_Times_Char =>
          Pop (ND);
          --  [T] := [T] * [T+1] :
          ND.S (Curr_TCB.T).V := ND.S (Curr_TCB.T).I * Character'Val (ND.S (Curr_TCB.T + 1).I);
        when SF_Int_Times_VStr =>
          Pop (ND);
          --  [T] := [T] * [T+1] :
          ND.S (Curr_TCB.T).V := ND.S (Curr_TCB.T).I * ND.S (Curr_TCB.T + 1).V;
        when SF_Trim_Left  => Top_Item.V := Trim (Top_Item.V, Left);
        when SF_Trim_Right => Top_Item.V := Trim (Top_Item.V, Right);
        when SF_Trim_Both  => Top_Item.V := Trim (Top_Item.V, Both);
        --
        when SF_Image_Ints             => Top_Item.V := To_VString (HAC_Image (Top_Item.I));
        when SF_Image_Floats           => Top_Item.V := To_VString (HAC_Image (Top_Item.R));
        when SF_Image_Attribute_Floats => Top_Item.V := To_VString (HAC_Float'Image (Top_Item.R));
        --
        when SF_Integer_Value => Top_Item.I := HAC_Integer'Value (To_String (Top_Item.V));
        when SF_Float_Value   => Top_Item.R := HAC_Float'Value   (To_String (Top_Item.V));
        when SF_Get_Env =>
          declare
            use Ada.Environment_Variables;
            Name : constant String := To_String (Top_Item.V);
          begin
            if Exists (Name) then
              Top_Item.V := To_VString (Value (Name));
            else
              Top_Item.V := Null_VString;
            end if;
          end;
        when SF_Niladic =>
          --  NILADIC functions need to push a new item (their own result).
          Push (ND);
          case SF_Niladic (Code) is
            when SF_Clock =>
              --  CLOCK function. Return time of units of seconds.
              ND.S (Curr_TCB.T).R := Defs.HAC_Float (GetClock - ND.Start_Time);
            when SF_Random_Float =>
              ND.S (Curr_TCB.T).R := Defs.HAC_Float (Random (ND.Gen));
            when SF_Argument_Count | SF_Directory_Separator | SF_Get_Needs_Skip_Line =>
              null;  --  Already processed by Do_Standard_Function (bound to generic functions).
          end case;
        when SF_EOF | SF_EOLN | SF_Argument | SF_Shell_Execute =>
          null;  --  Already processed by Do_Standard_Function (bound to generic functions).
      end case;
  end Do_SF_Operator;

end HAC.PCode.Interpreter.Operators;