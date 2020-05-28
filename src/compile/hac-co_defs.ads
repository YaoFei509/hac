-------------------------------------------------------------------------------------
--
--  HAC - HAC Ada Compiler
--
--  A compiler in Ada for an Ada subset
--
--  Copyright, license, etc. : see top package.
--
-------------------------------------------------------------------------------------
--

with HAC.Defs, HAC.PCode;

with Ada.Streams;

package HAC.Co_Defs is  --  Compiler definitions
  --  NB: cannot be a child package of Compiler because of Parser, Scanner, ...

  use HAC.Defs;

  type Exact_Typ is record  --  NB: was called "Item" in SmallAda.
    TYP  : Typen;
    Ref  : Index;
    --  If TYP is not a standard type, then (TYP, Ref) does identify the type.
    --  E.g. it can be (Enums, [index of the enumerated type definition]).
    --  If TYP = Records, Ref is an index into the Block_Table;
    --  if TYP = Arrays,  Ref is an index into the Arrays_Table , or
    --  if TYP = Enums,   Ref is an index into the Id table (the type's name).
  end record;

  Type_Undefined : constant Exact_Typ := (TYP => NOTYP, Ref => 0);

  -------------------------------------------------------------------------
  ------------------------------------------------------------ATabEntry----
  -------------------------------------------------------------------------
  --  Array-Table Entry : Array table entry represents an array.  Each entry
  --  contains the following fields (fields marked with a C are used only by
  --  the compiler and ignored by the interpreter):
  --
  type ATabEntry is record
    Index_xTyp   : Exact_Typ;  --  C  Type of the index
    Element_Size : Index;      --  Size of an element
    Element_xTyp : Exact_Typ;  --  C  Type of the elements of the array.
                               --        Element_xTYP.Ref is an index to an entry
                               --        in Arrays_Table if the elements of the array
                               --        are themselves arrays
    Array_Size   : Index;      --  C  Total size of the array
    Low, High    : Index;      --  Limits on the array index: array (Low .. High) of Element_TYP
  end record;

  -------------------------------------------------------------------------
  ------------------------------------------------------------BTabEntry----
  -------------------------------------------------------------------------
  --  Block-table Entry : Each entry represents a subprogram or a record type.
  --
  --  A subprogram activation record consists of:
  --
  --         (1) the five word fixed area; (see definition of S in Interpreter)
  --         (2) an area for the actual parameters (whether values or
  --             addresses), and
  --         (3) an area for the local variables of the subprogram
  --
  --  Once again, fields marked with C are used only by the compiler
  --
  type BTabEntry is record
    Id                : Alfa;         --   Name of the block
    Last_Id_Idx       : Index;        -- C pointer to the last identifier in this block
    Last_Param_Id_Idx : Index;        -- C pointer to the last parameter in this block
    PSize             : Index;        --   sum of the lengths of areas (1) & (2) above
    VSize             : Index := 0;   --   sum of PSize and length of area (3)
                                      --   (i.e. size of the activation record for
                                      --    this block if it is a subprogram)
    SrcFrom           : Positive;     --   Source code line count.  Source starts here
    SrcTo             : Positive;     --   and goes until here    (* Manuel *)
  end record;

  type aObject is
  (
      --  Declared number: untyped constant, like
      --  "pi : constant := 3.1415927"; (RM 3.3.2).
      Declared_Number_or_Enum_Item,
      --
      Variable,
      TypeMark,
      --
      Prozedure,
      Funktion,
      --
      aTask,
      aEntry,
      --
      Label
  );

  ------------------------------------------------------------------------
  ------------------------------------------------------------TabEntry----
  ------------------------------------------------------------------------
  --  Identifier Table Entry
  type IdTabEntry is record
    Name           : Alfa;          --  identifier name in ALL CAPS
    Name_with_case : Alfa;          --  identifier name with original casing
    Link           : Index;
    Obj            : aObject;       --  One of:
                                    --    Declared_Number, Variable, TypeMark,
                                    --    Prozedure, Funktion, aTask, aEntry
    Read_only      : Boolean;       --  If Obj = Variable and Read_only = True,
                                    --    it's a typed constant.
    xTyp           : Exact_Typ;     --  Type identification
    Block_Ref      : Index;         --  Was: Ref (was used also for what is now xTyp.Ref,
                                    --       which caused a mixup for functions return types!)
    Normal         : Boolean;       --  value param?
    LEV            : PCode.Nesting_level;
    Adr_or_Sz      : Integer;
  end record;

  --  Obj                           Meaning of Adr_or_Sz
  --  -------------------------------------------------------------------------------
  --  Declared_Number_or_Enum_Item  Value (number), position (enumerated type)
  --  Variable                      Relative position in the stack.
  --  TypeMark                      Size (in PCode stack items) of an object
  --                                    of the declared type.
  --  Prozedure                     Index into the Object Code table,
  --                                    or Level 0 Standard Procedure code
  --  Funktion                      Index into the Object Code table,
  --                                    or Level 0 Standard Function code (SF_Code)
  --  aTask                         ?
  --  aEntry                        ?
  --  Label                         ?

  subtype Source_Line_String is String (1 .. 1000);

  -----------------------
  --  Compiler tables  --
  -----------------------

  subtype Fixed_Size_Object_Code_Table is HAC.PCode.Object_Code_Table (0 .. CDMax);

  type    Arrays_Table_Type            is array (1 .. AMax)                  of ATabEntry;
  type    Blocks_Table_Type            is array (0 .. BMax)                  of BTabEntry;
  type    Display_Type                 is array (PCode.Nesting_level)        of Integer;
  type    Entries_Table_Type           is array (0 .. EntryMax)              of Index;
  type    Float_Constants_Table_Type   is array (1 .. Float_Const_Table_Max) of HAC_Float;
  type    Identifier_Table_Type        is array (0 .. Id_Table_Max)          of IdTabEntry;
  subtype Strings_Constants_Table_Type is String (1 .. SMax);
  type    Tasks_Definitions_Table_Type is array (0 .. TaskMax)               of Index;

  --  Display: keeps track of addressing by nesting level. See Ben-Ari Appendix A.

  type Source_Stream_Access is access all Ada.Streams.Root_Stream_Type'Class;

end HAC.Co_Defs;