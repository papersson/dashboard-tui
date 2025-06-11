const std = @import("std");
const builtin = @import("builtin");

pub const RawMode = struct {
    original: switch (builtin.os.tag) {
        .macos, .linux, .freebsd, .netbsd, .dragonfly, .openbsd => std.c.termios,
        .windows => void,
        else => void,
    },
    
    pub fn enable() !RawMode {
        switch (builtin.os.tag) {
            .macos, .linux, .freebsd, .netbsd, .dragonfly, .openbsd => {
                const stdin_fd = std.io.getStdIn().handle;
                
                // Check if stdin is a TTY
                if (!std.posix.isatty(stdin_fd)) {
                    return RawMode{ .original = undefined };
                }
                
                const original = try std.posix.tcgetattr(stdin_fd);
                
                var raw = original;
                // Disable canonical mode, echo, and signals
                raw.lflag.ECHO = false;
                raw.lflag.ICANON = false;
                raw.lflag.ISIG = false;
                raw.lflag.IEXTEN = false;
                
                // Disable input processing
                raw.iflag.IXON = false;
                raw.iflag.ICRNL = false;
                raw.iflag.BRKINT = false;
                raw.iflag.INPCK = false;
                raw.iflag.ISTRIP = false;
                
                // Disable output processing
                raw.oflag.OPOST = false;
                
                // Set minimum characters and timeout
                raw.cc[@intFromEnum(std.posix.V.MIN)] = 0;
                raw.cc[@intFromEnum(std.posix.V.TIME)] = 1;
                
                try std.posix.tcsetattr(stdin_fd, .NOW, raw);
                
                return RawMode{ .original = original };
            },
            .windows => {
                // TODO: Implement Windows console mode
                return RawMode{ .original = {} };
            },
            else => {
                return RawMode{ .original = {} };
            },
        }
    }
    
    pub fn disable(self: *const RawMode) void {
        switch (builtin.os.tag) {
            .macos, .linux, .freebsd, .netbsd, .dragonfly, .openbsd => {
                const stdin_fd = std.io.getStdIn().handle;
                if (std.posix.isatty(stdin_fd)) {
                    std.posix.tcsetattr(stdin_fd, .NOW, self.original) catch {};
                }
            },
            else => {},
        }
    }
};