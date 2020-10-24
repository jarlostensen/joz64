const std = @import("std");
const video = @import("video.zig");
const font8x8 = @import("font8x8.zig");

const kLineHeightPixels = 8;
const kCharWidthPixels = 8;

const ConsoleContext = struct {

    font:?*[128][8]u8,
    colour:u32,
    bg_colour:u32,

    cursor_x:usize,
    cursor_y:usize,
};

var con_ctx = ConsoleContext{
    .font = null,
    .colour = video.kWhite,
    .bg_colour = 0,
    .cursor_x = 0,
    .cursor_y = 0,
};

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
            video.drawTextSegment(con_ctx.cursor_x, con_ctx.cursor_y, con_ctx.colour, con_ctx.font.?.*, text, start, pos-start);
            pos += 1;
            start = pos;
            con_ctx.cursor_y += kLineHeightPixels;
            con_ctx.cursor_x = 0;
        }
        else {
            pos += 1;
        }
    }
    
    if(start==0) {
        // if no line breaks
        video.drawText(con_ctx.cursor_x, con_ctx.cursor_y, con_ctx.colour, con_ctx.font.?.*, text);
        con_ctx.cursor_x += text.len * kCharWidthPixels;
    }
}

