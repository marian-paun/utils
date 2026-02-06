#!/usr/bin/bash

# Configuration
BROKER="oramicro1.alpine-blues.ts.net"
TOPIC="homeassistant/sensor/Rpi4/diskio"
ZRAM_DEVICES=(/dev/zram*)
TOTAL_ZRAMS=${#ZRAM_DEVICES[@]}
# Use -z to skip idle devices and simplify the line count
MONITOR_LIST="sda $(ls /dev/zram* | xargs -n1 basename)"

safe_bc() {
  local val="${1:-0}"
  [[ ! "$val" =~ ^[0-9.-]+$ ]] && val=0
  echo "$val"
}

format_number() {
  local num="$(safe_bc "$1")"
  [[ "$num" == .* ]] && echo "0$num" || echo "$num"
}

create_device_json() {
  local device="$1" r_s rkB_s w_s wkB_s util
  r_s="$(format_number "$2")"
  rkB_s="$(format_number "$3")"
  w_s="$(format_number "$4")"
  wkB_s="$(format_number "$5")"
  util="$(format_number "$6")"
  echo "\"$device\": { \"reads_sec\": $r_s, \"read_kbytes_sec\": $rkB_s, \"writes_sec\": $w_s, \"write_kbytes_sec\": $wkB_s, \"util_pct\": $util }"
}

zram_r_s=0; zram_rkB_s=0; zram_w_s=0; zram_wkB_s=0; zram_util=0; zram_count=0
sda_json=""

# Dynamically parse columns using an array to ensure we get the last field (%util)
while read -a cols; do
  dev="${cols[0]}"

  # Skip headers
  [[ "$dev" =~ ^(Device|Linux|avg-cpu) || -z "$dev" ]] && continue

  # Extract fields by index: 
  # 0=Device, 1=r/s, 2=rkB/s, 7=w/s, 8=wkB/s
  # The last column is always %util
  rs="${cols[1]}"
  rkb="${cols[2]}"
  ws="${cols[7]}"
  wkb="${cols[8]}"
  util="${cols[${#cols[@]}-1]}" # Anchors to the very last column

  if [[ "$dev" == "sda" ]]; then
    sda_json=$(create_device_json "sda" "$rs" "$rkb" "$ws" "$wkb" "$util")
  elif [[ "$dev" == zram* ]]; then
    zram_r_s=$(echo "$zram_r_s + $rs" | bc)
    zram_rkB_s=$(echo "$zram_rkB_s + $rkb" | bc)
    zram_w_s=$(echo "$zram_w_s + $ws" | bc)
    zram_wkB_s=$(echo "$zram_wkB_s + $wkb" | bc)
    zram_util=$(echo "$zram_util + $util" | bc)
    ((zram_count++))

    if [ "$zram_count" -eq "$TOTAL_ZRAMS" ]; then
      avg_util=$(echo "scale=2; $zram_util / $zram_count" | bc)
      zram_json=$(create_device_json "zram" "$zram_r_s" "$zram_rkB_s" "$zram_w_s" "$zram_wkB_s" "$avg_util")

      json_message="{$sda_json, $zram_json}"
      /usr/bin/mosquitto_pub -h "$BROKER" -t "$TOPIC" -m "$json_message"

      # Reset
      zram_r_s=0; zram_rkB_s=0; zram_w_s=0; zram_wkB_s=0; zram_util=0; zram_count=0
    fi
  fi
done < <(/bin/iostat -dxyk $MONITOR_LIST 60)
