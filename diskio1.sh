#!/usr/bin/bash

# Configuration
BROKER="oramicro2.alpine-blues.ts.net"
TOPIC="homeassistant/sensor/Rpi4/diskio"

# Dynamically find zram devices and sda
MONITOR_LIST="sda $(ls /dev/zram* 2>/dev/null | xargs -n1 basename)"

while true; do
  # Run iostat for a 60s interval. 
  # We use 2 iterations and take the second one (statistics[1]) to get accurate interval stats.
  json_message=$(iostat -o JSON -dxyk $MONITOR_LIST 60 2 | jq -c '
    .sysstat.hosts[0].statistics[1] | 
    {
      sda: (.disk[] | select(.disk_device == "sda") | {
        reads_sec: ."r/s", 
        read_kbytes_sec: ."rkB/s", 
        writes_sec: ."w/s", 
        write_kbytes_sec: ."wkB/s", 
        util_pct: .util
      }),
      zram: ([.disk[] | select(.disk_device | startswith("zram"))] | 
        if length > 0 then
          {
            reads_sec: (map(."r/s") | add),
            read_kbytes_sec: (map(."rkB/s") | add),
            writes_sec: (map(."w/s") | add),
            write_kbytes_sec: (map(."wkB/s") | add),
            util_pct: ((map(.util) | add) / length)
          }
        else
          {reads_sec: 0, read_kbytes_sec: 0, writes_sec: 0, write_kbytes_sec: 0, util_pct: 0}
        end
      )
    }
  ')

  if [ -n "$json_message" ] && [ "$json_message" != "null" ]; then
    /usr/bin/mosquitto_pub -h "$BROKER" -u "${MQTT_USER}" -P "${MQTT_PWD}" -t "$TOPIC" -m "$json_message"
  fi
done
