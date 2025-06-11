const std = @import("std");

pub const Rect = struct {
    x: u16,
    y: u16,
    width: u16,
    height: u16,
    
    pub fn contains(self: Rect, x: u16, y: u16) bool {
        return x >= self.x and x < self.x + self.width and
               y >= self.y and y < self.y + self.height;
    }
    
    pub fn shrink(self: Rect, amount: u16) Rect {
        if (self.width <= amount * 2 or self.height <= amount * 2) {
            return Rect{ .x = self.x, .y = self.y, .width = 0, .height = 0 };
        }
        return Rect{
            .x = self.x + amount,
            .y = self.y + amount,
            .width = self.width - amount * 2,
            .height = self.height - amount * 2,
        };
    }
};

pub const Split = enum {
    horizontal,
    vertical,
};

pub const Layout = struct {
    allocator: std.mem.Allocator,
    root: *Node,
    
    pub const Node = union(enum) {
        panel: struct {
            id: []const u8,
            focused: bool = false,
        },
        split: struct {
            direction: Split,
            ratio: f32 = 0.5,
            first: *Node,
            second: *Node,
        },
    };
    
    pub fn init(allocator: std.mem.Allocator) !Layout {
        const root = try allocator.create(Node);
        root.* = .{ .panel = .{ .id = "todo", .focused = true } };
        return Layout{
            .allocator = allocator,
            .root = root,
        };
    }
    
    pub fn deinit(self: *Layout) void {
        self.destroyNode(self.root);
    }
    
    fn destroyNode(self: *Layout, node: *Node) void {
        switch (node.*) {
            .split => |split| {
                self.destroyNode(split.first);
                self.destroyNode(split.second);
            },
            .panel => {},
        }
        self.allocator.destroy(node);
    }
    
    pub fn splitPanel(self: *Layout, panel_id: []const u8, direction: Split, new_panel_id: []const u8, ratio: f32) !void {
        const node = self.findPanel(self.root, panel_id) orelse return error.PanelNotFound;
        
        const new_first = try self.allocator.create(Node);
        new_first.* = node.*;
        
        const new_second = try self.allocator.create(Node);
        new_second.* = .{ .panel = .{ .id = new_panel_id } };
        
        node.* = .{
            .split = .{
                .direction = direction,
                .ratio = ratio,
                .first = new_first,
                .second = new_second,
            },
        };
    }
    
    fn findPanel(self: *Layout, node: *Node, id: []const u8) ?*Node {
        switch (node.*) {
            .panel => |panel| {
                if (std.mem.eql(u8, panel.id, id)) return node;
            },
            .split => |split| {
                if (self.findPanel(split.first, id)) |found| return found;
                if (self.findPanel(split.second, id)) |found| return found;
            },
        }
        return null;
    }
    
    pub fn calculate(self: *Layout, bounds: Rect) void {
        self.calculateNode(self.root, bounds);
    }
    
    fn calculateNode(self: *Layout, node: *Node, bounds: Rect) void {
        switch (node.*) {
            .panel => {},
            .split => |split| {
                switch (split.direction) {
                    .horizontal => {
                        const first_height = @as(u16, @intFromFloat(@as(f32, @floatFromInt(bounds.height)) * split.ratio));
                        self.calculateNode(split.first, Rect{
                            .x = bounds.x,
                            .y = bounds.y,
                            .width = bounds.width,
                            .height = first_height,
                        });
                        self.calculateNode(split.second, Rect{
                            .x = bounds.x,
                            .y = bounds.y + first_height,
                            .width = bounds.width,
                            .height = bounds.height - first_height,
                        });
                    },
                    .vertical => {
                        const first_width = @as(u16, @intFromFloat(@as(f32, @floatFromInt(bounds.width)) * split.ratio));
                        self.calculateNode(split.first, Rect{
                            .x = bounds.x,
                            .y = bounds.y,
                            .width = first_width,
                            .height = bounds.height,
                        });
                        self.calculateNode(split.second, Rect{
                            .x = bounds.x + first_width,
                            .y = bounds.y,
                            .width = bounds.width - first_width,
                            .height = bounds.height,
                        });
                    },
                }
            },
        }
    }
    
    pub fn getPanelRect(self: *Layout, panel_id: []const u8, bounds: Rect) ?Rect {
        return self.getPanelRectNode(self.root, panel_id, bounds);
    }
    
    fn getPanelRectNode(self: *Layout, node: *Node, panel_id: []const u8, bounds: Rect) ?Rect {
        switch (node.*) {
            .panel => |panel| {
                if (std.mem.eql(u8, panel.id, panel_id)) return bounds;
            },
            .split => |split| {
                switch (split.direction) {
                    .horizontal => {
                        const first_height = @as(u16, @intFromFloat(@as(f32, @floatFromInt(bounds.height)) * split.ratio));
                        if (self.getPanelRectNode(split.first, panel_id, Rect{
                            .x = bounds.x,
                            .y = bounds.y,
                            .width = bounds.width,
                            .height = first_height,
                        })) |rect| return rect;
                        if (self.getPanelRectNode(split.second, panel_id, Rect{
                            .x = bounds.x,
                            .y = bounds.y + first_height,
                            .width = bounds.width,
                            .height = bounds.height - first_height,
                        })) |rect| return rect;
                    },
                    .vertical => {
                        const first_width = @as(u16, @intFromFloat(@as(f32, @floatFromInt(bounds.width)) * split.ratio));
                        if (self.getPanelRectNode(split.first, panel_id, Rect{
                            .x = bounds.x,
                            .y = bounds.y,
                            .width = first_width,
                            .height = bounds.height,
                        })) |rect| return rect;
                        if (self.getPanelRectNode(split.second, panel_id, Rect{
                            .x = bounds.x + first_width,
                            .y = bounds.y,
                            .width = bounds.width - first_width,
                            .height = bounds.height,
                        })) |rect| return rect;
                    },
                }
            },
        }
        return null;
    }
    
    pub fn focusNext(self: *Layout) void {
        var panels = std.ArrayList(*Node).init(self.allocator);
        defer panels.deinit();
        
        self.collectPanels(self.root, &panels) catch return;
        if (panels.items.len == 0) return;
        
        var current_idx: ?usize = null;
        for (panels.items, 0..) |panel, i| {
            if (panel.panel.focused) {
                current_idx = i;
                panel.panel.focused = false;
                break;
            }
        }
        
        const next_idx = if (current_idx) |idx| (idx + 1) % panels.items.len else 0;
        panels.items[next_idx].panel.focused = true;
    }
    
    fn collectPanels(self: *Layout, node: *Node, list: *std.ArrayList(*Node)) !void {
        switch (node.*) {
            .panel => try list.append(node),
            .split => |split| {
                try self.collectPanels(split.first, list);
                try self.collectPanels(split.second, list);
            },
        }
    }
};