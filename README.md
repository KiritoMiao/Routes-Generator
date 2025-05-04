## 🐦 BIRD Routes Generator

This project provides multiple dynamic route generator for [BIRD](https://bird.network.cz/).

---

### 📦 Modules

| Module                            | Core Executible           | Description                                                               |
| --------------------------------- | ------------------------- | ------------------------------------------------------------------------- |
| IP List to bird (Linux)           | `generate_bird_routes.py` | Python script to generate BIRD route config from a txt IP list            |
| Process Dynamic loader (Windows)  | `dynamic-route.ps1`       | PowerShell script to upload live IPs based on running processes to BIRD   |


---

### 📁 File Structure

Routes-Generator/
├── bird/
│   ├── generate_bird_routes.py           # IP-list based route generator
│   ├── generate-bird-routes.service      # systemd unit
│   ├── generate-bird-routes.timer        # systemd timer
│   └── install.sh                        # Linux installer script
│
├── windows/
│   └── dynamic-route.ps1                 # Windows PowerShell dynamic route uploader

---

### ⚙️ Usage
#### IP List to bird (Linux)

1. Clone the repo and install:

   ```bash
   git clone https://github.com/KiritoMiao/Routes-Generator.git
   cd Routes-Generator/bird
   chmod +x setup-bird-routes.sh
   sudo ./setup-bird-routes.sh
   ```

2. Test once:

   ```bash
   sudo systemctl start generate-bird-routes.service
   ```

3. Enable auto-update daily at 3:00 AM:

   ```bash
   sudo systemctl enable --now generate-bird-routes.timer
   ```

---
#### Process Dynamic loader (Windows)

1. Edit `windows/dynamic-route.ps1` to configure:

   * `$ProcessNames = @("chrome.exe", "ssh.exe")`
   * SSH connection and file upload settings

2. Run once:

   ```powershell
   .\dynamic-route.ps1
   ```

3. Run continuously every 10s (dynamic mode):

   ```powershell
   .\dynamic-route.ps1 -Dynamic
   ```

Optional switches:

* `-Verbose` – Show debug info
* `-DryRun` – Simulate only, no actual execution


---
