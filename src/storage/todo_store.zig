const std = @import("std");
const Todo = @import("../models/todo.zig").Todo;
const TodoList = @import("../models/todo.zig").TodoList;
const Priority = @import("../models/todo.zig").Priority;
const Status = @import("../models/todo.zig").Status;
const json = @import("json.zig");

pub const TodoStore = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    
    pub fn init(allocator: std.mem.Allocator) !TodoStore {
        const home = std.posix.getenv("HOME") orelse "/tmp";
        const config_dir = try std.fs.path.join(allocator, &[_][]const u8{ home, ".config", "tui-dashboard" });
        defer allocator.free(config_dir);
        
        // Create config directory if it doesn't exist
        std.fs.makeDirAbsolute(config_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        
        const path = try std.fs.path.join(allocator, &[_][]const u8{ config_dir, "todos.json" });
        
        return TodoStore{
            .allocator = allocator,
            .path = path,
        };
    }
    
    pub fn deinit(self: *TodoStore) void {
        self.allocator.free(self.path);
    }
    
    pub fn save(self: *TodoStore, todo_list: *TodoList) !void {
        // Create JSON structure
        var root = json.JsonValue{ .object = std.StringHashMap(json.JsonValue).init(self.allocator) };
        defer root.deinit(self.allocator);
        
        // Add version
        try root.object.put(try self.allocator.dupe(u8, "version"), json.JsonValue{ .string = try self.allocator.dupe(u8, "1.0") });
        
        // Create todos array
        var todos_array = std.ArrayList(json.JsonValue).init(self.allocator);
        
        for (todo_list.todos.items) |todo| {
            var todo_obj = std.StringHashMap(json.JsonValue).init(self.allocator);
            
            // Add todo fields
            try todo_obj.put(try self.allocator.dupe(u8, "id"), json.JsonValue{ .string = try self.allocator.dupe(u8, todo.id) });
            try todo_obj.put(try self.allocator.dupe(u8, "title"), json.JsonValue{ .string = try self.allocator.dupe(u8, todo.title) });
            try todo_obj.put(try self.allocator.dupe(u8, "description"), json.JsonValue{ .string = try self.allocator.dupe(u8, todo.description) });
            try todo_obj.put(try self.allocator.dupe(u8, "priority"), json.JsonValue{ .string = try self.allocator.dupe(u8, todo.priority.toString()) });
            try todo_obj.put(try self.allocator.dupe(u8, "status"), json.JsonValue{ .string = try self.allocator.dupe(u8, todo.status.toString()) });
            try todo_obj.put(try self.allocator.dupe(u8, "created_at"), json.JsonValue{ .number = @floatFromInt(todo.created_at) });
            
            // Add optional fields
            if (todo.due_date) |due| {
                try todo_obj.put(try self.allocator.dupe(u8, "due_date"), json.JsonValue{ .number = @floatFromInt(due) });
            } else {
                try todo_obj.put(try self.allocator.dupe(u8, "due_date"), json.JsonValue.null);
            }
            
            if (todo.completed_at) |completed| {
                try todo_obj.put(try self.allocator.dupe(u8, "completed_at"), json.JsonValue{ .number = @floatFromInt(completed) });
            } else {
                try todo_obj.put(try self.allocator.dupe(u8, "completed_at"), json.JsonValue.null);
            }
            
            // Add tags array
            var tags_array = std.ArrayList(json.JsonValue).init(self.allocator);
            for (todo.tags.items) |tag| {
                try tags_array.append(json.JsonValue{ .string = try self.allocator.dupe(u8, tag) });
            }
            try todo_obj.put(try self.allocator.dupe(u8, "tags"), json.JsonValue{ .array = tags_array });
            
            // Add subtasks array (simplified for now - just IDs)
            var subtasks_array = std.ArrayList(json.JsonValue).init(self.allocator);
            for (todo.subtasks.items) |subtask| {
                var subtask_obj = std.StringHashMap(json.JsonValue).init(self.allocator);
                try subtask_obj.put(try self.allocator.dupe(u8, "id"), json.JsonValue{ .string = try self.allocator.dupe(u8, subtask.id) });
                try subtask_obj.put(try self.allocator.dupe(u8, "title"), json.JsonValue{ .string = try self.allocator.dupe(u8, subtask.title) });
                try subtask_obj.put(try self.allocator.dupe(u8, "status"), json.JsonValue{ .string = try self.allocator.dupe(u8, subtask.status.toString()) });
                try subtasks_array.append(json.JsonValue{ .object = subtask_obj });
            }
            try todo_obj.put(try self.allocator.dupe(u8, "subtasks"), json.JsonValue{ .array = subtasks_array });
            
            try todos_array.append(json.JsonValue{ .object = todo_obj });
        }
        
        try root.object.put(try self.allocator.dupe(u8, "todos"), json.JsonValue{ .array = todos_array });
        
        // Stringify JSON
        const json_string = try json.stringify(self.allocator, root);
        defer self.allocator.free(json_string);
        
        // Write to temporary file first
        const temp_path = try std.fmt.allocPrint(self.allocator, "{s}.tmp", .{self.path});
        defer self.allocator.free(temp_path);
        
        const file = try std.fs.createFileAbsolute(temp_path, .{});
        defer file.close();
        
        try file.writeAll(json_string);
        try file.sync();
        
        // Atomic rename
        try std.fs.renameAbsolute(temp_path, self.path);
    }
    
    pub fn load(self: *TodoStore, todo_list: *TodoList) !void {
        // Clear existing todos
        todo_list.deinit();
        todo_list.* = TodoList.init(self.allocator);
        
        // Read file
        const file = std.fs.openFileAbsolute(self.path, .{}) catch |err| switch (err) {
            error.FileNotFound => return, // No todos file yet
            else => return err,
        };
        defer file.close();
        
        const stat = try file.stat();
        const contents = try self.allocator.alloc(u8, stat.size);
        defer self.allocator.free(contents);
        
        _ = try file.read(contents);
        
        // Parse JSON
        var parser = json.Parser.init(self.allocator, contents);
        var root = try parser.parse();
        defer root.deinit(self.allocator);
        
        // Validate structure
        if (root != .object) return error.InvalidFormat;
        
        const todos_value = root.object.get("todos") orelse return error.MissingTodos;
        if (todos_value != .array) return error.InvalidTodosFormat;
        
        // Load todos
        for (todos_value.array.items) |todo_value| {
            if (todo_value != .object) continue;
            
            const todo_obj = todo_value.object;
            
            // Extract required fields
            const title_value = todo_obj.get("title") orelse continue;
            if (title_value != .string) continue;
            
            // Create todo
            const todo = try todo_list.add(title_value.string);
            
            // Load ID if present (replace generated one)
            if (todo_obj.get("id")) |id_value| {
                if (id_value == .string) {
                    self.allocator.free(todo.id);
                    todo.id = try self.allocator.dupe(u8, id_value.string);
                }
            }
            
            // Load description
            if (todo_obj.get("description")) |desc_value| {
                if (desc_value == .string) {
                    self.allocator.free(todo.description);
                    todo.description = try self.allocator.dupe(u8, desc_value.string);
                }
            }
            
            // Load priority
            if (todo_obj.get("priority")) |pri_value| {
                if (pri_value == .string) {
                    if (Priority.fromString(pri_value.string)) |priority| {
                        todo.priority = priority;
                    }
                }
            }
            
            // Load status
            if (todo_obj.get("status")) |status_value| {
                if (status_value == .string) {
                    if (Status.fromString(status_value.string)) |status| {
                        todo.status = status;
                    }
                }
            }
            
            // Load timestamps
            if (todo_obj.get("created_at")) |created_value| {
                if (created_value == .number) {
                    todo.created_at = @intFromFloat(created_value.number);
                }
            }
            
            if (todo_obj.get("due_date")) |due_value| {
                if (due_value == .number) {
                    todo.due_date = @intFromFloat(due_value.number);
                }
            }
            
            if (todo_obj.get("completed_at")) |completed_value| {
                if (completed_value == .number) {
                    todo.completed_at = @intFromFloat(completed_value.number);
                }
            }
            
            // Load tags
            if (todo_obj.get("tags")) |tags_value| {
                if (tags_value == .array) {
                    for (tags_value.array.items) |tag_value| {
                        if (tag_value == .string) {
                            try todo.addTag(tag_value.string);
                        }
                    }
                }
            }
            
            // Load subtasks (simplified - just create new subtasks)
            if (todo_obj.get("subtasks")) |subtasks_value| {
                if (subtasks_value == .array) {
                    for (subtasks_value.array.items) |subtask_value| {
                        if (subtask_value == .object) {
                            if (subtask_value.object.get("title")) |subtask_title| {
                                if (subtask_title == .string) {
                                    const subtask = try todo.addSubtask(subtask_title.string);
                                    
                                    // Load subtask status
                                    if (subtask_value.object.get("status")) |subtask_status| {
                                        if (subtask_status == .string) {
                                            if (Status.fromString(subtask_status.string)) |status| {
                                                subtask.status = status;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Sort by priority after loading
        todo_list.sortByPriority();
    }
};