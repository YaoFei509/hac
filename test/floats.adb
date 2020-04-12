--  Output should be empty if the compiler is correct.

with HAC_Pack; use HAC_Pack;

procedure Floats is

  procedure Test_Exp_Log is
    scale : constant := 500.0;
    steps : constant := 100;
    x1, x2 : Real;
  begin
    for i in 0 .. steps loop
      x1 := Real (i) * scale * (1.0 / Real (steps));
      x2 := Log (Exp (x1));
      if abs (x2 - x1) > 0.0 then
        Put_Line ("Compiler bug [Exp_Log]");
      end if;
    end loop;
  end Test_Exp_Log;

  procedure Test_Trigo is
    pi : constant := 3.141592653;
    scale : Real := pi * 0.25;
    steps : constant := 100;
    x, s, c, t : Real;
  begin
    for i in 0 .. steps loop
      x := Real (i) * scale * (1.0 / Real (steps));
      s := Sin (x);
      c := Cos (x);
      if abs (c) > 0.0 then
        t := s / c;
        if abs (Arctan (t) - x) > 1.0e-15 then
          Put_Line ("Compiler bug [Trigo]");
        end if;
      end if;
    end loop;
  end Test_Trigo;

  x1 : Real;
  x2 : Real;
  x3 : Real;

  type R is record
    x1 : Real;
    x2 : Real;
    x3 : Real;
  end record;

  ww : array (1 .. 7) of R;

  v : R;

  neg_float_value : constant := -5.07;

begin
  v.x1 := 1.0;
  v.x2 := 3.0;
  x3 := 5.0;
  v.x3 := 6.0;
  if x3 /= 5.0 then
    Put_Line ("Compiler bug [A]");
  end if;
  x1 := v.x1;
  if x1 /= 1.0 then
    Put_Line ("Compiler bug [B]");
  end if;
  x3 := v.x2;
  if x3 /= 3.0 then
    Put_Line ("Compiler bug [C]");
  end if;
  ww (1).x3:= 3.4_5_6_7_8_9;
  ww (5).x3:= ww (1).x3;
  ww (1).x3 := 7.89;
  v.x3 := 1.0;
  v.x2 := 2.0;
  if abs (ww (5).x3 - (2.345_678 + 1.111111)) > 0.000_000_1 then
    Put_Line ("Compiler bug [D]");
  end if;
  x2 := neg_float_value;
  if -x2 /= 5.07 then
    Put_Line ("Compiler bug [E]");  --  Former HAC bug: unary minus was ineffective for floats
  end if;
  --
  Test_Exp_Log;
  Test_Trigo;
  --
end Floats;