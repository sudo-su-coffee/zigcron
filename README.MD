# ⚡ zigcron

**Sub-Millisecond, Zero-Dependency Cloud-Native Job Scheduler & Event Engine.**

`zigcron` is a high-performance, embeddable Zig scheduler and lightweight CLI daemon. It brings modern cloud scheduling primitives—inspired by **AWS EventBridge Scheduler**—directly into standalone applications, background daemons, and containerized environments without relying on external system services or legacy OS `crontab`.

---

## 🎯 Key Capabilities & Features

`zigcron` natively implements enterprise scheduling primitives inspired by AWS EventBridge Scheduler:

### 1. ⚡ Rate Expressions (`rate()`)
Human-readable fixed-interval execution rules:
* `rate(10 seconds)`
* `rate(5 minutes)`
* `rate(12 hours)`

### 2. 🔀 Flexible Time Windows (Jitter Control)
Prevent downstream "thundering herd" bottlenecks by randomizing execution offsets using `flexible_time_window`:
```json
"flexible_time_window": {
  "mode": "FLEXIBLE",
  "maximum_window_seconds": 10
}

```

### 3. 🔁 Automatic Retries & Dead-Letter Queues (DLQ)

When a task fails, `zigcron` retries up to `maximum_retry_attempts`. If retries are exhausted, the failure event is automatically written to a configured DLQ JSON file for post-mortem analysis.

### 4. 📝 Built-in File Logging (`zigcron.log`)

The daemon automatically creates and appends logs to `zigcron.log` in its current working directory while simultaneously streaming formatted output to stdout/stderr.

### 5. 🎯 Execution Payloads & Limits

Pass structured JSON payloads directly to target standard input and set per-task resource ceilings (`timeout_ms`, `max_memory_mb`).

### 6. 🔌 C-ABI Shared Library (`libzigcron.so`)

Compiled directly to a dynamic shared object (`.so` / `.dll` / `.dylib`) for seamless integration into **C, C++, Python, Rust, Go, or Node.js** via FFI.

---

## 📊 Feature Matrix

| Feature | Legacy OS Cron | AWS EventBridge | `zigcron` Engine |
| --- | --- | --- | --- |
| **Dependencies** | Requires `crond` | AWS Cloud Service | **Zero-Dependency Native Binary** |
| **Rates (`rate()`)** | ❌ No | ✅ Yes | ✅ **Supported** |
| **Jitter / Windows** | ❌ Manual `sleep` hacks | ✅ Built-in | ✅ **Supported (`flexible_time_window`)** |
| **Dead-Letter Queue** | ❌ No | ✅ SQS / EventBridge | ✅ **Built-in File/Log DLQ** |
| **Automatic Logging** | ❌ System mail / standard | ✅ CloudWatch | ✅ **Built-in (`zigcron.log`)** |
| **Binary Footprint** | System package | N/A (SaaS) | **~350 KB Executable** |
| **Execution Latency** | Seconds | Sub-second | **Sub-Millisecond** |

---

## 🛠️ Build Commands

```bash
# 1. Run unit tests
zig build test

# 2. Build executable & C shared library (.so)
zig build

# 3. Build optimized production binary (< 400KB)
zig build -Doptimize=ReleaseSmall

# 4. Cross-compile for Linux ARM64 (AWS Graviton)
zig build -Dtarget=aarch64-linux-gnu -Doptimize=ReleaseSmall

```

Binary outputs:

* **Executable Daemon:** `./zig-out/bin/zigcron`
* **C Shared Object:** `./zig-out/lib/libzigcron.so`

---

## 🚀 Daemon Execution & Production Setup

### Option A: Running as a Background Daemon

Pass your configuration file path directly to `zigcron`. It automatically handles writing structured states to `zigcron.log`:

```bash
# Start zigcron in the background
./zig-out/bin/zigcron schedules.json &

# Monitor auto-generated execution logs in real-time
tail -f zigcron.log

```

### Option B: Systemd Daemon Service (Ubuntu / Debian / Kali)

For production Linux deployments, manage `zigcron` using `systemd`. Create `/etc/systemd/system/zigcron.service`:

```ini
[Unit]
Description=Zigcron Event Bridge Job Scheduler Daemon
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/zigcron
ExecStart=/opt/zigcron/zig-out/bin/zigcron /opt/zigcron/schedules.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target

```

Enable and start the daemon:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now zigcron

```

Check status and inspect auto-generated logs:

```bash
sudo systemctl status zigcron
tail -f /opt/zigcron/zigcron.log

```

---

## 🚦 Configuration Format (`schedules.json`)

```json
[
  {
    "id": 1,
    "name": "critical-db-backup",
    "state": "ENABLED",
    "schedule": "rate(1 hour)",
    "timezone": "UTC",
    "target": {
      "command": "echo 'Running DB backup...'",
      "input": "{\"db_name\": \"production_v2\"}"
    },
    "flexible_time_window": {
      "mode": "FLEXIBLE",
      "maximum_window_seconds": 5
    },
    "retry_policy": {
      "maximum_retry_attempts": 3,
      "maximum_event_age_seconds": 3600
    },
    "misfire_policy": "fire_immediately",
    "dead_letter_config": {
      "path": "/tmp/zigcron_dlq.json"
    },
    "resources": {
      "max_memory_mb": 512,
      "timeout_ms": 60000
    }
  }
]

```

---

## 🔌 C-ABI & Shared Library Usage (`libzigcron.so`)

Link `libzigcron.so` in C/C++ or load dynamically via Python `ctypes`:

### Python FFI Example (`test_zigcron.py`)

```python
import ctypes

# Load the dynamic library compiled by Zig
lib = ctypes.CDLL("./zig-out/lib/libzigcron.so")

# Configure return type for string export
lib.zigcron_version.restype = ctypes.c_char_p

# Call Zig C-ABI export
version = lib.zigcron_version().decode("utf-8")
print(f"Loaded zigcron shared library version: {version}")

```

---

## 📜 License

[MIT License](https://www.google.com/search?q=LICENSE)
