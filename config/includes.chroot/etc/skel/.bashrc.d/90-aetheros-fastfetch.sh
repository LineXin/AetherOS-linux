# AetherOS interactive shell greeting
if [[ $- == *i* ]] && command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi
