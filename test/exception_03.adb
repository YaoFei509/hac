procedure Exception_03 is
  procedure P1 is
    function F2 return Integer is
      a : array (1 .. 3) of Integer;
    begin
      a (0) := 123;     --  <-  *** Boom! *** : 0 is out-of-range
      return 0;
    end F2;
    i : Integer := F2;  --  <-  Trace-back should show this line
  begin
    null;
  end P1;
  dummy : Integer;
begin
  P1;                   --  <-  Trace-back should show this line
  dummy := 1234;
  dummy := 4321;
  P1;                   --  <-  No executed due to previously raised exception.
end Exception_03;
