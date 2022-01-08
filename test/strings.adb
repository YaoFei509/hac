with HAL;

procedure Strings is
  use HAL;

  procedure Failure (Msg : VString) is
  begin
    Put_Line (+"Failure in test: [" & Msg & ']');
    Set_Exit_Status (1);  --  Compiler test failed.
  end Failure;

  procedure Assert (Msg: VString; Check : in Boolean) is
  --  Similar to RM 11.4.2 but without raising an exception.
  begin
    if not Check then Failure (Msg & ", assertion"); end if;
  end Assert;

  s1, s2, s3, s4, s4_s4 : VString;
  Planck   : constant Real := 6.62607015e-34;
  Pi_9_dgt : constant Real := 3.141592653;
  Avogadro : constant Real := 6.02214076e023;
  r : Real;
  fs_1 : String (4 .. 6);

  type Enum is (U, V, W);

begin
  s4 := To_VString ("abc") & 'd' & "ef";
  if s4 /= +"abcdef" then
    Failure (+"Comparing VString to VString, or converting Literal String to VString");
  end if;
  if s4 /= "abcdef" then
    Failure (+"Comparing VString to Literal String");
  end if;
  --
  if Element (s4, 3) /= 'c'    then Failure (+"VString Element"); end if;
  if Length (s4) /= 6          then Failure (+"VString Length"); end if;
  if Slice (s4, 3, 5) /= "cde" then Failure (+"VString Slice"); end if;
  --
  s1 := +"ab";
  s2 := +"cdef";
  s3 := 'b' & s2;
  --
  if s1 & s2 /= s4      then Failure (+"VString & VString"); end if;
  if s1 & "cdef" /= s4  then Failure (+"VString & String"); end if;
  if "ab" & s2 /= s4    then Failure (+"String  & VString"); end if;
  if 'a' & s3 /= s4     then Failure (+"Character & VString"); end if;
  if 7 & s1 /= +"7ab"   then Failure (+"Int & VString"); end if;
  --
  if s1 & 7 /= +"ab7"   then Failure (+"VStr & Int = +Str_Lit"); end if;
  if s1 & 7 /=  "ab7"   then Failure (+"VStr & Int =  Str_Lit"); end if;
  --
  if Real (3.14) & s2 /= "3.14cdef"     then Failure (+"R & VString"); end if;
  if s2 & Pi_9_dgt /= "cdef3.141592653" then Failure (+"VString & R"); end if;
  if s2 & Avogadro /= +"cdef6.02214076E+23" then
    Failure (+"Compiler bug - HAC_Image for HAC_Float :" & Avogadro);
    Put_Line (Avogadro);
  end if;
  if s1 & Planck /= +"ab6.62607015E-34" then
    Failure (+"Compiler bug - HAC_Image for HAC_Float :" & Planck);
    Put_Line (Planck);
  end if;
  if not (+"A" < +"B")   then Failure (+"VString < VString"); end if;
  if not (+"AA" > +"A")  then Failure (+"VString > VString"); end if;
  --
  if not (+"A" <= +"B")  then Failure (+"VString <= VString"); end if;
  if not (+"AA" >= +"A") then Failure (+"VString >= VString"); end if;
  if not (+"A" <= +"A")  then Failure (+"VString <= VString"); end if;
  if not (+"A" >= +"A")  then Failure (+"VString >= VString"); end if;
  --
  if To_Lower (+"X") /= +"x" then Failure (+"To_Lower VString"); end if;
  if To_Lower  ('X') /=  'x' then Failure (+"To_Lower Char");    end if;
  if To_Upper (+"x") /= +"X" then Failure (+"To_Upper VString"); end if;
  if To_Upper  ('x') /=  'X' then Failure (+"To_Upper Char");    end if;
  --
  if Index (s4, +"cat") /= 0 then Failure (+"Index, #1");    end if;
  if Index (s4, +"cde") /= 3 then Failure (+"Index, #2");    end if;
  if Index (s4,  "cat") /= 0 then Failure (+"Index, #3");    end if;
  if Index (s4,  "cde") /= 3 then Failure (+"Index, #4");    end if;
  --
  s4_s4 := s4 & s4;  --  abcdefabcdef
                     --  123456789012
  if Index (s4_s4, +"cd") /= 3 or
     Index (s4_s4,  "cd") /= 3 or
     Index (s4_s4,  'c')  /= 3
  then
    Failure (+"Index");
  end if;
  if Index (s4_s4, +"cd", 4) /= 9 or
     Index (s4_s4,  "cd", 4) /= 9 or
     Index (s4_s4,  'c', 4)  /= 9
  then
    Failure (+"Index, From");
  end if;
  if Index_Backward (s4_s4, +"cd") /= 9 or
     Index_Backward (s4_s4,  "cd") /= 9 or
     Index_Backward (s4_s4,  'c')  /= 9
  then
    Failure (+"Index_Backward");
  end if;
  if Index_Backward (s4_s4, +"cd", 8) /= 3 or
     Index_Backward (s4_s4,  "cd", 8) /= 3 or
     Index_Backward (s4_s4,  'c', 8)  /= 3
  then
    Failure (+"Index_Backward, From");
  end if;
  --
  if  0 * 'x' /= +""                       then Failure (+"""*"", #1"); end if;
  if 10 * 'x' /= +"xxxxxxxxxx"             then Failure (+"""*"", #2"); end if;
  if  0 * (+"Fritz") /= +""                then Failure (+"""*"", #3"); end if;
  if  3 * (+"Fritz") /= +"FritzFritzFritz" then Failure (+"""*"", #4"); end if;
  --
  for i in -5 .. 5 loop
    if Integer_Value (Image (i)) /= i then Failure (+"Im/Val I"); end if;
    r := Real (i);
    if Float_Value (Image (r)) /= r then Failure (+"Im/Val R 1"); end if;
    r := Real (i) * 1.0e20;
    if Float_Value (Image (r)) /= r then Failure (+"Im/Val R 2"); end if;
    --  put_line (image(r));
  end loop;
  --
  fs_1 := "def";
  if +fs_1 /= Slice (s4, 4, 6)    then Failure (+"Fixed String to VString"); end if;
  if +"abc" & fs_1 /= +"abcdef"   then Failure (+"VString & String"); end if;
  if fs_1 & (+"ghi") /= +"defghi" then Failure (+"String & VString"); end if;
  --
  --  Strings_as_VStrings
  --
  if Enum'Image (V) /= "V" then Failure (+"Strings_as_VStrings, #1"); end if;
  --  Concatenation between various String internal types or with Character:
  if Enum'Image (U) & fs_1 /= "Udef" then Failure (+"Strings_as_VStrings, #2"); end if;
  if Enum'Image (W) & "aw" /= "Waw"  then Failure (+"Strings_as_VStrings, #3"); end if;
  if fs_1 & Enum'Image (W) /= "defW" then Failure (+"Strings_as_VStrings, #4"); end if;
  if "UB" & Enum'Image (U) /= "UBU"  then Failure (+"Strings_as_VStrings, #5"); end if;
  if 'U' & Enum'Image (V) /= "UV"    then Failure (+"Strings_as_VStrings, #6"); end if;
  if Enum'Image (U) & 'V' /= "UV"    then Failure (+"Strings_as_VStrings, #7"); end if;
  if To_String (To_VString ("abcd") & (+"ef")) /= "abcdef" then
    Failure (+"String <-> VString, #1");
  end if;
  --
  --  HAL functions
  --
  Assert (+"SW_1", not Starts_With (+"package",  "proc"));
  Assert (+"SW_2", not Starts_With (+"package", +"proc"));
  Assert (+"SW_3",     Starts_With (+"package",  "pack"));
  Assert (+"SW_4",     Starts_With (+"package", +"pack"));
  --
  Assert (+"EW_1", not Ends_With (+"package",  "proc"));
  Assert (+"EW_2", not Ends_With (+"package", +"proc"));
  Assert (+"EW_3",     Ends_With (+"package",  "age"));
  Assert (+"EW_4",     Ends_With (+"package", +"age"));
  --
  Assert (+"TAM_1", Tail_After_Match (+"/etc/genesix/gnx-startup", +"/") = "gnx-startup");
  Assert (+"TAM_2", Tail_After_Match (+"/etc/genesix/gnx-startup", +"ix") = "/gnx-startup");
  Assert (+"TAM_3", Tail_After_Match (+"/etc/genesix/gnx-startup", +"gene") = "six/gnx-startup");
  Assert (+"TAM_4", Tail_After_Match (+"/etc/genesix/gnx-startup", +"etc/genesix/gnx-startu") = "p");
  Assert (+"TAM_5", Tail_After_Match (+"/etc/genesix/gnx-startup", +"/etc/genesix/gnx-startu") = "p");
  Assert (+"TAM_6", Tail_After_Match (+"/etc/genesix/gnx-startup", +"/etc/genesix/gnx-startup") = "");
  Assert (+"TAM_7", Tail_After_Match (+"/etc/genesix/gnx-startup", +"/etc/genesix/gnx-startupp") = "");
  Assert (+"TAM_8", Tail_After_Match (+"/etc/genesix/gnx-startup", "/g") = "nx-startup");  --  Must match the last "/g"
  Assert (+"TAM_9", Tail_After_Match (+"/etc/genesix/gnx-startup", "/g") /= "enesix/gnx-startup");
  --
  --  The following test is in one answer of
  --  https://stackoverflow.com/questions/62080743/how-do-you-check-if-string-ends-with-another-string-in-ada
  Assert (+"EW_101", Ends_With (+"John Johnson", "son") = True);
  Assert (+"EW_102", Ends_With (+"", "") = True);
  Assert (+"EW_103", Ends_With (+" ", "") = True);
  Assert (+"EW_104", Ends_With (+"", " ") = False);
  Assert (+"EW_105", Ends_With (+" ", " ") = True);
  Assert (+"EW_106", Ends_With (+"", "n") = False);
  Assert (+"EW_107", Ends_With (+"n", "") = True);
  Assert (+"EW_108", Ends_With (+"n ", "n ") = True);
  Assert (+"EW_109", Ends_With (+" n", "n") = True);
  Assert (+"EW_110", Ends_With (+"n", " n") = False);
  Assert (+"EW_111", Ends_With (+" n", " n") = True);
end Strings;
