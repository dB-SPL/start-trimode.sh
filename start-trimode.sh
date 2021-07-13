#!/bin/bash

# Read arguments and check if valid
for arg in "$@"
do
    if [ "$arg" != "" && "$arg" != "-start-all" && "$arg" != "-stop-all" && "$arg" != "-reboot" && "$arg" != "-start-flrig" && "$arg" != "-stop-flrig" &&  "$arg" != "-start-fldigi" && "$arg" != "-stop-fldigi" && "$arg" != "-start-js8call" && "$arg" != "-stop-js8call" && "$arg" != "-start-garim" && "$arg" != "-stop-garim" ]
    then
    echo "ERROR: {$arg} is not a valid argument"
    invarg = TRUE
    fi
done

# If invalid argument, raise error
if [ "$invarg" = TRUE ]
    then
    exit 22
fi

# Read settings from config file
source ./start-trimode.config

config_enable(){
# Enables an application, and writes it to the config file.
# First check if application name is valid
	for app_name in pavucontrol conky flrig fldigi js8call rigctld ardopc ardopgui
		if [ "$1" = "$app_name" ]; then
			local app_valid=$1
		fi
	done
	if [[ ! -z "$app_valid" ]]; then
		local conf_stat=$(grep $1 start-trimode.config)
		[! -z "$conf_stat" ] && sed -i "s/$conf_stat/enable_$1=true/g" start-trimode.config || echo "enable_$1=true" > start-trimode.config
	fi
}

config_disable(){
# Disables an application, and writes it to the config file.
# First check if application name is valid
	for app_name in pavucontrol conky flrig fldigi js8call rigctld ardopc ardopgui
		if [ "$1" = "$app_name" ]; then
			local app_valid=$1
		fi
	done
	if [[ ! -z "$app_valid" ]]; then
		local conf_stat=$(grep $1 start-trimode.config)
		[! -z "$conf_stat" ] && sed -i "s/$conf_stat/enable_$1=false/g" start-trimode.config || echo "enable_$1=false" > start-trimode.config
	fi
# Check for required applications
[ -z "$(which pavucontrol)" ] && echo "Pulse Audio Volume Control is not installed... Skipping" || enable_pavucontrol=TRUE
[ -z "$(which conky)" ] && echo "Conky not installed... Skipping" || enable_conky=TRUE
[ -z "$(which flrig)" ] && echo "Flrig not installed... Skipping" || enable_flrig=TRUE
[ -z "$(which fldigi)" ] && echo "Fldigi not installed... Skipping" || enable_fldigi=TRUE
[ -z "$(which js8call)" ] && echo "Flrig not installed... Skipping" || enable_js8call=TRUE
[ -z "$(which rigctld)" ] && echo "Rig Control not installed... Skipping" || enable_rigctld=TRUE

[ -z "$(find $HOME -name piardopc)" ] && echo "ARDOP not installed... Skipping" || enable_rigctld=TRUE

[ -z "$(which xdotool)" ] && echo "Xdotool not installed, but is required.  Exiting..." || enable_xdotool=TRUE

# Create tmp directory and lock files
mkdir /tmp/start-trimode
touch /tmp/start-trimode/lockfile
touch /tmp/start-trimode/mode
touch /tmp/start-trimode/js8call-autoreply
touch /tmp/start-trimode/garim-beacon

# Set file location variables
script_filename=$(basename "$0")
script_full_path=$(realpath $0)
script_dir=$(dirname "$script_full_path")
lockfile="/tmp/start-trimode/lockfile"
modefile="/tmp/start-trimode/mode"
js8call_autoreply_file="/tmp/start-trimode/js8call-autoreply"
js8call_autoreply="$(cat $js8call_autoreply_file)"
garim_beacon_file="/tmp/start-trimode/garim-beacon"
garim_beacon="$(cat $garim_beacon_file)"
autoreply_beacon="$scriptdir/autoreply-beacon.sh"
autoreply_beacon_pid=$(pgrep -f autoreply-beacon.sh)
script_pid=$(cat $lockfile)
idletime=$(xprintidle)
idlefile="/tmp/start-trimode/idletime"
echo $idletime >$idlefile
desk_counter=0
desk_num=$(xdotool get_desktop)

# Print important variables to terminal for debugging
echo "mode = " $mode
echo "script_filename = "$script_filename
echo "script_full_path = "$script_full_path
echo "script_dir = "$script_dir
echo "lockfile = "$lockfile $(cat $lockfile)
echo "script_pid = "$script_pid
echo "idletime is $idletime ms"

if [[ $script_pid != "" ]]; then
	val=$(yad --center --width=300 --height=100 --title "Alert" --image "dialog-question" --buttons-layout=center --text "Another copy of the start-trimode.sh script appears to be running.  Continue?" --timeout=30 --button=gtk-yes:0 --button=gtk-no:1 )   
	ret=$?

	if [[ $ret -eq 0 ]]; then
		script_pid=$(pgrep -f $script_filename)
		echo $script_pid >$lockfile
		
		else
		echo "Another copy of the start-trimode.sh script appears to be running.  Exiting."
		exit 0
	fi
	
	else
	script_pid=$(pgrep -f $script_filename)
	# echo $script_pid > $lockfile
fi

get_time(){
# Get current time in UTC
	h=$(date -u +%H)
	m=$(date -u +%M)
	time=$h$m
}

# CPU Usage Function
cpu_check(){
	arg1=$1
	declare -i app_pid
	declare -i app_cpu
	declare -i cpu_limit
	app_name=$arg1
	app_cpu=`ps aux | grep $app_name | grep -v grep | awk {'print $3*100'}`
	if [[ $app_cpu > 9000 ]]
		then sleep 60
		app_cpu=`ps aux | grep $app_name | grep -v grep | awk {'print $3*100'}`
		if [[ $app_cpu > 9000 ]]
			then killall $app_name
		fi
	fi
}

# Send frequency to rigctld to change frequencies
set_freq(){
	freq=$1
	echo F $freq | netcat -w 1 localhost 4532
}

# Get frequency from rigctld
get_freq(){
	freq=$(echo f | netcat -w 1 localhost 4532)
	freq=${freq%"'n/"}
}

# Launch apps on specific desktops

launch_conky(){
		conky_pid=$(pidof conky)
		if [[ $conky_pid = "" ]]
			then conky &
		fi
}

launch_pavucontrol(){
		pavucontrol_pid=$(pidof pavucontrol)
		if [[ $pavucontrol_pid = "" ]]
			then xdotool set_desktop 0
			((desk_counter++))
			app_window=""
			pavucontrol &
			sleep 2
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "volume control");
				sleep 1;
			done
		xdotool search --name "volume control" windowminimize
		fi
}

launch_flrig(){
		flrig_pid=$(pidof flrig)		
		if [[ $flrig_pid = "" ]]
			then xdotool set_desktop 0
			((desk_counter++))
			flrig &
			sleep 3
			app_window=""
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "flrig");
				sleep 1;
			done
		fi
}

launch_fldigi(){
		fldigi_pid=$(pidof fldigi)
		flamp_pid=$(pidof flamp)
		
		if [[ $fldigi_pid != "" ]] && [[ $flamp_pid = "" ]]
			then xdotool set_desktop 3
			((desk_counter++))
			flamp &
			app_window=""
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "flamp");
				sleep 1;
			done
		fi		
		
		if [[ $fldigi_pid = "" ]] && [[ $flamp_pid = "" ]]
			then
			killall fldigi
			killall flamp
			killall flmsg		
			# Switch to FLDigi desktop and launch fldigi
			xdotool set_desktop 3
			((desk_counter++))
			fldigi &
			app_window=""
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "fldigi");
				sleep 1;
			done
			sleep 2

			app_window=""
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "flamp");
				sleep 1;
			done

			app_window=""
			#until [ $app_window != "" ]; do
			#	app_window=$(xdotool search --name "flmsg");
			#	sleep 1;
			#done

			# xdotool search --name 'fldigi ver' windowactivate key F5
		fi	
}

launch_js8call(){
		js8call_pid=$(pidof js8call)
		if [[ $js8call_pid = "" ]]
			then xdotool set_desktop 2
			((desk_counter++))
			export XAUTHORITY=/home/pi/.Xauthority
			export DISPLAY=:0.0
			killall js8
			app_window=""
			js8call &
			sleep 1
			until [ "$app_window" != "" ]; do
				app_window=$(xdotool search --name "js8call de kn4crd");
				sleep 1;
			done
			js8call_autoreply="true"
		fi
}

stop_js8call(){
		js8call_pid=$(pidof js8call)
		if [[ $js8call_pid != "" ]]; then
			xdotool set_desktop 2
			sleep 1
			app_window=$(xdotool search --name "js8call de kn4crd")
			sleep 1
			xdotool windowactivate $app_window
			sleep 5
			xdotool windowactivate $app_window key alt+f
			sleep 1
			xdotool windowactivate $app_window key x
			sleep 3
			killall js8call
			sleep 1
			killall js8
			((desk_counter++))
		fi
}

launch_rigctld(){
		rigctld_pid=$(pidof rigctld)
		if [[ $rigctld_pid = "" ]]; then
			# Launch rigctld with socat
			socat pty,link=/tmp/rigctl,b38400 tcp:localhost:4532,forever &
			rigctld -vvvvv -m 4 &
			sleep 1s
		fi
}

launch_piardopc(){
		# Check to make sure pavucontrol and rigctld are running
		pavucontrol_pid=$(pidof pavucontrol)
		rigctld_pid=$(pidof rigctld)
		piardop_pid=$(pidof piardopc)
		garim_pid=$(pidof garim)
		if [[ $pavucontrol = "" ]]; then
			launch_pavucontrol 
		fi
		
		# Launch piardopc
		if [[ $rigctld_pid = "" ]] && [[ $piardop_pid = "" ]]; then
			launch_rigctld
			~/Radio/ARDOP/piardopc 8515 pulse pulse --cat /tmp/rigctl:19200 --keystring 5420310A --unkeystring 5420300A &
		fi
		
		if [[ $rigctld_pid != "" ]] && [[ $piardop_pid = "" ]] ;then
			killall rigctld
			launch_rigctld
			~/Radio/ARDOP/piardopc 8515 pulse pulse --cat /tmp/rigctl:19200 --keystring 5420310A --unkeystring 5420300A &
			if [[ $garim_pid != "" ]]; then
				xdotool search --name "garim" key space d e t Return		
				sleep 5s
				xdotool search --name "garim" key space a t t space 1 Return
			fi
		fi
}

launch_piardop_gui(){
		piardop_gui_pid=$(pidof piARDOP_GUI)
		if [[ $piardop_gui_pid = "" ]]; then 
			xdotool set_desktop 1
			((desk_counter++))
			~/Radio/ARDOP/piARDOP_GUI 8515 &
			app_window=""
			until [[ $app_window != "" ]]; do
				app_window=$(xdotool search --name ardop_gui);
				sleep 1;
			done
			xdotool search --onlyvisible --name ardop_gui windowmove 250 100
		fi
}

launch_garim(){
		pavucontrol_pid=$(pidof pavucontrol)
		rigctld_pid=$(pidof rigctld)
		piardop_pid=$(pidof piardopc)
		piardop_gui_pid=$(pidof piARDOP_GUI)
		garim_pid=$(pidof garim)
		
		if [[ $pavucontrol_pid = "" ]]; then
			launch_pavucontrol
		fi
		
		if [[ $rigctld = "" ]]; then
		launch_rigctld
		fi
		
		if [[ $piardop_pid = "" ]] ;then 
		launch_piardopc
		fi
		
		if [[ piardop_gui_pid = "" ]]
			then launch_piardop_gui
		fi

		if [[ $garim_pid = "" ]]; then 
			xdotool set_desktop 1
			((desk_counter++))	
			garim &
			app_window=""
			sleep 1
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "garim");
				sleep 1;
			done
			xdotool search --name garim windowmove 250 300
			sleep 2
			xdotool search --name "garim" key space a t t space 1 Return
		fi
}

check_garim(){
		pavucontrol_pid=$(pidof pavucontrol)
		rigctld_pid=$(pidof rigctld)
		piardop_pid=$(pidof piardopc)
		piardop_gui_pid=$(pidof piARDOP_GUI)
		garim_pid=$(pidof garim)
		
		if [[ $pavucontrol_pid = "" ]]; then
			launch_pavucontrol
		fi
		
		if [[ $rigctld = "" ]]; then
		launch_rigctld
		fi
		
		if [[ $piardop_pid = "" ]]
			then 
			launch_piardopc
			else
			testardop=$(netcat -w 10 localhost 8515)
			if [[ "$testardop" = "" ]]; then
			kill -9 $piardiop_pid
			sleep 1
			launch_piardopc
			sleep 1
			xdotool search --name "garim" key space a t t space 1 Return
			fi
		fi
		
		if [[ piardop_gui_pid = "" ]]
			then launch_piardop_gui
		fi

		if [[ $garim_pid = "" ]]; then 
			xdotool set_desktop 1
			((desk_counter++))	
			garim &
			app_window=""
			sleep 1
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "garim");
				sleep 1;
			done
			xdotool search --name garim windowmove 250 300
			sleep 2
			xdotool search --name "garim" key space a t t space 1 Return
		fi
}

launch_all(){
	# Check all apps and open any that aren't running
	launch_pavucontrol
	launch_conky
	launch_flrig
	launch_fldigi
	launch_js8call
	launch_rigctld
	launch_piardopc
	launch_piardop_gui
	launch_garim
}

# Parse valid arguemnts
for arg in "$@"
do

    if [ "$arg" = "" ]
    then
    echo "Starting all tri-mode programs."
    launch_all
    fi

    if [ "$arg" = "-start-all" ]
    then
    echo "Starting all tri-mode programs."
    launch_all
    fi
    
    if [ "$arg" = "-stop-all" ]
    then
    echo "Stopping all tri-mode programs."
    echo "Not yet implemented"
    fi
    
    if [ "$arg" = "-reboot" ]
    then
    echo "Preparing for reboot."
    echo "Not yet implemented"
    fi
    
    if [ "$arg" = "-start-flrig" ]
    then
    echo "Starting FLRig."
    launch_flrig
    fi
    
    if [ "$arg" = "-stop-flrig" ]
    then
    echo "Stopping FLRig."
    echo "Not yet implemented"
    fi
    
    if [ "$arg" = "-start-fldigi" ]
    then
    echo "Starting FLDigi."
    launch_fldigi
    fi
    
    if [ "$arg" = "-stop-fldigi" ]
    then
    echo "Stopping FLDigi."
    fi
    
    if [ "$arg" = "-start-js8call" ]
    then
    echo "Starting JS8Call."
    launch_js8call
    fi
    
    if [ "$arg" = "-stop-js8call" ]
    then
    echo "Stopping JS8Call."
    stop_js8call
    fi
    
    if [ "$arg" = "-start-garim" ]
    then
    echo "Starting gARIM."
    launch_garim
    fi
    
    if [ "$arg" = "-stop-garim" ]
    then
    echo "Stopping gARIM."
    echo "Not yet implemented"
    fi
done

if [ $desk_counter != 0 ]; then
    xdotool set_desktop $desk_num
fi
