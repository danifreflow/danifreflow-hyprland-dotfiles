#!/bin/bash

status=$(playerctl -p spotify status 2>/dev/null)
if [ "$status" = "Playing" ] || [ "$status" = "Paused" ]; then
  artist=$(playerctl -p spotify metadata artist)
  title=$(playerctl -p spotify metadata title)
  icon=$([ "$status" = "Playing" ] && echo "playing" || echo "paused")
  echo "{\"text\": \"$artist - $title\", \"class\": \"$icon\", \"alt\": \"$status\", \"tooltip\": \"$title by $artist\", \"icon\": \"$icon\"}"
else
  echo "{\"text\": \"\", \"class\": \"stopped\", \"alt\": \"No music\", \"tooltip\": \"Spotify not playing\", \"icon\": \"default\"}"
fi
