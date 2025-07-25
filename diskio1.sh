#!/usr/bin/bash

format_number() {
  local num="$1"
  if echo "$num" | grep -q "^\."; then
    echo "0$num"
  else
    echo "$num"
  fi
}

# Function to create JSON output for a single device
create_device_json() {
  local device="$1"
  local r_s="$(format_number $2)"
  local rkB_s="$(format_number $3)"
  local w_s="$(format_number $3)"
  local wkB_s="$(format_number $4)"
  local util="$(format_number $5)"
  echo "\"$device\": { \"reads_sec\": "$r_s", \"read_kbytes_sec\": "$rkB_s", \"writes_sec\": "$w_s", \"write_kbytes_sec\": "$wkB_s", \"util_pct\": "$util" }"
}

# Variables to store device data
sda_json=""
zram_json=""

# Variables to store aggregated zram metrics
zram_r_s=0
zram_rkB_s=0
zram_w_s=0
zram_wkB_s=0
zram_util=0
zram_count=0

# Get a list of all devices to monitor (sda and zram*)
devices="sda $(ls /dev/zram* 2>/dev/null | sed 's/\/dev\///')"

# Run iostat for the identified devices
/bin/iostat -dxyk $devices 60 | while read line; do
  # Get the device name from the first field
  device="${line%% *}"

  # Process only device lines
  case "$device" in
    sda|zram*)
      # Read all fields into variables
      r_s=$(echo "$line" | awk '{printf("%.2f", $2)}')
      rkB_s=$(echo "$line" | awk '{printf("%.2f", $3)}')
      w_s=$(echo "$line" | awk '{printf("%.2f", $8)}')
      wkB_s=$(echo "$line" | awk '{printf("%.2f", $9)}')
      util=$(echo "$line" | awk '{printf("%.2f", $23)}')  # get the last field

      if [ "$device" = "sda" ]; then
        sda_json=$(create_device_json "sda" "$r_s" "$rkB_s" "$w_s" "$wkB_s" "$util")
      elif echo "$device" | grep -q "^zram"; then
        # Accumulate zram metrics
        zram_r_s=$(echo "$zram_r_s + $r_s" | bc)
        zram_rkB_s=$(echo "$zram_rkB_s + $rkB_s" | bc)
        zram_w_s=$(echo "$zram_w_s + $w_s" | bc)
        zram_wkB_s=$(echo "$zram_wkB_s + $wkB_s" | bc)
        zram_util=$(echo "$zram_util + $util" | bc)
        zram_count=$((zram_count + 1))

#        zram_r_s=$(echo "$zram_r_s" "$r_s" | awk '{printf "%f, $1 + $2}')
#        zram_rkB_s=$(echo "$zram_rkB_s + $rkB_s" | bc)
#        zram_w_s=$(echo "$zram_w_s + $w_s" | bc)
#        zram_wkB_s=$(echo "$zram_wkB_s + $wkB_s" | bc)
#        zram_util=$(echo "$zram_util + $util" | bc)
#        zram_count=$((zram_count + 1))

        # If this is the last zram device, create the aggregated JSON
        if [ "$zram_count" -eq "$(ls /dev/zram* 2>/dev/null | wc -l)" ]; then
          # Calculate average utilization
#          zram_util=$(echo "scale=2; $zram_util / $zram_count" | bc)

          zram_json=$(create_device_json "zram" "$zram_r_s" "$zram_rkB_s" "$zram_w_s" "$wkB_s" "$zram_util")

          # Create and publish the complete JSON
          json_message="{$sda_json,$zram_json}"

          # Publish the combined JSON message
          /usr/bin/mosquitto_pub -h 127.0.0.1 -t 'homeassistant/sensor/Rpi4/diskio' -m "$json_message"
#          echo "$json_message"
          # Reset aggregated values for next iteration
          zram_r_s=0
          zram_rkB_s=0
          zram_w_s=0
          zram_wkB_s=0
          zram_util=0
          zram_count=0
        fi
      fi
    ;;
  esac
done
exit 0
