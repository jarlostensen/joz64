# joz64
UEFI kernel explorations in Zig.
This is me learning about Zig as well as playing around with an UEFI application.

A big thanks goes out to the Ziglang subreddit community and @andrewrk for help and guidance in this learning effort.

You will find some videos of how this project proceeds on https://www.youtube.com/channel/UCcMBPIHydEn4i3awhmue_MA/

## Building ##
At the point of writing this I've not been very succesful in getting the ```build.zig``` approach to work, with some included .S files failing the build system itself.<br/> 
While I wait for enlightenment the way to build the project is therefore to use ```build.bat``` which in addition to invoking  ```zig.exe``` correctly, also generates the bootable EFI disk image (using my ```efigen``` tool) and a VDI for use with VirtualBox, using the ```VBoxManage``` tool which is assumed to exist in ```C:\Program Files\Oracle\VirtualBox```.<br/>

