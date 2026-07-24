const std = @import("std");
const zigcron = @import("zigcron");

pub const std_options: std.Options = .{
    .log_level = .info,
    .logFn = struct {
        fn log(
            comptime level: std.log.Level,
            comptime scope: @TypeOf(.EnumLiteral),
            comptime format: []const u8,
            args: anytype,
        ) void {
            _ = scope;
            // 1. Output to standard console
            std.log.defaultLog(level, .default, format, args);

            // 2. Open or create zigcron.log in current working directory
            var file = std.fs.cwd().openFile("zigcron.log", .{ .mode = .read_write }) catch |err| switch (err) {
                error.FileNotFound => std.fs.cwd().createFile("zigcron.log", .{}) catch return,
                else => return,
            };
            defer file.close();

            file.seekFromEnd(0) catch return;

            var buf: [2048]u8 = undefined;
            const formatted = std.fmt.bufPrint(&buf, "[" ++ @tagName(level) ++ "] " ++ format ++ "\n", args) catch return;
            _ = file.writeAll(formatted) catch return;
        }
    }.log,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip(); // skip binary name

    const config_path = args.next() orelse "schedules.json";

    std.log.info("Starting zigcron daemon (AWS EventBridge compatible)...", .{});
    std.log.info("Loading config file: {s}", .{config_path});

    const file_contents = std.fs.cwd().readFileAlloc(allocator, config_path, 1024 * 1024) catch |err| {
        std.log.err("Failed to open configuration file '{s}': {any}", .{ config_path, err });
        return err;
    };
    defer allocator.free(file_contents);

    const parsed = try zigcron.parser.parseSchedules(allocator, file_contents);
    defer parsed.deinit();

    var runtimes = std.ArrayList(zigcron.scheduler.ScheduleRuntime).init(allocator);
    defer runtimes.deinit();

    for (parsed.value) |config| {
        const parsed_sched = zigcron.scheduler.ParsedSchedule.parse(config.schedule) catch |err| {
            std.log.err("Skipping schedule '{s}': Invalid schedule string '{s}' ({any})", .{ config.name, config.schedule, err });
            continue;
        };

        try runtimes.append(.{
            .config = config,
            .interval_seconds = parsed_sched.interval_seconds,
            .last_run_timestamp = 0,
        });

        std.log.info("Registered task [{d}] '{s}' | State: {s} | Schedule: {s}", .{
            config.id,
            config.name,
            @tagName(config.state),
            config.schedule,
        });
    }

    var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));

    std.log.info("Daemon active. Running main tick loop...", .{});

    while (true) {
        const now = std.time.timestamp();

        for (runtimes.items) |*item| {
            if (item.shouldRun(now)) {
                const jitter = item.calculateJitterDelay(prng.random());
                if (jitter > 0) {
                    std.log.info("[{s}] Flexible window jitter offset: {d}s", .{ item.config.name, jitter });
                    std.time.sleep(jitter * std.time.ns_per_s);
                }

                std.log.info("Triggering schedule: '{s}'...", .{item.config.name});
                const res = try zigcron.runner.executeTarget(allocator, item.config);
                item.last_run_timestamp = std.time.timestamp();

                std.log.info("Completed '{s}' in {d}ms (exit code: {d})", .{
                    item.config.name,
                    res.duration_ms,
                    res.exit_code,
                });
            }
        }

        std.time.sleep(1 * std.time.ns_per_s);
    }
}