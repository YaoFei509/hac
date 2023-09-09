package body HAC_Sys.Targets.Semantics is

  overriding procedure Initialize_Code_Emission (m : in out Machine) is
    use HAT;
  begin
    m.busy := True;
    m.started := Clock;
    m.ref_map.Clear;
  end Initialize_Code_Emission;

  overriding procedure Finalize_Code_Emission
    (m       : in out Machine;
     strings :        String)
  is
    use HAT;
  begin
    m.finished := Clock;
    m.total_time := m.finished - m.started;
    m.busy := False;
  end Finalize_Code_Emission;

  overriding procedure Mark_Declaration (m : in out Machine; is_built_in : Boolean) is
  begin
    m.decl_map (m.CD.Id_Count).is_built_in := is_built_in;
    if not is_built_in then
      m.decl_map (m.CD.Id_Count) :=
        (is_built_in => False,
         file_name   => m.CD.CUD.source_file_name,
         line        => m.CD.CUD.line_count,
         column      => m.CD.syStart + 1,
         id_index    => m.CD.Id_Count);
    end if;
  end Mark_Declaration;

  overriding procedure Mark_Reference (m : in out Machine; located_id : Natural) is
    use HAT;
    admit_duplicates : constant Boolean := True;
    key : constant VString :=
      --  Example: "c:\files\source.adb 130 12"
      m.CD.CUD.source_file_name &
      m.CD.CUD.line_count'Image &
      Integer'Image (m.CD.syStart + 1);
  begin
    if admit_duplicates then
      m.ref_map.Include (key, located_id);
    else
      m.ref_map.Insert (key, located_id);
    end if;
  exception
    when Constraint_Error =>
      raise Constraint_Error with "Duplicate reference key: " & To_String (key);
  end Mark_Reference;

  overriding procedure Find_Declaration
    (m         : in out Machine;
     ref       : in     Reference_Point'Class;
     decl      :    out Declaration_Point'Class;
     was_found :    out Boolean)
  is
    curs : Reference_Mapping.Cursor;
    use HAT, Reference_Mapping;
  begin
    curs :=
      m.ref_map.Find
        (ref.file_name & ref.line'Image & ref.column'Image);
    if curs = No_Element then
      decl.id_index := -1;
      was_found := False;
    else
      decl  := Declaration_Point'Class (m.decl_map (Element (curs)));
      was_found := True;
    end if;
  end Find_Declaration;

end HAC_Sys.Targets.Semantics;