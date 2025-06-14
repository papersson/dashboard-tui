const std = @import("std");
const Screen = @import("../terminal/screen.zig").Screen;
const Color = @import("../terminal/screen.zig").Color;
const Event = @import("../terminal/input.zig").Event;
const Key = @import("../terminal/input.zig").Key;
const Rect = @import("../ui/layout.zig").Rect;
const Theme = @import("../ui/theme.zig").Theme;

pub const NotesPanel = struct {
    allocator: std.mem.Allocator,
    focused: bool = false,
    content: std.ArrayList(u8),
    lines: std.ArrayList([]const u8),
    cursor_line: usize = 0,
    cursor_col: usize = 0,
    scroll_offset: usize = 0,
    insert_mode: bool = false,
    last_command: u8 = 0,
    
    pub fn init(allocator: std.mem.Allocator) !NotesPanel {
        var content = std.ArrayList(u8).init(allocator);
        const lines = std.ArrayList([]const u8).init(allocator);
        
        // Add some default content
        const default_text = "Quick Notes\n===========\n\n- Press 'i' to enter insert mode\n- Press 'Esc' to exit insert mode\n- Use arrow keys to navigate\n\n";
        try content.appendSlice(default_text);
        
        return NotesPanel{
            .allocator = allocator,
            .content = content,
            .lines = lines,
        };
    }
    
    pub fn deinit(self: *NotesPanel) void {
        self.lines.deinit();
        self.content.deinit();
    }
    
    pub fn handleEvent(self: *NotesPanel, event: Event) !bool {
        switch (event) {
            .key => |key| {
                if (self.insert_mode) {
                    switch (key) {
                        .escape => {
                            self.insert_mode = false;
                            return true;
                        },
                        .char => |c| {
                            if (c <= 127) { // ASCII range
                                try self.insertChar(@intCast(c));
                            }
                            return true;
                        },
                        .enter => {
                            try self.insertChar('\n');
                            return true;
                        },
                        .backspace => {
                            self.deleteChar();
                            return true;
                        },
                        .arrow_left => {
                            self.moveCursorLeft();
                            return true;
                        },
                        .arrow_right => {
                            self.moveCursorRight();
                            return true;
                        },
                        .arrow_up => {
                            self.moveCursorUp();
                            return true;
                        },
                        .arrow_down => {
                            self.moveCursorDown();
                            return true;
                        },
                        else => {},
                    }
                } else {
                    switch (key) {
                        .char => |c| switch (c) {
                            'i' => {
                                self.insert_mode = true;
                                self.last_command = 0;
                                return true;
                            },
                            'h' => {
                                self.moveCursorLeft();
                                self.last_command = 0;
                                return true;
                            },
                            'j' => {
                                self.moveCursorDown();
                                self.last_command = 0;
                                return true;
                            },
                            'k' => {
                                self.moveCursorUp();
                                self.last_command = 0;
                                return true;
                            },
                            'l' => {
                                self.moveCursorRight();
                                self.last_command = 0;
                                return true;
                            },
                            'e' => {
                                self.moveToEndOfWord();
                                self.last_command = 0;
                                return true;
                            },
                            'b' => {
                                self.moveToBeginningOfWord();
                                self.last_command = 0;
                                return true;
                            },
                            'd' => {
                                if (self.last_command == 'd') {
                                    self.deleteLine();
                                    self.last_command = 0;
                                } else {
                                    self.last_command = 'd';
                                }
                                return true;
                            },
                            else => {},
                        },
                        .arrow_left => {
                            self.moveCursorLeft();
                            return true;
                        },
                        .arrow_right => {
                            self.moveCursorRight();
                            return true;
                        },
                        .arrow_up => {
                            self.moveCursorUp();
                            return true;
                        },
                        .arrow_down => {
                            self.moveCursorDown();
                            return true;
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }
        return false;
    }
    
    pub fn render(self: *NotesPanel, screen: *Screen, bounds: Rect, theme: Theme) !void {
        // Update lines from content
        self.updateLines();
        
        // Fill solid background
        const bg_color = Color{ .r = 20, .g = 40, .b = 30 }; // Dark green background
        var y: u16 = bounds.y;
        while (y < bounds.y + bounds.height) : (y += 1) {
            var x: u16 = bounds.x;
            while (x < bounds.x + bounds.width) : (x += 1) {
                screen.setCell(x, y, .{
                    .char = ' ',
                    .fg = theme.text_primary,
                    .bg = bg_color,
                    .style = .{},
                });
            }
        }
        
        // Draw border
        screen.drawBox(bounds.x, bounds.y, bounds.width, bounds.height,
                      if (self.focused) theme.accent else theme.border, bg_color);
        
        // Title with mode indicator
        const mode_indicator = if (self.insert_mode) " [INSERT]" else " [NORMAL]";
        var title_buf: [32]u8 = undefined;
        const title = std.fmt.bufPrint(&title_buf, " NOTES{s} ", .{mode_indicator}) catch " NOTES ";
        const title_x = bounds.x + (bounds.width - @as(u16, @intCast(title.len))) / 2;
        screen.writeText(title_x, bounds.y, title, theme.text_primary, bg_color, .{ .bold = true });
        
        // Calculate visible area
        const content_y = bounds.y + 1;
        const content_height = if (bounds.height > 3) bounds.height - 3 else 0;
        const content_width = if (bounds.width > 2) bounds.width - 2 else 0;
        
        // Adjust scroll to keep cursor visible
        if (self.cursor_line < self.scroll_offset) {
            self.scroll_offset = self.cursor_line;
        } else if (self.cursor_line >= self.scroll_offset + content_height) {
            self.scroll_offset = self.cursor_line - content_height + 1;
        }
        
        // Render visible lines
        var line_y: usize = 0;
        while (line_y < content_height) : (line_y += 1) {
            const line_idx = self.scroll_offset + line_y;
            if (line_idx >= self.lines.items.len) break;
            
            const line = self.lines.items[line_idx];
            const display_line = if (line.len > content_width) line[0..content_width] else line;
            
            screen.writeText(bounds.x + 1, content_y + @as(u16, @intCast(line_y)), display_line, theme.text_primary, bg_color, .{});
            
            // Show cursor
            if (self.focused and line_idx == self.cursor_line) {
                const cursor_x = @min(self.cursor_col, line.len);
                if (cursor_x <= content_width) {
                    screen.setCell(bounds.x + 1 + @as(u16, @intCast(cursor_x)), content_y + @as(u16, @intCast(line_y)), .{
                        .char = if (cursor_x < line.len) line[cursor_x] else ' ',
                        .fg = bg_color,
                        .bg = if (self.insert_mode) theme.accent else theme.text_primary,
                        .style = .{},
                    });
                }
            }
        }
        
        // Status line
        if (bounds.height > 2) {
            var status_buf: [64]u8 = undefined;
            const status = std.fmt.bufPrint(&status_buf, " Line {d}/{d}, Col {d} ", .{
                self.cursor_line + 1,
                self.lines.items.len,
                self.cursor_col + 1,
            }) catch "";
            
            if (status.len < bounds.width) {
                screen.writeText(bounds.x + bounds.width - @as(u16, @intCast(status.len)), bounds.y + bounds.height - 1, status, theme.text_dim, bg_color, .{});
            }
        }
    }
    
    fn updateLines(self: *NotesPanel) void {
        self.lines.clearRetainingCapacity();
        
        if (self.content.items.len == 0) {
            self.lines.append("") catch {};
            return;
        }
        
        var start: usize = 0;
        for (self.content.items, 0..) |char, i| {
            if (char == '\n') {
                self.lines.append(self.content.items[start..i]) catch {};
                start = i + 1;
            }
        }
        
        // Add last line if doesn't end with newline
        if (start < self.content.items.len or (self.content.items.len > 0 and self.content.items[self.content.items.len - 1] == '\n')) {
            self.lines.append(self.content.items[start..]) catch {};
        }
        
        if (self.lines.items.len == 0) {
            self.lines.append("") catch {};
        }
    }
    
    fn getCursorPosition(self: *NotesPanel) usize {
        var pos: usize = 0;
        for (self.lines.items[0..self.cursor_line]) |line| {
            pos += line.len + 1; // +1 for newline
        }
        pos += @min(self.cursor_col, if (self.cursor_line < self.lines.items.len) self.lines.items[self.cursor_line].len else 0);
        return @min(pos, self.content.items.len);
    }
    
    fn insertChar(self: *NotesPanel, char: u8) !void {
        const pos = self.getCursorPosition();
        try self.content.insert(pos, char);
        
        if (char == '\n') {
            self.cursor_line += 1;
            self.cursor_col = 0;
        } else {
            self.cursor_col += 1;
        }
    }
    
    fn deleteChar(self: *NotesPanel) void {
        if (self.content.items.len == 0) return;
        
        const pos = self.getCursorPosition();
        if (pos == 0) return;
        
        _ = self.content.orderedRemove(pos - 1);
        
        if (self.cursor_col > 0) {
            self.cursor_col -= 1;
        } else if (self.cursor_line > 0) {
            self.cursor_line -= 1;
            self.updateLines();
            if (self.cursor_line < self.lines.items.len) {
                self.cursor_col = self.lines.items[self.cursor_line].len;
            }
        }
    }
    
    fn moveCursorLeft(self: *NotesPanel) void {
        if (self.cursor_col > 0) {
            self.cursor_col -= 1;
        } else if (self.cursor_line > 0) {
            self.cursor_line -= 1;
            if (self.cursor_line < self.lines.items.len) {
                self.cursor_col = self.lines.items[self.cursor_line].len;
            }
        }
    }
    
    fn moveCursorRight(self: *NotesPanel) void {
        if (self.cursor_line < self.lines.items.len) {
            const line_len = self.lines.items[self.cursor_line].len;
            if (self.cursor_col < line_len) {
                self.cursor_col += 1;
            } else if (self.cursor_line < self.lines.items.len - 1) {
                self.cursor_line += 1;
                self.cursor_col = 0;
            }
        }
    }
    
    fn moveCursorUp(self: *NotesPanel) void {
        if (self.cursor_line > 0) {
            self.cursor_line -= 1;
            if (self.cursor_line < self.lines.items.len) {
                self.cursor_col = @min(self.cursor_col, self.lines.items[self.cursor_line].len);
            }
        }
    }
    
    fn moveCursorDown(self: *NotesPanel) void {
        if (self.cursor_line < self.lines.items.len - 1) {
            self.cursor_line += 1;
            if (self.cursor_line < self.lines.items.len) {
                self.cursor_col = @min(self.cursor_col, self.lines.items[self.cursor_line].len);
            }
        }
    }
    
    fn moveToEndOfWord(self: *NotesPanel) void {
        if (self.cursor_line >= self.lines.items.len) return;
        const line = self.lines.items[self.cursor_line];
        
        // Skip current word
        while (self.cursor_col < line.len and line[self.cursor_col] != ' ') {
            self.cursor_col += 1;
        }
        
        // Skip spaces
        while (self.cursor_col < line.len and line[self.cursor_col] == ' ') {
            self.cursor_col += 1;
        }
        
        // Move to end of next word
        while (self.cursor_col < line.len and line[self.cursor_col] != ' ') {
            self.cursor_col += 1;
        }
        
        // Go back one character to be on the last char of the word
        if (self.cursor_col > 0 and (self.cursor_col == line.len or line[self.cursor_col] == ' ')) {
            self.cursor_col -= 1;
        }
    }
    
    fn moveToBeginningOfWord(self: *NotesPanel) void {
        if (self.cursor_line >= self.lines.items.len) return;
        const line = self.lines.items[self.cursor_line];
        
        if (self.cursor_col == 0) {
            // Move to previous line
            if (self.cursor_line > 0) {
                self.cursor_line -= 1;
                self.cursor_col = if (self.cursor_line < self.lines.items.len) self.lines.items[self.cursor_line].len else 0;
            }
            return;
        }
        
        // Move back to start of current word or previous word
        self.cursor_col -= 1;
        
        // Skip spaces backwards
        while (self.cursor_col > 0 and line[self.cursor_col] == ' ') {
            self.cursor_col -= 1;
        }
        
        // Move to beginning of word
        while (self.cursor_col > 0 and line[self.cursor_col - 1] != ' ') {
            self.cursor_col -= 1;
        }
    }
    
    fn deleteLine(self: *NotesPanel) void {
        if (self.lines.items.len == 0) return;
        
        // Calculate start and end positions in content
        var start_pos: usize = 0;
        for (self.lines.items[0..self.cursor_line]) |line| {
            start_pos += line.len + 1; // +1 for newline
        }
        
        var end_pos = start_pos;
        if (self.cursor_line < self.lines.items.len) {
            end_pos += self.lines.items[self.cursor_line].len;
            if (self.cursor_line < self.lines.items.len - 1) {
                end_pos += 1; // Include the newline
            }
        }
        
        // Remove the line from content
        if (end_pos > start_pos) {
            var i = end_pos;
            while (i > start_pos) : (i -= 1) {
                _ = self.content.orderedRemove(start_pos);
            }
        }
        
        // Adjust cursor
        if (self.cursor_line >= self.lines.items.len - 1 and self.cursor_line > 0) {
            self.cursor_line -= 1;
        }
        self.cursor_col = 0;
        
        // Update lines
        self.updateLines();
    }
};