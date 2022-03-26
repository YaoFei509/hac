with HAC_Sys.Compiler,
     HAC_Sys.Errors;

with Ada.Characters.Handling,
     Ada.Exceptions;
with HAC_Sys.Defs;

package body HAC_Sys.Builder is

  procedure Compile_Pending_Bodies_Single_Round
    (BD : in out Build_Data; num_pending : out Natural)
  is
    use HAL, Librarian;
    pending : Library_Unit_Vectors.Vector;
    previous_context : Co_Defs.Id_Set.Set;
    needs_body_dummy : Boolean;
  begin
    for lu of BD.LD.Library loop
      if lu.status = Body_Postponed then
        pending.Append (lu);
      end if;
    end loop;
    --
    --  The list of pending bodies is established
    --  for this round. Of course the library may expand
    --  further due to dependencies, adding pending bodies
    --  for the next round.
    --
    for lu of pending loop
      declare
        upper_vname : constant VString := To_Upper (lu.full_name);
        upper_name : constant String := To_String (upper_vname);
        fn : String := Find_Unit_File_Name (upper_name);
      begin
        fn (fn'Last) := 'b';  --  Name ending for a unit's body (*.adb).
        previous_context :=
          BD.LD.Library.Element (BD.LD.Map.Element (upper_vname)).spec_context;
        Compiler.Compile_Unit
          (BD.CD, BD.LD, upper_name, fn, False,
           lu.id_index,
           lu.id_body_index,
           previous_context,
           lu.kind,
           needs_body_dummy);
        lu.status := Done;
        Change_Unit_Details (BD.LD, lu);
      end;
    end loop;
    --
    num_pending := Integer (pending.Length);
  end Compile_Pending_Bodies_Single_Round;

  procedure Build_Main (BD : in out Build_Data) is
    use Librarian, HAL.VStr_Pkg, Ada.Exceptions, Ada.Text_IO;
    num_pending : Natural;
    main_unit : Library_Unit :=
      (full_name     => BD.main_name_hint,
       kind          => Procedure_Unit,
       status        => In_Progress,    --  Temporary value.
       id_index      => Co_Defs.No_Id,  --  Temporary value.
       id_body_index => Co_Defs.No_Id,  --  Temporary value.
       spec_context  => Co_Defs.Id_Set.Empty_Set);
  begin
    BD.LD.Library.Clear;
    BD.LD.Map.Clear;
    Librarian.Register_Unit (BD.LD, main_unit);
    Compiler.Compile_Main (
      BD.CD,
      BD.LD,
      To_String (BD.main_name_hint),
      To_String (BD.cmp_dump_file_name),
      To_String (BD.listing_file_name),
      To_String (BD.var_map_file_name)
    );
    main_unit.id_index := BD.CD.Main_Proc_Id_Index;
    Librarian.Change_Unit_Details (BD.LD, main_unit);

    if BD.CD.trace.detail_level >= 2 then
      Compiler.Progress_Message
        (BD.CD, "--  Compilation of eventual with'ed unit's bodies  --");
    end if;
    loop
      Compile_Pending_Bodies_Single_Round (BD, num_pending);
      if num_pending > 0 and BD.CD.trace.detail_level >= 2 then
        Compiler.Progress_Message
          (BD.CD, "--  Compiled bodies:" & Integer'Image (num_pending));
      end if;
      exit when num_pending = 0;
    end loop;
    if BD.CD.comp_dump_requested then
      Compiler.Print_Tables (BD.CD);
      Close (BD.CD.comp_dump);
    end if;
    if BD.asm_dump_file_name /= "" then
      Compiler.Dump_Asm (BD.CD, To_String (BD.asm_dump_file_name));
    end if;
  exception
    when Errors.Compilation_abandoned =>
      --  Just too many errors...
      Errors.Compilation_Errors_Summary (BD.CD);
      if BD.CD.comp_dump_requested then
        Compiler.Print_Tables (BD.CD);
        Close (BD.CD.comp_dump);
      end if;
      Compiler.Dump_Asm (BD.CD, To_String (BD.asm_dump_file_name));
    when E : HAC_Sys.Librarian.Circular_Unit_Dependency =>
      Errors.Error
        (BD.CD,
         Defs.err_library_error,
         "Circular unit dependency (""->"" means ""depends on""): " &
         To_String (BD.main_name_hint) & " -> " &
         Exception_Message (E));
  end Build_Main;

  procedure Set_Diagnostic_File_Names (
    BD                 : in out Build_Data;
    asm_dump_file_name :        String  := "";  --  Assembler output of compiled object code
    cmp_dump_file_name :        String  := "";  --  Compiler dump
    listing_file_name  :        String  := "";  --  Listing of source code with details
    var_map_file_name  :        String  := ""   --  Output of variables (map)
  )
  is
    use HAL;
  begin
    BD.asm_dump_file_name := To_VString (asm_dump_file_name);
    BD.cmp_dump_file_name := To_VString (cmp_dump_file_name);
    BD.listing_file_name  := To_VString (listing_file_name);
    BD.var_map_file_name  := To_VString (var_map_file_name);
  end Set_Diagnostic_File_Names;

  --  Set current main source stream (file, editor data, zipped file,...)
  procedure Set_Main_Source_Stream (
    BD         : in out Build_Data;
    s          : access Ada.Streams.Root_Stream_Type'Class;
    file_name  : in     String;       --  Can be a virtual name (editor title, zip entry)
    start_line : in     Natural := 0  --  We could have a shebang or other Ada sources before
  )
  is
    main_name_guess : String := Ada.Characters.Handling.To_Upper (file_name);
    last_slash, last_dot : Natural := 0;
  begin
    Co_Defs.Set_Source_Stream (BD.CD.CUD, s, file_name, start_line);
    --  Guess unit name from file name (operation is the reverse of GNAT_Naming in Librarian).
    for i in main_name_guess'Range loop
      case main_name_guess (i) is
        when '.'       => last_dot := i;
        when '/' | '\' => last_slash := i;
        when '-'       => main_name_guess (i) := '.';  --  Child unit (GNAT naming convention)
        when others    => null;
      end case;
    end loop;
    if last_dot = 0  --  no dot at all
      or else last_dot < last_slash  --  dot only in a path
    then
      last_dot := main_name_guess'Last + 1;
    end if;
    BD.main_name_hint := HAL.To_VString (main_name_guess (last_slash + 1 .. last_dot - 1));
  end Set_Main_Source_Stream;

  procedure Set_Message_Feedbacks (
    BD           : in out Build_Data;
    trace_params : in     Co_Defs.Compilation_Trace_Parameters
  )
  is
  begin
    Compiler.Set_Message_Feedbacks (BD.CD, trace_params);
  end Set_Message_Feedbacks;

  function Build_Successful (BD : Build_Data) return Boolean is
  begin
    return Compiler.Unit_Compilation_Successful (BD.CD);
    --  NB: currently, only full builds are supported.
  end Build_Successful;

  function Object_Code_Size (BD : Build_Data) return Natural is
  begin
    return Compiler.Unit_Object_Code_Size (BD.CD);
    --  Whatever the build mode, the entire object code lands into Main_CD's object code.
  end Object_Code_Size;

  function Maximum_Object_Code_Size return Natural is
  begin
    return Defs.CDMax;
  end Maximum_Object_Code_Size;

  procedure Skip_Shebang (f : in out Ada.Text_IO.File_Type; shebang_offset : out Natural) is
    use Ada.Text_IO;
  begin
    shebang_offset := 0;
    if not End_Of_File (f) then
      declare
        possible_shebang : constant String := Get_Line (f);
      begin
        if possible_shebang'Length >= 2
          and then possible_shebang (possible_shebang'First .. possible_shebang'First + 1) = "#!"
        then
          shebang_offset := 1;  --  Ignore the first line, but count it.
        else
          Reset (f);
        end if;
      end;
    end if;
  end Skip_Shebang;

end HAC_Sys.Builder;
