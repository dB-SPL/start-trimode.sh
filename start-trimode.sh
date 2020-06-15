#!/bin/bash

# Set file location variables
script_filename=$(basename "$0")
script_full_path=$(realpath $0)
script_dir=$(dirname "$script_full_path")
lockfile="$script_dir/var/lockfile"
modefile="$script_dir/var/mode"
js8call_autoreply_file="$script_dir/var/js8call-autoreply"
js8call_autoreply="$(cat $js8call_autoreply_file)"
garim_beacon_file="$script_dir/var/garim-beacon"
garim_beacon="$(cat $garim_beacon_file)"
script_pid=$(cat $lockfile)
idletime=$(xprintidle)
idlefile="$script_dir/var/idletime"
echo $idletime >$idlefile


# Set mode variable
if [[ $1 = "interactive" ]]; then
	mode="interactive"
fi

if [[ $1 = "away" ]]; then
	mode="away"
fi

if [[ $1 = "reset" ]]; then
	mode="away"
	js8call_autoreply="true"
	echo $js8call_autoreply >$js8call_autoreply_file
	garim_beacon="false"
	echo $garim_beacon >$garim_beacon_file
	echo $script_pid >$lockfile
fi

if [[ $1 != "interactive" ]] && [[ $1 != "away" ]] && [[ $1 != "reset" ]]; then
	mode=$(cat $modefile)
	if [ $idletime -gt 1800000 ]; then
		mode="away"
	fi
	
fi

echo $mode >$modefile

# Primt important variables to terminal for debugging
echo "mode = " $mode
echo "script_filename = "$script_filename
echo "script_full_path = "$script_full_path
echo "script_dir = "$script_dir
echo "lockfile = "$lockfile $(cat $lockfile)
echo "js8call_autoreply_file = "$js8call_autoreply_file
echo "js8call_autoreply = "$(cat $js8call_autoreply_file)
echo "garim_beacon_file = "$garim_beacon_file
echo "garim_beacon = "$(cat $garim_beacon_file)
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
	echo $script_pid >$lockfile
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

			xdotool search --name 'fldigi ver' windowactivate key F5
		fi	
}

launch_js8call(){
		js8call_pid=$(pidof js8call)
		if [[ $js8call_pid = "" ]]
			then xdotool set_desktop 2
			((desk_counter++))
			killall js8
			app_window=""
			js8call &
			sleep 1
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "js8call de kn4crd");
				sleep 1;
			done
			js8call_autoreply="true"
			echo $js8call_autoreply >$js8call_autoreply_file
		fi
}

launch_rigctld(){
		rigctld_pid=$(pidof rigctld)
		if [[ $rigctld_pid = "" ]]; then
			# Launch rigctld with socat
			socat pty,link=/tmp/rigctl,waitslave,b38400 tcp:localhost:4532,retry &
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
			/home/pi/Radio/ARDOP/piardopc 8515 pulse pulse --cat /tmp/rigctl:38400 --keystring 5420310A --unkeystring 5420300A &
		fi
		
		if [[ $rigctld_pid != "" ]] && [[ $piardop_pid = "" ]] ;then
			killall rigctld
			launch_rigctld
			~/Radio/ARDOP/piardopc 8515 pulse pulse --cat /tmp/rigctl:38400 --keystring 5420310A --unkeystring 5420300A &
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
			sleep 2
			xdotool search --name "garim" key space a t t space 1 Return
			garim_beacon="false"
			echo $garim_beacon >$garim_beacon_file
		fi
}

desk_counter=0
desk_num=$(xdotool get_desktop)


if [[ $mode = "" ]]; then
	
	# Set away mode or interactive
	val=$(yad --center --width=300 --height=100 --title "Start in Away Mode?" --image "dialog-question" --buttons-layout=center --text "Should I start in Interactive Mode or Away Mode?  Defaulting to Away Mode in 30 seconds." --timeout=30 --button=Interactive:0 --button=Away:1 )   
	ret=$?

	if [[ $ret -eq 0 ]]; then
		echo "Interactive Mode Clicked.  Exiting."
		mode="interactive"
		echo $mode >$(echo $script_dir)/var/mode
		echo "" >$lockfile	
		exit 0
	fi

	if [[ $ret -eq 1 ]]; then
		echo "Away Mode Clicked."
		mode="away"
		echo $mode >$(echo $script_dir)/var/mode
	fi

	if [[ $ret -eq 70 ]]; then
		echo "Timeout reached. Defaulting to Away Mode."
		mode="away"
		echo $mode >$(echo $script_dir)/var/mode
	fi
	
fi

if [[ $mode != "interactive" ]]; then

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
		
		# Return to original desktop
		if [[ $desk_counter != 0 ]]; then
			xdotool set_desktop $desk_num
		fi
		
	echo "" >$lockfile	

	exit
fi
