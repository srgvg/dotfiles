# https://github.com/zebbern/claude-code-guide
#
# DISABLE_TELEMETRY=1 intentionally NOT set: it disables Statsig feature-flag
# evaluation, which Remote Control (claude rc / --remote-control / the
# /remote-control toggle) hard-requires. Proven 2026-08-24 on 2.1.241.
export DISABLE_ERROR_REPORTING=1
export DISABLE_NON_ESSENTIAL_MODEL_CALLS=1
