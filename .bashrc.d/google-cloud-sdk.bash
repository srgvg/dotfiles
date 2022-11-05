# gcloud installed and managed by asdf
hash asdf || exit

# https://cloud.google.com/blog/products/containers-kubernetes/kubectl-auth-changes-in-gke
export USE_GKE_GCLOUD_AUTH_PLUGIN=False

# The next line updates PATH for the Google Cloud SDK.
## already included with asdf PATH
#if [ -f $(asdf where gcloud)/path.bash.inc ]; then . $(asdf where gcloud)/path.bash.inc; fi

# The next line enables shell command completion for gcloud.
if [ -f $(asdf where gcloud)/completion.bash.inc ]; then . $(asdf where gcloud)/completion.bash.inc; fi
