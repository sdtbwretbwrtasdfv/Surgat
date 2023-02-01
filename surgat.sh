#!/bin/bash
version="1.0"
ssh_dir="Database"
keys_dir=$ssh_dir/keys
machines_file=$ssh_dir/machines
notes_dir=$ssh_dir/notes
fastactions_dir=$ssh_dir/fast_actions
args_at_end=""
args_at_start=""
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
tab=' '
banner="
 __.            ,\n
(__ . .._._  _.-+-\n
.__)(_|[ (_](_] |\n
.........._|......\n V:$version SRV MANAGER
"



function machine_choose {
	echo ""
	echo -ne "Choose the machine: \n"
	for (( i=1; i <= $machines_count; i++ ))
	do
		echo -e "$i." "${names[$i-1]} (${ips[$i-1]}:${ports[$i-1]})"
	done
		echo ""
		read chosen_machine
	chosen_machine_array_number=$(($chosen_machine - 1))
}
function ssh_add(){
	echo -n "Enter user name: "
	read user_name
	echo -n "Enter machine IP: "
	read machine
	echo -n "Enter Port: "
	read port
	echo -n "Enter the name of machine: "
	read name
	echo -n "Please Provide note "
		nano $notes_dir/$user_name"@"$machine
	echo $user_name"@"$machine:$port"|"$name >> $machines_file
	echo ""
	ssh-keygen -t rsa -q -N '' -f $keys_dir/$user_name"@"$machine
	ssh-copy-id -p $port -i $keys_dir/$user_name"@"$machine.pub $user_name@$machine
}
function ssh_delete(){
	machine_choose
	ip_to_del=$(echo ${ips[$chosen_machine_array_number]})
	username_to_del=$(echo ${users[$chosen_machine_array_number]})
	port_to_del=$(echo ${ports[$chosen_machine_array_number]})
	name_to_del=$(echo ${names[$chosen_machine_array_number]})
	string_to_del="$username_to_del@$ip_to_del:$port_to_del|$name_to_del"
	key=$keys_dir/$username_to_del@$ip_to_del
	keypub="$keys_dir/$username_to_del@$ip_to_del.pub"
	notes=$notes_dir/$username_to_del@$ip_to_del
	if [[ -f "$key" ]]
	then
		rm $key
	fi
	if [[ -f "$notes" ]]
	then
		rm $notes
	fi

	if [[ -f "$keypub" ]]
	then
		rm $keypub
	fi
	grep -v $string_to_del $machines_file >> $machines_file"_"
	rm $machines_file
	mv $machines_file"_" $machines_file
}
function ssh_connect(){
	machine_choose
	clear
	echo -e "Remember that:  ${YELLOW}\n"
	cat $notes_dir/${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]}
	echo -e ${NC}
	ssh ${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]} -p ${ports[$chosen_machine_array_number]} -i $keys_dir/${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]} $args_at_end
}
function ssh_connect_run(){
	machine_choose
	echo -e ${BLUE}
	ssh $args_at_start ${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]} -p ${ports[$chosen_machine_array_number]} -i $keys_dir/${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]} $args_at_end
	echo -e ${NC}
}
function srv_stop_service(){
	echo "Provide port to kill: "
		read port_to_kill
	args_at_end="sudo fuser -k "$port_to_kill"/tcp"
	ssh_connect_run
}
function srv_list_service(){
	args_at_end="sudo lsof -i -P -n | grep LISTEN | grep -v 127.0.0.1"
	ssh_connect_run
}
function forward_srv_to_arm(){
	echo "Provide port at SRV you want to forward to ARM:"
		read port_remote
	echo "Provide local ARM port to use:"
		read port_local
	args_at_start="-M -S my-socket-name -fNT -L $port_local:0.0.0.0:$port_remote"
	ssh_connect_run
}
function list_arm_fwds(){
	echo""
	echo -e "${BLUE}You set up the following local port forwardings:${YELLOW}"
	lsof -a -i4 -P -c '/^ssh$/' -u$USER -s TCP:LISTEN
	echo -e "${BLUE}The processes that set up these forwardings are:${YELLOW}"
	ps -f -p $(lsof -t -a -i4 -P -c '/^ssh$/' -u$USER -s TCP:LISTEN)
	echo -e "${BLUE}You set up the following remote port forwardings:${YELLOW}"
	ps -f -p $(lsof -t -a -i -c '/^ssh$/' -u$USER -s TCP:ESTABLISHED) | awk 'NR == 1 || /R (\S+:)?[[:digit:]]+:\S+:[[:digit:]]+.*/ '
	echo -e "${NC}"
}
function socat_fwd_on_srv_tcp(){
	echo "Provide local port on SRV:"
		lcl_prt
	echo "Provide remote server where to fork traffic:"
		frk_srv
	echo "Provide remote server port where to fork traffic:"
		frk_srv_prt
	args_at_end="socat TCP-LISTEN:$lcl_prt,fork TCP:$frk_srv:$frk_srv_prt"
	ssh_connect_run
}

function ssh_menu(){
	options=("Connect" "Add machine" "Delete machine" "List services at SRV" "Stop service at SRV" "FWD port from SRV to ARM" "List ARM FWDs" "Socat FWD TCP on SRV                         ")
	echo "$title"
	PS10="$prompt "
	select opt in "${options[@]}"; do
	    case "$REPLY" in
	    1 ) ssh_connect; break;;
	    2 ) ssh_add; break;;
	    3 ) ssh_delete; break;;
	    4 ) srv_list_service; break;;
	    5 ) srv_stop_service; break;;
	    6 ) forward_srv_to_arm; break;;
	    7 ) list_arm_fwds; break;;
	    7 ) socat_fwd_on_srv_tcp; break;;
	    $(( ${#options[@]}+1 )) ) echo "Invalid option. Try another one.";continue;;
	    *) echo "Invalid option. Try another one.";continue;;
	    esac
	done
}


function main(){
	echo -e ${RED}$banner${NC}
	if [[ ! -d "$ssh_dir" ]]; then mkdir $ssh_dir; fi
	if [[ ! -d "$keys_dir" ]]; then mkdir $keys_dir; fi
	if [[ ! -d $fastactions_dir ]]; then mkdir $fastactions_dir; fi
	if [[ ! -f $ssh_dir/machines ]]; then touch $ssh_dir/machines; fi
	if [[ ! -d $ssh_dir/notes ]]; then	mkdir $ssh_dir/notes; fi

	machines=($(sed "s/|.*//" $machines_file))
	machines_count=${#machines[@]}
	users=($(sed "s/@.*//" $machines_file))
	names=($(sed "s/.*|//" $machines_file))
	ips=($(cat $machines_file | sed 's/.*@//' | sed 's/:.*//'))
	ports=($(cat $machines_file | sed 's/.*://' | sed 's/|.*//'))

	ssh_menu

}
main
