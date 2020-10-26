const std = @import("std");
const kernel = @import("kernel.zig");
const uefi = std.os.uefi;

const assert = std.debug.assert;

//debug const utils = @import("utils.zig");
//debug const L = std.unicode.utf8ToUtf16LeStringLiteral;

//ZZZ: depends on pixel format being RGB, we should have one per version
pub const kWhite = 0xffffff;
pub const kRed   = 0xff0000;
pub const kGreen = 0x00ff00;
pub const kBlue  = 0x0000ff;
pub const kYellow = 0xffff00;
pub const kCornflowerBlue = 0x6495ed;

const kMaxHorizRes:u32 = 1024;

pub const VideoError = error {
    GraphicsProtocolError,
    NoSuitableModeFound,
    SetModeFailed,
};

pub const Rectangle = struct {
    top:usize,
    left:usize,
    bottom:usize,
    right:usize,

    pub fn Width(self:*const Rectangle) usize {
        return self.right - self.left;
    }

    pub fn Height(self:*const Rectangle) usize {
        return self.bottom - self.top;
    }
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

var video_initialised = false;

pub fn initialiseVideo() VideoError!bool {

    assert(video_initialised==false);

    const boot_services = uefi.system_table.boot_services.?;

    // debugvar buffer: [256]u8 = undefined;
    // debugvar wbuffer: [256]u16 = undefined;
    
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
            
            var max_horiz_res:u32 = 0;
            var mode_num:i32 = 0;
            var found_mode:i32 = -1;

            var size_of_info:usize = 0;
            var info:*uefi.protocols.GraphicsOutputModeInformation = undefined;
            var status = gop.queryMode(@intCast(u32, mode_num), &size_of_info, &info);
            while(status == uefi.Status.Success) {

                switch(info.pixel_format) {
                    uefi.protocols.GraphicsPixelFormat.PixelRedGreenBlueReserved8BitPerColor,
                    uefi.protocols.GraphicsPixelFormat.PixelBlueGreenRedReserved8BitPerColor => {
                        
                        // pick highest res mode <= 1024
                        if ( info.horizontal_resolution > max_horiz_res 
                                and 
                            info.horizontal_resolution <= kMaxHorizRes ) {

                                max_horiz_res = info.horizontal_resolution;
                                active_mode_info.pixel_stride = info.pixels_per_scan_line;
                                active_mode_info.framebuffer_stride = info.pixels_per_scan_line << 2;
                                active_mode_info.horiz_res = info.horizontal_resolution;
                                active_mode_info.vert_res = info.vertical_resolution;
                                found_mode = mode_num;
                        }
                    },
                    else => {},
                }

                mode_num += 1;
                status = gop.queryMode(@intCast(u32, mode_num), &size_of_info, &info);
            }

            if ( found_mode>=0 )
            {
                active_mode_info.framebuffer_base = @intToPtr([*]u8, gop.mode.frame_buffer_base);
                active_mode_info.framebuffer_size = gop.mode.frame_buffer_size;
                // debugutils.efiPrint(buffer[0..], wbuffer[0..], "    found a matching mode {}, {}x{} stride is {}\n\r", 
                // debug.{found_mode, active_mode_info.horiz_res, active_mode_info.pixel_stride, active_mode_info.pixel_stride}
                // debug);
            }
            else {
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

    video_initialised = true;
    return true;
}

pub fn getActiveModeHorizontalRes() usize {
    assert(video_initialised==true);
    return active_mode_info.horiz_res;
}

pub fn getActiveModeVerticalRes() usize {
    assert(video_initialised==true);
    return active_mode_info.vert_res;
}

pub fn getActiveModePixelStride() usize {
    assert(video_initialised==true);
    return @intCast(usize, active_mode_info.pixel_stride);
}

pub fn getActiveModeFramebufferSize() usize {
    assert(video_initialised==true);
    return @intCast(usize, active_mode_info.framebuffer_size);
}

fn frameBufferPtr(left:usize, top:usize) [*]u32 {
    var wptr:[*]u32 = @ptrCast([*]u32, @alignCast(@alignOf([*]u32), active_mode_info.framebuffer_base));
    wptr += top*active_mode_info.pixel_stride + left;
    return wptr;
}

// as of 0.6.0 I can't use a completely anonymous structure in the function signature for this to be usable from outside this module.
// https://old.reddit.com/r/Zig/comments/jihmht/anonymous_structure_as_function_arguments/
pub const drawTextSegmentArgs = struct {
            left:usize = 0,
            top:usize = 0,
            colour:u32 = 0,
            bg_colour:u32 = 0xffffffff,
            font:[128][8]u8 = undefined, 
            offs:usize = 0,
            len:usize = 0
};

// draw sub segment of text at position left,top using font and colour
pub fn drawTextSegment(args:drawTextSegmentArgs,
        comptime text: []const u8 )void {
    if(args.len==0)
        return;

    assert(video_initialised==true);
    assert(args.offs+args.len <= text.len);
    
    var wptr = frameBufferPtr(args.left, args.top);

    // pixel set, or not set
    const colour_lut = [2]u32{args.bg_colour, args.colour};
    
    var n = args.offs;
    const end = args.offs+args.len;
    while(n < end) {

        const c = text[n];
        var line:usize = 0;
        var line_ptr = wptr;
        while(line < 8) {

            var pixels:u8 = args.font[c][line];
            switch(pixels) {
                0 => {
                    line_ptr[0] = args.bg_colour; line_ptr[1] = args.bg_colour;
                    line_ptr[2] = args.bg_colour; line_ptr[3] = args.bg_colour;
                    line_ptr[4] = args.bg_colour; line_ptr[5] = args.bg_colour;
                    line_ptr[6] = args.bg_colour; line_ptr[7] = args.bg_colour;
                },
                0xff => {
                    line_ptr[0] = args.colour; line_ptr[1] = args.colour;
                    line_ptr[2] = args.colour; line_ptr[3] = args.colour;
                    line_ptr[4] = args.colour; line_ptr[5] = args.colour;
                    line_ptr[6] = args.colour; line_ptr[7] = args.colour;
                },
                else => {
                    var index:u8 = 0;
                    while(index<8) {
                        const set = pixels & 1;
                        line_ptr[index] = colour_lut[set];
                        pixels >>= 1;
                        index += 1;
                    }
                }
            }
            
            line+=1;
            line_ptr += active_mode_info.pixel_stride;
        }
        //NOTE: based on font being 8x8x
        wptr += 8;
        n += 1;
    }
}

// draw text at position left,top using font and colour
pub fn drawText(left:usize, top:usize, colour:u32, bg_colour:u32, font:[128][8]u8, comptime text: []const u8) void {
    if(text.len==0)
        return;
    drawTextSegment( .{
         .left = left, 
         .top = top, 
         .colour = colour, 
         .bg_colour = bg_colour, 
         .font = font, 
         .len = text.len}, 
    text);
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

fn scrollUpRegionFullWidth(top:usize, bottom:usize, linesToScroll:usize) void {
    var wptr = frameBufferPtr(0, top);
    var rptr = wptr + linesToScroll*active_mode_info.pixel_stride;

    var strip:usize = 0;
    const strips:usize = (bottom - top) / linesToScroll;
    const rem_lines:usize = @mod((bottom - top), linesToScroll);
    while(strip < strips) {

        var line = linesToScroll;
        while(line>0) {
            @memcpy(wptr, rptr, active_mode_info.framebuffer_stride);
            wptr += active_mode_info.pixel_stride;
            rptr += active_mode_info.pixel_stride;
            line -= 1;
        }

        strip += 1;
    }

    while(rem_lines>0) {
        @memcpy(wptr, rptr, active_mode_info.framebuffer_stride);
        wptr += active_mode_info.pixel_stride;
        rptr += active_mode_info.pixel_stride;
        rem_lines -= 1;
    }
}

pub fn scrollRegion(region:Rectangle, linesToScroll:usize, up:bool) void {
    
    if ( region.Width() == 0 or region.Height() == 0 or linesToScroll==0 )
        return;

    if( linesToScroll>=region.Height() )
    {
        //TODO: just clear region
        return;
    }


}

pub fn clearScreen(colour:u32) void {
    assert(video_initialised==true);
    var wptr = frameBufferPtr(0, 0);
    var pixels_to_fill = active_mode_info.pixel_stride * active_mode_info.vert_res;
    while(pixels_to_fill>0) {
        wptr[0] = colour;
        wptr+=1;
        pixels_to_fill -= 1;
    }
}
