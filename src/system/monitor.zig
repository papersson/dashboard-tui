const std = @import("std");
const builtin = @import("builtin");

pub const SystemStats = struct {
    cpu_usage: f32,
    memory_usage: f32,
    memory_total: u64,
    memory_used: u64,
    process_count: u32,
};

pub const SystemMonitor = struct {
    allocator: std.mem.Allocator,
    last_cpu_idle: u64 = 0,
    last_cpu_total: u64 = 0,
    
    pub fn init(allocator: std.mem.Allocator) SystemMonitor {
        return SystemMonitor{
            .allocator = allocator,
        };
    }
    
    pub fn getStats(self: *SystemMonitor) !SystemStats {
        switch (builtin.os.tag) {
            .macos => return self.getStatsMacOS(),
            .linux => return self.getStatsLinux(),
            else => return SystemStats{
                .cpu_usage = 0.0,
                .memory_usage = 0.0,
                .memory_total = 0,
                .memory_used = 0,
                .process_count = 0,
            },
        }
    }
    
    fn getStatsMacOS(self: *SystemMonitor) !SystemStats {
        var stats = SystemStats{
            .cpu_usage = 0.0,
            .memory_usage = 0.0,
            .memory_total = 0,
            .memory_used = 0,
            .process_count = 0,
        };
        
        // Get memory stats using vm_stat
        const vm_stat_result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "vm_stat" },
        });
        defer self.allocator.free(vm_stat_result.stdout);
        defer self.allocator.free(vm_stat_result.stderr);
        
        // Parse vm_stat output
        var lines = std.mem.tokenizeScalar(u8, vm_stat_result.stdout, '\n');
        var page_size: u64 = 4096; // Default page size
        var pages_free: u64 = 0;
        var pages_active: u64 = 0;
        var pages_inactive: u64 = 0;
        var pages_speculative: u64 = 0;
        var pages_wired: u64 = 0;
        var pages_compressed: u64 = 0;
        
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "page size of")) |_| {
                var parts = std.mem.tokenizeScalar(u8, line, ' ');
                while (parts.next()) |part| {
                    if (std.fmt.parseInt(u64, part, 10)) |size| {
                        page_size = size;
                        break;
                    } else |_| {}
                }
            } else if (std.mem.indexOf(u8, line, "Pages free:")) |_| {
                pages_free = try parseVmStatLine(line);
            } else if (std.mem.indexOf(u8, line, "Pages active:")) |_| {
                pages_active = try parseVmStatLine(line);
            } else if (std.mem.indexOf(u8, line, "Pages inactive:")) |_| {
                pages_inactive = try parseVmStatLine(line);
            } else if (std.mem.indexOf(u8, line, "Pages speculative:")) |_| {
                pages_speculative = try parseVmStatLine(line);
            } else if (std.mem.indexOf(u8, line, "Pages wired down:")) |_| {
                pages_wired = try parseVmStatLine(line);
            } else if (std.mem.indexOf(u8, line, "Pages occupied by compressor:")) |_| {
                pages_compressed = try parseVmStatLine(line);
            }
        }
        
        // Calculate memory usage
        const total_pages = pages_free + pages_active + pages_inactive + pages_speculative + pages_wired + pages_compressed;
        stats.memory_total = total_pages * page_size;
        stats.memory_used = (pages_active + pages_wired + pages_compressed) * page_size;
        stats.memory_usage = if (stats.memory_total > 0) 
            @as(f32, @floatFromInt(stats.memory_used)) / @as(f32, @floatFromInt(stats.memory_total))
        else 0.0;
        
        // Get CPU usage using top
        const top_result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{ "top", "-l", "1", "-n", "0" },
        });
        defer self.allocator.free(top_result.stdout);
        defer self.allocator.free(top_result.stderr);
        
        // Parse CPU usage from top output
        lines = std.mem.tokenizeScalar(u8, top_result.stdout, '\n');
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "CPU usage:")) |_| {
                // Format: "CPU usage: 12.5% user, 10.2% sys, 77.3% idle"
                const idle_start = std.mem.indexOf(u8, line, "% idle");
                if (idle_start) |end| {
                    // Find the start of the idle percentage
                    var i = end;
                    while (i > 0 and line[i - 1] != ' ') : (i -= 1) {}
                    const idle_str = line[i..end];
                    if (std.fmt.parseFloat(f32, idle_str)) |idle| {
                        stats.cpu_usage = (100.0 - idle) / 100.0;
                    } else |_| {}
                }
            } else if (std.mem.indexOf(u8, line, "Processes:")) |_| {
                // Format: "Processes: 421 total, 3 running, 418 sleeping"
                var parts = std.mem.tokenizeScalar(u8, line, ' ');
                _ = parts.next(); // Skip "Processes:"
                if (parts.next()) |count_str| {
                    if (std.fmt.parseInt(u32, count_str, 10)) |count| {
                        stats.process_count = count;
                    } else |_| {}
                }
            }
        }
        
        return stats;
    }
    
    fn getStatsLinux(self: *SystemMonitor) !SystemStats {
        var stats = SystemStats{
            .cpu_usage = 0.0,
            .memory_usage = 0.0,
            .memory_total = 0,
            .memory_used = 0,
            .process_count = 0,
        };
        
        // Read CPU stats from /proc/stat
        const stat_file = try std.fs.openFileAbsolute("/proc/stat", .{});
        defer stat_file.close();
        
        var buf: [256]u8 = undefined;
        const bytes_read = try stat_file.read(&buf);
        const stat_line = buf[0..bytes_read];
        
        // Parse CPU line: "cpu  user nice system idle iowait irq softirq steal guest guest_nice"
        if (std.mem.startsWith(u8, stat_line, "cpu ")) {
            var parts = std.mem.tokenizeAny(u8, stat_line[4..], " \n");
            var values: [10]u64 = undefined;
            var i: usize = 0;
            while (parts.next()) |part| : (i += 1) {
                if (i >= 10) break;
                values[i] = std.fmt.parseInt(u64, part, 10) catch 0;
            }
            
            const idle = values[3] + values[4]; // idle + iowait
            const total = values[0] + values[1] + values[2] + values[3] + values[4] + values[5] + values[6] + values[7];
            
            if (self.last_cpu_total > 0) {
                const total_diff = total - self.last_cpu_total;
                const idle_diff = idle - self.last_cpu_idle;
                if (total_diff > 0) {
                    stats.cpu_usage = 1.0 - (@as(f32, @floatFromInt(idle_diff)) / @as(f32, @floatFromInt(total_diff)));
                }
            }
            
            self.last_cpu_idle = idle;
            self.last_cpu_total = total;
        }
        
        // Read memory stats from /proc/meminfo
        const meminfo_file = try std.fs.openFileAbsolute("/proc/meminfo", .{});
        defer meminfo_file.close();
        
        var mem_buf: [4096]u8 = undefined;
        const mem_bytes = try meminfo_file.read(&mem_buf);
        const meminfo = mem_buf[0..mem_bytes];
        
        var mem_total: u64 = 0;
        var mem_free: u64 = 0;
        var mem_available: u64 = 0;
        var buffers: u64 = 0;
        var cached: u64 = 0;
        
        var lines = std.mem.tokenizeScalar(u8, meminfo, '\n');
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "MemTotal:")) {
                mem_total = try parseMemInfoLine(line) * 1024;
            } else if (std.mem.startsWith(u8, line, "MemFree:")) {
                mem_free = try parseMemInfoLine(line) * 1024;
            } else if (std.mem.startsWith(u8, line, "MemAvailable:")) {
                mem_available = try parseMemInfoLine(line) * 1024;
            } else if (std.mem.startsWith(u8, line, "Buffers:")) {
                buffers = try parseMemInfoLine(line) * 1024;
            } else if (std.mem.startsWith(u8, line, "Cached:")) {
                cached = try parseMemInfoLine(line) * 1024;
            }
        }
        
        stats.memory_total = mem_total;
        if (mem_available > 0) {
            stats.memory_used = mem_total - mem_available;
        } else {
            // Fallback for older kernels without MemAvailable
            stats.memory_used = mem_total - mem_free - buffers - cached;
        }
        stats.memory_usage = if (stats.memory_total > 0)
            @as(f32, @floatFromInt(stats.memory_used)) / @as(f32, @floatFromInt(stats.memory_total))
        else 0.0;
        
        // Count processes
        var proc_dir = try std.fs.openIterableDirAbsolute("/proc", .{});
        defer proc_dir.close();
        
        var count: u32 = 0;
        var iter = proc_dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .directory) {
                // Check if directory name is a number (PID)
                _ = std.fmt.parseInt(u32, entry.name, 10) catch continue;
                count += 1;
            }
        }
        stats.process_count = count;
        
        return stats;
    }
    
    fn parseVmStatLine(line: []const u8) !u64 {
        var parts = std.mem.tokenizeAny(u8, line, ": .");
        _ = parts.next(); // Skip label
        if (parts.next()) |value_str| {
            return std.fmt.parseInt(u64, value_str, 10) catch 0;
        }
        return 0;
    }
    
    fn parseMemInfoLine(line: []const u8) !u64 {
        var parts = std.mem.tokenizeAny(u8, line, ": kB");
        _ = parts.next(); // Skip label
        if (parts.next()) |value_str| {
            return std.fmt.parseInt(u64, value_str, 10) catch 0;
        }
        return 0;
    }
};