<h1 align="center">
    <img src="https://avatars.githubusercontent.com/u/114239186?s=100&v=4" alt="palera1n logo">
    <p>checkn0nce</p>
</h1>
<h3 align="center">An iOS 12.0-17.0 beta nonce setting tool for checkm8 devices.</h3>
<p align="center">
    <strong><a href="CHANGELOG.md">Change Log</a></strong>
</p>

# How does it work?
It boots the device with multiple patches required. On first run, it'll boot into pwned DFU Mode which will then set boot arguments and other variables. It will then take the nonce generator and patch the kernel which changes the nonce generator on the device itself.

# Warning
- We are **NOT** responsible for any data loss. The user of this program accepts responsibility should something happen to their device. While nothing should happen, setting the device's nonce generator has risks in itself. **If your device is stuck in recovery, please run one of the following:**
   - futurerestore --exit-recovery
   - irecovery -n

# Prerequisites
- A checkm8 vulnerable iOS device on iOS 12.0-17.0 beta (A8-A11)
  - The device must be on iOS 15.0-17.0 beta
- Linux or macOS computer

# How to use?

1. Clone the repo with ``git clone --recursive https://github.com/glowberri/checkn0nce && cd checkn0nce``
   - If you've already cloned the repo, just run ``cd checkn0nce``
2. Open up a terminal window and ``cd`` to the directory
3. Run ``./checkn0nce.sh --generator <Nonce Generator you want to set> <iOS version you're on>``
     - Put your device in DFU Mode before running this command

Your device will then boot into pwned DFU Mode which will then set boot arguments and other variables. It will then take the nonce generator and patch the kernel which changes the nonce generator on the device itself.

# Credits

- [nyuszika7h](https://github.com/nyuszika7h) for the script to help get into DFU
- [libimobiledevice](https://github.com/libimobiledevice) for several tools used in this project (irecovery, ideviceenterrecovery etc), and [nikias](https://github.com/nikias) for keeping it up to date
