const std = @import("std");
const Screen = @import("../terminal/screen.zig").Screen;
const Color = @import("../terminal/screen.zig").Color;
const Style = @import("../terminal/screen.zig").Style;
const Rect = @import("../ui/layout.zig").Rect;
const Theme = @import("../ui/theme.zig").Theme;
const Todo = @import("../models/todo.zig").Todo;
const TodoList = @import("../models/todo.zig").TodoList;
const Priority = @import("../models/todo.zig").Priority;
const Status = @import("../models/todo.zig").Status;
const Event = @import("../terminal/input.zig").Event;
const Key = @import("../terminal/input.zig").Key;

pub const TodoPanel = struct {
    allocator: std.mem.Allocator,
    todos: TodoList,
    selected_index: usize = 0,
    scroll_offset: usize = 0,
    input_mode: InputMode = .normal,
    input_buffer: std.ArrayList(u8),
    filter_text: []u8,
    show_completed: bool = true,
    focused: bool = false,
    
    const InputMode = enum {
        normal,
        adding,
        editing,
        filtering,
    };
    
    pub fn init(allocator: std.mem.Allocator) !TodoPanel {
        return TodoPanel{
            .allocator = allocator,
            .todos = TodoList.init(allocator),
            .input_buffer = std.ArrayList(u8).init(allocator),
            .filter_text = try allocator.alloc(u8, 0),
        };
    }
    
    pub fn deinit(self: *TodoPanel) void {
        self.todos.deinit();
        self.input_buffer.deinit();
        self.allocator.free(self.filter_text);
    }
    
    pub fn handleEvent(self: *TodoPanel, event: Event) !bool {
        switch (self.input_mode) {
            .normal => return try self.handleNormalMode(event),
            .adding, .editing => return try self.handleInputMode(event),
            .filtering => return try self.handleFilterMode(event),
        }
    }
    
    fn handleNormalMode(self: *TodoPanel, event: Event) !bool {
        switch (event) {
            .key => |key| switch (key) {
                .char => |c| switch (c) {
                    'j' => {
                        self.moveDown();
                        return true;
                    },
                    'k' => {
                        self.moveUp();
                        return true;
                    },
                    'a' => {
                        self.input_mode = .adding;
                        self.input_buffer.clearAndFree();
                        return true;
                    },
                    'd' => {
                        try self.deleteSelected();
                        return true;
                    },
                    ' ' => {
                        self.toggleSelected();
                        return true;
                    },
                    'p' => {
                        self.cyclePriority();
                        return true;
                    },
                    'f' => {
                        self.input_mode = .filtering;
                        self.input_buffer.clearAndFree();
                        return true;
                    },
                    'c' => {
                        self.show_completed = !self.show_completed;
                        return true;
                    },
                    '1' => {
                        self.setPriority(.high);
                        return true;
                    },
                    '2' => {
                        self.setPriority(.medium);
                        return true;
                    },
                    '3' => {
                        self.setPriority(.low);
                        return true;
                    },
                    else => {},
                },
                .arrow_down => {
                    self.moveDown();
                    return true;
                },
                .arrow_up => {
                    self.moveUp();
                    return true;
                },
                .enter => {
                    if (self.getSelectedTodo()) |_| {
                        self.input_mode = .editing;
                        if (self.getSelectedTodo()) |todo| {
                            self.input_buffer.clearAndFree();
                            try self.input_buffer.appendSlice(todo.title);
                        }
                    }
                    return true;
                },
                else => {},
            },
            else => {},
        }
        return false;
    }
    
    fn handleInputMode(self: *TodoPanel, event: Event) !bool {
        switch (event) {
            .key => |key| switch (key) {
                .escape => {
                    self.input_mode = .normal;
                    self.input_buffer.clearAndFree();
                    return true;
                },
                .enter => {
                    const text = self.input_buffer.items;
                    if (text.len > 0) {
                        switch (self.input_mode) {
                            .adding => {
                                _ = try self.todos.add(text);
                                self.todos.sortByPriority();
                            },
                            .editing => {
                                if (self.getSelectedTodo()) |todo| {
                                    self.allocator.free(todo.title);
                                    todo.title = try self.allocator.dupe(u8, text);
                                }
                            },
                            else => {},
                        }
                    }
                    self.input_mode = .normal;
                    self.input_buffer.clearAndFree();
                    return true;
                },
                .backspace => {
                    if (self.input_buffer.items.len > 0) {
                        _ = self.input_buffer.pop();
                    }
                    return true;
                },
                .char => |c| {
                    if (c >= 32 and c < 127) {
                        try self.input_buffer.append(@intCast(c));
                    }
                    return true;
                },
                else => {},
            },
            else => {},
        }
        return false;
    }
    
    fn handleFilterMode(self: *TodoPanel, event: Event) !bool {
        switch (event) {
            .key => |key| switch (key) {
                .escape => {
                    self.input_mode = .normal;
                    self.allocator.free(self.filter_text);
                    self.filter_text = try self.allocator.alloc(u8, 0);
                    self.input_buffer.clearAndFree();
                    return true;
                },
                .enter => {
                    self.allocator.free(self.filter_text);
                    self.filter_text = try self.allocator.dupe(u8, self.input_buffer.items);
                    self.input_mode = .normal;
                    self.input_buffer.clearAndFree();
                    return true;
                },
                .backspace => {
                    if (self.input_buffer.items.len > 0) {
                        _ = self.input_buffer.pop();
                    }
                    return true;
                },
                .char => |c| {
                    if (c >= 32 and c < 127) {
                        try self.input_buffer.append(@intCast(c));
                    }
                    return true;
                },
                else => {},
            },
            else => {},
        }
        return false;
    }
    
    pub fn render(self: *TodoPanel, screen: *Screen, bounds: Rect, theme: Theme) !void {
        // Clear background
        screen.fillRect(bounds.x, bounds.y, bounds.width, bounds.height, theme.panel_bg);
        
        // Draw border
        const border_color = if (self.focused) theme.border_active else theme.border;
        screen.drawBox(bounds.x, bounds.y, bounds.width, bounds.height, border_color, theme.panel_bg);
        
        // Draw title
        const title = "TODO LIST";
        const completed_count = blk: {
            var count: usize = 0;
            for (self.todos.todos.items) |todo| {
                if (todo.status == .completed) count += 1;
            }
            break :blk count;
        };
        
        var title_buf: [64]u8 = undefined;
        const title_text = std.fmt.bufPrint(&title_buf, "{s} [{d}/{d}]", .{ title, completed_count, self.todos.todos.items.len }) catch title;
        screen.writeText(bounds.x + 2, bounds.y, title_text, theme.accent, theme.panel_bg, .{ .bold = true });
        
        // Draw todos
        const content_bounds = bounds.shrink(1);
        const visible_height = content_bounds.height - 2; // Account for title and input
        
        // Get filtered todos
        var visible_todos = std.ArrayList(*Todo).init(self.allocator);
        defer visible_todos.deinit();
        
        for (self.todos.todos.items) |todo| {
            if (!self.show_completed and todo.status == .completed) continue;
            if (self.filter_text.len > 0) {
                if (std.mem.indexOf(u8, todo.title, self.filter_text) == null) continue;
            }
            try visible_todos.append(todo);
        }
        
        // Adjust scroll if needed
        if (self.selected_index >= visible_todos.items.len and visible_todos.items.len > 0) {
            self.selected_index = visible_todos.items.len - 1;
        }
        
        if (self.selected_index < self.scroll_offset) {
            self.scroll_offset = self.selected_index;
        } else if (self.selected_index >= self.scroll_offset + visible_height) {
            self.scroll_offset = self.selected_index - visible_height + 1;
        }
        
        // Render visible todos
        var y = content_bounds.y + 1;
        var i = self.scroll_offset;
        while (i < visible_todos.items.len and y < content_bounds.y + content_bounds.height - 1) : ({
            i += 1;
            y += 1;
        }) {
            const todo = visible_todos.items[i];
            const is_selected = i == self.selected_index;
            
            // Background for selected item
            if (is_selected) {
                screen.fillRect(content_bounds.x, y, content_bounds.width, 1, theme.accent_dim);
            }
            
            // Priority symbol
            const priority_color = switch (todo.priority) {
                .high => theme.high_priority,
                .medium => theme.medium_priority,
                .low => theme.low_priority,
            };
            screen.writeText(content_bounds.x + 1, y, todo.priority.symbol(), priority_color, if (is_selected) theme.accent_dim else theme.panel_bg, .{});
            
            // Status indicator
            const status_char: []const u8 = switch (todo.status) {
                .completed => "✓",
                .in_progress => "▸",
                .pending => " ",
            };
            const status_color = if (todo.status == .completed) theme.success else theme.text_primary;
            screen.writeText(content_bounds.x + 3, y, status_char, status_color, if (is_selected) theme.accent_dim else theme.panel_bg, .{});
            
            // Todo title
            const text_color = if (todo.status == .completed) theme.text_dim else theme.text_primary;
            const text_style = Style{ .dim = todo.status == .completed };
            const max_width = content_bounds.width - 6;
            const todo_title = if (todo.title.len > max_width) todo.title[0..max_width] else todo.title;
            screen.writeText(content_bounds.x + 5, y, todo_title, text_color, if (is_selected) theme.accent_dim else theme.panel_bg, text_style);
            
            // Due date indicator if overdue
            if (todo.isOverdue()) {
                const overdue_text = "!";
                screen.writeText(content_bounds.x + content_bounds.width - 2, y, overdue_text, theme.@"error", if (is_selected) theme.accent_dim else theme.panel_bg, .{ .bold = true });
            }
        }
        
        // Draw input line
        const input_y = content_bounds.y + content_bounds.height - 1;
        switch (self.input_mode) {
            .adding => {
                screen.writeText(content_bounds.x + 1, input_y, "[+] ", theme.accent, theme.panel_bg, .{});
                screen.writeText(content_bounds.x + 5, input_y, self.input_buffer.items, theme.text_primary, theme.panel_bg, .{});
                screen.cursor_visible = true;
                screen.cursor_x = content_bounds.x + 5 + @as(u16, @intCast(self.input_buffer.items.len));
                screen.cursor_y = input_y;
            },
            .editing => {
                screen.writeText(content_bounds.x + 1, input_y, "[~] ", theme.accent, theme.panel_bg, .{});
                screen.writeText(content_bounds.x + 5, input_y, self.input_buffer.items, theme.text_primary, theme.panel_bg, .{});
                screen.cursor_visible = true;
                screen.cursor_x = content_bounds.x + 5 + @as(u16, @intCast(self.input_buffer.items.len));
                screen.cursor_y = input_y;
            },
            .filtering => {
                screen.writeText(content_bounds.x + 1, input_y, "[/] ", theme.accent, theme.panel_bg, .{});
                screen.writeText(content_bounds.x + 5, input_y, self.input_buffer.items, theme.text_primary, theme.panel_bg, .{});
                screen.cursor_visible = true;
                screen.cursor_x = content_bounds.x + 5 + @as(u16, @intCast(self.input_buffer.items.len));
                screen.cursor_y = input_y;
            },
            .normal => {
                if (self.filter_text.len > 0) {
                    var filter_buf: [64]u8 = undefined;
                    const filter_display = std.fmt.bufPrint(&filter_buf, "Filter: {s}", .{self.filter_text}) catch "";
                    screen.writeText(content_bounds.x + 1, input_y, filter_display, theme.text_secondary, theme.panel_bg, .{});
                } else {
                    screen.writeText(content_bounds.x + 1, input_y, "[a] Add  [d] Delete  [p] Priority  [f] Filter", theme.text_dim, theme.panel_bg, .{});
                }
            },
        }
    }
    
    fn moveUp(self: *TodoPanel) void {
        if (self.selected_index > 0) {
            self.selected_index -= 1;
        }
    }
    
    fn moveDown(self: *TodoPanel) void {
        const max_index = self.getVisibleCount();
        if (max_index > 0 and self.selected_index < max_index - 1) {
            self.selected_index += 1;
        }
    }
    
    fn getVisibleCount(self: *TodoPanel) usize {
        var count: usize = 0;
        for (self.todos.todos.items) |todo| {
            if (!self.show_completed and todo.status == .completed) continue;
            if (self.filter_text.len > 0) {
                if (std.mem.indexOf(u8, todo.title, self.filter_text) == null) continue;
            }
            count += 1;
        }
        return count;
    }
    
    fn getSelectedTodo(self: *TodoPanel) ?*Todo {
        var visible_index: usize = 0;
        for (self.todos.todos.items) |todo| {
            if (!self.show_completed and todo.status == .completed) continue;
            if (self.filter_text.len > 0) {
                if (std.mem.indexOf(u8, todo.title, self.filter_text) == null) continue;
            }
            if (visible_index == self.selected_index) return todo;
            visible_index += 1;
        }
        return null;
    }
    
    fn toggleSelected(self: *TodoPanel) void {
        if (self.getSelectedTodo()) |todo| {
            todo.toggleComplete();
        }
    }
    
    fn deleteSelected(self: *TodoPanel) !void {
        if (self.getSelectedTodo()) |todo| {
            _ = self.todos.remove(todo.id);
            if (self.selected_index > 0 and self.selected_index >= self.getVisibleCount()) {
                self.selected_index -= 1;
            }
        }
    }
    
    fn cyclePriority(self: *TodoPanel) void {
        if (self.getSelectedTodo()) |todo| {
            todo.priority = switch (todo.priority) {
                .low => .medium,
                .medium => .high,
                .high => .low,
            };
            self.todos.sortByPriority();
        }
    }
    
    fn setPriority(self: *TodoPanel, priority: Priority) void {
        if (self.getSelectedTodo()) |todo| {
            todo.priority = priority;
            self.todos.sortByPriority();
        }
    }
};