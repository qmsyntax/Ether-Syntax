@echo off
rem Opens the Godot editor on this project. winget installs Godot without a PATH alias
rem unless run as admin, so locate the executable in the winget package folder directly.
setlocal
set "PKG=%LOCALAPPDATA%\Microsoft\WinGet\Packages"
set "GODOT="
rem dir only expands wildcards in the last path component, so recurse from the package root.
for /f "delims=" %%F in ('dir /b /s "%PKG%\Godot_v*_win64.exe" 2^>nul') do set "GODOT=%%F"
if not defined GODOT (
  echo Could not find Godot under %PKG%. Is it installed?
  exit /b 1
)
echo Launching %GODOT%
start "" "%GODOT%" --editor --path "%~dp0game"
endlocal
