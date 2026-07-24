# ⚡ zigcron

**Sub-Millisecond, Zero-Dependency Cloud-Native Job Scheduler & Event Engine.**

`zigcron` is a high-performance, embeddable Zig scheduler and lightweight CLI daemon. It brings modern cloud scheduling primitives—inspired by **AWS EventBridge Scheduler**—directly into standalone Zig applications and containerized environments without relying on external system services or legacy OS `crontab`.

---

## 🎯 Key Capabilities & Scheduling Patterns

`zigcron` supports four distinct schedule types alongside enterprise resilience controls:

### 1. 🕒 Standard & Extended Cron Expressions
Evaluates standard 5-part UNIX cron syntax as well as extended expressions:
* `0 10 * * ? *` → Every day at 10:00 AM
* `*/15 * * * *` → Every 15 minutes

### 2. ⚡ Rate Expressions (`rate()`)
Human-readable fixed interval schedules:
* `rate(5 minutes)`
* `rate(12 hours)`
* `rate(7 days)`

### 3. 🎯 One-Time Execution (`at()`)
Schedule a job to fire exactly once at a specific UTC or local ISO-8601 timestamp:
* `at(2026-08-01T14:30:00Z)`

### 4. 🔀 Flexible Time Windows (Jitter Control)
Avoid downstream "thundering herd" bottlenecks by specifying a randomized execution window:
* `flexible_window: 300s` → Randomizes execution within a 5-minute window following the trigger time.

### 5. 🌍 Timezone & DST Awareness
Schedule events relative to local timezones rather than hardcoding UTC offsets:
* `.timezone = "America/New_York"`

### 6. 🔄 Automatic Retries & DLQ Handlers
Configurable exponential backoff retries and Dead-Letter Queue (DLQ) routing for failed tasks.

---

## ✨ Why `zigcron` vs. Traditional Cron?

| Feature | Legacy OS Cron | AWS EventBridge | `zigcron` Engine |
| :--- | :--- | :--- | :--- |
| **Dependencies** | Requires `crond` daemon | AWS Cloud Service | **Zero-Dependency Native Zig** |
| **Rates (`rate()`)** | ❌ No | ✅ Yes | ✅ **Supported** |
| **One-time (`at()`)** | ❌ No (requires `atd`) | ✅ Yes | ✅ **Supported** |
| **Jitter / Windows** | ❌ Manual `sleep` hacks | ✅ Built-in | ✅ **Built-in** |
| **Binary Footprint** | System package | N/A (SaaS) | **~350 KB Executable** |
| **Execution Latency**| Seconds | Sub-second | **Sub-Millisecond** |

---

## 🛠️ Usage for Zig Developers (Library Import)

### Step 1: Import in `main.zig`

```zig
const std = @import("std");
const zigcron = @import("zigcron");

pub fn myTask(ctx: *anyopaque) void {
    _ = ctx;
    std.debug.print("🚀 Executing scheduled job!\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var scheduler = zigcron.Scheduler.init(allocator);
    defer scheduler.deinit();

    // 1. Add a Rate Schedule
    try scheduler.addJob(.{
        .name = "cache-cleanup",
        .schedule = try zigcron.Schedule.parse("rate(5 minutes)"),
        .handler = myTask,
        .jitter_seconds = 30, // Randomize within 30s window
    });

    // 2. Add a One-Time Schedule
    try scheduler.addJob(.{
        .name = "database-migration",
        .schedule = try zigcron.Schedule.parse("at(2026-12-31T23:59:59Z)"),
        .handler = myTask,
    });

    // Start background event loop
    try scheduler.start();
}

```

---

## 🚦 CLI Daemon Usage

Run `zigcron` as a lightweight standalone scheduler daemon using a simple JSON configuration:

```bash
zigcron --config schedules.json

```

**`schedules.json` Example:**

```json
[
  {
    "name": "nightly-backup",
    "schedule": "cron(0 2 * * ? *)",
    "command": "/bin/sh -c 'backup.sh'",
    "flexible_window_minutes": 15,
    "max_retries": 3
  },
  {
    "name": "metrics-flush",
    "schedule": "rate(10 seconds)",
    "command": "curl -X POST http://localhost:8080/flush"
  }
]

```

---

## 📜 License

[MIT License](https://www.google.com/search?q=LICENSE)
