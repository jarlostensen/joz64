@echo off

if exist build goto do_build
mkdir build

:do_build
cd build

rem ZZZ: until I figure out why build.zig doesn't work with assembly source I need to do this manually
..\zig\zig clang -c ../kernel/arch/x86_64/kernel.s
if %ERRORLEVEL% equ 0 (
    zig build-exe ../kernel/efi_main.zig --object kernel.o --name bootx64 -target x86_64-uefi-msvc --subsystem efi_application -femit-asm

    if %ERRORLEVEL% equ 0 (
        ..\tools\efigen.exe -i bootx64.efi -o boot.dd 
        del boot.vdi
        "c:\Program Files\Oracle\VirtualBox\VBoxManage.exe" convertdd boot.dd boot.vdi --format VDI
        rem NOTE: this is just so that I don't have to re-load the vdi in VirtualBox every time it builds
        "c:\Program Files\Oracle\VirtualBox\VBoxManage.exe" internalcommands sethduuid boot.vdi 70c248ad-8295-4f18-b307-54ad0bd1e9df
    )
)

cd ..
