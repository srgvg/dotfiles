#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from i3pystatus import Status
from i3pystatus.updates import aptget

COLAU = "#66AAFF"
COLAU2 = "#7799FF"
COLHW = "#999999"
COLIN = "#FFFFFF"

status = Status()

status.register("clock",
                color=COLIN,
                format="%a %-d %B %Y %T",)

status.register("online",
                hints = {"separator": False, "separator_block_width": 1},
                format_online="",
                color=COLAU,
                format_offline="",
                color_offline="#ff0000")

status.register("shell",
                hints = {"separator": False, "separator_block_width": 1},
                ignore_empty_stdout=True,
                color=COLIN,
                command="i3pystatus-commands wifi",
                interval=2)

status.register("keyboard_locks",
                hints = {"separator": False, "separator_block_width": 1},
                color=COLIN,
                format="{num}",
                num_on="",
                num_off="_",)

status.register("backlight",
                hints = {"separator": False, "separator_block_width": 2},
                color=COLIN,
                transforms={'percentage': lambda cdict: round((cdict["brightness"] / cdict["max_brightness"]) * 10)},
                format="{percentage}",
                format_no_backlight="",
                interval=2)

status.register("updates",
                format="APT: {count}",
                color_working="#FF0000",
                backends=[aptget.AptGet()])

status.register("pulseaudio",
                sink=None,
                color_unmuted=COLAU,
                color_muted="",
                format="🔊 {volume}%",
                format_muted="🚫",)

status.register("shell",
                hints = {"separator": False, "separator_block_width": 5},
                ignore_empty_stdout=True,
                color=COLAU,
                command="i3pystatus-commands audio_current_sink",
                interval=3)

status.register("shell",
                ignore_empty_stdout=True,
                color=COLAU,
                command="i3pystatus-commands audio_sonos_volume",
                interval=1)

status.register("now_playing",
                color=COLAU,
                format="[🎶{status} {title} ({artist})]",
                status={'pause': '', 'stop': '', 'play': ''},)

status.register("battery",
                format=" {percentage:.0f}% {consumption:.1f}W {remaining:%E%hh:%Mm} {status}",
                critical_level_percentage=10,
                alert=True,
                alert_percentage=5,
                status={"DIS": "",
                        "CHR": "",
                        "FULL": "",},
                charging_color="#ff7700",
                full_color=COLHW,)

status.register("temp",
                color=COLHW,
                format=" {temp}°C")

status.register("cpu_freq",
                color=COLHW,
                format="{avgg}GHz")

status.register("load",
                color=COLHW,
                format=" {avg1} {avg5} {avg15} {tasks}")

status.register("disk",
                color=COLHW,
                path="/",
                format=" {percentage_avail}%",)

status.register("mem",
                color=COLHW,
                format="🐏 {percent_used_mem}%",)

status.register("network",
                interface="enp0s31f6",
                format_up="🖧  [\[ {v6cidr} \]] [{v4cidr}]",
                format_down="",)

status.register("network",
                interface="wlp4s0",
                format_up=" [{quality:3.0f}% '{essid}'] [\[ {v6cidr} \]] [{v4cidr}]",
                format_down="",)

status.register("network",
                interface="enxe04f4394834e",
                format_up="🖧  [\[ {v6cidr} \]] [{v4cidr}] Dock",
                format_down="",)


status.run()
