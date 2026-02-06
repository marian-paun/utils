#!/bin/sh

LSW=""
LSR=""
PUEI=""
while read line; do
  case "$line" in
    *"Logical Sectors Written"*)
      GBW=$(echo "$line" | awk '{print $4}');
      ;;
    *"Logical Sectors Read"*)
      GBR=$(echo "$line" | awk '{print $4}');
      ;;
    *"Percentage Used Endurance Indicator"*)
      PUEI=$(echo "$line" | awk '{print $4}');
      ;;
  esac
done <<< $(/usr/builtin/sbin/smartctl -l devstat /dev/"$2")
GBR=$( echo $GBR / 2048 / 1024 | bc -l);
GBW=$( echo $GBW / 2048 / 1024 | bc -l);
json="{\"$2\":{\"GBR\":\"$GBR\",\"GBW\":\"$GBW\",\"PUEI\":\"$PUEI\"}}"
#echo $json | jq
/usr/bin/mosquitto_pub  -h oramicro1.alpine-blues.ts.net -t "homeassistant/sensor/$1/smartctl/$2" -m "$json"
