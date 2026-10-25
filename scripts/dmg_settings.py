# -*- coding: utf-8 -*-
"""dmgbuild configuration for the OpenTune macOS installer (.dmg)."""

import os

app_path = defines.get("app_path", "build/macos/Build/Products/Release/OpenTune.app")
app_name = os.path.basename(app_path)
bg_path = defines.get("background_path", None)
icon_path = defines.get("icon_path", None)

format = "UDZO"
size = None
compression_level = 9

files = [app_path]
symlinks = {"Applications": "/Applications"}
hide_extensions = [app_name]

if icon_path and os.path.exists(icon_path):
    icon = icon_path

if bg_path and os.path.exists(bg_path):
    background = bg_path
else:
    background = "builtin-arrow"

window_rect = ((200, 120), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 180

icon_size = 110
text_size = 13

icon_locations = {
    app_name: (180, 190),
    "Applications": (480, 190),
}
