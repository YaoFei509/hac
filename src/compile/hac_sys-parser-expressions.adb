with HAC_Sys.Compiler.PCode_Emit;
with HAC_Sys.Parser.Attributes;
with HAC_Sys.Parser.Calls;
with HAC_Sys.Parser.Helpers;
with HAC_Sys.Parser.Ranges;
with HAC_Sys.Parser.Standard_Functions;
with HAC_Sys.Parser.Type_Conversion;
with HAC_Sys.PCode;
with HAC_Sys.Scanner;
with HAC_Sys.Errors;

package body HAC_Sys.Parser.Expressions is

  use Compiler.PCode_Emit, Co_Defs, Defs, Helpers, PCode, Scanner, Errors;

  procedure Static_Scalar_Expression
    (CD      : in out Co_Defs.Compiler_Data;
     Level   : in     Defs.Nesting_Level;
     FSys_ND : in     Defs.Symset;
     C       :    out Co_Defs.Constant_Rec)
  is
    --  This covers number declarations (RM 3.3.2) and enumeration items (RM 3.5.1).
    --  Additionally this compiler does on-the-fly declarations for static values:
    --  bounds in ranges (FOR, ARRAY), and values in CASE statements.
    --  Was: Constant in the Pascal compiler.
    X : Integer;
    Sign : HAC_Integer;
    use type HAC_Float, HAC_Integer;
    signed : Boolean := False;
    procedure In_Symbol is begin Scanner.In_Symbol (CD); end In_Symbol;
  begin
    C.TP := undefined_subtyp;
    C.I  := 0;
    Test (CD, Constant_Definition_Begin_Symbol, FSys_ND, err_illegal_symbol_for_a_number_declaration);
    if not Constant_Definition_Begin_Symbol (CD.Sy) then
      return;
    end if;
    if CD.Sy = character_literal then  --  Untyped character constant, occurs only in ranges.
      Construct_Root (C.TP, Chars);
      C.I  := CD.INum;
      In_Symbol;
    else
      Sign := 1;
      if CD.Sy in Plus_Minus then
        signed := True;
        if CD.Sy = Minus then
          Sign := -1;
        end if;
        In_Symbol;
      end if;
      case CD.Sy is
        when IDent =>
          --  Number defined using another one: "minus_pi : constant := -pi;"
          --  ... or, we have an enumeration item.
          X := Locate_CD_Id (CD, Level);
          if X /= 0 then
            if CD.id_table (X).entity = declared_number_or_enum_item then
              C.TP := CD.id_table (X).xtyp;
              if C.TP.TYP = Floats then
                C.R := HAC_Float (Sign) * CD.Float_Constants_Table (Integer (CD.id_table (X).adr_or_sz));
              else
                C.I := Sign * CD.id_table (X).adr_or_sz;
                if signed and then C.TP.TYP not in Numeric_Typ then
                  Error (CD, err_numeric_constant_expected);
                end if;
              end if;
            else
              Error (CD, err_illegal_constant_or_constant_identifier, severity => major);
            end if;
          end if;  --  X /= 0
          In_Symbol;

        when integer_literal =>
          C.TP.Construct_Root (Ints);
          C.I := Sign * CD.INum;
          In_Symbol;

        when real_literal =>
          C.TP.Construct_Root (Floats);
          C.R := HAC_Float (Sign) * CD.RNum;
          In_Symbol;

        when others =>
          Error_then_Skip (CD, FSys_ND, err_illegal_symbol_for_a_number_declaration);
      end case;
    end if;
    Test (CD, FSys_ND, empty_symset, err_incorrectly_used_symbol);
  end Static_Scalar_Expression;

  ------------------------------------------------------------------
  ---------------------------------------------------------Selector-
  procedure Selector
    (CD      : in out Co_Defs.Compiler_Data;
     context : in     Defs.Flow_Context;
     FSys    : in     Defs.Symset;
     V       : in out Co_Defs.Exact_Subtyp)
  is

    procedure Record_Field_Selector is
      Field_Offset, Field_Id : Integer;
      use type Alfa;
    begin
      if V.TYP = Records then
        Field_Id := CD.Blocks_Table (V.Ref).Last_Id_Idx;
        CD.id_table (0).name := CD.Id;
        while CD.id_table (Field_Id).name /= CD.Id loop  --  Search field identifier
          Field_Id := CD.id_table (Field_Id).link;
        end loop;
        if Field_Id = No_Id then
          Error (CD, err_undefined_identifier, A2S (CD.Id_with_case), severity => major);
        else
          CD.target.Mark_Reference (Field_Id);
          CD.id_table (Field_Id).is_referenced := True;
          Elevate_to_Maybe (CD.id_table (Field_Id).is_read);
          V := CD.id_table (Field_Id).xtyp;
          Field_Offset := Integer (CD.id_table (Field_Id).adr_or_sz);
          if Field_Offset /= 0 then
            Emit_1 (CD, k_Record_Field_Offset, Operand_2_Type (Field_Offset));
          end if;
        end if;
      else
        Error (CD, err_var_with_field_selector_must_be_record);
      end if;
      In_Symbol (CD);
    end Record_Field_Selector;

    procedure Array_Coordinates_Selector is
      Array_Index_Typ : Exact_Subtyp;  --  Evaluation of "i", "j+7", "k*2" in "a (i, j+7, k*2)".
      use type HAC_Integer;

      procedure Emit_Index_Instructions (ATI : Integer; ATE : Array_Table_Entry) is
        range_check_needed : constant Boolean :=
          Array_Index_Typ.Discrete_First < ATE.Index_xTyp.Discrete_First or else
          Array_Index_Typ.Discrete_Last  > ATE.Index_xTyp.Discrete_Last;
      begin
        if ATE.Element_Size = 1 then
          if range_check_needed then
            Emit_1 (CD, k_Array_Index_Element_Size_1, Operand_2_Type (ATI));
          else
            Emit_1 (CD, k_Array_Index_No_Check_Element_Size_1, Operand_2_Type (ATI));
          end if;
        else
          if range_check_needed then
            Emit_1 (CD, k_Array_Index, Operand_2_Type (ATI));
          else
            Emit_1 (CD, k_Array_Index_No_Check, Operand_2_Type (ATI));
          end if;
        end if;
      end Emit_Index_Instructions;

      procedure Show_Range_Error (ATE : Array_Table_Entry) is
      begin
        Error
          (CD, err_range_constraint_error,
           "value of index (" &
           (if Ranges.Is_Singleton_Range (Array_Index_Typ) then
              --  More understandable message part for a single value
              Discrete_Image
               (CD,
                Array_Index_Typ.Discrete_First,
                ATE.Index_xTyp.TYP,
                ATE.Index_xTyp.Ref)
            else
              "range: " &
              Discrete_Range_Image
                (CD,
                 Array_Index_Typ.Discrete_First,
                 Array_Index_Typ.Discrete_Last,
                 ATE.Index_xTyp.TYP,
                 ATE.Index_xTyp.Ref)) &
              ") is out of the array's range, " &
              Discrete_Range_Image
                (CD,
                 ATE.Index_xTyp.Discrete_First,
                 ATE.Index_xTyp.Discrete_Last,
                 ATE.Index_xTyp.TYP,
                 ATE.Index_xTyp.Ref),
              severity => minor);
      end Show_Range_Error;

      procedure Show_Type_Mismatch_Error (ATE : Array_Table_Entry) is
      begin
        Type_Mismatch
          (CD,
           err_wrong_type_for_array_index,
           Found    => Array_Index_Typ,
           Expected => ATE.Index_xTyp);
      end Show_Type_Mismatch_Error;

      indices : Natural := 0;
      first_dimension : Boolean := True;
      dims : Integer;

    begin
      Array_Indices :
      loop
        In_Symbol (CD);  --  Consume '(', (wrongly) '[', or ',' symbol.
        Expression (CD, context, FSys + Comma_RParent + RBrack, Array_Index_Typ);
        indices := indices + 1;
        if V.TYP = Arrays then
          declare
            ATI : constant Integer := V.Ref;
            ATE : Array_Table_Entry renames CD.Arrays_Table (ATI);
          begin
            if first_dimension then
              dims := ATE.dimensions;
              first_dimension := False;
            end if;
            if Exact_Typ (ATE.Index_xTyp) /= Exact_Typ (Array_Index_Typ) then
              Show_Type_Mismatch_Error (ATE);
            elsif Ranges.Do_Ranges_Overlap (Array_Index_Typ,  ATE.Index_xTyp) then
              Emit_Index_Instructions (ATI, ATE);
            else
              Show_Range_Error (ATE);
            end if;
            V := ATE.Element_xTyp;
          end;
        else
          Error (CD, err_indexed_variable_must_be_an_array);
        end if;
        exit Array_Indices when CD.Sy /= Comma;
      end loop Array_Indices;
      if indices < dims then
        Error (CD, err_too_few_array_indices, indices'Image, dims'Image);
      elsif indices > dims then
        Error (CD, err_too_many_array_indices, indices'Image, dims'Image);
      end if;
    end Array_Coordinates_Selector;

  begin
    pragma Assert (Selector_Symbol_Loose (CD.Sy));  --  '.' or '(' or (wrongly) '['
    loop
      if CD.Sy = Period then
        --  Record field selector.
        In_Symbol (CD);  --  Consume '.' symbol.
        if CD.Sy = IDent then
          Record_Field_Selector;
        else
          Error (CD, err_identifier_missing);
        end if;
      else
        --  Array element selector.
        if CD.Sy = LBrack then  --  '['
          --  Common mistake by Pascal, Python or R programmers.
          Error (CD, err_left_bracket_instead_of_parenthesis);
        end if;
        Array_Coordinates_Selector;
        if CD.Sy = RBrack then  --  ']' : same kind of mistake as for '[' ...
          Error (CD, err_right_bracket_instead_of_parenthesis);
          In_Symbol (CD);
        else
          Need (CD, RParent, err_closing_parenthesis_missing);
        end if;
      end if;
      exit when not Selector_Symbol_Loose (CD.Sy);
    end loop;
    --
    Test
      (CD, FSys, empty_symset,
       (if FSys = Semicolon_Set then err_semicolon_missing else err_incorrectly_used_symbol));
  end Selector;

  is_logical_operator : constant Symset :=          --  RM 4.5 (2)
    (AND_Symbol | OR_Symbol | XOR_Symbol => True,
     others => False);

  relational_operator : constant Symset :=          --  RM 4.5 (3)
    (Comparison_Operator => True, others => False);

  binary_adding_operator : constant Symset :=       --  RM 4.5 (4)
    (Plus | Minus | Ampersand_Symbol => True,
     others => False);

  multiplying_operator : constant Symset :=         --  RM 4.5 (6)
    (Times | Divide | MOD_Symbol | REM_Symbol => True,
     others => False);

  highest_precedence_operator : constant Symset :=  --  RM 4.5 (7)
    (ABS_Symbol | NOT_Symbol | Power => True,
     others => False);

  ------------------------------------------------------------------
  -------------------------------------------------------Expression-
  procedure Expression
    (CD      : in out Co_Defs.Compiler_Data;
     context : in     Defs.Flow_Context;
     FSys    : in     Defs.Symset;
     X       :    out Co_Defs.Exact_Subtyp)
  is
    procedure Relation (FSys_Rel : Symset; X : out Exact_Subtyp) is  --  RM 4.4 (3)
      Y : Exact_Subtyp;

      procedure Issue_Comparison_Type_Mismatch_Error is
      begin
        Type_Mismatch (CD, err_incompatible_types_for_comparison, Found => Y, Expected => X);
      end Issue_Comparison_Type_Mismatch_Error;

      Rel_OP : Symbol;
      Not_In : Boolean;

    begin  --  Relation
      --
      --  Single  simple_expression,  or:  simple_expression OPERATOR simple_expression
      --
      Simple_Expression (CD, context, FSys_Rel + relational_operator + IN_Symbol + NOT_Symbol, X);
      --
      case CD.Sy is
        when Comparison_Operator =>
          --
          --  We collect here a comparison (relational) operator, e.g.: x < y
          --
          Rel_OP := CD.Sy;
          In_Symbol (CD);
          Simple_Expression (CD, context, FSys_Rel, Y);
          if Internally_VString_Set (X.TYP) and then Internally_VString_Set (Y.TYP) then
            --  The internal type is actually a VString on both sides.
            Emit_Comparison_Instruction (CD, Rel_OP, VStrings);
          elsif Is_Char_Array (CD, X) and Is_Char_Array (CD, Y) then
            --  String object comparison, e.g. sx = sy
            Emit (CD, k_Swap);
            Emit_Std_Funct
              (CD,
               SF_String_to_VString,
               Operand_1_Type (CD.Arrays_Table (X.Ref).Array_Size));
            Emit (CD, k_Swap);
            Emit_Std_Funct
              (CD,
               SF_String_to_VString,
               Operand_1_Type (CD.Arrays_Table (Y.Ref).Array_Size));
            Emit_Comparison_Instruction (CD, Rel_OP, VStrings);
          elsif X.TYP = Y.TYP then
            if X.TYP = Enums and then X.Ref /= Y.Ref then
              Issue_Comparison_Type_Mismatch_Error;
            elsif PCode_Atomic_Comparable_Typ (X.TYP) then
              Emit_Comparison_Instruction (CD, Rel_OP, X.TYP);
            else
              Issue_Undefined_Operator_Error (CD, Rel_OP, X, Y);
            end if;
          elsif Is_Char_Array (CD, X) and Y.TYP = String_Literals then
            --  s = "abc"
            --  We needs convert the literal before anything else,
            --  since it takes two elements on the stack.
            Emit_Std_Funct (CD, SF_String_Literal_to_VString);
            Emit (CD, k_Swap);
            Emit_Std_Funct
              (CD,
               SF_String_to_VString,
               Operand_1_Type (CD.Arrays_Table (X.Ref).Array_Size));
            Emit (CD, k_Swap);
            Emit_Comparison_Instruction (CD, Rel_OP, VStrings);
          elsif Internally_VString_Set (X.TYP) and then Y.TYP = String_Literals then
            --  E.g., X < "World".
            --  Y is on top of the stack, we turn it into a VString.
            --  If this becomes a perfomance issue we could consider
            --  a new Standard Function (SF_Code) for (VStr op Lit_Str).
            Emit_Std_Funct (CD, SF_String_Literal_to_VString);     --  Now we have X < +"World".
            Emit_Comparison_Instruction (CD, Rel_OP, VStrings);    --  Emit "<" (X, +Y).
          elsif X.TYP = Ints and Y.TYP = Floats then
            Forbid_Type_Coercion (CD, Rel_OP, X, Y);
            X.TYP := Floats;
            Emit_1 (CD, k_Integer_to_Float, 1);
          elsif X.TYP = Floats and Y.TYP = Ints then
            Forbid_Type_Coercion (CD, Rel_OP, X, Y);
            Y.TYP := Floats;
            Emit_1 (CD, k_Integer_to_Float, 0);
          else
            Issue_Comparison_Type_Mismatch_Error;
          end if;
          Construct_Root (X, Bools);  --  The result of the comparison is always Boolean.
        when IN_Symbol | NOT_Symbol =>
          --
          --  We collect here a membership test, e.g.: x [not] in a .. b
          --
          Not_In := CD.Sy = NOT_Symbol;
          In_Symbol (CD);
          if Not_In then
            Need (CD, IN_Symbol, err_IN_missing);
          end if;
          if CD.error_count = 0 then
            Ranges.Dynamic_Range (CD, context, FSys_Rel, err_discrete_type_expected, Y);
            if Exact_Typ (X) /= Exact_Typ (Y) then
              Type_Mismatch (CD, err_membership_test_type_mismatch, Found => Y, Expected => X);
              --  The RM 4.5.2 (2) seems to accept any types for X and Y. The test would be False
              --  if types were incompatible. However, in that situation, GNAT says
              --  "incompatible types", ObjectAda says "LRM:8.6(28), Inappropriate operands
              --  for "IN" operation".
            end if;
            if Not_In then
              Emit_Std_Funct (CD, SF_not_in_discrete_Interval);
            else
              Emit_Std_Funct (CD, SF_in_discrete_Interval);
            end if;
            Construct_Root (X, Bools);  --  The result of the membership test is always Boolean.
          end if;
        when others =>
          null;
      end case;
    end Relation;

    logical_operator  : Symbol;
    previous_operator : Symbol;
    Y                 : Exact_Subtyp;
    short_circuit     : Boolean;
    LC_Cond_Jump      : Integer;

    procedure Process_Short_Circuit (Cond_Jump : Opcode) is
    begin
      In_Symbol (CD);
      short_circuit := True;
      LC_Cond_Jump := CD.LC;
      Emit (CD, Cond_Jump);
      Emit (CD, k_Pop);      --  Discard X value from stack. Top item will be Y.
    end Process_Short_Circuit;

  begin  --  Expression
    Relation (FSys + is_logical_operator, X);
    --
    --  RM 4.4 (2): we collect here possible relations, connected by
    --              logical operators: X {and Y}.
    --
    previous_operator := Dummy_Symbol;
    while is_logical_operator (CD.Sy) loop
      logical_operator := CD.Sy;
      In_Symbol (CD);
      --
      --  Short-circuit forms of AND, OR.
      --
      short_circuit := False;
      if logical_operator = AND_Symbol and CD.Sy = THEN_Symbol then
        Process_Short_Circuit (k_Jump_If_Zero_No_Pop);
        --
        --    Jump on X = False (i.e. 0). If X = True, then X and Y = Y.
        --
        --       X          :    0      0      1      1
        --                         \      \
        --       Y          :    0  |   1  |   0      1
        --                         /      /    |      |
        --       X and Y    :    0      0      0      1
        --
        logical_operator := AND_THEN_Symbol;
      elsif logical_operator = OR_Symbol and CD.Sy = ELSE_Symbol then
        Process_Short_Circuit (k_Jump_If_Non_Zero_No_Pop);
        --
        --    Jump on X = True (i.e. 1). If X = False, then X or Y = Y.
        --
        --       X          :    0      0      1      1
        --                                       \      \
        --       Y          :    0      1      0  |   1  |
        --                       |      |        /      /
        --       X or Y     :    0      1      1      1
        --
        logical_operator := OR_ELSE_Symbol;
      end if;
      if previous_operator /= Dummy_Symbol and then logical_operator /= previous_operator then
        Error (CD, err_mixed_logical_operators, severity => minor);
      end if;
      --
      --  Right side of the logical operator.
      --
      Relation (FSys + is_logical_operator, Y);
      --
      if X.TYP = Bools and Y.TYP = Bools then
        if short_circuit then
          --  Patch the address for the conditional jump, with the place
          --  right after the evaluation of relation Y:
          CD.ObjCode (LC_Cond_Jump).Y := Operand_2_Type (CD.LC);
        else
          case logical_operator is
            when AND_Symbol => Emit (CD, k_AND_Boolean);
            when OR_Symbol  => Emit (CD, k_OR_Boolean);
            when XOR_Symbol => Emit (CD, k_XOR_Boolean);
            when others     => null;
          end case;
        end if;
      else
        Error (CD, err_resulting_type_should_be_Boolean);
        X.TYP := NOTYP;
      end if;
      previous_operator := logical_operator;
    end loop;
    if X.TYP = NOTYP and then CD.error_count = 0 then
      Error (CD, err_object_used_before_end_own_declaration, severity => major);
    end if;
  end Expression;

  procedure Simple_Expression                                            --  RM 4.4 (4)
    (CD      : in out Co_Defs.Compiler_Data;
     context : in     Defs.Flow_Context;
     FSys    : in     Defs.Symset;
     X       :    out Co_Defs.Exact_Subtyp)
  is

    procedure Term (FSys_Term : Symset; X : out Exact_Subtyp) is         --  RM 4.4 (5)

      procedure Factor (FSys_Fact : Symset; X : out Exact_Subtyp) is     --  RM 4.4 (6)

        procedure Primary (FSys_Prim : Symset; X : out Exact_Subtyp) is  --  RM 4.4 (7)

          procedure Process_Identifier is
            ident_index : constant Integer := Locate_CD_Id (CD, context.level);
            r : Identifier_Table_Entry renames CD.id_table (ident_index);

            procedure Process_Object_Identifier is
              LC_Mem : constant Integer := CD.LC;
            begin
              if Selector_Symbol_Loose (CD.Sy) then  --  '.' or '(' or (wrongly) '['
                Emit_2
                  (CD,
                   (if r.normal then
                      k_Push_Address           --  Composite: push "v'Access".
                    else
                      k_Push_Discrete_Value),  --  Composite: push "(a.all)'Access", that is, a.
                   Operand_1_Type (r.lev),
                   Operand_2_Type (r.adr_or_sz));

                Selector (CD, context, FSys_Prim + Apostrophe, X);

                if Standard_or_Enum_Typ (X.TYP) then
                  --  We are at a leaf point of composite type selection,
                  --  so the stack top is expected to contain a value, not
                  --  an address (for an expression).
                  Emit (CD, k_Dereference);
                end if;
              else
                --  No selector.
                Emit_2
                  (CD,
                   (if Standard_or_Enum_Typ (X.TYP) then
                     (if r.normal then
                       (if Discrete_Typ (r.xtyp.TYP) then
                          k_Push_Discrete_Value   --  Push variable v's discrete value.
                        else
                          k_Push_Value)           --  Push variable v's value.
                      else
                        k_Push_Indirect_Value)    --  Push "a.all" (a is an access).
                    elsif r.normal then
                      k_Push_Address              --  Composite: push "v'Access".
                    else
                      k_Push_Discrete_Value),     --  Composite: push "(a.all)'Access, that is, a.
                   Operand_1_Type (r.lev),
                   Operand_2_Type (r.adr_or_sz));
              end if;

              if CD.Sy = Apostrophe then  --  Attribute on an object.
                In_Symbol (CD);
                Attributes.Object_Attribute (CD, context.level, FSys_Prim, X, LC_Mem, X);
              else
                --  The variable or parameter itself, not an attribute on it, has been read.
                --  We check that it has been even written on the way to this expression.
                Mark_Read_and_Check_Read_before_Written (CD, context, r);
              end if;
            end Process_Object_Identifier;

          begin
            In_Symbol (CD);
            X := r.xtyp;

            case r.entity is

              when Object_Kind =>
                Process_Object_Identifier;

              when declared_number_or_enum_item =>
                if X.TYP = Floats then
                  --  Address is an index in the float constants table.
                  Emit_1 (CD, k_Push_Float_Literal, Operand_2_Type (r.adr_or_sz));
                else
                  --  Here the address is actually the immediate (discrete) value.
                  Emit_1 (CD, k_Push_Discrete_Literal, Operand_2_Type (r.adr_or_sz));
                  --  The local subtype for the value V is the range V .. V.
                  Ranges.Set_Singleton_Range (X, r.adr_or_sz);
                end if;

              when prozedure | prozedure_intrinsic =>
                Error (CD, err_expected_constant_function_variable_or_subtype);

              when funktion =>
                Calls.Subprogram_or_Entry_Call
                  (CD, context, FSys_Prim, ident_index, Normal_Procedure_Call);

              when funktion_intrinsic =>
                Standard_Functions.Standard_Function
                  (CD, context, FSys_Prim, ident_index, SF_Code'Val (r.adr_or_sz), X);

              when type_mark =>
                Subtype_Prefixed_Expression (CD, context, FSys_Prim, ident_index, X);

              when others =>
                null;
            end case;

            if X.TYP = NOTYP and then CD.error_count = 0 then
              Error
                (CD, err_object_used_before_end_own_declaration,
                 '"' & A2S (r.name_with_case) & """ ", severity => major);
            end if;
          end Process_Identifier;

        begin
          X := undefined_subtyp;
          Test (CD, Primary_Begin_Symbol, FSys_Prim, err_primary_unexpected_symbol);

          case CD.Sy is

            when IDent =>
              Process_Identifier;

            when character_literal | integer_literal =>
              --  Here we have a discrete literal.
              X.Construct_Root (if CD.Sy = character_literal then Chars else Ints);
              CD.target.Emit_Push_Discrete_Literal (CD.INum);
              --  The local subtype for the value V is the range V .. V.
              Ranges.Set_Singleton_Range (X, CD.INum);
              In_Symbol (CD);

            when real_literal =>
              X.Construct_Root (Floats);
              Emit_Push_Float_Literal (CD, CD.RNum);
              In_Symbol (CD);

            when string_literal =>
              Construct_Root (X, String_Literals);
              CD.target.Emit_Push_Discrete_Literals
                (Operand_1_Type (CD.SLeng),  --  String Literal Length
                 Operand_2_Type (CD.INum));  --  Index To String IdTab
              In_Symbol (CD);

            when LParent =>
              --  '(' : what is inside the parentheses is an
              --        expression of the lowest level.
              In_Symbol (CD);
              Expression (CD, context, FSys_Prim + RParent, X);
              if CD.Sy = Comma then
                Error (CD, err_not_yet_implemented, "aggregates (RM 4.3)", severity => major);
              end if;
              Need (CD, RParent, err_closing_parenthesis_missing);

            when others =>
              null;

          end case;

          if X.TYP = NOTYP and then CD.error_count = 0 then
            Error (CD, err_object_used_before_end_own_declaration, severity => major);
          end if;
        end Primary;

        Y : Exact_Subtyp;

      begin  --  Factor
        case CD.Sy is

          when ABS_Symbol =>
            In_Symbol (CD);
            Primary (FSys_Fact, X);
            case X.TYP is
              when Ints   => Emit_Std_Funct (CD, SF_Abs_Int);
              when Floats => Emit_Std_Funct (CD, SF_Abs_Float);
              when NOTYP  => null;  --  Another error before.
              when others => Error (CD, err_argument_to_std_function_of_wrong_type);
            end case;
            X.Construct_Root (X.TYP);  --  Forget subtype bounds

          when NOT_Symbol =>
            In_Symbol (CD);
            Primary (FSys_Fact, X);
            case X.TYP is
              when Bools => Emit (CD, k_NOT_Boolean);
              when NOTYP  => null;  --  Another error before.
              when others => Error (CD, err_resulting_type_should_be_Boolean);
            end case;

          when others =>
            Primary (FSys_Fact + highest_precedence_operator, X);
            if CD.Sy = Power then
              In_Symbol (CD);
              Primary (FSys_Fact, Y);
              if X.TYP in Numeric_Typ and then X.TYP = Y.TYP then
                CD.target.Emit_Arithmetic_Binary_Instruction (Power, X.TYP);
              elsif X.TYP = Floats and Y.TYP = Ints then
                Emit (CD, k_Power_Float_Integer);
              else
                Issue_Undefined_Operator_Error (CD, Power, X, Y);
              end if;
              X.Construct_Root (X.TYP);  --  Forget subtype bounds
            end if;
        end case;
      end Factor;

      use type HAC_Integer;
      Mult_OP : Symbol;
      Y       : Exact_Subtyp;
    begin  --  Term
      Factor (FSys_Term + multiplying_operator, X);
      --
      --  We collect here possible factors: a {* b}
      --
      while multiplying_operator (CD.Sy) loop
        Mult_OP := CD.Sy;
        In_Symbol (CD);
        Factor (FSys_Term + multiplying_operator, Y);
        if X.TYP = NOTYP or Y.TYP = NOTYP then
          null;  --  Something is already wrong at this point; nothing to check or emit.
        else
          case Mult_OP is

            when Times =>     --  *
              if X.TYP in Numeric_Typ and then Y.TYP in Numeric_Typ then
                if X.TYP = Y.TYP then
                  CD.target.Emit_Arithmetic_Binary_Instruction (Times, X.TYP);
                else
                  Forbid_Type_Coercion (CD, Mult_OP, X, Y);
                end if;
                --  Figure out the subtype range after the
                --  multiplication, if possible. NB: beyond trivial cases,
                --  compile-time overflow checks would be needed.
                if X.TYP = Ints then
                  --  Find some possible static values.
                  if Ranges.Is_Singleton_Range (X, 0) then
                    --  0 * Y = 0.
                    null;  --  Keep X's range, which is [0; 0].
                  elsif Ranges.Is_Singleton_Range (Y, 0) then
                    --  X * 0 = 0.
                    Ranges.Set_Singleton_Range (X, 0);
                  elsif Ranges.Is_Singleton_Range (X, 1) then
                    --  1 * Y = Y.
                    X.Discrete_First := Y.Discrete_First;
                    X.Discrete_Last  := Y.Discrete_Last;
                  elsif Ranges.Is_Singleton_Range (Y, 1) then
                    --  X * 1 = X.
                    null;  --  Keep X's range.
                  else
                    X.Construct_Root (X.TYP);  --  Forget subtype bounds
                  end if;
                end if;
              elsif X.TYP = Ints then
                --  N * (something non-numeric)
                case Y.TYP is
                  when Chars =>
                    Emit_Std_Funct (CD, SF_Int_Times_Char);  --  N * Some_Char
                    Construct_Root (X, VStrings);
                  when String_Literals =>
                    --  Y is on top of the stack, we turn it into a VString.
                    Emit_Std_Funct (CD, SF_String_Literal_to_VString);
                    Emit_Std_Funct (CD, SF_Int_Times_VStr);  --  N * Some_String_Literal
                    Construct_Root (X, VStrings);
                  when VStrings | Strings_as_VStrings =>
                    Emit_Std_Funct (CD, SF_Int_Times_VStr);  --  N * Some_VString
                    Construct_Root (X, VStrings);
                  when others =>
                    Issue_Undefined_Operator_Error (CD, Mult_OP, X, Y);
                end case;
              else
                Issue_Undefined_Operator_Error (CD, Mult_OP, X, Y);
              end if;

            when Divide =>    --  /
              if X.TYP in Numeric_Typ and then X.TYP = Y.TYP then
                CD.target.Emit_Arithmetic_Binary_Instruction (Divide, X.TYP);
                X.Construct_Root (X.TYP);  --  Forget subtype bounds
              else
                if X.TYP = Ints then
                  Forbid_Type_Coercion (CD, Mult_OP, X, Y);
                  Emit_1 (CD, k_Integer_to_Float, 1);  --  NB: this assumed Y.TYP was Floats!
                  X.TYP := Floats;
                end if;
                if Y.TYP = Ints then
                  Forbid_Type_Coercion (CD, Mult_OP, X, Y);
                  Emit_1 (CD, k_Integer_to_Float, 0);  --  NB: this assumed Y.TYP was Floats!
                  Y.TYP := Floats;
                end if;
                Error (CD, err_illegal_type_for_arithmetic_expression);
                X.TYP := NOTYP;
              end if;

            when MOD_Symbol | REM_Symbol =>
              if X.TYP = Ints and Y.TYP = Ints then
                if Mult_OP = MOD_Symbol then
                  Emit (CD, k_MOD_Integer);
                else
                  Emit (CD, k_REM_Integer);
                end if;
              else
                Error (CD, err_mod_requires_integer_arguments);
                X.TYP := NOTYP;
              end if;

            when others =>
              raise Internal_error with "Unknown operator in Term";
          end case;
        end if;
      end loop;
    end Term;

    procedure Check_HAT_Operator_Visibility (op : Symbol) is
    begin
      if not CD.CUD.Use_HAT_Stack (CD.CUD.use_hat_stack_top) then
        --  HAT is not USE-visible
        Error
          (CD,
           err_general_error,
           "operator (" & Op_Hint (op) &
           ") not visible (missing a ""use " & HAT_Name & """ clause)",
           severity => major);
      end if;
    end Check_HAT_Operator_Visibility;

    additive_operator : Symbol;
    y                 : Exact_Subtyp;

    function Do_VString_Concatenation return Boolean is
    begin
      if X.TYP /= VStrings and y.TYP /= VStrings then
        return False;
      end if;
      --  Below this line, at least X or Y is a VString, defined in the HAT package.
      Check_HAT_Operator_Visibility (Ampersand_Symbol);
      --  RM References are about Unbounded_String (A.4.5).
      if Internally_VString_Set (X.TYP) and then Internally_VString_Set (y.TYP) then
        --  v1 & v2              A.4.5 (15)
        --  v & Enum'Image (x)   A.4.5 (16),
        --  Enum'Image (x) & v   A.4.5 (17)
        Emit_Std_Funct (CD, SF_Two_VStrings_Concat);
      elsif y.TYP = String_Literals then                          --  v & "x"  A.4.5 (16)
        --  Y is on top of the stack, we turn it into a VString.
        --  If this becomes a perfomance issue we could consider
        --  adding a Standard Function (SF_Code) for (VStr op Lit_Str).
        Emit_Std_Funct (CD, SF_String_Literal_to_VString);
        --  Now we concatenate both VStrings.
        Emit_Std_Funct (CD, SF_Two_VStrings_Concat);
      elsif X.TYP = String_Literals then                          --  "x" & v  A.4.5 (17)
        Emit_Std_Funct (CD, SF_LStr_VString_Concat);
      elsif Is_Char_Array (CD, y) then                            --  v & s    A.4.5 (16)
        Emit_Std_Funct (CD,
          SF_String_to_VString,
          Operand_1_Type (CD.Arrays_Table (y.Ref).Array_Size)
        );
        Emit_Std_Funct (CD, SF_Two_VStrings_Concat);
      elsif Is_Char_Array (CD, X) then                            --  s & v    A.4.5 (17)
        Emit (CD, k_Swap);   --  v, then s on the stack
        Emit_Std_Funct (CD,  --  s -> +s
          SF_String_to_VString,
          Operand_1_Type (CD.Arrays_Table (X.Ref).Array_Size)
        );
        Emit (CD, k_Swap);   --  +s, then v on the stack
        Emit_Std_Funct (CD, SF_Two_VStrings_Concat);
      elsif y.TYP = Chars then                                    --  v & 'x'  A.4.5 (18)
        Emit_Std_Funct (CD, SF_VString_Char_Concat);
      elsif X.TYP = Chars then                                    --  'x' & v  A.4.5 (19)
        Emit_Std_Funct (CD, SF_Char_VString_Concat);
      --
      --  Hereafter, we have "&" operators on VString provided only by HAT
      --  and not by Ada.Unbounded_Strings
      --
      elsif y.TYP = Ints then      Emit_Std_Funct (CD, SF_VString_Int_Concat);       --  v & 123
      elsif X.TYP = Ints then      Emit_Std_Funct (CD, SF_Int_VString_Concat);       --  123 & v
      elsif y.TYP = Floats then    Emit_Std_Funct (CD, SF_VString_Float_Concat);     --  v & 3.14159
      elsif X.TYP = Floats then    Emit_Std_Funct (CD, SF_Float_VString_Concat);     --  3.14159 & v
      elsif y.TYP = Durations then Emit_Std_Funct (CD, SF_VString_Duration_Concat);  --  v & dur
      elsif X.TYP = Durations then Emit_Std_Funct (CD, SF_Duration_VString_Concat);  --  dur & v
      elsif y.TYP = Bools then     Emit_Std_Funct (CD, SF_VString_Boolean_Concat);   --  v & is_found
      elsif X.TYP = Bools then     Emit_Std_Funct (CD, SF_Boolean_VString_Concat);   --  is_found & v
      else
        return False;
      end if;
      Construct_Root (X, VStrings);
      return True;
    end Do_VString_Concatenation;

    function Do_String_Concatenation return Boolean is
      --  Arguments can be one of the three internal representations of String:
      --      1)  sv  : VString (the parser sees the TYP Strings_as_VStrings)
      --      2)  sc  : constrained array of character
      --      3) "xy" : literal string
      --  Additionally, we can have a character:
      --      4)  'x' : character (value or literal)
      --
      --  So, it makes 16 argument combinations. We note them [ab].
      --  For example, a concatenation of a Strings_as_VStrings and a Literal
      --  is noted [13].
      --
      --  Result is always Strings_as_VStrings.
      --  RM Reference: the predefined "&" operator 4.5.3(3), applied to String.

      procedure Emit_sc1_amp_sv2 is  --  Emit code for: sc1 & sv2
      begin
        Emit (CD, k_Swap);   --  sv2, then sc1 on the stack
        Emit_Std_Funct
          (CD,  --  sv1 := To_VString (sc1)
           SF_String_to_VString,
           Operand_1_Type (CD.Arrays_Table (X.Ref).Array_Size));
        Emit (CD, k_Swap);   --  sv1, then sv2 on the stack
        Emit_Std_Funct (CD, SF_Two_VStrings_Concat);  --  sv1 & sv2
      end Emit_sc1_amp_sv2;

      procedure Emit_sc2_to_sv2 is
      begin
        Emit_Std_Funct
          (CD,  --  sv2 := To_VString (sc2)
           SF_String_to_VString,
           Operand_1_Type (CD.Arrays_Table (y.Ref).Array_Size));
      end Emit_sc2_to_sv2;

    begin
      if X.TYP = Strings_as_VStrings then
        if y.TYP = Strings_as_VStrings then     --  [11] sv1 & sv2
          Emit_Std_Funct (CD, SF_Two_VStrings_Concat);
        elsif Is_Char_Array (CD, y) then        --  [12] sv1 & sc2
          Emit_sc2_to_sv2;
          --  Back to case [11]:
          Emit_Std_Funct (CD, SF_Two_VStrings_Concat);
        elsif y.TYP = String_Literals then      --  [13] sv1 & "xy"
          Emit_Std_Funct (CD, SF_String_Literal_to_VString);
          --  Back to case [11]:
          Emit_Std_Funct (CD, SF_Two_VStrings_Concat);
        elsif y.TYP = Chars then                --  [14] sv1 & 'x'
          Emit_Std_Funct (CD, SF_VString_Char_Concat);
        else
          return False;
        end if;
      elsif Is_Char_Array (CD, X) then
        if y.TYP = Strings_as_VStrings then     --  [21] sc1 & sv2
          Emit_sc1_amp_sv2;
        elsif Is_Char_Array (CD, y) then        --  [22] sc1 & sc2
          Emit_sc2_to_sv2;
          Emit_sc1_amp_sv2;
        elsif y.TYP = String_Literals then      --  [23] sc1 & "xy"
          Emit_Std_Funct (CD, SF_String_Literal_to_VString);
          Emit_sc1_amp_sv2;
        elsif y.TYP = Chars then                --  [24] sc1 & 'x'
          Emit_Std_Funct (CD, SF_Char_to_VString);
          Emit_sc1_amp_sv2;
        else
          return False;
        end if;
      elsif X.TYP = String_Literals then
        if y.TYP = Strings_as_VStrings then     --  [31] "xy" & sv2
          Emit_Std_Funct (CD, SF_LStr_VString_Concat);
        elsif Is_Char_Array (CD, y) then        --  [32] "xy" & sc2
          Emit_sc2_to_sv2;
          Emit_Std_Funct (CD, SF_LStr_VString_Concat);
        elsif y.TYP = String_Literals then      --  [33] "ab" & "cd"
          Emit_Std_Funct (CD, SF_String_Literal_to_VString);
          Emit_Std_Funct (CD, SF_LStr_VString_Concat);
        elsif y.TYP = Chars then                --  [34] "ab" & 'c'
          Emit_Std_Funct (CD, SF_Char_to_VString);
          Emit_Std_Funct (CD, SF_LStr_VString_Concat);
        else
          return False;
        end if;
      elsif X.TYP = Chars then
        if y.TYP = Strings_as_VStrings then     --  [41] 'x' & sv2
          Emit_Std_Funct (CD, SF_Char_VString_Concat);
        elsif Is_Char_Array (CD, y) then        --  [42] 'x' & sc2
          Emit_sc2_to_sv2;
          Emit_Std_Funct (CD, SF_Char_VString_Concat);
        elsif y.TYP = String_Literals then      --  [43] 'a' & "bc"
          Emit_Std_Funct (CD, SF_String_Literal_to_VString);
          Emit_Std_Funct (CD, SF_Char_VString_Concat);
        elsif y.TYP = Chars then                --  [34] 'a' & 'b'
          Emit_Std_Funct (CD, SF_Char_to_VString);
          Emit_Std_Funct (CD, SF_Char_VString_Concat);
        else
          return False;
        end if;
      else
        return False;
      end if;
      Construct_Root (X, Strings_as_VStrings);
      return True;
    end Do_String_Concatenation;

  begin  --  Simple_Expression
    if CD.Sy in Plus_Minus then
      --
      --  Unary + , -      RM 4.5 (5), 4.4 (4)
      --
      additive_operator := CD.Sy;
      In_Symbol (CD);
      Term (FSys + Plus_Minus_Set, X);
      --  At this point we have consumed "+X" or "-X".
      if X.TYP in String_Literals | Strings_as_VStrings | Chars | VStrings
        or else Is_Char_Array (CD, X)
      then
        Check_HAT_Operator_Visibility (additive_operator);
        case Plus_Minus (additive_operator) is

          when Plus =>
            case X.TYP is
              when String_Literals =>                              --  +"Hello"
                Emit_Std_Funct (CD, SF_String_Literal_to_VString);
              when Strings_as_VStrings =>                          --  +Enum'Image (x)
                --  Nothing to do, except setting X's
                --  subtype as an "official" VString.
                null;
              when Chars =>                                        --  +'H'
                Emit_Std_Funct (CD, SF_Char_to_VString);
              when Arrays =>
                if Is_Char_Array (CD, X) then                      --  +S
                  Emit_Std_Funct
                    (CD,
                     SF_String_to_VString,
                     Operand_1_Type (CD.Arrays_Table (X.Ref).Array_Size));
                else
                  Issue_Undefined_Operator_Error (CD, additive_operator, X);
                end if;
              when others =>
                Issue_Undefined_Operator_Error (CD, additive_operator, X);
            end case;
            Construct_Root (X, VStrings);

          when Minus =>
            if X.TYP = VStrings then                               --  -v
              Construct_Root (X, Strings_as_VStrings);
            else
              Issue_Undefined_Operator_Error (CD, additive_operator, X);
            end if;
        end case;
      elsif X.TYP not in Numeric_Typ then
        Error (CD, err_illegal_type_for_arithmetic_expression);
      elsif additive_operator = Minus then
        Emit_Unary_Minus (CD, X.TYP);
        if X.TYP = Ints then
          Ranges.Negate_Range (CD, X);
        end if;
      end if;
    else
      Term (FSys + binary_adding_operator, X);
    end if;
    --
    --  Binary operators: we collect here possible terms: a {+ b}      RM 4.4 (4)
    --
    while binary_adding_operator (CD.Sy) loop
      additive_operator := CD.Sy;
      In_Symbol (CD);
      Term (FSys + binary_adding_operator, y);
      if X.TYP = NOTYP or y.TYP = NOTYP then
        null;  --  Something is already wrong at this point; nothing to check or emit.
      else
        case additive_operator is

          when OR_Symbol =>
            if X.TYP = Bools and y.TYP = Bools then
              Emit (CD, k_OR_Boolean);
            else
              Error (CD, err_resulting_type_should_be_Boolean);
              X.TYP := NOTYP;
            end if;

          when XOR_Symbol =>
            if X.TYP = Bools and y.TYP = Bools then
              Emit (CD, k_XOR_Boolean);
            else
              Error (CD, err_resulting_type_should_be_Boolean);
              X.TYP := NOTYP;
            end if;

          when Plus | Minus =>
            if X.TYP in Numeric_Typ and then y.TYP in Numeric_Typ then
              if X.TYP = y.TYP then
                CD.target.Emit_Arithmetic_Binary_Instruction (additive_operator, X.TYP);
              else
                Forbid_Type_Coercion (CD, additive_operator, X, y);
              end if;
              if X.TYP = Ints then
                if Ranges.Is_Singleton_Range (y, 0) then
                  --  X +/- 0 = X.
                  null;  --  Keep X's range.
                else
                  X.Construct_Root (X.TYP);  --  Forget subtype bounds
                end if;
              end if;
            elsif X.TYP = Times and y.TYP = Times and additive_operator = Minus then
              Emit_Std_Funct (CD, SF_Time_Subtract);  --  T2 - T1
              Construct_Root (X, Durations);
            elsif X.TYP = Durations then
              if y.TYP = Floats then
                --  Duration hack for "X + 1.234" (see Delay_Statement
                --  for full explanation).
                Emit_Std_Funct (CD, SF_Float_to_Duration);
                Construct_Root (y, Durations);  --  Now X and Y have the type Duration.
              end if;
              if y.TYP = Durations then
                if additive_operator = Plus then
                  Emit_Std_Funct (CD, SF_Duration_Add);
                else
                  Emit_Std_Funct (CD, SF_Duration_Subtract);
                end if;
              else
                Issue_Undefined_Operator_Error (CD, additive_operator, X, y);
              end if;
            else
              Issue_Undefined_Operator_Error (CD, additive_operator, X, y);
            end if;

          when Ampersand_Symbol =>
            if not (Do_VString_Concatenation or else Do_String_Concatenation) then
              Issue_Undefined_Operator_Error (CD, additive_operator, X, y);
            end if;

          when others =>
            --  Doesn't happen: Binary_Adding_Operators(OP) is True.
            null;
        end case;
      end if;
    end loop;
  end Simple_Expression;

  procedure Boolean_Expression
    (CD      : in out Co_Defs.Compiler_Data;
     context : in     Defs.Flow_Context;
     FSys    : in     Defs.Symset;
     X       :    out Co_Defs.Exact_Subtyp)
  is
  begin
    Expression (CD, context, FSys, X);
    Check_Boolean (CD, X.TYP);
  end Boolean_Expression;

  procedure Subtype_Prefixed_Expression
    (CD           : in out Co_Defs.Compiler_Data;
     context      : in     Defs.Flow_Context;
     FSys         : in     Defs.Symset;
     Typ_ID_Index : in     Natural;
     X            : in out Co_Defs.Exact_Subtyp)
  is
    Mem_Sy : constant Symbol := CD.Sy;
  begin
    pragma Assert (CD.id_table (Typ_ID_Index).entity = type_mark);
    In_Symbol (CD);
    case Mem_Sy is
      when LParent    =>  --  S (...)
        Type_Conversion (CD, context, FSys, CD.id_table (Typ_ID_Index), X);
      when Apostrophe =>  --  S'First, S'Image, ...
        Attributes.Subtype_Attribute (CD, context, FSys, Typ_ID_Index, X);
      when others =>
        Error (CD, err_general_error, "expected ""'"" or ""("" here", severity => major);
    end case;
  end Subtype_Prefixed_Expression;

end HAC_Sys.Parser.Expressions;
