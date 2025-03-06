
# starship shell prompt stuff
# https://starship.rs/
eval "$(starship init bash)"
# to update startship:
# bash <(curl -fsSL https://starship.rs/install.sh) --verbose --bin-dir $HOME/bin2 --yes

# https://superuser.com/questions/992210/how-to-set-environment-variables-for-a-gnome-wayland-session
echo "PATH=${PATH}" >  $HOME/.config/environment.d/50-path.conf
export PATH

# at some point CDPATH completion stopped working, this seems to fix/workarounf it
#__load_completion cd

# https://github.com/akinomyoga/ble.sh?tab=readme-ov-file#set-up-bashrc
[[ ! ${BLE_VERSION-} ]] || ble-attach
