@echo off

cd..
call build
cd exm

if "%1"=="" goto gallery

rem Try without extension
if exist %1.adb ..\hax -v2 %1.adb
if exist %1.adb goto fin

..\hax -v2 %1
goto fin

:gallery

..\hax gallery.adb

:fin