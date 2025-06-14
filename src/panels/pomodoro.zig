const std = @import("std");
const Screen = @import("../terminal/screen.zig").Screen;
const Color = @import("../terminal/screen.zig").Color;
const Event = @import("../terminal/input.zig").Event;
const Key = @import("../terminal/input.zig").Key;
const Rect = @import("../ui/layout.zig").Rect;
const Theme = @import("../ui/theme.zig").Theme;
const VisualEffects = @import("../ui/visual_effects.zig").VisualEffects;
const Gradient = @import("../ui/visual_effects.zig").Gradient;
const GlowEffect = @import("../ui/visual_effects.zig").GlowEffect;

pub const PomodoroPanel = struct {
    allocator: std.mem.Allocator,
    focused: bool = false,
    state: State = .idle,
    duration: i64 = 25 * 60 * 1000, // 25 minutes in milliseconds
    elapsed: i64 = 0,
    start_time: i64 = 0,
    cycles: u32 = 0,
    
    const State = enum {
        idle,
        work,
        short_break,
        long_break,
    };
    
    pub fn init(allocator: std.mem.Allocator) !PomodoroPanel {
        return PomodoroPanel{
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *PomodoroPanel) void {
        _ = self;
    }
    
    pub fn handleEvent(self: *PomodoroPanel, event: Event) !bool {
        switch (event) {
            .key => |key| switch (key) {
                .char => |c| switch (c) {
                    ' ' => {
                        self.toggleTimer();
                        return true;
                    },
                    'r', 'R' => {
                        self.resetTimer();
                        return true;
                    },
                    's', 'S' => {
                        self.skipTimer();
                        return true;
                    },
                    else => {},
                },
                else => {},
            },
            else => {},
        }
        return false;
    }
    
    pub fn update(self: *PomodoroPanel) void {
        if (self.state == .idle) return;
        
        const now = std.time.milliTimestamp();
        self.elapsed = now - self.start_time;
        
        // Check if timer completed
        if (self.elapsed >= self.duration) {
            self.completeTimer();
        }
    }
    
    pub fn render(self: *PomodoroPanel, screen: *Screen, bounds: Rect, theme: Theme) !void {
        // Update timer
        self.update();
        
        // Render gradient background with timer-based colors
        const progress = if (self.duration > 0) @as(f32, @floatFromInt(self.elapsed)) / @as(f32, @floatFromInt(self.duration)) else 0.0;
        const pomodoro_gradient = Gradient{
            .start_color = Color{ 
                .r = @intFromFloat(50.0 * (1.0 - progress) + 100.0 * progress),
                .g = @intFromFloat(20.0 + 30.0 * progress),
                .b = 60
            },
            .end_color = Color{ .r = 20, .g = 10, .b = 40 },
            .type = .radial,
        };
        VisualEffects.renderGradient(screen, bounds, pomodoro_gradient);
        
        // Add shadow effect
        if (theme.panel_shadow) |shadow| {
            VisualEffects.renderShadow(screen, bounds, shadow);
        }
        
        // Draw border with glow effect
        const border_color = if (self.focused) theme.accent else theme.border;
        if (self.state != .idle and theme.border_glow != null) {
            const glow_intensity = @as(f32, @floatFromInt(@mod(std.time.milliTimestamp(), 2000))) / 2000.0;
            const glow = GlowEffect{
                .color = if (self.state == .work) theme.high_priority else theme.success,
                .intensity = 0.3 + glow_intensity * 0.4,
                .radius = 3,
            };
            VisualEffects.renderGlowBorder(screen, bounds, border_color, glow);
        } else if (self.focused and theme.border_glow != null) {
            VisualEffects.renderGlowBorder(screen, bounds, border_color, theme.border_glow.?);
        } else {
            screen.drawBox(bounds.x, bounds.y, bounds.width, bounds.height, border_color, Color.black);
        }
        
        // Title
        const title = " POMODORO ";
        const title_x = bounds.x + (bounds.width - @as(u16, @intCast(title.len))) / 2;
        const title_color = if (self.state == .work) theme.high_priority else if (self.state != .idle) theme.success else theme.text_primary;
        screen.writeText(title_x, bounds.y, title, title_color, Color.black, .{ .bold = true });
        
        // Timer display
        const remaining = self.duration - self.elapsed;
        const minutes = @divFloor(remaining, 60000);
        const seconds = @divFloor(@mod(remaining, 60000), 1000);
        
        var timer_buf: [16]u8 = undefined;
        const timer_text = std.fmt.bufPrint(&timer_buf, "{d:0>2}:{d:0>2}", .{ minutes, seconds }) catch "??:??";
        
        // Large timer display
        const timer_y = bounds.y + bounds.height / 2 - 1;
        const timer_x = bounds.x + (bounds.width - @as(u16, @intCast(timer_text.len))) / 2;
        
        // Draw timer with larger appearance by using box drawing
        if (bounds.width >= 10 and bounds.height >= 5) {
            // Draw timer background
            var i: u16 = 0;
            while (i < timer_text.len) : (i += 1) {
                screen.setCell(timer_x + i, timer_y, .{
                    .char = timer_text[i],
                    .fg = switch (self.state) {
                        .work => theme.accent,
                        .short_break => theme.success,
                        .long_break => theme.medium_priority,
                        .idle => theme.text_dim,
                    },
                    .bg = Color.black,
                    .style = .{ .bold = true },
                });
            }
        }
        
        // State indicator
        const state_text = switch (self.state) {
            .idle => "⏸  READY",
            .work => "▶  FOCUS TIME",
            .short_break => "☕ SHORT BREAK",
            .long_break => "🌴 LONG BREAK",
        };
        
        const state_x = bounds.x + (bounds.width - @as(u16, @intCast(state_text.len))) / 2;
        screen.writeText(state_x, timer_y + 2, state_text, theme.text_secondary, Color.black, .{});
        
        // Cycle counter
        var cycle_buf: [32]u8 = undefined;
        const cycle_text = std.fmt.bufPrint(&cycle_buf, "Cycles: {d}", .{self.cycles}) catch "Cycles: ?";
        const cycle_x = bounds.x + (bounds.width - @as(u16, @intCast(cycle_text.len))) / 2;
        screen.writeText(cycle_x, timer_y + 3, cycle_text, theme.text_dim, Color.black, .{});
        
        // Progress bar
        if (bounds.height > 8) {
            const bar_progress = if (self.duration > 0)
                @as(f32, @floatFromInt(self.elapsed)) / @as(f32, @floatFromInt(self.duration))
            else 0.0;
            
            const bar_width = @min(bounds.width - 4, 30);
            const bar_x = bounds.x + (bounds.width - bar_width) / 2;
            const bar_y = timer_y - 2;
            
            self.drawProgressBar(screen, bar_x, bar_y, bar_width, bar_progress, theme, Color.black);
        }
        
        // Controls
        if (bounds.height > 10) {
            const controls = "[Space] Start/Pause  [R] Reset  [S] Skip";
            const controls_x = bounds.x + (bounds.width - @as(u16, @intCast(controls.len))) / 2;
            screen.writeText(controls_x, bounds.y + bounds.height - 2, controls, theme.text_dim, Color.black, .{});
        }
    }
    
    fn toggleTimer(self: *PomodoroPanel) void {
        switch (self.state) {
            .idle => {
                self.startWork();
            },
            .work, .short_break, .long_break => {
                // Pause by going to idle but keeping elapsed time
                self.state = .idle;
            },
        }
    }
    
    fn startWork(self: *PomodoroPanel) void {
        self.state = .work;
        self.duration = 25 * 60 * 1000; // 25 minutes
        self.elapsed = 0;
        self.start_time = std.time.milliTimestamp();
    }
    
    fn startShortBreak(self: *PomodoroPanel) void {
        self.state = .short_break;
        self.duration = 5 * 60 * 1000; // 5 minutes
        self.elapsed = 0;
        self.start_time = std.time.milliTimestamp();
    }
    
    fn startLongBreak(self: *PomodoroPanel) void {
        self.state = .long_break;
        self.duration = 15 * 60 * 1000; // 15 minutes
        self.elapsed = 0;
        self.start_time = std.time.milliTimestamp();
    }
    
    fn resetTimer(self: *PomodoroPanel) void {
        self.state = .idle;
        self.elapsed = 0;
        self.cycles = 0;
    }
    
    fn skipTimer(self: *PomodoroPanel) void {
        self.completeTimer();
    }
    
    fn completeTimer(self: *PomodoroPanel) void {
        switch (self.state) {
            .work => {
                self.cycles += 1;
                if (@mod(self.cycles, 4) == 0) {
                    self.startLongBreak();
                } else {
                    self.startShortBreak();
                }
            },
            .short_break, .long_break => {
                self.startWork();
            },
            .idle => {},
        }
    }
    
    fn drawProgressBar(self: *PomodoroPanel, screen: *Screen, x: u16, y: u16, width: u16, progress: f32, theme: Theme, bg: Color) void {
        _ = self;
        
        const filled = @as(u16, @intFromFloat(@as(f32, @floatFromInt(width)) * progress));
        var i: u16 = 0;
        while (i < width) : (i += 1) {
            const char: u21 = if (i < filled) '█' else '░';
            const color = if (i < filled) theme.accent else theme.border;
            screen.setCell(x + i, y, .{
                .char = char,
                .fg = color,
                .bg = bg,
                .style = .{},
            });
        }
    }
};