const std = @import("std");
const Color = @import("../terminal/screen.zig").Color;

pub const Theme = struct {
    // Base colors
    bg: Color = Color{ .r = 10, .g = 10, .b = 10 },
    panel_bg: Color = Color{ .r = 26, .g = 26, .b = 26 },
    border: Color = Color{ .r = 42, .g = 42, .b = 42 },
    border_active: Color = Color{ .r = 0, .g = 255, .b = 255 },
    
    // Text colors
    text_primary: Color = Color{ .r = 224, .g = 224, .b = 224 },
    text_secondary: Color = Color{ .r = 128, .g = 128, .b = 128 },
    text_dim: Color = Color{ .r = 80, .g = 80, .b = 80 },
    
    // Priority colors
    high_priority: Color = Color{ .r = 255, .g = 0, .b = 110 },
    medium_priority: Color = Color{ .r = 255, .g = 190, .b = 11 },
    low_priority: Color = Color{ .r = 58, .g = 134, .b = 255 },
    
    // Status colors
    success: Color = Color{ .r = 6, .g = 255, .b = 165 },
    warning: Color = Color{ .r = 251, .g = 86, .b = 7 },
    @"error": Color = Color{ .r = 255, .g = 0, .b = 110 },
    
    // Accent colors
    accent: Color = Color{ .r = 0, .g = 255, .b = 255 },
    accent_dim: Color = Color{ .r = 0, .g = 150, .b = 150 },
    
    pub const cyberpunk = Theme{};
    
    pub const minimal = Theme{
        .bg = Color{ .r = 255, .g = 255, .b = 255 },
        .panel_bg = Color{ .r = 245, .g = 245, .b = 245 },
        .border = Color{ .r = 200, .g = 200, .b = 200 },
        .border_active = Color{ .r = 0, .g = 0, .b = 0 },
        .text_primary = Color{ .r = 30, .g = 30, .b = 30 },
        .text_secondary = Color{ .r = 100, .g = 100, .b = 100 },
        .text_dim = Color{ .r = 150, .g = 150, .b = 150 },
        .high_priority = Color{ .r = 220, .g = 38, .b = 127 },
        .medium_priority = Color{ .r = 255, .g = 176, .b = 0 },
        .low_priority = Color{ .r = 33, .g = 150, .b = 243 },
        .success = Color{ .r = 76, .g = 175, .b = 80 },
        .warning = Color{ .r = 255, .g = 152, .b = 0 },
        .@"error" = Color{ .r = 244, .g = 67, .b = 54 },
        .accent = Color{ .r = 33, .g = 150, .b = 243 },
        .accent_dim = Color{ .r = 100, .g = 181, .b = 246 },
    };
};