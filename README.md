# start-trimode.sh
start-trimode.sh is a shell script to start ham radio apps in a multi-desktop environment.  It's written for use on a Raspberry Pi, but it can be adapted to any version of Linux.

This is a rough draft.  Parts of it are hard-coded for my setup, and require work to make it more "universal".

It assumes you're using the following apps, and that they're already installed and set-up correctly:

flrig
fldigi
flmsg
flamp
JS8Call
piARDOPC
piARDOP_GUI
gARIM

It also requires xdotool to control the apps and switch desktops, so if you don't already have that installed, you'll need to install it.  In a terminal window, type:

sudo apt-get update
supdo apt-get upgrade
sudo apt-get install xdotool
