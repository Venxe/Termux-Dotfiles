set fish_greeting ""
set -x MOZ_WEBRENDER 0
set -x MOZ_DISABLE_RDD_SANDBOX 1
set -x MOZ_DISABLE_GPU_SANDBOX 1
set -x LIBGL_ALWAYS_SOFTWARE 1

clear

if status is-interactive
    starship init fish | source
end
