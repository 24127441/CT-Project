#!/bin/bash

# --- 1. EXPLICITLY SET PATHS (CRITICAL FIX) ---
# This ensures the script knows where Flutter/Android are,
# even if .bashrc isn't loaded by the shell executing this script.
export FLUTTER_HOME="$HOME/Dev/flutter"
export ANDROID_HOME="$HOME/Dev/android/SDK"
export PATH="$FLUTTER_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# --- 2. AUTO-DETECT IP ---
# Try to find the IP for a wireless interface (often starts with 'wlan' or 'wl')
IP=$(ip a | grep 'inet ' | grep 'wlan' | awk '{print $2}' | cut -d/ -f1 | head -n 1)

# If no 'wlan' IP is found, try to find the IP for a wired interface (often starts with 'eth' or 'enp')
if [ -z "$IP" ]; then
    IP=$(ip a | grep 'inet ' | grep -E 'eth|enp' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
fi

# Fallback: Try to find any local IP address (e.g., one starting with 192.)
if [ -z "$IP" ]; then
    IP=$(ip a | grep 'inet ' | grep '192.' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
fi

echo "--------------------------------------------"
echo -e "\033[33mDetected Computer IP: $IP\033[0m" # Yellow color
echo -e "\033[36mLaunching Flutter App...\033[0m" # Cyan color
echo -e "\033[37mTarget API: http://$IP:8000/api\033[0m" # Gray/White color
echo "--------------------------------------------"

# --- 3. FORCE GENERATE LOCAL.PROPERTIES (CRITICAL FIX) ---
# This ensures Gradle (which runs separately) knows where to find the Flutter SDK.
# Without this, Gradle might fail with "command not found" for flutter.
echo "Generating frontend/android/local.properties..."
cat > frontend/android/local.properties <<EOF
sdk.dir=$ANDROID_HOME
flutter.sdk=$FLUTTER_HOME
EOF

# --- 4. CLEAN & RUN ---
cd frontend

# Optional: Clean gradle cache if previous builds messed up permissions
# rm -rf android/.gradle 

echo "Running Flutter..."
flutter run --dart-define=SERVER_IP=$IP
