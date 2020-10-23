const std = @import("std");
const kernel = @import("kernel.zig");
const font8x8 = @import("font8x8.zig");

const uefi = std.os.uefi;

//debug
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub const VideoError = error {
    GraphicsProtocolError,
    NoSuitableModeFound,
};

const ActiveModeInfo = struct {
    mode:u32,
    framebuffer_base:?[*]u8,
    framebuffer_size:usize,
    framebuffer_stride:usize,
};

var active_mode_info = ActiveModeInfo{

    .mode = 0,
    .framebuffer_base = null,
    .framebuffer_size = 0,
    .framebuffer_stride = 0,
};

pub fn initialiseVideo() VideoError!bool {
    const boot_services = uefi.system_table.boot_services.?;

    const con_out = uefi.system_table.con_out.?;
    
    var handles:[4]uefi.Handle = undefined;
    var handles_size:usize = 4*@sizeOf(uefi.Handle);
    if ( boot_services.locateHandle(std.os.uefi.tables.LocateSearchType.ByProtocol, 
                    &uefi.protocols.GraphicsOutputProtocol.guid, 
                    null,
                    &handles_size, 
                    &handles) == uefi.Status.Success ) {
        var num_handles = handles_size/@sizeOf(uefi.Handle);

        var gop:*uefi.protocols.GraphicsOutputProtocol = undefined;
        if ( boot_services.handleProtocol(handles[0], &uefi.protocols.GraphicsOutputProtocol.guid, @ptrCast(*?*c_void, &gop)) == uefi.Status.Success ) {
            
            const kDesiredHorizontalResolution:u32 = 800;
            const kDesiredVerticalResolution:u32 = 600;
            
            var mode_num:i32 = 0;
            var found_mode:i32 = -1;

            var size_of_info:usize = 0;
            var info:*uefi.protocols.GraphicsOutputModeInformation = undefined;
            var status = gop.queryMode(@intCast(u32, mode_num), &size_of_info, &info);
            while(status == uefi.Status.Success) {

                
                found_mode = switch(info.pixel_format) {
                    uefi.protocols.GraphicsPixelFormat.PixelRedGreenBlueReserved8BitPerColor,
                    uefi.protocols.GraphicsPixelFormat.PixelBlueGreenRedReserved8BitPerColor => pixFormatBlk: {

                        if ( info.horizontal_resolution == kDesiredHorizontalResolution 
                                and 
                            info.vertical_resolution == kDesiredVerticalResolution ) {
                                break :pixFormatBlk mode_num;
                        }
                        break :pixFormatBlk -1;
                    },
                    else => -1,
                };
                
                if ( found_mode>=0 )
                {
                    active_mode_info.framebuffer_base = @intToPtr([*]u8, gop.mode.frame_buffer_base);
                    active_mode_info.framebuffer_size = gop.mode.frame_buffer_size;
                    active_mode_info.framebuffer_stride = active_mode_info.framebuffer_size / kDesiredVerticalResolution;
                    active_mode_info.mode = @intCast(u32, found_mode);
                    break;
                }

                mode_num += 1;
                status = gop.queryMode(@intCast(u32, mode_num), &size_of_info, &info);
            }

            if (found_mode<0 ) 
            {
                return VideoError.NoSuitableModeFound;
            }            
        }
        else {
            return VideoError.GraphicsProtocolError;
        }
    }
    else {
        return VideoError.GraphicsProtocolError;
    }

    return true;
}

pub fn drawFilledSquare(left:usize, top:usize, right:usize, bottom:usize, colour:u32) void {

    var wptr:[*]u32 = @ptrCast([*]u32, @alignCast(@alignOf([*]u32), active_mode_info.framebuffer_base));
    wptr += top*800 + left;
    var cols = bottom - top;
    var rows = right - left;
    while(cols>0) {
        var row:usize = 0;
        while(row < rows) {
            wptr[row] = colour;
            row += 1;
        }
        wptr += 800;
        cols -= 1;
    }
}

pub fn dumpFont(font:[128][8]u8, top:usize, left:usize, colour:u32) void {
    var wptr:[*]u32 = @ptrCast([*]u32, @alignCast(@alignOf([*]u32), active_mode_info.framebuffer_base));
    var topptr = wptr;
    wptr += top*800 + left;

    const pixel_stride:u32 = @intCast(u32, active_mode_info.framebuffer_stride >> 2);

    var point:usize = 0;
    while(point < 128) {
        
        var line:usize = 0;
        var line_ptr = wptr;
        while(line < 8) {
            var pixels:u8 = font[point][line];
            var index:u8 = 0;
            while(index<8) {
                const set = pixels & 1;
                line_ptr[index] = set*colour;
                pixels >>= 1;
                index += 1;
            }
            line+=1;
            line_ptr += pixel_stride;
        }
        wptr += 12;
        point += 1;
        if ( @mod(point, 32)==0 ) {
            // next character line
            topptr += (pixel_stride * 12);
            wptr = topptr;
        }
    }
}