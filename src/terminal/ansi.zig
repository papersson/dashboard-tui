const std = @import("std");

pub const ESC = "\x1b";
pub const CSI = ESC ++ "[";

// Cursor movement
pub fn moveCursor(writer: anytype, row: u16, col: u16) !void {
    try writer.print(CSI ++ "{d};{d}H", .{ row, col });
}

pub fn moveCursorUp(writer: anytype, n: u16) !void {
    try writer.print(CSI ++ "{d}A", .{n});
}

pub fn moveCursorDown(writer: anytype, n: u16) !void {
    try writer.print(CSI ++ "{d}B", .{n});
}

pub fn moveCursorRight(writer: anytype, n: u16) !void {
    try writer.print(CSI ++ "{d}C", .{n});
}

pub fn moveCursorLeft(writer: anytype, n: u16) !void {
    try writer.print(CSI ++ "{d}D", .{n});
}

// Cursor visibility
pub fn hideCursor(writer: anytype) !void {
    try writer.writeAll(CSI ++ "?25l");
}

pub fn showCursor(writer: anytype) !void {
    try writer.writeAll(CSI ++ "?25h");
}

// Screen operations
pub fn clearScreen(writer: anytype) !void {
    try writer.writeAll(CSI ++ "2J");
    try moveCursor(writer, 1, 1);
}

pub fn clearLine(writer: anytype) !void {
    try writer.writeAll(CSI ++ "2K");
}

pub fn clearToEndOfLine(writer: anytype) !void {
    try writer.writeAll(CSI ++ "0K");
}

// Alternative screen buffer
pub fn enterAlternateScreen(writer: anytype) !void {
    try writer.writeAll(CSI ++ "?1049h");
}

pub fn exitAlternateScreen(writer: anytype) !void {
    try writer.writeAll(CSI ++ "?1049l");
}

// Colors and styling
pub fn resetStyle(writer: anytype) !void {
    try writer.writeAll(CSI ++ "0m");
}

pub fn setBold(writer: anytype) !void {
    try writer.writeAll(CSI ++ "1m");
}

pub fn setDim(writer: anytype) !void {
    try writer.writeAll(CSI ++ "2m");
}

pub fn setItalic(writer: anytype) !void {
    try writer.writeAll(CSI ++ "3m");
}

pub fn setUnderline(writer: anytype) !void {
    try writer.writeAll(CSI ++ "4m");
}

pub fn setBlink(writer: anytype) !void {
    try writer.writeAll(CSI ++ "5m");
}

pub fn setReverse(writer: anytype) !void {
    try writer.writeAll(CSI ++ "7m");
}

// 24-bit RGB colors
pub fn setForegroundRGB(writer: anytype, r: u8, g: u8, b: u8) !void {
    try writer.print(CSI ++ "38;2;{d};{d};{d}m", .{ r, g, b });
}

pub fn setBackgroundRGB(writer: anytype, r: u8, g: u8, b: u8) !void {
    try writer.print(CSI ++ "48;2;{d};{d};{d}m", .{ r, g, b });
}

// Basic 16 colors
pub const Color = enum(u8) {
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,
    bright_black = 90,
    bright_red = 91,
    bright_green = 92,
    bright_yellow = 93,
    bright_blue = 94,
    bright_magenta = 95,
    bright_cyan = 96,
    bright_white = 97,
};

pub fn setForeground(writer: anytype, color: Color) !void {
    try writer.print(CSI ++ "{d}m", .{@intFromEnum(color)});
}

pub fn setBackground(writer: anytype, color: Color) !void {
    try writer.print(CSI ++ "{d}m", .{@intFromEnum(color) + 10});
}

// Mouse support
pub fn enableMouse(writer: anytype) !void {
    try writer.writeAll(CSI ++ "?1000h"); // X10 mouse protocol
    try writer.writeAll(CSI ++ "?1002h"); // Mouse tracking
    try writer.writeAll(CSI ++ "?1006h"); // SGR mouse mode
}

pub fn disableMouse(writer: anytype) !void {
    try writer.writeAll(CSI ++ "?1006l");
    try writer.writeAll(CSI ++ "?1002l");
    try writer.writeAll(CSI ++ "?1000l");
}

// Terminal size
pub fn getTerminalSize() !struct { width: u16, height: u16 } {
    if (std.posix.isatty(std.io.getStdOut().handle)) {
        var size: std.c.winsize = undefined;
        if (std.c.ioctl(std.io.getStdOut().handle, std.c.T.IOCGWINSZ, &size) == 0) {
            return .{
                .width = size.col,
                .height = size.row,
            };
        }
    }
    // Default fallback
    return .{ .width = 80, .height = 24 };
}