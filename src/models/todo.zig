const std = @import("std");

pub const Priority = enum {
    low,
    medium,
    high,
    
    pub fn toString(self: Priority) []const u8 {
        return switch (self) {
            .low => "low",
            .medium => "medium",
            .high => "high",
        };
    }
    
    pub fn fromString(str: []const u8) ?Priority {
        if (std.mem.eql(u8, str, "low")) return .low;
        if (std.mem.eql(u8, str, "medium")) return .medium;
        if (std.mem.eql(u8, str, "high")) return .high;
        return null;
    }
    
    pub fn symbol(self: Priority) []const u8 {
        return switch (self) {
            .low => "○",
            .medium => "◐",
            .high => "◉",
        };
    }
};

pub const Status = enum {
    pending,
    in_progress,
    completed,
    
    pub fn toString(self: Status) []const u8 {
        return switch (self) {
            .pending => "pending",
            .in_progress => "in_progress",
            .completed => "completed",
        };
    }
    
    pub fn fromString(str: []const u8) ?Status {
        if (std.mem.eql(u8, str, "pending")) return .pending;
        if (std.mem.eql(u8, str, "in_progress")) return .in_progress;
        if (std.mem.eql(u8, str, "completed")) return .completed;
        return null;
    }
};

pub const Todo = struct {
    allocator: std.mem.Allocator,
    id: []u8,
    title: []u8,
    description: []u8,
    priority: Priority = .medium,
    status: Status = .pending,
    tags: std.ArrayList([]u8),
    due_date: ?i64 = null, // Unix timestamp
    created_at: i64,
    completed_at: ?i64 = null,
    subtasks: std.ArrayList(*Todo),
    
    pub fn create(allocator: std.mem.Allocator, title: []const u8) !*Todo {
        const todo = try allocator.create(Todo);
        errdefer allocator.destroy(todo);
        
        todo.* = Todo{
            .allocator = allocator,
            .id = try generateId(allocator),
            .title = try allocator.dupe(u8, title),
            .description = try allocator.dupe(u8, ""),
            .tags = std.ArrayList([]u8).init(allocator),
            .created_at = std.time.timestamp(),
            .subtasks = std.ArrayList(*Todo).init(allocator),
        };
        
        return todo;
    }
    
    pub fn deinit(self: *Todo) void {
        self.allocator.free(self.id);
        self.allocator.free(self.title);
        self.allocator.free(self.description);
        
        for (self.tags.items) |tag| {
            self.allocator.free(tag);
        }
        self.tags.deinit();
        
        for (self.subtasks.items) |subtask| {
            subtask.deinit();
            self.allocator.destroy(subtask);
        }
        self.subtasks.deinit();
    }
    
    pub fn addTag(self: *Todo, tag: []const u8) !void {
        const tag_copy = try self.allocator.dupe(u8, tag);
        try self.tags.append(tag_copy);
    }
    
    pub fn removeTag(self: *Todo, tag: []const u8) void {
        var i: usize = 0;
        while (i < self.tags.items.len) {
            if (std.mem.eql(u8, self.tags.items[i], tag)) {
                self.allocator.free(self.tags.items[i]);
                _ = self.tags.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }
    
    pub fn addSubtask(self: *Todo, title: []const u8) !*Todo {
        const subtask = try Todo.create(self.allocator, title);
        try self.subtasks.append(subtask);
        return subtask;
    }
    
    pub fn toggleComplete(self: *Todo) void {
        if (self.status == .completed) {
            self.status = .pending;
            self.completed_at = null;
        } else {
            self.status = .completed;
            self.completed_at = std.time.timestamp();
        }
    }
    
    pub fn isOverdue(self: *const Todo) bool {
        if (self.due_date) |due| {
            return due < std.time.timestamp() and self.status != .completed;
        }
        return false;
    }
    
    fn generateId(allocator: std.mem.Allocator) ![]u8 {
        var buf: [16]u8 = undefined;
        // Use nanoTimestamp for better randomness
        var prng = std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
        prng.random().bytes(&buf);
        
        const hex = "0123456789abcdef";
        var id = try allocator.alloc(u8, 32);
        for (buf, 0..) |byte, i| {
            id[i * 2] = hex[byte >> 4];
            id[i * 2 + 1] = hex[byte & 0x0F];
        }
        return id;
    }
};

pub const TodoList = struct {
    allocator: std.mem.Allocator,
    todos: std.ArrayList(*Todo),
    
    pub fn init(allocator: std.mem.Allocator) TodoList {
        return .{
            .allocator = allocator,
            .todos = std.ArrayList(*Todo).init(allocator),
        };
    }
    
    pub fn deinit(self: *TodoList) void {
        for (self.todos.items) |todo| {
            todo.deinit();
            self.allocator.destroy(todo);
        }
        self.todos.deinit();
    }
    
    pub fn add(self: *TodoList, title: []const u8) !*Todo {
        const todo = try Todo.create(self.allocator, title);
        try self.todos.append(todo);
        return todo;
    }
    
    pub fn remove(self: *TodoList, id: []const u8) bool {
        for (self.todos.items, 0..) |todo, i| {
            if (std.mem.eql(u8, todo.id, id)) {
                todo.deinit();
                self.allocator.destroy(todo);
                _ = self.todos.swapRemove(i);
                return true;
            }
        }
        return false;
    }
    
    pub fn findById(self: *TodoList, id: []const u8) ?*Todo {
        for (self.todos.items) |todo| {
            if (std.mem.eql(u8, todo.id, id)) return todo;
        }
        return null;
    }
    
    pub fn sortByPriority(self: *TodoList) void {
        std.mem.sort(*Todo, self.todos.items, {}, struct {
            fn lessThan(_: void, a: *Todo, b: *Todo) bool {
                const a_pri = @intFromEnum(a.priority);
                const b_pri = @intFromEnum(b.priority);
                if (a_pri != b_pri) return a_pri > b_pri; // High priority first
                return a.created_at < b.created_at;
            }
        }.lessThan);
    }
    
    pub fn filterByTag(self: *TodoList, tag: []const u8, result: *std.ArrayList(*Todo)) !void {
        for (self.todos.items) |todo| {
            for (todo.tags.items) |t| {
                if (std.mem.eql(u8, t, tag)) {
                    try result.append(todo);
                    break;
                }
            }
        }
    }
    
    pub fn filterByStatus(self: *TodoList, status: Status, result: *std.ArrayList(*Todo)) !void {
        for (self.todos.items) |todo| {
            if (todo.status == status) {
                try result.append(todo);
            }
        }
    }
};