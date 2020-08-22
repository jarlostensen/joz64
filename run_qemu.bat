qemu-system-x86_64 -cpu qemu64 -m 512 -L OVMF_dir/ -bios .\external\OVMF-X64-r15214\OVMF.fd -drive format=raw,file=build\boot.dd,if=ide 
