const std = @import("std");
const Screen = @import("terminal/screen.zig").Screen;
const Color = @import("terminal/screen.zig").Color;
const ansi = @import("terminal/ansi.zig");
const RawMode = @import("terminal/raw_mode.zig").RawMode;
const InputReader = @import("terminal/input.zig").InputReader;
const Event = @import("terminal/input.zig").Event;
const Key = @import("terminal/input.zig").Key;
const Layout = @import("ui/layout.zig").Layout;
const Rect = @import("ui/layout.zig").Rect;
const Theme = @import("ui/theme.zig").Theme;
const TodoPanel = @import("panels/todo.zig").TodoPanel;
const PatrickPanel = @import("panels/patrick.zig").PatrickPanel;
const PomodoroPanel = @import("panels/pomodoro.zig").PomodoroPanel;
const NotesPanel = @import("panels/notes.zig").NotesPanel;

pub const Dashboard = struct {
    allocator: std.mem.Allocator,
    screen: Screen,
    raw_mode: RawMode,
    input_reader: InputReader,
    layout: Layout,
    theme: Theme,
    running: bool = true,
    
    // Panels
    todo_panel: TodoPanel,
    patrick_panel: PatrickPanel,
    pomodoro_panel: PomodoroPanel,
    notes_panel: NotesPanel,
    
    // State
    active_panel: []const u8 = "todo",
    show_help: bool = false,
    
    pub fn init(allocator: std.mem.Allocator) !Dashboard {
        const raw_mode = try RawMode.enable();
        errdefer raw_mode.disable();
        
        var screen = try Screen.init(allocator);
        errdefer screen.deinit();
        
        var layout = try Layout.init(allocator);
        errdefer layout.deinit();
        
        // Create a 4-panel layout:
        // First split horizontally to create top and bottom rows
        try layout.splitPanel("todo", .horizontal, "bottom_row", 0.6);
        // Split the top row (todo) vertically
        try layout.splitPanel("todo", .vertical, "patrick", 0.7);
        // Split the bottom row into notes and pomodoro
        // When we split "bottom_row" vertically with ratio 0.5:
        // - The left 50% remains as "bottom_row" 
        // - The right 50% becomes "pomodoro"
        try layout.splitPanel("bottom_row", .vertical, "pomodoro", 0.5);
        
        // So we need to create a notes panel that references "bottom_row"
        // Since bottom_row is now the left half of the bottom section
        
        var todo_panel = try TodoPanel.init(allocator);
        errdefer todo_panel.deinit();
        todo_panel.focused = true;
        
        var patrick_panel = try PatrickPanel.init(allocator);
        errdefer patrick_panel.deinit();
        
        var pomodoro_panel = try PomodoroPanel.init(allocator);
        errdefer pomodoro_panel.deinit();
        
        var notes_panel = try NotesPanel.init(allocator);
        errdefer notes_panel.deinit();
        
        return Dashboard{
            .allocator = allocator,
            .screen = screen,
            .raw_mode = raw_mode,
            .input_reader = InputReader.init(),
            .layout = layout,
            .theme = Theme.cyberpunk,
            .todo_panel = todo_panel,
            .patrick_panel = patrick_panel,
            .pomodoro_panel = pomodoro_panel,
            .notes_panel = notes_panel,
        };
    }
    
    pub fn deinit(self: *Dashboard) void {
        self.todo_panel.deinit();
        self.patrick_panel.deinit();
        self.pomodoro_panel.deinit();
        self.notes_panel.deinit();
        self.layout.deinit();
        self.screen.deinit();
        self.raw_mode.disable();
    }
    
    pub fn run(self: *Dashboard) !void {
        const stdout = std.io.getStdOut().writer();
        
        // Setup terminal
        try ansi.enterAlternateScreen(stdout);
        defer ansi.exitAlternateScreen(stdout) catch {};
        
        try ansi.hideCursor(stdout);
        defer ansi.showCursor(stdout) catch {};
        
        try ansi.enableMouse(stdout);
        defer ansi.disableMouse(stdout) catch {};
        
        // Initial render
        try self.render();
        
        // Main loop
        while (self.running) {
            // Handle events
            if (try self.input_reader.readEvent()) |event| {
                try self.handleEvent(event);
            }
            
            // Check for resize
            const new_size = try ansi.getTerminalSize();
            if (new_size.width != self.screen.width or new_size.height != self.screen.height) {
                try self.screen.resize();
            }
            
            // Render
            try self.render();
            
            // Small delay to prevent high CPU usage
            std.time.sleep(16 * std.time.ns_per_ms); // ~60 FPS
        }
    }
    
    fn handleEvent(self: *Dashboard, event: Event) !void {
        // Global shortcuts
        switch (event) {
            .key => |key| {
                if (self.show_help) {
                    self.show_help = false;
                    return;
                }
                
                switch (key) {
                    .char => |c| switch (c) {
                        'q' => {
                            self.running = false;
                            return;
                        },
                        '?' => {
                            self.show_help = true;
                            return;
                        },
                        else => {},
                    },
                    .tab => {
                        self.focusNextPanel();
                        return;
                    },
                    else => {},
                }
            },
            else => {},
        }
        
        // Route to active panel
        if (std.mem.eql(u8, self.active_panel, "todo")) {
            _ = try self.todo_panel.handleEvent(event);
        } else if (std.mem.eql(u8, self.active_panel, "patrick")) {
            _ = try self.patrick_panel.handleEvent(event);
        } else if (std.mem.eql(u8, self.active_panel, "pomodoro")) {
            _ = try self.pomodoro_panel.handleEvent(event);
        } else if (std.mem.eql(u8, self.active_panel, "notes")) {
            _ = try self.notes_panel.handleEvent(event);
        }
    }
    
    fn render(self: *Dashboard) !void {
        const stdout = std.io.getStdOut().writer();
        
        // Clear screen
        self.screen.clear();
        
        // Calculate layout
        const screen_bounds = Rect{
            .x = 0,
            .y = 0,
            .width = self.screen.width,
            .height = self.screen.height,
        };
        
        // Draw header
        self.renderHeader(screen_bounds);
        
        // Draw panels with adjusted bounds
        const content_bounds = Rect{
            .x = 0,
            .y = 2,
            .width = screen_bounds.width,
            .height = screen_bounds.height - 4, // Header + footer
        };
        
        // Use layout system to render panels
        self.layout.calculate(content_bounds);
        
        // Render todo panel
        if (self.layout.getPanelRect("todo", content_bounds)) |todo_bounds| {
            try self.todo_panel.render(&self.screen, todo_bounds, self.theme);
        }
        
        // Render patrick panel
        if (self.layout.getPanelRect("patrick", content_bounds)) |patrick_bounds| {
            try self.patrick_panel.render(&self.screen, patrick_bounds, self.theme);
        }
        
        // Render notes panel (it's called "bottom_row" in the layout)
        if (self.layout.getPanelRect("bottom_row", content_bounds)) |notes_bounds| {
            try self.notes_panel.render(&self.screen, notes_bounds, self.theme);
        }
        
        // Render pomodoro panel
        if (self.layout.getPanelRect("pomodoro", content_bounds)) |pomodoro_bounds| {
            try self.pomodoro_panel.render(&self.screen, pomodoro_bounds, self.theme);
        }
        
        // Draw footer
        self.renderFooter(Rect{
            .x = 0,
            .y = screen_bounds.height - 2,
            .width = screen_bounds.width,
            .height = 2,
        });
        
        // Draw help overlay if needed
        if (self.show_help) {
            self.renderHelp(screen_bounds);
        }
        
        // Render to terminal
        try self.screen.render(stdout);
    }
    
    fn renderHeader(self: *Dashboard, bounds: Rect) void {
        // Background
        self.screen.fillRect(0, 0, bounds.width, 2, self.theme.bg);
        
        // Title
        const title = "🚀 PERSONAL DASHBOARD";
        self.screen.writeText(2, 0, title, self.theme.accent, self.theme.bg, .{ .bold = true });
        
        // Date/time
        const timestamp = std.time.timestamp();
        const epoch_seconds = @as(u64, @intCast(timestamp));
        const epoch_day = std.time.epoch.EpochDay{ .day = @intCast(epoch_seconds / 86400) };
        const year_day = epoch_day.calculateYearDay();
        const month_day = year_day.calculateMonthDay();
        
        var date_buf: [32]u8 = undefined;
        const date_str = std.fmt.bufPrint(&date_buf, "{d:0>4}-{d:0>2}-{d:0>2}", .{
            year_day.year,
            @intFromEnum(month_day.month),
            month_day.day_index + 1,
        }) catch "????-??-??";
        
        const time_secs = @mod(epoch_seconds, 86400);
        const hours = @divFloor(time_secs, 3600);
        const minutes = @divFloor(@mod(time_secs, 3600), 60);
        const seconds = @mod(time_secs, 60);
        
        var time_buf: [16]u8 = undefined;
        const time_str = std.fmt.bufPrint(&time_buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hours, minutes, seconds }) catch "??:??:??";
        
        var datetime_buf: [64]u8 = undefined;
        const datetime = std.fmt.bufPrint(&datetime_buf, "{s}  {s}", .{ date_str, time_str }) catch "";
        
        if (datetime.len < bounds.width) {
            self.screen.writeText(bounds.width - @as(u16, @intCast(datetime.len)) - 2, 0, datetime, self.theme.text_secondary, self.theme.bg, .{});
        }
        
        // Separator line
        var x: u16 = 0;
        while (x < bounds.width) : (x += 1) {
            self.screen.setCell(x, 1, .{
                .char = '─',
                .fg = self.theme.border,
                .bg = self.theme.bg,
                .style = .{},
            });
        }
    }
    
    fn renderFooter(self: *Dashboard, bounds: Rect) void {
        // Separator line
        var x: u16 = 0;
        while (x < bounds.width) : (x += 1) {
            self.screen.setCell(x, bounds.y, .{
                .char = '─',
                .fg = self.theme.border,
                .bg = self.theme.bg,
                .style = .{},
            });
        }
        
        // Shortcuts
        const shortcuts = "[Tab] Switch Panel  [?] Help  [q] Quit  [s] Settings  [/] Search";
        self.screen.writeText(2, bounds.y + 1, shortcuts, self.theme.text_dim, self.theme.bg, .{});
    }
    
    fn renderHelp(self: *Dashboard, bounds: Rect) void {
        // Calculate help window size
        const help_width: u16 = 60;
        const help_height: u16 = 20;
        const help_x = (bounds.width - help_width) / 2;
        const help_y = (bounds.height - help_height) / 2;
        
        // Draw background overlay
        var y: u16 = help_y;
        while (y < help_y + help_height) : (y += 1) {
            var x: u16 = help_x;
            while (x < help_x + help_width) : (x += 1) {
                if (self.screen.getCell(x, y)) |cell| {
                    cell.bg = Color{ .r = 20, .g = 20, .b = 20 };
                }
            }
        }
        
        // Draw help box
        self.screen.drawBox(help_x, help_y, help_width, help_height, self.theme.accent, Color{ .r = 20, .g = 20, .b = 20 });
        
        // Title
        self.screen.writeText(help_x + (help_width - 4) / 2, help_y, " HELP ", self.theme.accent, Color{ .r = 20, .g = 20, .b = 20 }, .{ .bold = true });
        
        // Help content
        const help_lines = [_][]const u8{
            "GLOBAL SHORTCUTS:",
            "  Tab        - Switch between panels",
            "  ?          - Show this help",
            "  q          - Quit application",
            "",
            "TODO PANEL:",
            "  j/k        - Navigate items",
            "  Space      - Toggle completion",
            "  a          - Add new todo",
            "  Enter      - Edit todo",
            "",
            "NOTES PANEL:",
            "  i          - Insert mode",
            "  Esc        - Normal mode",
            "  hjkl/↑↓←→  - Navigate",
            "",
            "POMODORO:",
            "  Space      - Start/Pause",
            "  r          - Reset timer",
            "  s          - Skip to next",
            "",
            "Press any key to close...",
        };
        
        for (help_lines, 0..) |line, i| {
            self.screen.writeText(help_x + 2, help_y + 2 + @as(u16, @intCast(i)), line, self.theme.text_primary, Color{ .r = 20, .g = 20, .b = 20 }, .{});
        }
    }
    
    fn focusNextPanel(self: *Dashboard) void {
        // Switch focus between panels
        self.layout.focusNext();
        
        // Update panel focus states and active panel
        var panels = std.ArrayList(*Layout.Node).init(self.allocator);
        defer panels.deinit();
        
        self.layout.collectPanels(self.layout.root, &panels) catch return;
        
        // Clear all focus states first
        self.todo_panel.focused = false;
        self.patrick_panel.focused = false;
        self.pomodoro_panel.focused = false;
        self.notes_panel.focused = false;
        
        // Set focus based on layout
        for (panels.items) |node| {
            switch (node.*) {
                .panel => |panel| {
                    if (panel.focused) {
                        if (std.mem.eql(u8, panel.id, "todo")) {
                            self.todo_panel.focused = true;
                            self.active_panel = "todo";
                        } else if (std.mem.eql(u8, panel.id, "patrick")) {
                            self.patrick_panel.focused = true;
                            self.active_panel = "patrick";
                        } else if (std.mem.eql(u8, panel.id, "pomodoro")) {
                            self.pomodoro_panel.focused = true;
                            self.active_panel = "pomodoro";
                        } else if (std.mem.eql(u8, panel.id, "bottom_row")) {
                            self.notes_panel.focused = true;
                            self.active_panel = "notes";
                        }
                    }
                },
                else => {},
            }
        }
    }
};