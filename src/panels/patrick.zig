const std = @import("std");
const Screen = @import("../terminal/screen.zig").Screen;
const Color = @import("../terminal/screen.zig").Color;
const Event = @import("../terminal/input.zig").Event;
const Rect = @import("../ui/layout.zig").Rect;
const Theme = @import("../ui/theme.zig").Theme;
const VisualEffects = @import("../ui/visual_effects.zig").VisualEffects;
const Gradient = @import("../ui/visual_effects.zig").Gradient;
const GlowEffect = @import("../ui/visual_effects.zig").GlowEffect;

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
        
        // Render gradient background with animated colors
        const patrick_gradient = Gradient{
            .start_color = Color{ 
                .r = @intFromFloat(40.0 + @as(f32, @floatFromInt(self.frame)) * 5.0),
                .g = 10,
                .b = @intFromFloat(50.0 + @as(f32, @floatFromInt(self.frame)) * 8.0)
            },
            .end_color = Color{ .r = 20, .g = 5, .b = 30 },
            .type = .radial,
        };
        VisualEffects.renderGradient(screen, bounds, patrick_gradient);
        
        // Add shadow effect
        if (theme.panel_shadow) |shadow| {
            VisualEffects.renderShadow(screen, bounds, shadow);
        }
        
        // Draw border with glow effect
        const border_color = if (self.focused) theme.accent else theme.border;
        if (self.focused and theme.border_glow != null) {
            const glow = GlowEffect{
                .color = colors[self.frame],
                .intensity = 0.8,
                .radius = 4,
            };
            VisualEffects.renderGlowBorder(screen, bounds, border_color, glow);
        } else {
            screen.drawBox(bounds.x, bounds.y, bounds.width, bounds.height, border_color, Color.black);
        }
        
        // Title with glow
        const title = " PATRICK STAR ";
        const title_x = bounds.x + (bounds.width - @as(u16, @intCast(title.len))) / 2;
        screen.writeText(title_x, bounds.y, title, colors[self.frame], Color.black, .{ .bold = true });
        
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
                            .bg = Color.black,
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
            screen.writeText(msg_x, msg_y, message, colors[self.frame], Color.black, .{ .italic = true });
        }
    }
};