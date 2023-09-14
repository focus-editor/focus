@echo off

jai -quiet first.jai

if %ERRORLEVEL% EQU 0 (
    pushd build_debug
    focus.exe
    popd
)
