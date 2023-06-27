#!/usr/bin/env bash

mkdir -p logs
set -e 

log="$(date +%T)"-"$(date +%F)"-"$(uname)"-"$(uname -r)".log
cd logs
touch "$log"
cd ..

{

echo "[*] Command ran:`if [ $EUID = 0 ]; then echo " sudo"; fi` ./checkn0nce.sh $@"

# =========
# Variables
# =========
version="1.0.0"
os=$(uname)
dir="$(pwd)/binaries/$os"
max_args=2
arg_count=0
iBEC="$(pwd)/other/iBEC"
iBSS="$(pwd)/other/iBSS"

# =========
# Functions
# =========
step() {
    for i in $(seq "$1" -1 0); do
        if [ "$(get_device_mode)" = "dfu" ]; then
            break
        fi
        printf '\r\e[K\e[1;36m%s (%d)' "$2" "$i"
        sleep 1
    done
    printf '\e[0m\n'
}

print_help() {
    cat << EOF
Usage: $0 [Options] [ subcommand | iOS version ]
iOS 12.0-17.0 beta nonce setting tool for checkm8 devices
Options:
    --help              Print this help
    --generator         Set the nonce generator of the device
Subcommands:
    dfuhelper           An alias for --dfuhelper
The iOS version argument should be the iOS version of your device.
And the nonce generator argument should be the nonce generator that you want to set your device to.
It is required when starting from DFU mode.
EOF
}

parse_opt() {
    case "$1" in
        --)
            no_more_opts=1
            ;;
        --generator)
            nonce="$2"
            ;;
        --dfuhelper)
            dfuhelper=1
            ;;
        --dfu)
            echo "[!] DFU mode devices are now automatically detected and --dfu is deprecated"
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            echo "[-] Unknown option $1. Use $0 --help for help."
            exit 1;
    esac
}

parse_arg() {
    arg_count=$((arg_count + 1))
    case "$1" in
        dfuhelper)
            dfuhelper=1
            ;;
        *)
            version="$1"
            ;;
        generator)
            nonce="$2"
            ;;
    esac
}

parse_cmdline() {
    for arg in $@; do
        if [[ "$arg" == --* ]] && [ -z "$no_more_opts" ]; then
            parse_opt "$arg";
        elif [ "$arg_count" -lt "$max_args" ]; then
            parse_arg "$arg";
        else
            echo "[-] Too many arguments. Use $0 --help for help.";
            exit 1;
        fi
    done
}

recovery_fix_auto_boot() {
    "$dir"/irecovery -c "setenv auto-boot true"
    "$dir"/irecovery -c "saveenv"
}

_info() {
    if [ "$1" = 'recovery' ]; then
        echo $("$dir"/irecovery -q | grep "$2" | sed "s/$2: //")
    elif [ "$1" = 'normal' ]; then
        echo $("$dir"/ideviceinfo | grep "$2: " | sed "s/$2: //")
    fi
}

_pwn() {
    pwnd=$(_info recovery PWND)
    if [ "$pwnd" = "" ]; then
        echo "[*] Pwning device"
        "$dir"/gaster pwn
        sleep 2
        "$dir"/gaster reset
        sleep 1
    fi
}

_reset() {
    echo "[*] Resetting DFU state"
    "$dir"/gaster reset
}

get_device_mode() {
    if [ "$os" = "Darwin" ]; then
        apples="$(system_profiler SPUSBDataType 2> /dev/null | grep -B1 'Vendor ID: 0x05ac' | grep 'Product ID:' | cut -dx -f2 | cut -d' ' -f1 | tail -r)"
    elif [ "$os" = "Linux" ]; then
        apples="$(lsusb | cut -d' ' -f6 | grep '05ac:' | cut -d: -f2)"
    fi
    local device_count=0
    local usbserials=""
    for apple in $apples; do
        case "$apple" in
            12a8|12aa|12ab)
            device_mode=normal
            device_count=$((device_count+1))
            ;;
            1281)
            device_mode=recovery
            device_count=$((device_count+1))
            ;;
            1227)
            device_mode=dfu
            device_count=$((device_count+1))
            ;;
            1222)
            device_mode=diag
            device_count=$((device_count+1))
            ;;
            1338)
            device_mode=checkra1n_stage2
            device_count=$((device_count+1))
            ;;
            4141)
            device_mode=pongo
            device_count=$((device_count+1))
            ;;
        esac
    done
    if [ "$device_count" = "0" ]; then
        device_mode=none
    elif [ "$device_count" -ge "2" ]; then
        echo "[-] Please attach only one device" > /dev/tty
        kill -30 0
        exit 1;
    fi
    if [ "$os" = "Linux" ]; then
        usbserials=$(cat /sys/bus/usb/devices/*/serial)
    elif [ "$os" = "Darwin" ]; then
        usbserials=$(system_profiler SPUSBDataType 2> /dev/null | grep 'Serial Number' | cut -d: -f2- | sed 's/ //')
    fi
    if grep -qE '(ramdisk tool|SSHRD_Script) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [0-9]{1,2} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}' <<< "$usbserials"; then
        device_mode=ramdisk
    fi
    echo "$device_mode"
}

_wait() {
    if [ "$(get_device_mode)" != "$1" ]; then
        echo "[*] Waiting for device in $1 mode"
    fi

    while [ "$(get_device_mode)" != "$1" ]; do
        sleep 1
    done

    if [ "$1" = 'recovery' ]; then
        recovery_fix_auto_boot;
    fi
}

_dfuhelper() {
    local step_one;
    deviceid=$( [ -z "$deviceid" ] && _info normal ProductType || echo $deviceid )
    if [[ "$1" = 0x801* && "$deviceid" != *"iPad"* ]]; then
        step_one="Hold volume down + side button"
    else
        step_one="Hold home + power button"
    fi
    echo "[*] Press any key when ready for DFU mode"
    read -n 1 -s
    step 3 "Get ready"
    step 4 "$step_one" &
    sleep 3
    "$dir"/irecovery -c "reset" &
    wait
    if [[ "$1" = 0x801* && "$deviceid" != *"iPad"* ]]; then
        step 10 'Release side button, but keep holding volume down'
    else
        step 10 'Release power button, but keep holding home button'
    fi
    sleep 1
    
    if [ "$(get_device_mode)" = "dfu" ]; then
        echo "[*] Device entered DFU!"
    else
        echo "[-] Device did not enter DFU mode, rerun the script and try again"
        return -1
    fi
}

_kill_if_running() {
    if (pgrep -u root -xf "$1" &> /dev/null > /dev/null); then
        # yes, it's running as root. kill it
        sudo killall $1
    else
        if (pgrep -x "$1" &> /dev/null > /dev/null); then
            killall $1
        fi
    fi
}

_exit_handler() {
    [ $? -eq 0 ] && exit
    echo "[-] An error occurred"

    if [ -d "logs" ]; then
        cd logs
        mv "$log" FAIL_${log}
        cd ..
    fi

    echo "[*] A failure log has been made. If you're going ask for help, please attach the latest log."
}
trap _exit_handler EXIT

# ===========
# Fixes
# ===========

# ============
# Dependencies
# ============

# Check for required commands
if [ "$os" = 'Linux' ]; then
    linux_cmds='lsusb'
fi

for cmd in curl unzip python3 git killall sudo grep pgrep ${linux_cmds}; do
    if ! command -v "${cmd}" > /dev/null; then
        echo "[-] Command '${cmd}' not installed, please install it!";
        cmd_not_found=1
    fi
done
if [ "$cmd_not_found" = "1" ]; then
    exit 1
fi

# Download gaster
if [ -e "$dir"/gaster ]; then
    "$dir"/gaster &> /dev/null > /dev/null | grep -q 'usb_timeout: 5' && rm "$dir"/gaster
fi

if [ ! -e "$dir"/gaster ]; then
    curl -sLO https://static.palera.in/deps/gaster-"$os".zip
    unzip gaster-"$os".zip
    mv gaster "$dir"/
    rm -rf gaster gaster-"$os".zip
fi

# ============
# Prep
# ============

chmod +x "$dir"/*
#if [ "$os" = 'Darwin' ]; then
#    xattr -d com.apple.quarantine "$dir"/*
#fi

# ============
# Start
# ============

echo "checkn0nce | Version $version"
echo "Written by Ghostanary/CanaryZen"
echo ""

version=""
parse_cmdline "$@"

if "$dir"/ideviceinfo -s -k HardwareModel | grep -i 'n53ap' &> /dev/null; then
   device="iPhone6,2"
fi

if "$dir"/ideviceinfo -s -k HardwareModel | grep -i 'n51ap' &> /dev/null; then
   device="iPhone6,1"
fi

if "$dir"/ideviceinfo -s -k HardwareModel | grep -i 'j71ap' &> /dev/null; then
   device="iPad4,1"
fi

if "$dir"/ideviceinfo -s -k HardwareModel | grep -i 'j72ap' &> /dev/null; then
   device="iPad4,2"
fi

if "$dir"/ideviceinfo -s -k HardwareModel | grep -i 'j85ap' &> /dev/null; then
   device="iPad4,4"
fi


# Get device's iOS version from ideviceinfo if in normal mode
echo "[*] Waiting for devices"
while [ "$(get_device_mode)" = "none" ]; do
    sleep 1;
done
echo $(echo "[*] Detected $(get_device_mode) mode device" | sed 's/dfu/DFU/')

if grep -E 'pongo|checkra1n_stage2|diag' <<< "$(get_device_mode)"; then
    echo "[-] Detected device in unsupported mode '$(get_device_mode)'"
    exit 1;
fi

if [ "$(get_device_mode)" != "normal" ] && [ -z "$version" ] && [ "$dfuhelper" != "1" ]; then
    echo "[-] You must pass the version your device is on when not starting from normal mode"
    exit
fi

if [ "$(get_device_mode)" = "ramdisk" ]; then
    # If a device is in ramdisk mode, perhaps iproxy is still running?
    _kill_if_running iproxy
    echo "[*] Switching device into recovery mode..."
    "$dir"/ideviceenterrecovery $(_info normal UniqueDeviceID)
    _wait recovery
fi

if [ "$(get_device_mode)" = "normal" ]; then
    version=${version:-$(_info normal ProductVersion)}
    arch=$(_info normal CPUArchitecture)
    if [ "$arch" = "arm64e" ]; then
        echo "[-] checkn0nce doesn't, and never will, work on non-checkm8 devices"
        exit
    fi
    echo "Hello, $(_info normal ProductType) on $version!"

    echo "[*] Switching device into recovery mode..."
    "$dir"/ideviceenterrecovery $(_info normal UniqueDeviceID)
    _wait recovery
fi

# Grab more info
echo "[*] Getting device info..."
cpid=$(_info recovery CPID)
model=$(_info recovery MODEL)
deviceid=$(_info recovery PRODUCT)
udid=$(_info normal UniqueDeviceID)

if [ "$dfuhelper" = "1" ]; then
    echo "[*] Running DFU helper"
    _dfuhelper "$cpid"
    exit
fi

# Have the user put the device into DFU
if [ "$(get_device_mode)" != "dfu" ]; then
    recovery_fix_auto_boot;
    _dfuhelper "$cpid" || {
        echo "[-] Failed to enter DFU mode, run checkn0nce.sh again"
        exit -1
    }
fi

sleep 2
_pwn
_reset

echo "[*] Injecting iBSS Protocol if affected..."

"$dir"/irecovery -f "$iBSS/ibss.$device.img4"

echo "[*] Injecting iBEC Protocol if affected..."

if [ "$device" = iPhone6,1 ] || [ "$device" = iPhone6,2 ] || [ "$device" = iPad4,1 ] || [ "$device" = iPad4,2 ] || [ "$device" = iPad4,3 ] || [ "$device" = iPad4,4 ] || [ "$device" = iPad4,5 ] || [ "$device" = iPad4,6 ] || [ "$device" = iPad4,7 ] || [ "$device" = iPad4,8 ] || [ "$device" = iPad4,9 ]
then
    "$dir"/irecovery -f "$iBEC/ibec.$device.img4"
fi

echo "[*] Setting nonce generator to $2..."
"$dir"/irecovery -c "setenv com.apple.System.boot-nonce $2"
sleep 1
"$dir"/irecovery -c "saveenv"
sleep 1
"$dir"/irecovery -c "setenv auto-boot false"
sleep 1
"$dir"/irecovery -c "saveenv"
sleep 1
echo "[*] Rebooting your device (if it doesn't reboot, you may force reboot)"
"$dir"/irecovery -n

if [ -d "logs" ]; then
    cd logs
     mv "$log" SUCCESS_${log}
    cd ..
fi

echo ""
echo "Done!"
echo "The device should now boot to recovery mode"
echo "If this is your first time setting the device nonce generator, you may now flash using FutureRestore"
echo "Enjoy!"

} 2>&1 | tee logs/${log}
