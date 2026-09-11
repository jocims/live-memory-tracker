# WP Engine Live RAM Monitor

A zero-footprint, real-time PHP memory monitoring suite designed for WP Engine server pods. It deploys a temporary Must-Use (MU) plugin (`00-live-ram-tracker.php`) to capture peak RAM consumption per request directly from PHP's Zend Engine, streams metrics from Apache error logs, and displays a live 3-table terminal dashboard.

---

## Repository Files

| File | Scope & Execution Behavior |
| :--- | :--- |
| `README.md` | Usage guide and operational overview. |
| `live_ram_monitor_list.txt` | **Targeted Mode:** Prompts you to enter a list of specific install names **separated by spaces**. |
| `live_ram_monitor.txt` | **Server-Wide Mode:** Automatically runs across **all live installs on the entire server**. |

---

## Key Differences Between Options

- **`live_ram_monitor_list.txt` (Targeted):**
  When you execute this command, the script pauses and asks you to type or paste target install names separated by spaces (for example: `install1 install2 install3`). It deploys the diagnostic plugin and monitors error logs **only** for those specified sites.

- **`live_ram_monitor.txt` (Pod-Wide):**
  When you execute this command, it bypasses the prompt and automatically deploys the diagnostic plugin across every active site path (`/nas/content/live/*`) on the server pod simultaneously.

---

## Features

- **Zero Persistent Overhead:** Hooks into `shutdown` via a temporary MU-plugin to read `memory_get_peak_usage(true)`.
- **Smart Endpoint & Action Normalization:** Strips cache busters (`?_cacheBuster=...`), groups versioned REST routes (`/wp-json/*`), and captures both GET and POST `admin-ajax.php` actions (`?action=...`).
- **Real-Time 3-Table Dashboard:**
  1. **Install Totals:** Cumulative RAM usage, request snapshots, average RAM, and site peak RAM.
  2. **Smart Aggregated Endpoints:** Normalized routes and specific AJAX actions ranked by total RAM impact.
  3. **Raw Specific URIs:** Exact, unmodified request paths for precise URL debugging.
- **Auto-Destruction on Exit:** Pressing `Ctrl+C` immediately triggers cleanup, unlinking all `00-live-ram-tracker.php` files and purging temporary files from `/tmp/`.

---

## How to Run

Copy the full text contents from either `.txt` file and paste it directly into your SSH terminal session.

### Option 1: Targeted Installs (`live_ram_monitor_list.txt`)
Use this option to monitor specific WordPress sites on the pod without attaching handlers to unneeded installs.

1. Open and copy the full contents of `live_ram_monitor_list.txt`.
2. Paste it directly into your terminal and press **Enter**.
3. When prompted, enter your target install names separated by spaces:
   ```text
   Enter target install names separated by spaces (e.g. install1 install2 install3):
   Installs > install1 install2 install3