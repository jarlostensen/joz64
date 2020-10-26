const std = @import("std");
const video = @import("video.zig");
const font8x8 = @import("font8x8.zig");

const assert = std.debug.assert;

const kLineHeightPixels = 8;
const kCharWidthPixels = 8;

pub const CursorPos = struct {
    x:usize,
    y:usize,
};

pub const Size = struct {
    width:usize,
    height:usize,
};

const ConsoleContext = struct {

    font:?*[128][8]u8,
    colour:u32,
    bg_colour:u32,

    cursor_pos:CursorPos,
    size:Size,

    initialised:bool,
};

var con_ctx = ConsoleContext{
    .font = null,
    .colour = video.kWhite,
    .bg_colour = 0,    
    .cursor_pos = CursorPos{ .x = 0, .y=0 },
    .size = Size{ .width = 0, .height = 0 },
    .initialised = false,
};

pub fn initConsole() void {
    assert(con_ctx.initialised==false);
    con_ctx.size.width = video.getActiveModeHorizontalRes() / kCharWidthPixels;
    con_ctx.size.height = video.getActiveModeVerticalRes() / kLineHeightPixels;
}

pub fn getConsoleSize() Size {
    assert(con_ctx.initialised==false);
    return con_ctx.size;
}

//sets cursor position (in units of characters and lines)
pub fn setCursorPos(c:usize, l:usize) void {
    var x = c * kCharWidthPixels;
    var y = l * kLineHeightPixels;
    if ( x >= video.getActiveModeHorizontalRes() ) {
        x = video.getActiveModeHorizontalRes() - kCharWidthPixels;
    }
    if( y >= video.getActiveModeVerticalRes() ) {
        y = video.getActiveModeVerticalRes() - kLineHeightPixels;
    }
    con_ctx.cursor_pos.x = x;
    con_ctx.cursor_pos.y = y;
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

pub fn outputString(comptime text: []const u8) void {

    var start:usize = 0;
    var pos:usize = 0;
    for(text) |c| {
        if ( c == '\n' ) {
            video.drawTextSegment(con_ctx.cursor_pos.x, con_ctx.cursor_pos.y, con_ctx.colour, con_ctx.bg_colour, con_ctx.font.?.*, text, start, pos-start);
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

pub fn clearScreen() void {
    video.clearScreen(con_ctx.bg_colour);
}
