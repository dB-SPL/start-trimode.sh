#!/bin/bash

# Launch apps on specific desktops

launch_conky(){
		conky_pid=$(pidof conky)
		if [[ $conky_pid = "" ]]
			then conky &
		fi
}

launch_flrig(){
		flrig_pid=$(pidof flrig)		
		if [[ $flrig_pid = "" ]]
			then xdotool set_desktop 0
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
		if [[ $fldigi_pid = "" ]]
			then killall flamp
			killall flmsg		
			# Switch to FLDigi desktop and launch fldigi
			xdotool set_desktop 3
			fldigi &
			sleep 3
			app_window=""
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "fldigi");
				sleep 1;
			done

			# Minimize FLMSG and FLAMP windows
			app_window=""
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "flamp");
				sleep 1;
				xdotool windowminimize $app_window
			done
			app_window=""
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "flmsg");
				sleep 1;
				xdotool windowminimize $app_window;
			done
		fi
}

launch_js8call(){
		js8call_pid=$(pidof js8call)
		if [[ $js8call_pid = "" ]]
			then xdotool set_desktop 2
			app_window=""
			js8call &
			sleep 5
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "js8call de kn4crd");
				sleep 1;
			done
		fi
}

launch_pavucontrol(){
		pavucontrol_pid=$(pidof pavucontrol)
		if [[ $pavucontrol_pid = "" ]]
			then xdotool set_desktop 1
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

launch_rigctld(){
		rigctld_pid=$(pidof rigctld)
		if [[ $rigctl_pid = "" ]]
			then
			# Launch rigctld with socat
			socat pty,link=/tmp/rigctl,waitslave,b38400 tcp:localhost:4532,retry &
			rigctld -vvvvv -m 4 &
		fi
}

launch_piardopc(){
		# Check to make sure pavucontrol and rigctld are running
		pavucontrol_pid=$(pidof pavucontrol)	
		if [[ $pavucontrol = "" ]]
			then launch_pavucontrol 
		fi
		rigctld_pid=$(pidof rigctld)
		if [[ $rigctl_pid = "" ]]
			then launch_rigctld
		fi
		# Launch piardopc
		piardop_pid=$(pidof piardopc)
		if [[ $piardop_pid = "" ]]
			then ~/Radio/ARDOP/piardopc 8515 pulse pulse &
		fi
}

launch_piardop_gui(){
		piardop_gui_pid=$(pidof piARDOP_GUI)
		if [[ $piardop_gui_pid = "" ]]
			then xdotool set_desktop 1
			~/Radio/ARDOP/piARDOP_GUI 8515 &
		fi
}

launch_garim(){
		pavucontrol_pid=$(pidof pavucontrol)
		if [[ $pavucontrol_pid = "" ]]
			then launch_pavucontrol
		fi
		rigctld_pid=$(pidof rigctld)
		if [[ $rigctld = "" ]]
			then launch_rigctld
		fi
		piardop_gui_pid=$(pidof piardop_gui)
		if [[ piardop_gui_pid = "" ]]
			then launch_piardop_gui
		fi
		garim_pid=$(pidof garim)
		if [[ $garim_pid = "" ]]
			then xdotool set_desktop 1			
			garim &
			app_window=""
			sleep 1
			until [ $app_window != "" ]; do
				app_window=$(xdotool search --name "garim");
				sleep 1;
			done
		sleep 2
		xdotool search --name "garim" windowactivate
		xdotool keydown Alt key t keyup Alt key Down Right Return
		fi
}

launch_conky
launch_flrig
launch_fldigi
launch_js8call
launch_pavucontrol
launch_rigctld
launch_piardopc
launch_piardop_gui
launch_garim

exit
