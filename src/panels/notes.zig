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
                                return true;
                            },
                            'h' => {
                                self.moveCursorLeft();
                                return true;
                            },
                            'j' => {
                                self.moveCursorDown();
                                return true;
                            },
                            'k' => {
                                self.moveCursorUp();
                                return true;
                            },
                            'l' => {
                                self.moveCursorRight();
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
        
        // Draw border
        screen.drawBox(bounds.x, bounds.y, bounds.width, bounds.height,
                      if (self.focused) theme.accent else theme.border, theme.panel_bg);
        
        // Title with mode indicator
        const mode_indicator = if (self.insert_mode) " [INSERT]" else " [NORMAL]";
        var title_buf: [32]u8 = undefined;
        const title = std.fmt.bufPrint(&title_buf, " NOTES{s} ", .{mode_indicator}) catch " NOTES ";
        const title_x = bounds.x + (bounds.width - @as(u16, @intCast(title.len))) / 2;
        screen.writeText(title_x, bounds.y, title, theme.text_primary, theme.panel_bg, .{ .bold = true });
        
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
        var y: usize = 0;
        while (y < content_height) : (y += 1) {
            const line_idx = self.scroll_offset + y;
            if (line_idx >= self.lines.items.len) break;
            
            const line = self.lines.items[line_idx];
            const display_line = if (line.len > content_width) line[0..content_width] else line;
            
            screen.writeText(bounds.x + 1, content_y + @as(u16, @intCast(y)), display_line, theme.text_primary, theme.panel_bg, .{});
            
            // Show cursor
            if (self.focused and line_idx == self.cursor_line) {
                const cursor_x = @min(self.cursor_col, line.len);
                if (cursor_x <= content_width) {
                    screen.setCell(bounds.x + 1 + @as(u16, @intCast(cursor_x)), content_y + @as(u16, @intCast(y)), .{
                        .char = if (cursor_x < line.len) line[cursor_x] else ' ',
                        .fg = theme.panel_bg,
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
                screen.writeText(bounds.x + bounds.width - @as(u16, @intCast(status.len)), bounds.y + bounds.height - 1, status, theme.text_dim, theme.panel_bg, .{});
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
};