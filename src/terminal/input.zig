const std = @import("std");
const builtin = @import("builtin");

pub const Key = union(enum) {
    char: u21,
    ctrl_char: u8, // Ctrl+A through Ctrl+Z
    function: u8, // F1-F12
    arrow_up,
    arrow_down,
    arrow_left,
    arrow_right,
    home,
    end,
    page_up,
    page_down,
    insert,
    delete,
    backspace,
    tab,
    enter,
    escape,
    
    pub fn isChar(self: Key, char: u21) bool {
        return switch (self) {
            .char => |c| c == char,
            else => false,
        };
    }
    
    pub fn isCtrl(self: Key, char: u8) bool {
        return switch (self) {
            .ctrl_char => |c| c == char,
            else => false,
        };
    }
};

pub const Button = enum {
    left,
    middle,
    right,
    scroll_up,
    scroll_down,
    release,
};

pub const MouseEvent = struct {
    x: u16,
    y: u16,
    button: Button,
    modifiers: struct {
        shift: bool = false,
        alt: bool = false,
        ctrl: bool = false,
    } = .{},
};

pub const Event = union(enum) {
    key: Key,
    mouse: MouseEvent,
    resize: struct { width: u16, height: u16 },
};

pub const InputReader = struct {
    buffer: [256]u8 = undefined,
    buffer_len: usize = 0,
    
    pub fn init() InputReader {
        return .{};
    }
    
    pub fn readEvent(self: *InputReader) !?Event {
        // Try to parse existing buffer first
        if (self.buffer_len > 0) {
            if (try self.parseBuffer()) |event| {
                return event;
            }
        }
        
        // Read more input
        const stdin = std.io.getStdIn().reader();
        
        // Non-blocking read
        switch (builtin.os.tag) {
            .macos, .linux, .freebsd, .netbsd, .dragonfly, .openbsd => {
                var fds = [_]std.posix.pollfd{
                    .{
                        .fd = std.io.getStdIn().handle,
                        .events = std.posix.POLL.IN,
                        .revents = 0,
                    },
                };
                
                const poll_result = try std.posix.poll(&fds, 10); // 10ms timeout
                
                if (poll_result > 0 and (fds[0].revents & std.posix.POLL.IN) != 0) {
                    const bytes_read = try stdin.read(self.buffer[self.buffer_len..]);
                    if (bytes_read > 0) {
                        self.buffer_len += bytes_read;
                        return try self.parseBuffer();
                    }
                }
            },
            else => {
                // Fallback for other platforms
                const bytes_read = try stdin.read(self.buffer[self.buffer_len..]);
                if (bytes_read > 0) {
                    self.buffer_len += bytes_read;
                    return try self.parseBuffer();
                }
            },
        }
        
        return null;
    }
    
    fn parseBuffer(self: *InputReader) !?Event {
        if (self.buffer_len == 0) return null;
        
        // Handle escape sequences
        if (self.buffer[0] == 0x1B) { // ESC
            if (self.buffer_len == 1) {
                // Just escape key
                self.buffer_len = 0;
                return Event{ .key = .escape };
            }
            
            // CSI sequences
            if (self.buffer_len >= 3 and self.buffer[1] == '[') {
                return self.parseCSISequence();
            }
            
            // Alt+key sequences
            if (self.buffer_len >= 2) {
                const key = self.buffer[1];
                self.consumeBytes(2);
                return Event{ .key = .{ .char = key } };
            }
        }
        
        // Handle control characters
        if (self.buffer[0] < 32) {
            const key = self.buffer[0];
            self.consumeBytes(1);
            
            switch (key) {
                0x01...0x08 => return Event{ .key = .{ .ctrl_char = key + 'a' - 1 } },
                0x09 => return Event{ .key = .tab },
                0x0A => return Event{ .key = .enter },
                0x0B...0x0C => return Event{ .key = .{ .ctrl_char = key + 'a' - 1 } },
                0x0D => return Event{ .key = .enter },
                0x0E...0x1A => return Event{ .key = .{ .ctrl_char = key + 'a' - 1 } },
                0x7F => return Event{ .key = .backspace },
                else => return null,
            }
        }
        
        // Handle UTF-8 characters
        const len = std.unicode.utf8ByteSequenceLength(self.buffer[0]) catch 1;
        if (self.buffer_len >= len) {
            const codepoint = std.unicode.utf8Decode(self.buffer[0..len]) catch blk: {
                self.consumeBytes(1);
                break :blk @as(u21, self.buffer[0]);
            };
            self.consumeBytes(len);
            return Event{ .key = .{ .char = codepoint } };
        }
        
        return null;
    }
    
    fn parseCSISequence(self: *InputReader) ?Event {
        var i: usize = 2; // Skip ESC[
        var nums = [_]u16{ 0, 0, 0 };
        var num_count: usize = 0;
        var current_num: u16 = 0;
        var has_digit = false;
        
        while (i < self.buffer_len) : (i += 1) {
            const byte = self.buffer[i];
            
            if (byte >= '0' and byte <= '9') {
                current_num = current_num * 10 + (byte - '0');
                has_digit = true;
            } else if (byte == ';') {
                if (num_count < nums.len) {
                    nums[num_count] = current_num;
                    num_count += 1;
                }
                current_num = 0;
                has_digit = false;
            } else {
                // Terminal character
                if (has_digit and num_count < nums.len) {
                    nums[num_count] = current_num;
                    num_count += 1;
                }
                
                const event = switch (byte) {
                    'A' => Event{ .key = .arrow_up },
                    'B' => Event{ .key = .arrow_down },
                    'C' => Event{ .key = .arrow_right },
                    'D' => Event{ .key = .arrow_left },
                    'H' => Event{ .key = .home },
                    'F' => Event{ .key = .end },
                    '~' => blk: {
                        if (num_count > 0) {
                            break :blk switch (nums[0]) {
                                1 => Event{ .key = .home },
                                2 => Event{ .key = .insert },
                                3 => Event{ .key = .delete },
                                4 => Event{ .key = .end },
                                5 => Event{ .key = .page_up },
                                6 => Event{ .key = .page_down },
                                15...26 => Event{ .key = .{ .function = @intCast(nums[0] - 14) } },
                                else => null,
                            };
                        }
                        break :blk null;
                    },
                    'M' => self.parseMouseEvent(nums, num_count),
                    else => null,
                };
                
                if (event != null) {
                    self.consumeBytes(i + 1);
                    return event;
                }
                break;
            }
        }
        
        return null;
    }
    
    fn parseMouseEvent(_: *InputReader, nums: [3]u16, num_count: usize) ?Event {
        if (num_count != 3) return null;
        
        const button_code = nums[0];
        const x = nums[1];
        const y = nums[2];
        
        const button: Button = switch (button_code & 0x43) {
            0 => .left,
            1 => .middle,
            2 => .right,
            3 => .release,
            64 => .scroll_up,
            65 => .scroll_down,
            else => return null,
        };
        
        return Event{
            .mouse = .{
                .x = x - 1, // Convert from 1-based to 0-based
                .y = y - 1,
                .button = button,
                .modifiers = .{
                    .shift = (button_code & 0x04) != 0,
                    .alt = (button_code & 0x08) != 0,
                    .ctrl = (button_code & 0x10) != 0,
                },
            },
        };
    }
    
    fn consumeBytes(self: *InputReader, count: usize) void {
        if (count >= self.buffer_len) {
            self.buffer_len = 0;
        } else {
            std.mem.copyForwards(u8, &self.buffer, self.buffer[count..self.buffer_len]);
            self.buffer_len -= count;
        }
    }
};