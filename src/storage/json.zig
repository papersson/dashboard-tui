const std = @import("std");

pub const JsonValue = union(enum) {
    null,
    bool: bool,
    number: f64,
    string: []const u8,
    array: std.ArrayList(JsonValue),
    object: std.StringHashMap(JsonValue),
    
    pub fn deinit(self: *JsonValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .array => |*arr| {
                for (arr.items) |*item| {
                    item.deinit(allocator);
                }
                arr.deinit();
            },
            .object => |*obj| {
                var iter = obj.iterator();
                while (iter.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                obj.deinit();
            },
            .string => |s| allocator.free(s),
            else => {},
        }
    }
};

pub const Parser = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    pos: usize = 0,
    
    pub fn init(allocator: std.mem.Allocator, input: []const u8) Parser {
        return .{
            .allocator = allocator,
            .input = input,
        };
    }
    
    pub fn parse(self: *Parser) !JsonValue {
        self.skipWhitespace();
        return try self.parseValue();
    }
    
    fn parseValue(self: *Parser) !JsonValue {
        self.skipWhitespace();
        
        if (self.pos >= self.input.len) return error.UnexpectedEnd;
        
        return switch (self.input[self.pos]) {
            'n' => try self.parseNull(),
            't', 'f' => try self.parseBool(),
            '"' => JsonValue{ .string = try self.parseString() },
            '-', '0'...'9' => JsonValue{ .number = try self.parseNumber() },
            '[' => JsonValue{ .array = try self.parseArray() },
            '{' => JsonValue{ .object = try self.parseObject() },
            else => error.UnexpectedCharacter,
        };
    }
    
    fn parseNull(self: *Parser) !JsonValue {
        if (self.pos + 4 > self.input.len or !std.mem.eql(u8, self.input[self.pos..self.pos + 4], "null")) {
            return error.InvalidNull;
        }
        self.pos += 4;
        return JsonValue.null;
    }
    
    fn parseBool(self: *Parser) !JsonValue {
        if (self.pos + 4 <= self.input.len and std.mem.eql(u8, self.input[self.pos..self.pos + 4], "true")) {
            self.pos += 4;
            return JsonValue{ .bool = true };
        } else if (self.pos + 5 <= self.input.len and std.mem.eql(u8, self.input[self.pos..self.pos + 5], "false")) {
            self.pos += 5;
            return JsonValue{ .bool = false };
        }
        return error.InvalidBool;
    }
    
    fn parseString(self: *Parser) ![]const u8 {
        if (self.input[self.pos] != '"') return error.ExpectedQuote;
        self.pos += 1;
        
        const start = self.pos;
        while (self.pos < self.input.len) : (self.pos += 1) {
            if (self.input[self.pos] == '"' and (self.pos == 0 or self.input[self.pos - 1] != '\\')) {
                const str = try self.allocator.dupe(u8, self.input[start..self.pos]);
                self.pos += 1;
                return str;
            }
        }
        return error.UnterminatedString;
    }
    
    fn parseNumber(self: *Parser) !f64 {
        const start = self.pos;
        
        if (self.input[self.pos] == '-') self.pos += 1;
        
        // Integer part
        if (self.pos >= self.input.len) return error.InvalidNumber;
        if (self.input[self.pos] == '0') {
            self.pos += 1;
        } else if (self.input[self.pos] >= '1' and self.input[self.pos] <= '9') {
            while (self.pos < self.input.len and self.input[self.pos] >= '0' and self.input[self.pos] <= '9') {
                self.pos += 1;
            }
        } else {
            return error.InvalidNumber;
        }
        
        // Fractional part
        if (self.pos < self.input.len and self.input[self.pos] == '.') {
            self.pos += 1;
            const frac_start = self.pos;
            while (self.pos < self.input.len and self.input[self.pos] >= '0' and self.input[self.pos] <= '9') {
                self.pos += 1;
            }
            if (self.pos == frac_start) return error.InvalidNumber;
        }
        
        // Exponent part
        if (self.pos < self.input.len and (self.input[self.pos] == 'e' or self.input[self.pos] == 'E')) {
            self.pos += 1;
            if (self.pos < self.input.len and (self.input[self.pos] == '+' or self.input[self.pos] == '-')) {
                self.pos += 1;
            }
            const exp_start = self.pos;
            while (self.pos < self.input.len and self.input[self.pos] >= '0' and self.input[self.pos] <= '9') {
                self.pos += 1;
            }
            if (self.pos == exp_start) return error.InvalidNumber;
        }
        
        return try std.fmt.parseFloat(f64, self.input[start..self.pos]);
    }
    
    fn parseArray(self: *Parser) !std.ArrayList(JsonValue) {
        if (self.input[self.pos] != '[') return error.ExpectedBracket;
        self.pos += 1;
        
        var array = std.ArrayList(JsonValue).init(self.allocator);
        errdefer {
            for (array.items) |*item| {
                item.deinit(self.allocator);
            }
            array.deinit();
        }
        
        self.skipWhitespace();
        if (self.pos < self.input.len and self.input[self.pos] == ']') {
            self.pos += 1;
            return array;
        }
        
        while (true) {
            try array.append(try self.parseValue());
            
            self.skipWhitespace();
            if (self.pos >= self.input.len) return error.UnexpectedEnd;
            
            if (self.input[self.pos] == ',') {
                self.pos += 1;
            } else if (self.input[self.pos] == ']') {
                self.pos += 1;
                return array;
            } else {
                return error.ExpectedCommaOrBracket;
            }
        }
    }
    
    fn parseObject(self: *Parser) !std.StringHashMap(JsonValue) {
        if (self.input[self.pos] != '{') return error.ExpectedBrace;
        self.pos += 1;
        
        var object = std.StringHashMap(JsonValue).init(self.allocator);
        errdefer {
            var iter = object.iterator();
            while (iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                entry.value_ptr.deinit(self.allocator);
            }
            object.deinit();
        }
        
        self.skipWhitespace();
        if (self.pos < self.input.len and self.input[self.pos] == '}') {
            self.pos += 1;
            return object;
        }
        
        while (true) {
            self.skipWhitespace();
            const key = try self.parseString();
            errdefer self.allocator.free(key);
            
            self.skipWhitespace();
            if (self.pos >= self.input.len or self.input[self.pos] != ':') {
                return error.ExpectedColon;
            }
            self.pos += 1;
            
            const value = try self.parseValue();
            try object.put(key, value);
            
            self.skipWhitespace();
            if (self.pos >= self.input.len) return error.UnexpectedEnd;
            
            if (self.input[self.pos] == ',') {
                self.pos += 1;
            } else if (self.input[self.pos] == '}') {
                self.pos += 1;
                return object;
            } else {
                return error.ExpectedCommaOrBrace;
            }
        }
    }
    
    fn skipWhitespace(self: *Parser) void {
        while (self.pos < self.input.len) : (self.pos += 1) {
            switch (self.input[self.pos]) {
                ' ', '\t', '\n', '\r' => continue,
                else => break,
            }
        }
    }
};

pub fn stringify(allocator: std.mem.Allocator, value: JsonValue) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();
    
    try stringifyValue(&list, value);
    return list.toOwnedSlice();
}

fn stringifyValue(writer: *std.ArrayList(u8), value: JsonValue) !void {
    switch (value) {
        .null => try writer.appendSlice("null"),
        .bool => |b| try writer.appendSlice(if (b) "true" else "false"),
        .number => |n| try writer.writer().print("{d}", .{n}),
        .string => |s| {
            try writer.append('"');
            for (s) |c| {
                switch (c) {
                    '"' => try writer.appendSlice("\\\""),
                    '\\' => try writer.appendSlice("\\\\"),
                    '\n' => try writer.appendSlice("\\n"),
                    '\r' => try writer.appendSlice("\\r"),
                    '\t' => try writer.appendSlice("\\t"),
                    else => try writer.append(c),
                }
            }
            try writer.append('"');
        },
        .array => |arr| {
            try writer.append('[');
            for (arr.items, 0..) |item, i| {
                if (i > 0) try writer.appendSlice(", ");
                try stringifyValue(writer, item);
            }
            try writer.append(']');
        },
        .object => |obj| {
            try writer.append('{');
            var iter = obj.iterator();
            var first = true;
            while (iter.next()) |entry| {
                if (!first) try writer.appendSlice(", ");
                first = false;
                
                try stringifyValue(writer, JsonValue{ .string = entry.key_ptr.* });
                try writer.appendSlice(": ");
                try stringifyValue(writer, entry.value_ptr.*);
            }
            try writer.append('}');
        },
    }
}