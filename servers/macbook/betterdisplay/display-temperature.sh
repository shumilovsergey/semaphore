#!/bin/zsh

BETTERDISPLAY="/opt/homebrew/bin/betterdisplaycli"
DISPLAY="Q24G2"

if ioreg -r -k AppleClamshellState -d 4 | grep -q '"AppleClamshellState" = Yes'; then
    "$BETTERDISPLAY" set --name="$DISPLAY" --temperature=12%
else
    "$BETTERDISPLAY" set --name="$DISPLAY" --temperature=0%
fi
