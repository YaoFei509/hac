--  This demo reads a text file (itself) and displays
--  its contents on the console.

with HAL; use HAL;

procedure File_Read is
  s : VString;
  f : File_Type;
begin
  Open (f, "file_read.adb");
  while not End_Of_File (f) loop
    Get_Line (f, s);
    Put_Line (s);
  end loop;
  Close (f);
end File_Read;
