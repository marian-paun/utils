#!/usr/bin/env bash

/usr/bin/mosquitto_sub -R -h 10.242.55.111 -t oramicro1/command/# |
  while read payload ; do
    echo Received $payload
    case $payload in
      restart_metrics2mqtt)
        sudo systemctl restart metrics2mqtt.service 
        ;;
      *)
        echo $payload
        ;;
    esac
  done
