const std = @import("std");
const Screen = @import("../terminal/screen.zig").Screen;
const Color = @import("../terminal/screen.zig").Color;
const Event = @import("../terminal/input.zig").Event;
const Rect = @import("../ui/layout.zig").Rect;
const Theme = @import("../ui/theme.zig").Theme;

pub const PatrickPanel = struct {
    allocator: std.mem.Allocator,
    focused: bool = false,
    frame: usize = 0,
    last_update: i64 = 0,
    
    // Original Patrick Star ASCII art
    const patrick_art = [_][]const u8{
        "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠖⠉⠀⢹⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⢀⠀⢠⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⠀⠀⠀⡴⠁⠀⠀⠀⠀⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⠀⣀⣼⡇⢀⣤⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⢀⣽⠉⠀⠘⠻⠟⠀⢠⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
        "⡠⠤⣄⠀⠀⠀⢀⡞⠉⡈⡱⠮⠉⠙⡄⠀⠈⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀",
        "⣇⠀⠀⠙⢦⡀⣾⠀⠼⣿⠃⢼⡧⠄⡄⠀⠀⡇⠀⠀⠀⠀⠀⣠⠖⠊⣣",
        "⠹⡆⠀⠀⠀⠉⢸⢦⣀⡰⢧⣀⣀⡴⡁⠀⠀⣷⠀⠀⢀⡠⠖⠉⠀⠀⢰⠇",
        "⠀⠹⡄⠀⠀⠀⠏⣄⡀⠀⠀⣀⣠⣤⣿⠓⠀⠸⡀⣠⠔⠋⠀⠀⠀⣰⠃⠀",
        "⠀⠀⠙⡄⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⡏⠀⠀⡠⠟⠁⠀⠀⠀⢀⡞⠁⠀⠀",
        "⠀⠀⠀⠘⣆⠀⠠⣤⣿⠟⠛⠟⢋⡽⠋⠀⠀⠈⠀⠀⠀⠀⡰⠋⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠈⢦⠀⠈⠙⠓⠒⠉⠁⠀⠀⠀⠀⠀⠀⠀⢠⠞⠁⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⢀⡟⠀⠀⠀⠀⠄⠀⠀⠀⠀⠀⠀⠀⣴⠋⠀⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⢀⡏⠀⡤⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠞⠹⡄⠀⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⢸⣆⠀⠀⠀⠀⠀⠀⠀⠁⠀⠀⠀⠀⠀⠀⣧⠀⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⢹⠿⣦⣄⠀⣴⣤⣀⠀⠁⠇⠀⠀⠀⢀⣠⡾⢻⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠸⡄⢹⠛⣿⣬⣉⡁⠀⠀⠂⠀⣀⣠⣴⡾⠟⠉⡎⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⢳⡈⣻⠋⠉⢻⡛⠛⢿⠿⠿⠛⠋⠉⠀⣀⣀⡼⠁⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⠀⣿⢯⡓⠦⠤⠼⠙⠒⠋⠀⠂⠀⠀⡰⠋⢀⡞⠁⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⠸⣇⠀⠈⠓⠦⢤⣀⣀⠀⣀⠀⠂⣠⢍⣾⡏⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⠀⠘⡷⠢⠤⠤⢤⠼⠈⠉⢻⡄⠀⡇⢀⣸⠇⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⠀⠀⠹⣄⠀⢀⡞⠀⠀⠀⠀⠙⣏⠚⠉⢫⠇⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⠀⠀⠀⠈⠓⠋⠀⠀⠀⠀⠀⠀⠘⢦⡀⢀⠞⠀⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣉⣁⠀⠀⠀⠀⠀⠀⠀",
    };
    
    const colors = [_]Color{
        Color{ .r = 255, .g = 192, .b = 203 }, // Pink
        Color{ .r = 255, .g = 182, .b = 193 }, // Light Pink
        Color{ .r = 255, .g = 105, .b = 180 }, // Hot Pink
        Color{ .r = 255, .g = 20, .b = 147 },  // Deep Pink
        Color{ .r = 219, .g = 112, .b = 147 }, // Pale Violet Red
    };
    
    pub fn init(allocator: std.mem.Allocator) !PatrickPanel {
        return PatrickPanel{
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *PatrickPanel) void {
        _ = self;
    }
    
    pub fn handleEvent(self: *PatrickPanel, event: Event) !bool {
        _ = self;
        _ = event;
        return false;
    }
    
    pub fn update(self: *PatrickPanel) void {
        const now = std.time.milliTimestamp();
        if (now - self.last_update < 500) return; // Update every 500ms for animation
        self.last_update = now;
        self.frame = (self.frame + 1) % colors.len;
    }
    
    pub fn render(self: *PatrickPanel, screen: *Screen, bounds: Rect, theme: Theme) !void {
        // Update animation
        self.update();
        
        // Define background color
        const bg_color = Color{ .r = 40, .g = 20, .b = 40 }; // Purple background
        
        // Fill solid background
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
                      if (self.focused) theme.accent else theme.border, 
                      bg_color);
        
        // Title
        const title = " PATRICK STAR ";
        const title_x = bounds.x + (bounds.width - @as(u16, @intCast(title.len))) / 2;
        screen.writeText(title_x, bounds.y, title, theme.text_primary, bg_color, .{ .bold = true });
        
        // Calculate center position for Patrick
        const art_height = patrick_art.len;
        // Calculate visual width by counting Unicode codepoints
        var art_width: u16 = 0;
        var iter = (try std.unicode.Utf8View.init(patrick_art[0])).iterator();
        while (iter.nextCodepoint()) |_| {
            art_width += 1;
        }
        
        // Show as much of Patrick as fits in the panel
        const content_height = if (bounds.height > 2) bounds.height - 2 else 0;
        const content_width = if (bounds.width > 2) bounds.width - 2 else 0;
        
        // Center Patrick in the panel, or show top-left if too big
        const start_y = if (art_height < content_height) 
            bounds.y + 1 + (content_height - @as(u16, @intCast(art_height))) / 2
        else 
            bounds.y + 1;
            
        const start_x = if (art_width < content_width)
            bounds.x + 1 + (content_width - @as(u16, @intCast(art_width))) / 2
        else
            bounds.x + 1;
        
        // Draw Patrick with animated colors, clipping to panel bounds
        for (patrick_art, 0..) |line, i| {
            const line_y = start_y + @as(u16, @intCast(i));
            
            // Skip lines outside panel
            if (line_y < bounds.y + 1) continue;
            if (line_y >= bounds.y + bounds.height - 1) break;
            
            // Use UTF-8 iterator to properly handle Unicode characters
            var utf8_iter = (try std.unicode.Utf8View.init(line)).iterator();
            var visual_col: u16 = 0;
            
            while (utf8_iter.nextCodepoint()) |codepoint| {
                const char_x = start_x + visual_col;
                
                // Skip characters outside panel
                if (char_x >= bounds.x + 1 and char_x < bounds.x + bounds.width - 1 and
                    line_y >= bounds.y + 1 and line_y < bounds.y + bounds.height - 1) {
                    if (codepoint != ' ') {
                        const color = colors[(self.frame + i) % colors.len];
                        screen.setCell(char_x, line_y, .{
                            .char = codepoint,
                            .fg = color,
                            .bg = bg_color,
                            .style = .{},
                        });
                    }
                }
                visual_col += 1;
            }
        }
        
        // Add a small message at the bottom if there's room
        const messages = [_][]const u8{
            "Is mayonnaise an instrument?",
            "I can't see my forehead!",
            "Finland!",
            "I love you",
        };
        if (bounds.height > art_height + 3) {
            const message = messages[self.frame % messages.len];
            const msg_x = bounds.x + (bounds.width - @as(u16, @intCast(message.len))) / 2;
            const msg_y = bounds.y + bounds.height - 2;
            screen.writeText(msg_x, msg_y, message, colors[self.frame], bg_color, .{ .italic = true });
        }
    }
};