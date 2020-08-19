@echo off

if exist build goto do_build
mkdir build

:do_build
cd build

rem ZZZ: until I figure out why build.zig doesn't work with assembly source I need to do this manually
..\zig\zig clang -c ../kernel/arch/x86_64/kernel.s
if %ERRORLEVEL% equ 0 (
    ..\zig\zig.exe build-exe ../kernel/efi_main.zig --object kernel.o --name bootx64 -target x86_64-uefi-msvc --subsystem efi_application -femit-asm

    if %ERRORLEVEL% equ 0 (
        ..\tools\efigen.exe -i bootx64.efi -o boot.dd 
        del boot.vdi
        "c:\Program Files\Oracle\VirtualBox\VBoxManage.exe" convertdd boot.dd boot.vdi --format VDI
    )
)

cd ..
