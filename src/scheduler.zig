const std = @import("std");
const parser = @import("parser.zig");
const runner = @import("runner.zig");

pub const RateUnit = enum { seconds, minutes, hours };

pub const ParsedSchedule = struct {
    interval_seconds: u64,

    pub fn parse(expr: []const u8) !ParsedSchedule {
        if (!std.mem.startsWith(u8, expr, "rate(") or !std.mem.endsWith(u8, expr, ")")) {
            return error.InvalidScheduleFormat;
        }

        const inner = expr[5 .. expr.len - 1];
        var iter = std.mem.tokenizeScalar(u8, inner, ' ');
        const amount_str = iter.next() orelse return error.InvalidScheduleFormat;
        const unit_str = iter.next() orelse return error.InvalidScheduleFormat;

        const amount = try std.fmt.parseInt(u64, amount_str, 10);
        var multiplier: u64 = 1;

        if (std.mem.startsWith(u8, unit_str, "second")) {
            multiplier = 1;
        } else if (std.mem.startsWith(u8, unit_str, "minute")) {
            multiplier = 60;
        } else if (std.mem.startsWith(u8, unit_str, "hour")) {
            multiplier = 3600;
        } else {
            return error.UnknownRateUnit;
        }

        return ParsedSchedule{ .interval_seconds = amount * multiplier };
    }
};

pub const ScheduleRuntime = struct {
    config: parser.ScheduleConfig,
    interval_seconds: u64,
    last_run_timestamp: i64 = 0,

    pub fn shouldRun(self: *ScheduleRuntime, current_time: i64) bool {
        // 1. Check if disabled
        if (self.config.state == .DISABLED) return false;

        // 2. Check elapsed interval
        if (current_time - self.last_run_timestamp < @as(i64, @intCast(self.interval_seconds))) {
            return false;
        }

        return true;
    }

    pub fn calculateJitterDelay(self: *const ScheduleRuntime, random: std.Random) u64 {
        if (self.config.flexible_time_window.mode == .FLEXIBLE and self.config.flexible_time_window.maximum_window_seconds > 0) {
            return random.uintAtMost(u64, self.config.flexible_time_window.maximum_window_seconds);
        }
        return 0;
    }
};