const std = @import("std");

pub const parser = @import("parser.zig");
pub const scheduler = @import("scheduler.zig");
pub const runner = @import("runner.zig");

// C-ABI Exported Interface
pub export fn zigcron_version() [*:0]const u8 {
    return "0.2.0";
}

test "parse rate expressions" {
    const s1 = try scheduler.ParsedSchedule.parse("rate(10 seconds)");
    try std.testing.expectEqual(@as(u64, 10), s1.interval_seconds);

    const s2 = try scheduler.ParsedSchedule.parse("rate(1 hour)");
    try std.testing.expectEqual(@as(u64, 3600), s2.interval_seconds);
}

test "parse schedules json" {
    const allocator = std.testing.allocator;
    const json_data =
        \\[
        \\  {
        \\    "id": 1,
        \\    "name": "test-job",
        \\    "state": "ENABLED",
        \\    "schedule": "rate(5 seconds)",
        \\    "target": { "command": "echo 'hello'" },
        \\    "flexible_time_window": { "mode": "FLEXIBLE", "maximum_window_seconds": 2 }
        \\  }
        \\]
    ;

    const parsed = try parser.parseSchedules(allocator, json_data);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 1), parsed.value.len);
    try std.testing.expectEqualStrings("test-job", parsed.value[0].name);
    try std.testing.expectEqual(parser.State.ENABLED, parsed.value[0].state);
}