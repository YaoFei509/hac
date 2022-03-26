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

with HAC_Sys.Co_Defs,
     HAC_Sys.Defs;

package HAC_Sys.Parser.Packages is

  --------------------------------------------------------------------------
  --  Parse a package right after the "PACKAGE name" symbol sequence.     --
  --  `name` has been entered as "Paquetage" kind, either as a            --
  --  library-level declaration and library item, or a declaration which  --
  --  is local to a subprogram.                                           --
  --------------------------------------------------------------------------

  procedure Package_Declaration (
    CD                   : in out Co_Defs.Compiler_Data;
    FSys                 :        Defs.Symset;
    subprogram_level     :        Defs.Nesting_level;
    needs_body           :    out Boolean
  );

  ------------------------------------------------------------------
  --  Parse a package's body right after the "PACKAGE BODY name"  --
  --  symbol sequence.                                            --
  ------------------------------------------------------------------

  procedure Package_Body (
    CD                   : in out Co_Defs.Compiler_Data;
    FSys                 :        Defs.Symset;
    subprogram_level     :        Defs.Nesting_level
  );

  ----------------------------------------------------------------------
  --  Parse Use clause.                                               --
  --  It is either part of a context clause, or a local declaration.  --
  --  8.4 (2)
  ----------------------------------------------------------------------

  procedure Use_Clause (
    CD    : in out Co_Defs.Compiler_Data;
    Level :        Defs.Nesting_level
  );

  -------------------------------------------------
  --  Apply the USE clause at any nesting level  --
  -------------------------------------------------

  procedure Apply_USE_Clause (
    CD       : in out Co_Defs.Compiler_Data;
    Level    : in     Defs.Nesting_level;
    Pkg_Idx  : in     Natural  --  Index in the identifier table for USEd package.
  );

end HAC_Sys.Parser.Packages;
