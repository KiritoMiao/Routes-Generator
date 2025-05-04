#! /usr/bin/env python3

import requests
import subprocess
from ipaddress import IPv4Network, IPv4Address, summarize_address_range, collapse_addresses
from typing import List

# ------------------- CONFIG SECTION ------------------- #
URL = "https://raw.githubusercontent.com/misakaio/chnroutes2/refs/heads/master/chnroutes.txt"  # Replace with txt format IP list
OUT_INTERFACE = "eth0" # interface
REVERSE = False  # Reverse the IP list to output ips not included
OUTPUT_FILE = "/etc/bird/bird-chn-ip4.conf" # output file
RELOAD_BIRD = True  # Reload BIRD 

# Telegram config
ENABLE_TELEGRAM = False
TELEGRAM_BOT_TOKEN = ""
TELEGRAM_CHAT_ID = ""
# ------------------------------------------------------ #

IGNORED = [
    IPv4Network("0.0.0.0/8"),
]

RESERVED = [
    IPv4Network("0.0.0.0/8"),
    IPv4Network("10.0.0.0/8"),
    IPv4Network("127.0.0.0/8"),
    IPv4Network("169.254.0.0/16"),
    IPv4Network("172.16.0.0/12"),
    IPv4Network("192.0.0.0/29"),
    IPv4Network("192.0.0.170/31"),
    IPv4Network("192.0.2.0/24"),
    IPv4Network("192.168.0.0/16"),
    IPv4Network("198.18.0.0/15"),
    IPv4Network("198.51.100.0/24"),
    IPv4Network("203.0.113.0/24"),
    IPv4Network("240.0.0.0/4"),
    IPv4Network("255.255.255.255/32"),
    IPv4Network("224.0.0.0/4"),
    IPv4Network("100.64.0.0/10"),
]


def send_telegram_message(message: str):
    if not ENABLE_TELEGRAM:
        return
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": TELEGRAM_CHAT_ID,
        "text": message,
        "parse_mode": "Markdown"
    }
    try:
        r = requests.post(url, data=payload)
        if r.status_code != 200:
            print(f"Telegram failed: {r.text}")
    except Exception as e:
        print(f"Telegram exception: {e}")


def is_reserved_or_ignored(network: IPv4Network, ignored: List[IPv4Network], reserved: List[IPv4Network]) -> bool:
    return any(network.subnet_of(r) for r in ignored + reserved)


def generate_routes(china_nets: List[IPv4Network], reverse: bool) -> List[str]:
    output_routes = []

    if not reverse:
        for net in collapse_addresses(china_nets):
            output_routes.append(f'route {net} via "{OUT_INTERFACE}";')
    else:
        excluded = collapse_addresses(china_nets + RESERVED + IGNORED)
        current_start = IPv4Address("0.0.0.0")

        for net in sorted(excluded, key=lambda n: int(n.network_address)):
            if current_start < net.network_address:
                gap = summarize_address_range(current_start, net.network_address - 1)
                for g in gap:
                    output_routes.append(f'route {g} via "{OUT_INTERFACE}";')
            current_start = max(current_start, net.broadcast_address + 1)

        if current_start <= IPv4Address("255.255.255.255"):
            gap = summarize_address_range(current_start, IPv4Address("255.255.255.255"))
            for g in gap:
                output_routes.append(f'route {g} via "{OUT_INTERFACE}";')

    return output_routes


def main():
    print(f"Downloading prefix list from {URL} ...")
    try:
        response = requests.get(URL)
        response.raise_for_status()
    except Exception as e:
        error_msg = f"Download failed: {e}"
        print(error_msg)
        send_telegram_message(f"❌ Route update failed.\n{error_msg}")
        return

    china_nets = []
    for line in response.text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        try:
            net = IPv4Network(line)
            if not is_reserved_or_ignored(net, IGNORED, RESERVED):
                china_nets.append(net)
        except ValueError:
            print(f"Invalid entry skipped: {line}")
            continue

    routes = generate_routes(china_nets, REVERSE)

    try:
        with open(OUTPUT_FILE, "w") as f:
            f.write("\n".join(routes) + "\n")
        print(f"Wrote {len(routes)} routes to {OUTPUT_FILE}")
    except Exception as e:
        error_msg = f"Failed to write route file: {e}"
        print(error_msg)
        send_telegram_message(f"❌ Failed to write route file.\n{error_msg}")
        return

    if RELOAD_BIRD:
        print("Reloading BIRD configuration ...")
        try:
            subprocess.run(["birdc", "configure"], check=True)
            print("BIRD reload successful.")
            send_telegram_message(f"✅ BIRD route update completed.\nRoutes: `{len(routes)}`\nReload: Successful")
        except subprocess.CalledProcessError as e:
            error_msg = f"BIRD reload failed: {e}"
            print(error_msg)
            send_telegram_message(f"⚠️ Route file saved, but BIRD reload failed.\n{error_msg}")
    else:
        send_telegram_message(f"✅ Route file generated.\nRoutes: `{len(routes)}`\nReload: Skipped")


if __name__ == "__main__":
    main()