const std = @import("std");
const Dashboard = @import("dashboard.zig").Dashboard;

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create and run dashboard
    var dashboard = try Dashboard.init(allocator);
    defer dashboard.deinit();
    
    // Add some sample todos for testing
    _ = try dashboard.todo_panel.todos.add("Deploy new feature");
    _ = try dashboard.todo_panel.todos.add("Write unit tests");
    _ = try dashboard.todo_panel.todos.add("Update documentation");
    _ = try dashboard.todo_panel.todos.add("Team meeting @2pm");
    _ = try dashboard.todo_panel.todos.add("Research TUI libraries");
    
    // Set some properties on the todos
    if (dashboard.todo_panel.todos.todos.items.len > 0) {
        dashboard.todo_panel.todos.todos.items[0].priority = .high;
        dashboard.todo_panel.todos.todos.items[0].status = .in_progress;
        
        dashboard.todo_panel.todos.todos.items[1].priority = .high;
        dashboard.todo_panel.todos.todos.items[1].status = .pending;
        
        dashboard.todo_panel.todos.todos.items[3].priority = .high;
        dashboard.todo_panel.todos.todos.items[3].due_date = std.time.timestamp() + 3600; // 1 hour from now
        
        dashboard.todo_panel.todos.todos.items[4].status = .completed;
        dashboard.todo_panel.todos.todos.items[4].completed_at = std.time.timestamp();
    }
    
    dashboard.todo_panel.todos.sortByPriority();
    
    try dashboard.run();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}