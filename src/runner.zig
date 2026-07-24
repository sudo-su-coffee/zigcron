const std = @import("std");
const parser = @import("parser.zig");

pub const ExecutionResult = struct {
    exit_code: u8,
    duration_ms: i64,
    timed_out: bool,
};

pub fn executeTarget(
    allocator: std.mem.Allocator,
    config: parser.ScheduleConfig,
) !ExecutionResult {
    var attempt: u32 = 0;
    const max_attempts = config.retry_policy.maximum_retry_attempts;

    const start_time = std.time.milliTimestamp();

    while (attempt <= max_attempts) : (attempt += 1) {
        if (attempt > 0) {
            std.log.warn("[{s}] Retry attempt {d}/{d}...", .{ config.name, attempt, max_attempts });
            std.time.sleep(1 * std.time.ns_per_s); // Exponential / linear delay
        }

        var child = std.process.Child.init(&[_][]const u8{ "sh", "-c", config.target.command }, allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();

        // Write target input payload to child stdin if provided
        if (config.target.input) |input_payload| {
            if (child.stdin) |*stdin| {
                _ = stdin.writeAll(input_payload) catch {};
                stdin.close();
                child.stdin = null;
            }
        }

        const term = try child.wait();
        const end_time = std.time.milliTimestamp();
        const duration = end_time - start_time;

        switch (term) {
            .Exited => |code| {
                if (code == 0) {
                    return ExecutionResult{ .exit_code = 0, .duration_ms = duration, .timed_out = false };
                }
            },
            else => {},
        }
    }

    // Retries exhausted -> Write to Dead-Letter Queue (DLQ) if configured
    if (config.dead_letter_config) |dlq| {
        try logToDLQ(allocator, dlq.path, config, "Execution failed after exhausting retry attempts.");
    }

    return ExecutionResult{ .exit_code = 1, .duration_ms = std.time.milliTimestamp() - start_time, .timed_out = false };
}

fn logToDLQ(allocator: std.mem.Allocator, path: []const u8, config: parser.ScheduleConfig, reason: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{ .truncate = false });
    defer file.close();
    try file.seekFromEnd(0);

    const log_entry = try std.fmt.allocPrint(allocator,
        \\{{"timestamp": {d}, "schedule_id": {d}, "name": "{s}", "reason": "{s}"}}
        \\
    , .{ std.time.timestamp(), config.id, config.name, reason });
    defer allocator.free(log_entry);

    _ = try file.writeAll(log_entry);
    std.log.err("[DLQ] Failure event dispatched to {s} for schedule '{s}'", .{ path, config.name });
}