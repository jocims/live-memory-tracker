#!/bin/bash

# Target Python binary on WP Engine
PYTHON_BIN="/usr/local/bin/redshell/rsh_python/bin/python3"

# Fallback to system python3 if WP Engine custom path doesn't exist
if [ ! -f "$PYTHON_BIN" ]; then
    PYTHON_BIN="python3"
fi

$PYTHON_BIN - << 'EOF'
import re, time, os, glob, signal, sys
from collections import defaultdict
from urllib.parse import urlparse, parse_qs

# Prompt user for space-separated install names
print("Enter target install names separated by spaces (e.g. jocitest sprungservice1 dt2025):")
try:
    user_input = input("Installs > ").strip()
    if not user_input:
        print("❌ No installs entered. Exiting.")
        sys.exit(1)
    TARGET_INSTALLS = [inst.strip() for inst in user_input.split() if inst.strip()]
except (KeyboardInterrupt, EOFError):
    print("\nExiting.")
    sys.exit(0)

MU_PLUGIN_CODE = """<?php
/**
 * Plugin Name: Live RAM Monitor (Temporary)
 * Description: Auto-deployed diagnostic logger for real-time memory monitoring.
 */

add_action('shutdown', function() {
    $mem = round(memory_get_peak_usage(true) / 1024 / 1024, 2);

    if ($mem >= 15) {
        $uri =$_SERVER['REQUEST_URI'] ?? 'CLI';
        $act =$_REQUEST['action'] ?? null;
        
        if ($act && strpos($uri, 'admin-ajax.php') !== false && strpos($uri, 'action=') === false) {$uri .= (strpos($uri, '?') !== false ? '&' : '?') . 'action=' . urlencode($act);
        }
        
        if ($act) {
            error_log(sprintf("[RAM-CHECK] %.2f MB | URI: %s | Action: %s", $mem, $uri,$act));
        } else {
            error_log(sprintf("[RAM-CHECK] %.2f MB | URI: %s", $mem,$uri));
        }
    }
});
"""

def normalize_uri(uri, action=None):
    """Strips dynamic query strings, normalizes REST API routes, and preserves AJAX actions."""
    parsed = urlparse(uri)
    base_path = parsed.path
    query_params = parse_qs(parsed.query)

    if "admin-ajax.php" in base_path:
        act_name = None
        if 'action' in query_params:
            act_name = query_params['action'][0]
        elif action and action != 'N/A':
            act_name = action

        if act_name:
            return f"/wp-admin/admin-ajax.php?action={act_name}"
        return base_path

    if "/wp-json/jetpack/" in base_path:
        parts = base_path.split("/")
        if len(parts) > 5:
            return "/".join(parts[:5]) + "/*"
        return base_path
    elif "/wp-json/" in base_path:
        parts = base_path.split("/")
        if len(parts) > 4:
            return "/".join(parts[:4]) + "/*"
        return base_path

    return base_path if base_path else "/"

def deploy_plugins():
    print(f"\n🚀 Deploying monitor plugin to specified installs: {', '.join(TARGET_INSTALLS)}...")
    valid_installs = []
    for install in TARGET_INSTALLS:
        mu_dir = f"/nas/content/live/{install}/wp-content/mu-plugins"
        if os.path.isdir(mu_dir):
            try:
                with open(os.path.join(mu_dir, "00-live-ram-tracker.php"), "w") as f:
                    f.write(MU_PLUGIN_CODE)
                print(f"  ✅ Deployed to {install}")
                valid_installs.append(install)
            except Exception as e:
                print(f"  ❌ Failed to deploy to {install}: {e}")
        else:
            print(f"  ⚠️ MU-plugins folder not found for: {install}")
    return valid_installs

def cleanup():
    print("\n🧹 Cleaning up temporary MU-plugins and temporary files...")
    for install in TARGET_INSTALLS:
        target = f"/nas/content/live/{install}/wp-content/mu-plugins/00-live-ram-tracker.php"
        if os.path.exists(target):
            try:
                os.remove(target)
            except Exception:
                pass
    if os.path.exists("/tmp/ram_monitor_results.log"):
        try:
            os.remove("/tmp/ram_monitor_results.log")
        except Exception:
            pass
    print("✅ Cleanup complete.")

active_targets = deploy_plugins()
if not active_targets:
    print("❌ No valid target installs found. Exiting.")
    cleanup()
    sys.exit(1)

install_data = defaultdict(lambda: {"snaps": 0, "total_mem": 0.0, "peak_mem": 0.0, "heaviest_mem": 0.0, "heaviest_uri": "-"})
smart_data = defaultdict(lambda: {"snaps": 0, "total_mem": 0.0, "peak_mem": 0.0})
raw_data = defaultdict(lambda: {"snaps": 0, "total_mem": 0.0, "peak_mem": 0.0})

start_time = time.strftime('%Y-%m-%d %H:%M:%S')
output_log = "/tmp/ram_monitor_results.log"

log_pattern = re.compile(r'\[RAM-CHECK\]\s+([\d.]+)\s*MB\s+\|\s+URI:\s+(\S+)(?:\s+\|\s+Action:\s+(\S+))?')

def render_table():
    current_time = time.strftime('%Y-%m-%d %H:%M:%S')
    os.system('clear')
    
    TABLE_WIDTH = 160
    URI_MAX_LEN = 75

    header1 = f"🔴 TARGETED PHP MEMORY MONITOR | MONITORED: {', '.join(active_targets)} | STARTED: {start_time} | LAST UPDATE: {current_time}\n" + "=" * TABLE_WIDTH + "\n"
    header1 += "📊 TABLE 1: INSTALL TOTALS (CUMULATIVE SITE RAM USAGE)\n" + "-" * TABLE_WIDTH + "\n"
    cols1 = "%-20s | %-6s | %-12s | %-12s | %-13s | %s\n" % (
        "INSTALL", "SNAPS", "AVG MEM(MB)", "PEAK MEM(MB)", "TOTAL MEM(MB)", "HEAVIEST URI"
    )
    divider = "-" * TABLE_WIDTH + "\n"

    table_text = header1 + cols1 + divider

    if install_data:
        sorted_installs = sorted(install_data.items(), key=lambda x: x[1]["total_mem"], reverse=True)[:5]
        for name, stats in sorted_installs:
            avg_mem = stats["total_mem"] / stats["snaps"] if stats["snaps"] > 0 else 0.0
            short_uri = (stats["heaviest_uri"][:URI_MAX_LEN] + "...") if len(stats["heaviest_uri"]) > URI_MAX_LEN else stats["heaviest_uri"]
            table_text += "%-20s | %-6d | %12.2f | %12.2f | %13.2f | %s\n" % (
                name, stats["snaps"], avg_mem, stats["peak_mem"], stats["total_mem"], short_uri
            )
    else:
        table_text += f"Waiting for incoming PHP traffic >=15MB on [{', '.join(active_targets)}]...\n"

    table_text += "=" * TABLE_WIDTH + "\n\n"

    header2 = "🧠 TABLE 2: SMART AGGREGATED ENDPOINTS (NORMALIZED ROUTES & AJAX ACTIONS)\n" + "-" * TABLE_WIDTH + "\n"
    cols2 = "%-20s | %-6s | %-12s | %-12s | %-13s | %s\n" % (
        "INSTALL", "SNAPS", "AVG MEM(MB)", "PEAK MEM(MB)", "TOTAL MEM(MB)", "BASE ROUTE / ENDPOINT"
    )

    table_text += header2 + cols2 + divider

    if smart_data:
        sorted_smart = sorted(smart_data.items(), key=lambda x: x[1]["total_mem"], reverse=True)[:10]
        for (install_name, route), stats in sorted_smart:
            avg_mem = stats["total_mem"] / stats["snaps"] if stats["snaps"] > 0 else 0.0
            short_route = (route[:URI_MAX_LEN] + "...") if len(route) > URI_MAX_LEN else route
            table_text += "%-20s | %-6d | %12.2f | %12.2f | %13.2f | %s\n" % (
                install_name, stats["snaps"], avg_mem, stats["peak_mem"], stats["total_mem"], short_route
            )
    else:
        table_text += "Waiting for smart endpoint data...\n"

    table_text += "=" * TABLE_WIDTH + "\n\n"

    header3 = "🔍 TABLE 3: RAW SPECIFIC REQUEST URIs (UNMODIFIED EXACT PATHS)\n" + "-" * TABLE_WIDTH + "\n"
    cols3 = "%-20s | %-6s | %-12s | %-12s | %-13s | %s\n" % (
        "INSTALL", "SNAPS", "AVG MEM(MB)", "PEAK MEM(MB)", "TOTAL MEM(MB)", "RAW EXACT URI"
    )

    table_text += header3 + cols3 + divider

    if raw_data:
        sorted_raw = sorted(raw_data.items(), key=lambda x: x[1]["total_mem"], reverse=True)[:10]
        for (install_name, uri), stats in sorted_raw:
            avg_mem = stats["total_mem"] / stats["snaps"] if stats["snaps"] > 0 else 0.0
            short_uri = (uri[:URI_MAX_LEN] + "...") if len(uri) > URI_MAX_LEN else uri
            table_text += "%-20s | %-6d | %12.2f | %12.2f | %13.2f | %s\n" % (
                install_name, stats["snaps"], avg_mem, stats["peak_mem"], stats["total_mem"], short_uri
            )
    else:
        table_text += "Waiting for raw URI data...\n"

    table_text += "=" * TABLE_WIDTH + "\n"

    print(table_text)
    print("Press [Ctrl+C] to stop and automatically remove all MU-plugins and temp files.")

    try:
        with open(output_log, "a") as out_f:
            out_f.write(table_text + "\n")
    except Exception:
        pass

file_pointers = {}
for install in active_targets:
    filepath = f"/var/log/apache2/{install}.error.log"
    if os.path.exists(filepath):
        try:
            f = open(filepath, "r", encoding="utf-8", errors="ignore")
            f.seek(0, 2)
            file_pointers[filepath] = (f, install)
        except Exception:
            continue

render_table()

try:
    while True:
        updated = False
        for filepath, (f, install_name) in file_pointers.items():
            while True:
                line = f.readline()
                if not line:
                    break
                match = log_pattern.search(line)
                if match:
                    mem = float(match.group(1))
                    raw_uri = match.group(2)
                    action_val = match.group(3) if match.group(3) else None
                    
                    norm_route = normalize_uri(raw_uri, action_val)
                    
                    install_data[install_name]["snaps"] += 1
                    install_data[install_name]["total_mem"] += mem
                    install_data[install_name]["peak_mem"] = max(install_data[install_name]["peak_mem"], mem)
                    if mem > install_data[install_name]["heaviest_mem"]:
                        install_data[install_name]["heaviest_uri"] = norm_route

                    smart_key = (install_name, norm_route)
                    smart_data[smart_key]["snaps"] += 1
                    smart_data[smart_key]["total_mem"] += mem
                    smart_data[smart_key]["peak_mem"] = max(smart_data[smart_key]["peak_mem"], mem)

                    raw_key = (install_name, raw_uri)
                    raw_data[raw_key]["snaps"] += 1
                    raw_data[raw_key]["total_mem"] += mem
                    raw_data[raw_key]["peak_mem"] = max(raw_data[raw_key]["peak_mem"], mem)

                    updated = True

        render_table()
        time.sleep(3)
except KeyboardInterrupt:
    pass
finally:
    for f, _ in file_pointers.values():
        f.close()
    cleanup()
    sys.exit(0)
EOF