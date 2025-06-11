const std = @import("std");
const ansi = @import("ansi.zig");

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    
    pub const black = Color{ .r = 10, .g = 10, .b = 10 };
    pub const white = Color{ .r = 224, .g = 224, .b = 224 };
    pub const gray = Color{ .r = 128, .g = 128, .b = 128 };
    pub const dim_gray = Color{ .r = 42, .g = 42, .b = 42 };
    pub const cyan = Color{ .r = 0, .g = 255, .b = 255 };
    pub const bright_cyan = Color{ .r = 150, .g = 255, .b = 255 };
    pub const red = Color{ .r = 255, .g = 0, .b = 110 };
    pub const yellow = Color{ .r = 255, .g = 190, .b = 11 };
    pub const green = Color{ .r = 6, .g = 255, .b = 165 };
    pub const blue = Color{ .r = 58, .g = 134, .b = 255 };
    pub const magenta = Color{ .r = 255, .g = 0, .b = 255 };
    
    pub fn eql(self: Color, other: Color) bool {
        return self.r == other.r and self.g == other.g and self.b == other.b;
    }
};

pub const Style = struct {
    bold: bool = false,
    dim: bool = false,
    italic: bool = false,
    underline: bool = false,
    blink: bool = false,
    reverse: bool = false,
};

pub const Cell = struct {
    char: u21 = ' ',
    fg: Color = Color.white,
    bg: Color = Color.black,
    style: Style = .{},
    
    pub fn eql(self: Cell, other: Cell) bool {
        return self.char == other.char and
               self.fg.eql(other.fg) and
               self.bg.eql(other.bg) and
               std.meta.eql(self.style, other.style);
    }
};

pub const Screen = struct {
    allocator: std.mem.Allocator,
    width: u16,
    height: u16,
    cells: []Cell,
    prev_cells: []Cell,
    cursor_x: u16 = 0,
    cursor_y: u16 = 0,
    cursor_visible: bool = false,
    
    pub fn init(allocator: std.mem.Allocator) !Screen {
        const size = try ansi.getTerminalSize();
        const total_cells = size.width * size.height;
        
        const screen = Screen{
            .allocator = allocator,
            .width = size.width,
            .height = size.height,
            .cells = try allocator.alloc(Cell, total_cells),
            .prev_cells = try allocator.alloc(Cell, total_cells),
        };
        
        // Initialize cells
        for (screen.cells) |*cell| {
            cell.* = Cell{};
        }
        for (screen.prev_cells) |*cell| {
            cell.* = Cell{};
        }
        
        return screen;
    }
    
    pub fn deinit(self: *Screen) void {
        self.allocator.free(self.cells);
        self.allocator.free(self.prev_cells);
    }
    
    pub fn clear(self: *Screen) void {
        for (self.cells) |*cell| {
            cell.* = Cell{};
        }
    }
    
    pub fn getCell(self: *Screen, x: u16, y: u16) ?*Cell {
        if (x >= self.width or y >= self.height) return null;
        return &self.cells[y * self.width + x];
    }
    
    pub fn setCell(self: *Screen, x: u16, y: u16, cell: Cell) void {
        if (self.getCell(x, y)) |c| {
            c.* = cell;
        }
    }
    
    pub fn writeText(self: *Screen, x: u16, y: u16, text: []const u8, fg: Color, bg: Color, style: Style) void {
        var col = x;
        var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
        
        while (iter.nextCodepoint()) |codepoint| {
            if (col >= self.width) break;
            self.setCell(col, y, .{
                .char = codepoint,
                .fg = fg,
                .bg = bg,
                .style = style,
            });
            col += 1;
        }
    }
    
    pub fn drawBox(self: *Screen, x: u16, y: u16, width: u16, height: u16, fg: Color, bg: Color) void {
        // Unicode box drawing characters
        const top_left = '┌';
        const top_right = '┐';
        const bottom_left = '└';
        const bottom_right = '┘';
        const horizontal = '─';
        const vertical = '│';
        
        // Top border
        self.setCell(x, y, .{ .char = top_left, .fg = fg, .bg = bg, .style = .{} });
        self.setCell(x + width - 1, y, .{ .char = top_right, .fg = fg, .bg = bg, .style = .{} });
        
        var i: u16 = 1;
        while (i < width - 1) : (i += 1) {
            self.setCell(x + i, y, .{ .char = horizontal, .fg = fg, .bg = bg, .style = .{} });
            self.setCell(x + i, y + height - 1, .{ .char = horizontal, .fg = fg, .bg = bg, .style = .{} });
        }
        
        // Bottom border
        self.setCell(x, y + height - 1, .{ .char = bottom_left, .fg = fg, .bg = bg, .style = .{} });
        self.setCell(x + width - 1, y + height - 1, .{ .char = bottom_right, .fg = fg, .bg = bg, .style = .{} });
        
        // Vertical borders
        i = 1;
        while (i < height - 1) : (i += 1) {
            self.setCell(x, y + i, .{ .char = vertical, .fg = fg, .bg = bg, .style = .{} });
            self.setCell(x + width - 1, y + i, .{ .char = vertical, .fg = fg, .bg = bg, .style = .{} });
        }
    }
    
    pub fn fillRect(self: *Screen, x: u16, y: u16, width: u16, height: u16, bg: Color) void {
        var row: u16 = 0;
        while (row < height) : (row += 1) {
            var col: u16 = 0;
            while (col < width) : (col += 1) {
                if (self.getCell(x + col, y + row)) |cell| {
                    cell.bg = bg;
                }
            }
        }
    }
    
    pub fn render(self: *Screen, writer: anytype) !void {
        // Hide cursor during rendering
        try ansi.hideCursor(writer);
        
        // Diff-based rendering
        var last_fg: ?Color = null;
        var last_bg: ?Color = null;
        var last_style: ?Style = null;
        
        var y: u16 = 0;
        while (y < self.height) : (y += 1) {
            var x: u16 = 0;
            var needs_move = true;
            
            while (x < self.width) : (x += 1) {
                const idx = y * self.width + x;
                const cell = self.cells[idx];
                const prev_cell = self.prev_cells[idx];
                
                // Skip if unchanged
                if (cell.eql(prev_cell)) {
                    needs_move = true;
                    continue;
                }
                
                // Move cursor if needed
                if (needs_move) {
                    try ansi.moveCursor(writer, y + 1, x + 1);
                    needs_move = false;
                }
                
                // Apply style changes
                if (last_style == null or !std.meta.eql(cell.style, last_style.?)) {
                    try ansi.resetStyle(writer);
                    if (cell.style.bold) try ansi.setBold(writer);
                    if (cell.style.dim) try ansi.setDim(writer);
                    if (cell.style.italic) try ansi.setItalic(writer);
                    if (cell.style.underline) try ansi.setUnderline(writer);
                    if (cell.style.blink) try ansi.setBlink(writer);
                    if (cell.style.reverse) try ansi.setReverse(writer);
                    last_style = cell.style;
                    last_fg = null;
                    last_bg = null;
                }
                
                // Apply color changes
                if (last_fg == null or !cell.fg.eql(last_fg.?)) {
                    try ansi.setForegroundRGB(writer, cell.fg.r, cell.fg.g, cell.fg.b);
                    last_fg = cell.fg;
                }
                
                if (last_bg == null or !cell.bg.eql(last_bg.?)) {
                    try ansi.setBackgroundRGB(writer, cell.bg.r, cell.bg.g, cell.bg.b);
                    last_bg = cell.bg;
                }
                
                // Write character
                if (cell.char < 128) {
                    try writer.writeByte(@intCast(cell.char));
                } else {
                    var buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(cell.char, &buf) catch 1;
                    try writer.writeAll(buf[0..len]);
                }
                
                // Update previous cell
                self.prev_cells[idx] = cell;
            }
        }
        
        // Reset style and show cursor if needed
        try ansi.resetStyle(writer);
        if (self.cursor_visible) {
            try ansi.moveCursor(writer, self.cursor_y + 1, self.cursor_x + 1);
            try ansi.showCursor(writer);
        }
    }
    
    pub fn resize(self: *Screen) !void {
        const size = try ansi.getTerminalSize();
        if (size.width == self.width and size.height == self.height) return;
        
        const new_total = size.width * size.height;
        
        // Reallocate buffers
        self.allocator.free(self.cells);
        self.allocator.free(self.prev_cells);
        
        self.cells = try self.allocator.alloc(Cell, new_total);
        self.prev_cells = try self.allocator.alloc(Cell, new_total);
        
        self.width = size.width;
        self.height = size.height;
        
        // Initialize new cells
        for (self.cells) |*cell| {
            cell.* = Cell{};
        }
        for (self.prev_cells) |*cell| {
            cell.* = Cell{};
        }
    }
};