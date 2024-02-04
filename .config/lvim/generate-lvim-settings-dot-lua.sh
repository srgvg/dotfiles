#!/bin/bash

cd $(dirname $0)

lvim --headless +'lua require("lvim.utils").generate_settings()' +qa && sort -o lv-settings.lua{,}

ls -l lv-settings.lua
