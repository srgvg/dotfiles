#!/bin/bash
# Source environment.d vars that GDM doesn't load
eval "$(/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator)"
# Unset stale vars that were commented out
unset WLR_DRM_NO_MODIFIERS WLR_DRM_NO_ATOMIC
# Disable ibus to allow Sway XKB compose key to work
# (environment.d can't set empty values, so we set them here)
export GTK_IM_MODULE="" QT_IM_MODULE="" XMODIFIERS=""
export WLR_RENDERER WLR_DRM_DEVICES VK_ICD_FILENAMES
exec sway --unsupported-gpu "$@"
