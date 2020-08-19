@echo off

if exist build goto do_build
mkdir build

:do_build
cd build

rem ZZZ: until I figure out why build.zig doesn't work with assembly source I need to do this manually
..\zig\zig clang -c ../kernel/arch/x86_64/kernel.s
if %ERRORLEVEL% equ 0 (
    ..\zig\zig.exe build-exe ../lab/lab.zig --object kernel.o -femit-asm
)

cd ..
