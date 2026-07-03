#!/bin/sh
printf '\033c\033]0;%s\a' Bullet Run
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Bullet Run（alpha2.5）.x86_64" "$@"
