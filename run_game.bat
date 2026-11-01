@echo off
set "GODOT_EXE=D:\steamlibrary\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot was not found. Import project.godot in your Godot 4 editor.
  pause
  exit /b 1
)
start "World Story" "%GODOT_EXE%" --path "%~dp0."
