#!/bin/bash
while true; do
    inotifywait -q -e delete /mnt/Astor.Audio/Music/Soundtrack/playing/
    echo "soundtrack file deleted"
done
