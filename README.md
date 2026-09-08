# WP Engine Live RAM Monitor

A zero-footprint, real-time PHP memory monitoring tool designed for WP Engine server pods. It deploys a temporary Must-Use (MU) plugin to capture peak memory usage per request directly from PHP's Zend Engine, streams metrics from Apache error logs, and displays a live 3-table dashboard in your terminal.

---

## Features

- **Interactive Target Selection:** Prompts for space-separated install names upon execution.
- **Zero Persistent Log Footprint:** Streams diagnostic metrics to temporary log handlers and guarantees complete removal of all files upon exit.
- **Smart Route & Action Aggregation:** Strips dynamic query strings (`?_cacheBuster=...`), normalizes versioned REST API routes (`/wp-json/*`), and captures both GET and POST `admin-ajax.php` actions.
- **Real-Time 3-Table Dashboard:**
  1. **Install Totals:** Cumulative RAM usage, request snapshots, average RAM, and site peak RAM.
  2. **Smart Aggregated Endpoints:** Normalized routes and specific AJAX actions ranked by RAM impact.
  3. **Raw URIs:** Exact, unmodified request paths for precise URL debugging.
- **Auto-Destruction on Exit:** Intercepts `Ctrl+C` signals to automatically purge injected `00-live-ram-tracker.php` plugins and temporary files across all target installs.

---

## Usage Methods

Choose either **Method A** (saving and running the script file) or **Method B** (running a one-liner command directly in SSH).

### Method A: Running as a Script File (Recommended)

1. **Upload or Save the File:**  
   Save the script as `live_ram_monitor.py` or `live_ram_monitor.sh` on your server.

2. **Run via Python:**
   ```bash
   /usr/local/bin/redshell/rsh_python/bin/python3 live_ram_monitor.py