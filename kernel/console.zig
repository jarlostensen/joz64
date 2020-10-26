const std = @import("std");
const types = @import("types.zig");
const video = @import("video.zig");
const font8x8 = @import("font8x8.zig");

const assert = std.debug.assert;

const kLineHeightPixels = 8;
const kCharWidthPixels = 8;

pub const CursorPos = struct {
    x:usize,
    y:usize,
};

const ConsoleContext = struct {

    font:?*[128][8]u8,
    colour:u32,
    bg_colour:u32,

    //NOTE: this position is in PIXELS (not console cells)
    cursor_pos:CursorPos,
    size:types.Size,

    initialised:bool,
};

var con_ctx = ConsoleContext{
    .font = null,
    .colour = video.kWhite,
    .bg_colour = 0,    
    .cursor_pos = .{ .x = 0, .y=0 },
    .size = .{ .width = 0, .height = 0 },
    .initialised = false,
};

pub fn initConsole() void {
    assert(con_ctx.initialised==false);
    con_ctx.size.width = video.getActiveModeHorizontalRes() / kCharWidthPixels;
    con_ctx.size.height = video.getActiveModeVerticalRes() / kLineHeightPixels;
}

pub fn getConsoleSize() types.Size {
    assert(con_ctx.initialised==false);
    return con_ctx.size;
}

fn consolePosToVideoPos(pos:types.Point) types.Point {
    return .{ .x = pos.x*kCharWidthPixels, .y = pos.y*kLineHeightPixels };
}

//sets cursor position (in units of characters and lines)
pub fn setCursorPos(pos:types.Point) void {
    var vpos = consolePosToVideoPos(pos);
    if ( vpos.x >= video.getActiveModeHorizontalRes() ) {
        vpos.x = video.getActiveModeHorizontalRes() - kCharWidthPixels;
    }
    if( vpos.y >= video.getActiveModeVerticalRes() ) {
        vpos.y = video.getActiveModeVerticalRes() - kLineHeightPixels;
    }
    con_ctx.cursor_pos.x = vpos.x;
    con_ctx.cursor_pos.y = vpos.y;
}

pub fn getCursorPos() CursorPos {
    var char_pos:CursorPos = cont_ctx.cursor_pos;
    char_pos.x /= kCharWidthPixels;
    char_pos.y /= kLineHeightPixels;
    return char_pos;    
}

pub fn selectFont(font:*[128][8]u8) void {
    con_ctx.font = font;
}

pub fn setTextColour(colour:u32) void {
    con_ctx.colour = colour;
}

pub fn setTextBgColour(colour:u32) void {
    con_ctx.bg_colour = colour;
}

pub fn outputString(text: []const u8) void {

    var start:usize = 0;
    var pos:usize = 0;
    for(text) |c| {
        if ( c == '\n' ) {
            video.drawTextSegment( .{ 
                .left = con_ctx.cursor_pos.x, 
                .top = con_ctx.cursor_pos.y, 
                .colour = con_ctx.colour, 
                .bg_colour = con_ctx.bg_colour, 
                .font = con_ctx.font.?.*, 
                .offs = start, 
                .len = pos-start},
                text);
            pos += 1;
            start = pos;
            //TODO: scroll
            con_ctx.cursor_pos.y += kLineHeightPixels;
            con_ctx.cursor_pos.x = 0;
        }
        else {
            pos += 1;
        }
    }
    
    if(start==0) {
        // if no line breaks
        video.drawText(con_ctx.cursor_pos.x, con_ctx.cursor_pos.y, con_ctx.colour, con_ctx.bg_colour, con_ctx.font.?.*, text);
        //TODO: clip
        con_ctx.cursor_pos.x += text.len * kCharWidthPixels;
    }
}

// clear the entire screen to BG colour
pub fn clearScreen() void {
    video.clearScreen(con_ctx.bg_colour);
}

// clear a region to BG colour
pub fn clearRegion(region:types.Rectangle) void {
    const vpos0 = consolePosToVideoPos(.{ .x = region.left, .y = region.top });
    const vpos1 = consolePosToVideoPos(.{ .x = region.right, .y = region.bottom });
    const vregion:types.Rectangle = .{ 
        .top = vpos0.y, .left = vpos0.x,
        .bottom = vpos1.y, .right = vpos1.x,
    };
    video.clearRegion(vregion, con_ctx.bg_colour);
}

pub fn selectClientRegion(region:types.Rectangle) void {

}