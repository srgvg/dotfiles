#!/bin/bash
# Source environment.d vars that GDM doesn't load
eval "$(/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator)"
# Unset stale vars that were commented out
unset WLR_DRM_NO_MODIFIERS WLR_DRM_NO_ATOMIC
# Disable ibus to allow Sway XKB compose key to work
# (environment.d can't set empty values, so we set them here)
export GTK_IM_MODULE="" QT_IM_MODULE="" XMODIFIERS=""
export WLR_RENDERER WLR_DRM_DEVICES VK_ICD_FILENAMES WLR_SCENE_DISABLE_DIRECT_SCANOUT WLR_NO_HARDWARE_CURSORS __GL_YIELD __GL_MaxFramesAllowed
# Default terminal (alacritty->foot migration, ~/etc/docs/foot-migration.md).
# Canonical home, independent of environment.d. Respects an inherited override;
# set TERMINAL=alacritty to fall back.
export TERMINAL="${TERMINAL:-foot}"
# Note: sway 1.12 no longer needs --unsupported-gpu to start on NVIDIA proprietary;
# the flag now only suppresses the informational swaynag message. Kept on purpose.
exec sway --unsupported-gpu "$@"
