# Expand $PATH to include the directory where snappy applications go (only when snapd is installed).
if [ -d /snap/bin ]; then
    pathmunge /snap/bin after
fi
