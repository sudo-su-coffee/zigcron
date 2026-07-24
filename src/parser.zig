const std = @import("std");

pub const State = enum {
    ENABLED,
    DISABLED,
};

pub const MisfirePolicy = enum {
    fire_immediately,
    skip_missed,
    catchup_all,
};

pub const FlexibleWindowMode = enum {
    OFF,
    FLEXIBLE,
};

pub const FlexibleTimeWindow = struct {
    mode: FlexibleWindowMode = .OFF,
    maximum_window_seconds: u32 = 0,
};

pub const RetryPolicy = struct {
    maximum_retry_attempts: u32 = 185,
    maximum_event_age_seconds: u32 = 86400,
};

pub const ResourceLimits = struct {
    max_memory_mb: u32 = 128,
    timeout_ms: u64 = 30000,
};

pub const Target = struct {
    command: []const u8,
    input: ?[]const u8 = null,
};

pub const DeadLetterConfig = struct {
    path: []const u8,
};

pub const ScheduleConfig = struct {
    id: u64,
    name: []const u8,
    state: State = .ENABLED,
    schedule: []const u8,
    timezone: []const u8 = "UTC",
    start_date: ?[]const u8 = null,
    end_date: ?[]const u8 = null,
    target: Target,
    flexible_time_window: FlexibleTimeWindow = .{},
    retry_policy: RetryPolicy = .{},
    misfire_policy: MisfirePolicy = .fire_immediately,
    dead_letter_config: ?DeadLetterConfig = null,
    resources: ResourceLimits = .{},
};

pub fn parseSchedules(allocator: std.mem.Allocator, json_raw: []const u8) !std.json.Parsed([]ScheduleConfig) {
    return std.json.parseFromSlice([]ScheduleConfig, allocator, json_raw, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
}