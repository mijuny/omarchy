# Mute-LED sync — keeps platform::{micmute,mute} brightness in sync
# with real PipeWire mute state.
#
# Runs on any laptop where /sys/class/leds/platform::micmute exists
# (or platform::mute, which exists on ASUS B9406CAA via the
# asus-wmi-platform-mute-led-dkms OPR package). No-op elsewhere.
#
# What this hook installs:
#   - udev rule that grants `input` group write access to the LED
#     brightness/trigger sysfs attributes. Fires reliably on every
#     device-add event including module reloads (DKMS upgrades).
#   - user systemd unit (already deployed under config/systemd/user/
#     by install/config/config.sh) that runs the sync daemon.
#   - adds the user to the `input` group (required to write the LED
#     brightness file from a user-level service).

if [[ ! -e /sys/class/leds/platform::micmute ]] && [[ ! -e /sys/class/leds/platform::mute ]]; then
  exit 0
fi

# Install udev rule. udev's MODE= / GROUP= only sets permissions on
# the primary device node; LED class devices have no /dev node, only
# sysfs attributes — so we use RUN+= to chmod/chgrp explicitly.
sudo tee /etc/udev/rules.d/60-omarchy-mute-led.rules >/dev/null <<'EOF'
# Allow user-level mute-LED sync (Omarchy).
SUBSYSTEM=="leds", KERNEL=="platform::mute", \
  RUN+="/usr/bin/chgrp input /sys%p/brightness /sys%p/trigger", \
  RUN+="/usr/bin/chmod 0664  /sys%p/brightness /sys%p/trigger"
SUBSYSTEM=="leds", KERNEL=="platform::micmute", \
  RUN+="/usr/bin/chgrp input /sys%p/brightness /sys%p/trigger", \
  RUN+="/usr/bin/chmod 0664  /sys%p/brightness /sys%p/trigger"
EOF
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=leds --action=add

# Ensure user is in `input` group so the sync service can write
# the brightness file.
if ! id -nG "$USER" | tr ' ' '\n' | grep -q '^input$'; then
  sudo usermod -aG input "$USER"
fi

# Enable and start the user systemd service. The .service file is
# deployed by install/config/config.sh from config/systemd/user/.
systemctl --user daemon-reload
systemctl --user enable --now omarchy-mute-led-sync.service
