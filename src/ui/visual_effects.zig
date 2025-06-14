const std = @import("std");
const Color = @import("../terminal/screen.zig").Color;
const Screen = @import("../terminal/screen.zig").Screen;
const Rect = @import("layout.zig").Rect;

// Gradient types for various visual effects
pub const GradientType = enum {
    linear_vertical,
    linear_horizontal,
    radial,
    diagonal,
};

// Gradient definition
pub const Gradient = struct {
    start_color: Color,
    end_color: Color,
    type: GradientType = .linear_vertical,
    
    // Create preset gradients
    pub const neon_blue = Gradient{
        .start_color = Color{ .r = 0, .g = 100, .b = 255 },
        .end_color = Color{ .r = 0, .g = 50, .b = 150 },
        .type = .linear_vertical,
    };
    
    pub const neon_purple = Gradient{
        .start_color = Color{ .r = 150, .g = 0, .b = 255 },
        .end_color = Color{ .r = 75, .g = 0, .b = 150 },
        .type = .linear_vertical,
    };
    
    pub const neon_cyan = Gradient{
        .start_color = Color{ .r = 0, .g = 255, .b = 255 },
        .end_color = Color{ .r = 0, .g = 150, .b = 200 },
        .type = .linear_vertical,
    };
    
    pub const dark_gradient = Gradient{
        .start_color = Color{ .r = 30, .g = 30, .b = 40 },
        .end_color = Color{ .r = 10, .g = 10, .b = 20 },
        .type = .linear_vertical,
    };
    
    pub const sunset = Gradient{
        .start_color = Color{ .r = 255, .g = 94, .b = 77 },
        .end_color = Color{ .r = 255, .g = 154, .b = 0 },
        .type = .linear_horizontal,
    };
    
    // Interpolate between colors
    pub fn interpolate(self: Gradient, t: f32) Color {
        const clamped_t = std.math.clamp(t, 0.0, 1.0);
        return Color{
            .r = @intFromFloat(@as(f32, @floatFromInt(self.start_color.r)) * (1.0 - clamped_t) + @as(f32, @floatFromInt(self.end_color.r)) * clamped_t),
            .g = @intFromFloat(@as(f32, @floatFromInt(self.start_color.g)) * (1.0 - clamped_t) + @as(f32, @floatFromInt(self.end_color.g)) * clamped_t),
            .b = @intFromFloat(@as(f32, @floatFromInt(self.start_color.b)) * (1.0 - clamped_t) + @as(f32, @floatFromInt(self.end_color.b)) * clamped_t),
        };
    }
};

// Glow effect for borders and text
pub const GlowEffect = struct {
    color: Color,
    intensity: f32 = 0.5,
    radius: u8 = 2,
    
    pub fn apply(self: GlowEffect, base_color: Color) Color {
        return Color{
            .r = @intFromFloat(@min(255, @as(f32, @floatFromInt(base_color.r)) + @as(f32, @floatFromInt(self.color.r)) * self.intensity)),
            .g = @intFromFloat(@min(255, @as(f32, @floatFromInt(base_color.g)) + @as(f32, @floatFromInt(self.color.g)) * self.intensity)),
            .b = @intFromFloat(@min(255, @as(f32, @floatFromInt(base_color.b)) + @as(f32, @floatFromInt(self.color.b)) * self.intensity)),
        };
    }
};

// Shadow effect for depth
pub const ShadowEffect = struct {
    offset_x: i8 = 1,
    offset_y: i8 = 1,
    opacity: f32 = 0.3,
    blur: u8 = 1,
};

// Visual effects renderer
pub const VisualEffects = struct {
    // Render gradient background
    pub fn renderGradient(screen: *Screen, bounds: Rect, gradient: Gradient) void {
        var y: u16 = 0;
        while (y < bounds.height) : (y += 1) {
            var x: u16 = 0;
            const t = switch (gradient.type) {
                .linear_vertical => @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(bounds.height - 1)),
                .linear_horizontal => 0.5, // Will be calculated per pixel
                .radial => 0.5, // Will be calculated per pixel
                .diagonal => 0.5, // Will be calculated per pixel
            };
            
            while (x < bounds.width) : (x += 1) {
                const pixel_t = switch (gradient.type) {
                    .linear_vertical => t,
                    .linear_horizontal => @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(bounds.width - 1)),
                    .radial => blk: {
                        const center_x = @as(f32, @floatFromInt(bounds.width)) / 2.0;
                        const center_y = @as(f32, @floatFromInt(bounds.height)) / 2.0;
                        const max_dist = @sqrt(center_x * center_x + center_y * center_y);
                        const dx = @as(f32, @floatFromInt(x)) - center_x;
                        const dy = @as(f32, @floatFromInt(y)) - center_y;
                        const dist = @sqrt(dx * dx + dy * dy);
                        break :blk dist / max_dist;
                    },
                    .diagonal => blk: {
                        const norm_x = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(bounds.width - 1));
                        const norm_y = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(bounds.height - 1));
                        break :blk (norm_x + norm_y) / 2.0;
                    },
                };
                
                const color = gradient.interpolate(pixel_t);
                if (screen.getCell(bounds.x + x, bounds.y + y)) |cell| {
                    cell.bg = color;
                }
            }
        }
    }
    
    // Render glowing border
    pub fn renderGlowBorder(screen: *Screen, bounds: Rect, border_color: Color, glow: GlowEffect) void {
        // Unicode box drawing characters with glow
        const top_left = '╔';
        const top_right = '╗';
        const bottom_left = '╚';
        const bottom_right = '╝';
        const horizontal = '═';
        const vertical = '║';
        
        // Apply glow to corners
        const glow_color = glow.apply(border_color);
        
        // Top border with glow
        screen.setCell(bounds.x, bounds.y, .{ .char = top_left, .fg = glow_color, .bg = Color.black, .style = .{ .bold = true } });
        screen.setCell(bounds.x + bounds.width - 1, bounds.y, .{ .char = top_right, .fg = glow_color, .bg = Color.black, .style = .{ .bold = true } });
        
        var x: u16 = 1;
        while (x < bounds.width - 1) : (x += 1) {
            const edge_distance = @min(x, bounds.width - 1 - x);
            const intensity = if (edge_distance < glow.radius) @as(f32, @floatFromInt(edge_distance)) / @as(f32, @floatFromInt(glow.radius)) else 1.0;
            const color = Color{
                .r = @intFromFloat(@as(f32, @floatFromInt(border_color.r)) * intensity + @as(f32, @floatFromInt(glow_color.r)) * (1.0 - intensity)),
                .g = @intFromFloat(@as(f32, @floatFromInt(border_color.g)) * intensity + @as(f32, @floatFromInt(glow_color.g)) * (1.0 - intensity)),
                .b = @intFromFloat(@as(f32, @floatFromInt(border_color.b)) * intensity + @as(f32, @floatFromInt(glow_color.b)) * (1.0 - intensity)),
            };
            screen.setCell(bounds.x + x, bounds.y, .{ .char = horizontal, .fg = color, .bg = Color.black, .style = .{ .bold = true } });
            screen.setCell(bounds.x + x, bounds.y + bounds.height - 1, .{ .char = horizontal, .fg = color, .bg = Color.black, .style = .{ .bold = true } });
        }
        
        // Bottom border
        screen.setCell(bounds.x, bounds.y + bounds.height - 1, .{ .char = bottom_left, .fg = glow_color, .bg = Color.black, .style = .{ .bold = true } });
        screen.setCell(bounds.x + bounds.width - 1, bounds.y + bounds.height - 1, .{ .char = bottom_right, .fg = glow_color, .bg = Color.black, .style = .{ .bold = true } });
        
        // Vertical borders with glow
        var y: u16 = 1;
        while (y < bounds.height - 1) : (y += 1) {
            const edge_distance = @min(y, bounds.height - 1 - y);
            const intensity = if (edge_distance < glow.radius) @as(f32, @floatFromInt(edge_distance)) / @as(f32, @floatFromInt(glow.radius)) else 1.0;
            const color = Color{
                .r = @intFromFloat(@as(f32, @floatFromInt(border_color.r)) * intensity + @as(f32, @floatFromInt(glow_color.r)) * (1.0 - intensity)),
                .g = @intFromFloat(@as(f32, @floatFromInt(border_color.g)) * intensity + @as(f32, @floatFromInt(glow_color.g)) * (1.0 - intensity)),
                .b = @intFromFloat(@as(f32, @floatFromInt(border_color.b)) * intensity + @as(f32, @floatFromInt(glow_color.b)) * (1.0 - intensity)),
            };
            screen.setCell(bounds.x, bounds.y + y, .{ .char = vertical, .fg = color, .bg = Color.black, .style = .{ .bold = true } });
            screen.setCell(bounds.x + bounds.width - 1, bounds.y + y, .{ .char = vertical, .fg = color, .bg = Color.black, .style = .{ .bold = true } });
        }
    }
    
    // Render shadow effect
    pub fn renderShadow(screen: *Screen, bounds: Rect, shadow: ShadowEffect) void {
        if (shadow.offset_x == 0 and shadow.offset_y == 0) return;
        
        const shadow_color = Color{
            .r = @intFromFloat(10.0 * (1.0 - shadow.opacity)),
            .g = @intFromFloat(10.0 * (1.0 - shadow.opacity)),
            .b = @intFromFloat(10.0 * (1.0 - shadow.opacity)),
        };
        
        // Render shadow with offset
        const start_x = if (shadow.offset_x > 0) @as(u16, @intCast(shadow.offset_x)) else 0;
        const start_y = if (shadow.offset_y > 0) @as(u16, @intCast(shadow.offset_y)) else 0;
        
        var y: u16 = 0;
        while (y < bounds.height) : (y += 1) {
            var x: u16 = 0;
            while (x < bounds.width) : (x += 1) {
                const shadow_x = bounds.x + x + start_x;
                const shadow_y = bounds.y + y + start_y;
                
                if (screen.getCell(shadow_x, shadow_y)) |cell| {
                    // Only apply shadow if not overlapping with the main element
                    if (shadow_x >= bounds.x + bounds.width or shadow_y >= bounds.y + bounds.height) {
                        cell.bg = shadow_color;
                    }
                }
            }
        }
    }
    
    // Add decorative corners
    pub fn renderDecorativeCorners(screen: *Screen, bounds: Rect, color: Color) void {
        // Decorative corner characters
        const tl_outer = '╭';
        const tl_inner = '┤';
        const tr_outer = '╮';
        const tr_inner = '├';
        const bl_outer = '╰';
        const bl_inner = '┤';
        const br_outer = '╯';
        const br_inner = '├';
        
        // Top-left corner decoration
        screen.setCell(bounds.x - 1, bounds.y - 1, .{ .char = tl_outer, .fg = color, .bg = Color.black, .style = .{} });
        screen.setCell(bounds.x + 1, bounds.y, .{ .char = tl_inner, .fg = color, .bg = Color.black, .style = .{} });
        
        // Top-right corner decoration
        screen.setCell(bounds.x + bounds.width, bounds.y - 1, .{ .char = tr_outer, .fg = color, .bg = Color.black, .style = .{} });
        screen.setCell(bounds.x + bounds.width - 2, bounds.y, .{ .char = tr_inner, .fg = color, .bg = Color.black, .style = .{} });
        
        // Bottom-left corner decoration
        screen.setCell(bounds.x - 1, bounds.y + bounds.height, .{ .char = bl_outer, .fg = color, .bg = Color.black, .style = .{} });
        screen.setCell(bounds.x + 1, bounds.y + bounds.height - 1, .{ .char = bl_inner, .fg = color, .bg = Color.black, .style = .{} });
        
        // Bottom-right corner decoration  
        screen.setCell(bounds.x + bounds.width, bounds.y + bounds.height, .{ .char = br_outer, .fg = color, .bg = Color.black, .style = .{} });
        screen.setCell(bounds.x + bounds.width - 2, bounds.y + bounds.height - 1, .{ .char = br_inner, .fg = color, .bg = Color.black, .style = .{} });
    }
};