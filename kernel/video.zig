const std = @import("std");
const kernel = @import("kernel.zig");
const font8x8 = @import("font8x8.zig");
const uefi = std.os.uefi;

//debug
const utils = @import("utils.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;


//ZZZ: depends on pixel format being RGB, we should have one per version
pub const kRed   = 0xff0000;
pub const kGreen = 0x00ff00;
pub const kBlue  = 0x00ff00;
pub const kYellow = 0xffff00;

pub const VideoError = error {
    GraphicsProtocolError,
    NoSuitableModeFound,
    SetModeFailed,
};

const ActiveModeInfo = struct {
    mode:u32,
    horiz_res:usize,
    vert_res:usize,
    framebuffer_base:?[*]u8,
    framebuffer_size:usize,
    framebuffer_stride:usize,
    pixel_stride:usize,
};

var active_mode_info = ActiveModeInfo{

    .mode = 0,
    .horiz_res = 0,
    .vert_res = 0,
    .framebuffer_base = null,
    .framebuffer_size = 0,
    .framebuffer_stride = 0,
    .pixel_stride = 0,
};

pub fn initialiseVideo() VideoError!bool {
    const boot_services = uefi.system_table.boot_services.?;    

    // debug
    //var buffer: [256]u8 = undefined;
    //var wbuffer: [256]u16 = undefined;
    
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

                                // utils.efiPrint(buffer[0..], wbuffer[0..], "    found mode {} {}x{}, stride is {}, format {}\n\r", 
                                //   .{mode_num, info.horizontal_resolution, info.vertical_resolution, info.pixels_per_scan_line, info.pixel_format}
                                // );

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
                    active_mode_info.pixel_stride = info.pixels_per_scan_line;
                    active_mode_info.framebuffer_stride = info.pixels_per_scan_line << 2;
                    active_mode_info.mode = @intCast(u32, found_mode);
                    active_mode_info.horiz_res = kDesiredHorizontalResolution;
                    active_mode_info.vert_res = kDesiredVerticalResolution;

                    // utils.efiPrint(buffer[0..], wbuffer[0..], "    found a matching mode {}, stride is {}\n\r", 
                    //               .{found_mode, active_mode_info.pixel_stride}
                    //             );
                    break;
                }

                mode_num += 1;
                status = gop.queryMode(@intCast(u32, mode_num), &size_of_info, &info);
            }

            if (found_mode<0 ) 
            {
                return VideoError.NoSuitableModeFound;
            }

            // at this point we have a mode and we want to switch to it

            // NOTE: VirtualBox
            //       This requires the VBoxSVGA graphics controller to be selected for the virtual machine. 

            if ( gop.setMode(@intCast(u32, found_mode)) != uefi.Status.Success ) {
                return VideoError.SetModeFailed;
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

pub fn getActiveModeHorizontalRes() usize {
    return active_mode_info.horiz_res;
}

pub fn getActiveModeVerticalRes() usize {
    return active_mode_info.vert_res;
}

pub fn getActiveModePixelStride() usize {
    return @intCast(usize, active_mode_info.pixel_stride);
}

fn frameBufferPtr(left:usize, top:usize) [*]u32 {
    var wptr:[*]u32 = @ptrCast([*]u32, @alignCast(@alignOf([*]u32), active_mode_info.framebuffer_base));
    wptr += top*active_mode_info.pixel_stride + left;
    return wptr;
}

pub fn drawText(left:usize, top:usize, colour:u32, font:[128][8]u8, comptime text: []const u8) void {
    var wptr = frameBufferPtr(left, top);
    
    for(text) |c| {

        var line:usize = 0;
        var line_ptr = wptr;
        while(line < 8) {
            var pixels:u8 = font[c][line];
            var index:u8 = 0;
            while(index<8) {
                const set = pixels & 1;
                line_ptr[index] = set*colour;
                pixels >>= 1;
                index += 1;
            }
            line+=1;
            line_ptr += active_mode_info.pixel_stride;
        }
        //NOTE: based on font being 8x8x
        wptr += 8;
    }
}

pub fn drawFilledSquare(left:usize, top:usize, right:usize, bottom:usize, colour:u32) void {

    var wptr = frameBufferPtr(left, top);
    var cols = bottom - top;
    var rows = right - left;
    while(cols>0) {
        var row:usize = 0;
        while(row < rows) {
            wptr[row] = colour;
            row += 1;
        }
        wptr += active_mode_info.pixel_stride;
        cols -= 1;
    }
}

pub fn dumpFont(font:[128][8]u8, top:usize, left:usize, colour:u32) void {
    var wptr = frameBufferPtr(left, top);
    var topptr = wptr;

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
            line_ptr += active_mode_info.pixel_stride;
        }
        wptr += 8;
        point += 1;
        if ( @mod(point, 32)==0 ) {
            // next character line
            topptr += (active_mode_info.pixel_stride * 8);
            wptr = topptr;
        }
    }
}