## 🐦 BIRD Routes Generator

This project provides tools to dynamically generate route configurations for [BIRD](https://bird.network.cz/), using static IP lists or live process-based connections.

---

### 📦 Modules

| Module                                 | Script/Executable         | Description                                                            |
| -------------------------------------- | ------------------------- | ---------------------------------------------------------------------- |
| IP List to BIRD (Linux)                | `generate_bird_routes.py` | Generates static BIRD routes from a plain text IP list                 |
| Process-based Route Uploader (Windows) | `dynamic-route.ps1`       | Extracts live IPs from process connections and uploads to BIRD via SSH |

---

### 📁 File Structure

```
Routes-Generator/
├── bird/
│   ├── generate_bird_routes.py         # IP-list based route generator
│   ├── generate-bird-routes.service    # systemd unit file
│   ├── generate-bird-routes.timer      # systemd timer file
│   └── install.sh                      # Linux installation script
│
├── windows/
│   └── dynamic-route.ps1               # PowerShell dynamic route uploader
```

---

### ⚙️ Usage

#### 📌 IP List to BIRD (Linux)

1. **Install:**

   ```bash
   git clone https://github.com/KiritoMiao/Routes-Generator.git
   cd Routes-Generator/bird
   chmod +x install.sh
   sudo ./install.sh
   ```

2. **Run once manually:**

   ```bash
   sudo systemctl start generate-bird-routes.service
   ```

3. **Enable automatic daily updates at 3:00 AM:**

   ```bash
   sudo systemctl enable --now generate-bird-routes.timer
   ```

---

#### 🪟 Process-based Dynamic Loader (Windows)

1. **Configure `windows/dynamic-route.ps1`:**

   * Set process names:

     ```powershell
     $ProcessNames = @("chrome.exe", "ssh.exe")
     ```
   * Define SSH settings (user, host, port, and target file)

2. **Run once manually:**

   ```powershell
   .\dynamic-route.ps1
   ```

3. **Run in continuous monitoring mode (every 10 seconds):**

   ```powershell
   .\dynamic-route.ps1 -Dynamic
   ```

**Optional flags:**

* `-Verbose` – Enables detailed output
* `-DryRun` – Simulate changes without uploading

