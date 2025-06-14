const std = @import("std");
const Screen = @import("../terminal/screen.zig").Screen;
const Color = @import("../terminal/screen.zig").Color;
const Event = @import("../terminal/input.zig").Event;
const Rect = @import("../ui/layout.zig").Rect;
const Theme = @import("../ui/theme.zig").Theme;

pub const SystemMonitorPanel = struct {
    allocator: std.mem.Allocator,
    focused: bool = false,
    cpu_usage: f32 = 0.0,
    memory_usage: f32 = 0.0,
    cpu_history: std.ArrayList(f32),
    memory_history: std.ArrayList(f32),
    update_timer: i64 = 0,
    
    pub fn init(allocator: std.mem.Allocator) !SystemMonitorPanel {
        var cpu_history = std.ArrayList(f32).init(allocator);
        var memory_history = std.ArrayList(f32).init(allocator);
        
        // Initialize with some dummy data for now
        var i: usize = 0;
        while (i < 30) : (i += 1) {
            try cpu_history.append(0.0);
            try memory_history.append(0.0);
        }
        
        return SystemMonitorPanel{
            .allocator = allocator,
            .cpu_history = cpu_history,
            .memory_history = memory_history,
        };
    }
    
    pub fn deinit(self: *SystemMonitorPanel) void {
        self.cpu_history.deinit();
        self.memory_history.deinit();
    }
    
    pub fn handleEvent(self: *SystemMonitorPanel, event: Event) !bool {
        _ = self;
        _ = event;
        return false;
    }
    
    pub fn update(self: *SystemMonitorPanel) void {
        const now = std.time.milliTimestamp();
        if (now - self.update_timer < 1000) return; // Update every second
        self.update_timer = now;
        
        // Generate some dummy data for visualization
        const random = std.crypto.random;
        self.cpu_usage = 0.3 + @as(f32, @floatFromInt(random.int(u8))) / 255.0 * 0.4; // 30-70%
        self.memory_usage = 0.5 + @as(f32, @floatFromInt(random.int(u8))) / 255.0 * 0.3; // 50-80%
        
        // Update history
        if (self.cpu_history.items.len >= 30) {
            _ = self.cpu_history.orderedRemove(0);
        }
        self.cpu_history.append(self.cpu_usage) catch {};
        
        if (self.memory_history.items.len >= 30) {
            _ = self.memory_history.orderedRemove(0);
        }
        self.memory_history.append(self.memory_usage) catch {};
    }
    
    pub fn render(self: *SystemMonitorPanel, screen: *Screen, bounds: Rect, theme: Theme) !void {
        // Update stats
        self.update();
        
        // Draw border
        screen.drawBox(bounds.x, bounds.y, bounds.width, bounds.height, 
                      if (self.focused) theme.accent else theme.border, theme.panel_bg);
        
        // Title
        const title = " SYSTEM MONITOR ";
        const title_x = bounds.x + (bounds.width - @as(u16, @intCast(title.len))) / 2;
        screen.writeText(title_x, bounds.y, title, theme.text_primary, theme.panel_bg, .{ .bold = true });
        
        // CPU Usage
        const cpu_label = "CPU:";
        screen.writeText(bounds.x + 2, bounds.y + 2, cpu_label, theme.text_primary, theme.panel_bg, .{});
        self.drawProgressBar(screen, bounds.x + 7, bounds.y + 2, 15, self.cpu_usage, theme);
        
        var cpu_text_buf: [16]u8 = undefined;
        const cpu_text = std.fmt.bufPrint(&cpu_text_buf, "{d:>3.0}%", .{self.cpu_usage * 100}) catch "???%";
        screen.writeText(bounds.x + 23, bounds.y + 2, cpu_text, theme.text_primary, theme.panel_bg, .{});
        
        // Memory Usage
        const mem_label = "MEM:";
        screen.writeText(bounds.x + 2, bounds.y + 3, mem_label, theme.text_primary, theme.panel_bg, .{});
        self.drawProgressBar(screen, bounds.x + 7, bounds.y + 3, 15, self.memory_usage, theme);
        
        var mem_text_buf: [16]u8 = undefined;
        const mem_text = std.fmt.bufPrint(&mem_text_buf, "{d:>3.0}%", .{self.memory_usage * 100}) catch "???%";
        screen.writeText(bounds.x + 23, bounds.y + 3, mem_text, theme.text_primary, theme.panel_bg, .{});
        
        // Draw graphs
        if (bounds.height > 10) {
            const graph_y = bounds.y + 5;
            const graph_height = @min(bounds.height - 8, 10);
            const graph_width = bounds.width - 4;
            
            screen.writeText(bounds.x + 2, graph_y, "CPU History:", theme.text_secondary, theme.panel_bg, .{});
            self.drawGraph(screen, bounds.x + 2, graph_y + 1, graph_width, graph_height / 2, self.cpu_history.items, theme, theme.accent);
            
            screen.writeText(bounds.x + 2, graph_y + graph_height / 2 + 2, "Memory History:", theme.text_secondary, theme.panel_bg, .{});
            self.drawGraph(screen, bounds.x + 2, graph_y + graph_height / 2 + 3, graph_width, graph_height / 2, self.memory_history.items, theme, theme.high_priority);
        }
    }
    
    fn drawProgressBar(self: *SystemMonitorPanel, screen: *Screen, x: u16, y: u16, width: u16, value: f32, theme: Theme) void {
        _ = self;
        
        const filled = @as(u16, @intFromFloat(@as(f32, @floatFromInt(width)) * value));
        var i: u16 = 0;
        while (i < width) : (i += 1) {
            const char: u21 = if (i < filled) '▇' else '▁';
            const color = if (i < filled) theme.accent else theme.border;
            screen.setCell(x + i, y, .{
                .char = char,
                .fg = color,
                .bg = theme.panel_bg,
                .style = .{},
            });
        }
    }
    
    fn drawGraph(self: *SystemMonitorPanel, screen: *Screen, x: u16, y: u16, width: u16, height: u16, data: []const f32, theme: Theme, color: Color) void {
        _ = self;
        
        if (data.len == 0 or height == 0) return;
        
        // Draw graph background
        var dy: u16 = 0;
        while (dy < height) : (dy += 1) {
            var dx: u16 = 0;
            while (dx < width) : (dx += 1) {
                screen.setCell(x + dx, y + dy, .{
                    .char = '·',
                    .fg = theme.border,
                    .bg = theme.panel_bg,
                    .style = .{},
                });
            }
        }
        
        // Draw data points
        const step = @max(1, data.len / width);
        var i: usize = 0;
        var gx: u16 = 0;
        while (i < data.len and gx < width) : (i += step) {
            const value = data[i];
            const bar_height = @as(u16, @intFromFloat(value * @as(f32, @floatFromInt(height))));
            
            var gy: u16 = 0;
            while (gy < bar_height and gy < height) : (gy += 1) {
                const plot_y = y + height - 1 - gy;
                screen.setCell(x + gx, plot_y, .{
                    .char = '█',
                    .fg = color,
                    .bg = theme.panel_bg,
                    .style = .{},
                });
            }
            gx += 1;
        }
    }
};