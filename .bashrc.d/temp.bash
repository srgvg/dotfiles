# systemd --user
export XDG_RUNTIME_DIR="/run/user/$UID"

export FLUX_FORWARD_NAMESPACE="flux"



notectl() {
	docker run -e NOTEWORTHY_DOMAIN=$NOTEWORTHY_DOMAIN --rm -it -v "/var/run/docker.sock:/var/run/docker.sock" decentralabs/noteworthy:taproot-beta "$@";
}

