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

with HAC_Sys.Co_Defs, HAC_Sys.Librarian;

package HAC_Sys.Compiler is

  use HAC_Sys.Co_Defs;

  --  Main compilation procedure.
  --  !!  NB: this is the "historic" compilation routine (there were only a main
  --  !!  procedure and no modularity in early HAC's).
  --  !!  Compile_Main is called exclusively by Build_Main
  --  !!  and will disappear eventually (duplicates code with Compile_Unit
  --  !!  and prevents building any unit as starting point).
  --
  --  The source code stream (CD.CUD.compiler_stream) is already
  --  available via Set_Source_Stream.
  --  If the stream stems from a file, the file must be already open and won't be closed.
  --
  procedure Compile_Main
    (CD                 : in out Co_Defs.Compiler_Data;
     LD                 : in out Librarian.Library_Data;
     main_name_hint     :        String);

  --  Compile unit not yet in the library.
  --  Unit's source code is compiled from an abstracted file (name: file_name)
  --  with the GNAT naming convention.
  --  Registration into the library is done later, by the librarian.
  --
  procedure Compile_Unit
    (CD                     : in out Co_Defs.Compiler_Data;
     LD                     : in out Librarian.Library_Data;
     upper_name             :        String;
     file_name              :        String;
     as_specification       :        Boolean;
     specification_id_index :        Natural;
     new_id_index           :    out Natural;
     unit_context           : in out Co_Defs.Id_Maps.Map;  --  in : empty for spec, spec's context for body
                                                           --  out: spec's context or body's full context.
     kind                   :    out Librarian.Unit_Kind;  --  The unit kind is discovered during parsing.
     needs_body             :    out Boolean);

  --  Initialize the compiler for an entire build.
  procedure Init_for_new_Build (CD : out Compiler_Data);

  procedure Set_Message_Feedbacks
    (CD           : in out Compiler_Data;
     trace_params : in     Compilation_Trace_Parameters);

  procedure Print_Tables (CD : in Compiler_Data);
  procedure Progress_Message (CD : Co_Defs.Compiler_Data; msg : String);
  procedure Dump_HAC_VM_Asm (CD : Co_Defs.Compiler_Data; file_name : String);

  function Unit_Compilation_Successful (CD : Compiler_Data) return Boolean;
  function Unit_Object_Code_Size (CD : Compiler_Data) return Natural;

end HAC_Sys.Compiler;
