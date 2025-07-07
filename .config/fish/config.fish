set -x DISPLAY :1
if status is-interactive
starship init fish | source
end
