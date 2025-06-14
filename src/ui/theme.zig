const std = @import("std");
const Color = @import("../terminal/screen.zig").Color;
const Gradient = @import("visual_effects.zig").Gradient;
const GlowEffect = @import("visual_effects.zig").GlowEffect;
const ShadowEffect = @import("visual_effects.zig").ShadowEffect;

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
    
    // Visual effects
    panel_gradient: ?Gradient = null,
    border_glow: ?GlowEffect = null,
    panel_shadow: ?ShadowEffect = null,
    
    // Enhanced colors for cyberpunk theme
    neon_pink: Color = Color{ .r = 255, .g = 20, .b = 147 },
    neon_blue: Color = Color{ .r = 0, .g = 191, .b = 255 },
    neon_green: Color = Color{ .r = 57, .g = 255, .b = 20 },
    dark_purple: Color = Color{ .r = 75, .g = 0, .b = 130 },
    
    pub const cyberpunk = Theme{
        // Enhanced cyberpunk colors
        .bg = Color{ .r = 5, .g = 5, .b = 15 }, // Very dark blue-black
        .panel_bg = Color{ .r = 15, .g = 15, .b = 25 },
        .border = Color{ .r = 50, .g = 50, .b = 80 },
        .border_active = Color{ .r = 0, .g = 255, .b = 255 },
        
        // Brighter text for better contrast
        .text_primary = Color{ .r = 240, .g = 240, .b = 250 },
        .text_secondary = Color{ .r = 160, .g = 160, .b = 180 },
        .text_dim = Color{ .r = 100, .g = 100, .b = 120 },
        
        // Neon priority colors
        .high_priority = Color{ .r = 255, .g = 20, .b = 147 }, // Neon pink
        .medium_priority = Color{ .r = 255, .g = 215, .b = 0 }, // Gold
        .low_priority = Color{ .r = 0, .g = 191, .b = 255 }, // Deep sky blue
        
        // Bright status colors
        .success = Color{ .r = 57, .g = 255, .b = 20 }, // Neon green
        .warning = Color{ .r = 255, .g = 140, .b = 0 }, // Dark orange
        .@"error" = Color{ .r = 255, .g = 69, .b = 0 }, // Red-orange
        
        // Cyan accents
        .accent = Color{ .r = 0, .g = 255, .b = 255 },
        .accent_dim = Color{ .r = 0, .g = 180, .b = 200 },
        
        // Visual effects
        .panel_gradient = Gradient.dark_gradient,
        .border_glow = GlowEffect{ .color = Color{ .r = 0, .g = 255, .b = 255 }, .intensity = 0.6, .radius = 3 },
        .panel_shadow = ShadowEffect{ .offset_x = 2, .offset_y = 2, .opacity = 0.4, .blur = 2 },
    };
    
    pub const neon_nights = Theme{
        .bg = Color{ .r = 10, .g = 0, .b = 20 }, // Deep purple-black
        .panel_bg = Color{ .r = 20, .g = 10, .b = 30 },
        .border = Color{ .r = 80, .g = 40, .b = 120 },
        .border_active = Color{ .r = 255, .g = 0, .b = 255 }, // Magenta
        
        .text_primary = Color{ .r = 255, .g = 240, .b = 255 },
        .text_secondary = Color{ .r = 200, .g = 180, .b = 220 },
        .text_dim = Color{ .r = 120, .g = 100, .b = 140 },
        
        .high_priority = Color{ .r = 255, .g = 0, .b = 128 },
        .medium_priority = Color{ .r = 255, .g = 0, .b = 255 },
        .low_priority = Color{ .r = 128, .g = 0, .b = 255 },
        
        .success = Color{ .r = 0, .g = 255, .b = 128 },
        .warning = Color{ .r = 255, .g = 128, .b = 0 },
        .@"error" = Color{ .r = 255, .g = 0, .b = 64 },
        
        .accent = Color{ .r = 255, .g = 0, .b = 255 },
        .accent_dim = Color{ .r = 180, .g = 0, .b = 180 },
        
        .panel_gradient = Gradient.neon_purple,
        .border_glow = GlowEffect{ .color = Color{ .r = 255, .g = 0, .b = 255 }, .intensity = 0.7, .radius = 4 },
        .panel_shadow = ShadowEffect{ .offset_x = 3, .offset_y = 3, .opacity = 0.5, .blur = 3 },
    };
    
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