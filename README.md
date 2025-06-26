# WPA3 Dragon Drain - airgeddon plugin
WPA3 Dragon Drain attack packaged as [airgeddon] plugin

## How Dragon Drain works
Dragon Drain attack overflows WPA3 routers by sending heavy requests in large amount to cause DoS (Denial of Service).

## What does this plugin do
This plugin gets Dragon Drain from original GitHub repository, edits, compiles and runs it integrated as a menu option in [airgeddon].

## Warnings
 - It works only on Debian based Linux distributions. Tested successfully using ALFA AWUS036ACM adapter (Mediatek MT7612U chipset). Pending to be tested using more wireless adapters.
 - It does not re-attempt to compile if something failed in the first go. First compilation could take a while.
 - Only some WPA3 access points are affected. Since this attack was discovered some time ago, most APs have already been patched against it. Therefore, if you are unsuccessful, the main reason could be that the access point is not vulnerable.

## How to install it
Deploy the `.sh` and the `.py` files inside your airgeddon's plugins dir. Depending on your Linux distribution it can be in different directories. Usually is at `/usr/share/airgeddon` or maybe in another location where you did the git clone command. 

```
~/airgeddon# tree
.
├── airgeddon.sh
├── known_pins.db
├── language_strings.sh
└── plugins
    ├── wpa3_dragon_drain_attack.py
    └── wpa3_dragon_drain.sh
```

## How to run it
Select the WPA3 Dragon Drain attack option from the WPA3 attacks menu in [airgeddon]. Scan to choose the WPA3 target and follow the on-screen instructions to proceed. The attack will continue indefinitely until you press Ctrl+C or close the attack window, performing a DoS on the Access Point.

This is how it should look like:

 ![attack](dragon.png)

## Credits
Thanks to Mathy Vanhoef for discovering the flaw. Original repository: https://github.com/vanhoefm/dragondrain-and-time
Thanks to OscarAkaElvis for his help in the development of the plugin

## TODO List
 - Pending to confirmation that tmp dir is not needed
 - Colorization of the attack window
 - Removal of -hold xterm window param after successful testing
 - Do the final review of the language strings by native speaker translators

[airgeddon]: https://github.com/v1s1t0r1sh3r3/airgeddon
