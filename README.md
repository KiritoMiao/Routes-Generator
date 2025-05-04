## BIRD Routes Generator

This project provides a dynamic route generator for [BIRD](https://bird.network.cz/) that fetches a IP ranges and automatically generates BIRD-compatible static route configuration files. It supports reverse mode, optional BIRD reload, and Telegram alerts.

---

### 📦 Features

* Downloads a txt IP ranges, default from [chnroutes2](https://github.com/misakaio/chnroutes2)
* Converts IPs to BIRD `route ... via` statements
* Supports reverse mode: generate routes **excluding** the ip list
* Optionally reloads BIRD after config generation
* Telegram integration for notifications
* systemd service and timer for automatic scheduling

---

### 📁 File Structure

All files are located under [`bird/`](https://github.com/KiritoMiao/Routes-Generator/tree/main/bird):

| File                           | Purpose                                      |
| ------------------------------ | -------------------------------------------- |
| `generate_bird_routes.py`      | Main route generation script                 |
| `generate-bird-routes.service` | systemd service to run the script            |
| `generate-bird-routes.timer`   | systemd timer to schedule it (daily @ 03:00) |
| `setup-bird-routes.sh`         | Interactive installer and configurator       |

---

### ⚙️ Installation

```bash
git clone https://github.com/KiritoMiao/Routes-Generator.git
cd Routes-Generator/bird
chmod +x setup-bird-routes.sh
sudo ./setup-bird-routes.sh
```

The setup script will:

* Download and install the Python script + systemd units
* Ask you to input:

  * Network interface for routing
  * Whether to reload BIRD after changes
  * Telegram bot config (optional)
* Configure the script
* Reload systemd and offer to run a test

---

### 🔄 Manual Usage

To test manually:

```bash
sudo systemctl start generate-bird-routes.service
```

To enable daily scheduled updates:

```bash
sudo systemctl enable --now generate-bird-routes.timer
```

To check logs:

```bash
journalctl -u generate-bird-routes.service
```

---

### ⚙️ Configuration

Edit `/etc/bird/generate_bird_routes.py` to change:

* `OUT_INTERFACE` – output interface (e.g. `eth0`, `wg0`)
* `REVERSE = True` – to generate routes not included in the list
* `RELOAD_BIRD = True` – whether to run `birdc configure`
* Telegram settings (optional alerts on success/failure)
