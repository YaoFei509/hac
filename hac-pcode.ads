-------------------------------------------------------------------------------------
--
-- HAC - HAC Ada Compiler
--
-- A compiler in Ada for an Ada subset

-- Legal licensing note:

--  Copyright (c) 2013 Gautier de Montmollin
--
--  History and authors list of works HAC was originally derived from
--  can be found in hac.txt.

--  Permission is hereby granted, free of charge, to any person obtaining a copy
--  of this software and associated documentation files (the "Software"), to deal
--  in the Software without restriction, including without limitation the rights
--  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--  copies of the Software, and to permit persons to whom the Software is
--  furnished to do so, subject to the following conditions:

--  The above copyright notice and this permission notice shall be included in
--  all copies or substantial portions of the Software.

--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
--  THE SOFTWARE.

-- NB: this is the MIT License, as found 12-Sep-2013 on the site
-- http://www.opensource.org/licenses/mit-license.php

-------------------------------------------------------------------------------------
--

-- This unit is used to store object codes in the ObjCode table.
-- The three procedures Emit, Emit1, and Emit2 are called from
-- the compiler and the parser.

package HAC.PCode is

  -- Store PCode object in the object code table
  procedure Emit(FCT: Integer);
  procedure Emit1(FCT, B: Integer);
  procedure Emit2(FCT, a, B: Integer);

  -----------------------------------------------------PCode Opcodes----

  kLoadAddress                : constant := 0;
  kPushV                      : constant := 1; -- Load Value
  kPushIndirect               : constant := 2;
  kUpdateDisplayV             : constant := 3;
  kAcceptRendezvous           : constant := 4;
  kEndRendezvous              : constant := 5;
  kWaitSemaphore              : constant := 6;
  kSignalSemaphore            : constant := 7;
  kStndFunctions              : constant := 8;
  kOffset                     : constant := 9;
  kJump                       : constant := 10;
  kCondJump                   : constant := 11;
  kSwitch                     : constant := 12;
  k_Switch_2                  : constant := 13;
  kFor1                       : constant := 14;
  kFor2                       : constant := 15;
  kFor1Rev                    : constant := 16;
  kFor2Rev                    : constant := 17;
  kMarkStack                  : constant := 18;
  kCall                       : constant := 19; -- procedure and task entry CALL
  kIndex1                     : constant := 20;
  kIndex                      : constant := 21;
  kLoadBlock                  : constant := 22;
  kCopyBlock                  : constant := 23;
  kLiteral                    : constant := 24;
  kLoadFloat                  : constant := 25;
  kCase26                     : constant := 26; -- Seems integer-to-float
  k_Read                      : constant := 27;
  kWriteString                : constant := 28;
  kWrite1                     : constant := 29;
  kWrite2                     : constant := 30;
  kExitCall                   : constant := 32;
  kExitFunction               : constant := 33;
  kCase34                     : constant := 34;
  k_NOT_Boolean               : constant := 35;
  k_Unary_MINUS_Integer       : constant := 36;
  kCase37                     : constant := 37;
  kStore                      : constant := 38;
  k_EQL_Float                 : constant := 39;
  k_NEQ_Float                 : constant := 40;
  k_LSS_Float                 : constant := 41;
  k_LEQ_Float                 : constant := 42;
  k_GTR_Float                 : constant := 43;
  k_GEQ_Float                 : constant := 44;
  -- 45..50: same, for integers
  k_OR_Boolean                : constant := 51;
  k_ADD_Integer               : constant := 52;
  k_SUBTRACT_Integer          : constant := 53;
  k_ADD_Float                 : constant := 54;
  k_SUBTRACT_Float            : constant := 55;
  k_AND_Boolean               : constant := 56;
  k_MULT_Integer              : constant := 57;
  k_DIV_Integer               : constant := 58;
  k_MOD_Integer               : constant := 59;
  k_MULT_Float                : constant := 60;
  k_DIV_Float                 : constant := 61;
  kGetNewline                 : constant := 62;
  kPutNewline                 : constant := 63;
  k_Set_current_file_pointer  : constant := 64;
  kFile_I_O                   : constant := 65;
  kHaltInterpreter            : constant := 66;
  kStringAssignment           : constant := 67;
  kDelay                      : constant := 68;
  kCursorAt                   : constant := 69;
  kSetQuatumTask              : constant := 70;
  kSetTaskPriority            : constant := 71;
  kSetTaskPriorityInheritance : constant := 72;
  kSelectiveWait              : constant := 73;
  kHighlightSource            : constant := 74;

  -- Save and restore an object file
  procedure SaveOBJ(FileName: String);
  procedure RestoreOBJ(FileName: String);

end HAC.PCode;