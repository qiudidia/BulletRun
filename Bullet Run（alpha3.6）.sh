#!/bin/sh
printf '\033c\033]0;%s\a' Bullet Run
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Bullet Run（alpha3.6）.x86_64" "$@"
