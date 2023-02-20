#!/bin/bash
version="1.0"
SCRIPTDIR=$(dirname "$(readlink -f "$0")")

ssh_dir=$SCRIPTDIR"/Database"
Wordlist_dir=$SCRIPTDIR"/Wordlist"
scripts_dir=$SCRIPTDIR"/Scripts"

function rand_name_gen(){
	snake_num=$(( 1 + $RANDOM % $(wc -l < $Wordlist_dir/snakes.txt) )); snake=$(sed -n "${snake_num}p" $Wordlist_dir/snakes.txt)
	adjective_num=$(( 1 + $RANDOM % $(wc -l < $Wordlist_dir/adjectives.txt) )); adjective=$(sed -n "${adjective_num}p" $Wordlist_dir/adjectives.txt)
	randname=$adjective"_"$snake
}
function rand_pwd_gen(){
	randpwd=$(openssl rand -hex 60)
}

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
.........._|......\n V:$version SRV MANAGER SURGAT (WHO OPEN THE DOORS)
"


function machine_choose(){
	echo ""
	echo -ne "${RED}CHOOSE THE MACHINE: ${NC}\n"
	echo ""
	fffff=""
	fffff=$(for (( i=1; i <= $machines_count; i++ )); do
		echo -e "Thiswouldbereplacedwithnewline$i." "${names[$i-1]}|${users[$i-1]}|${ips[$i-1]}|${ports[$i-1]}"
	done)

	DATA=$(echo -e "MACHINE NAME|USER|IP|SSH_PORT"$fffff | sed 's/Thiswouldbereplacedwithnewline/\n/g'|column -t -s "|")
	GREEN_SED='\\033[0;32m'
	RED_SED='\\033[0;31m'
	NC_SED='\\033[0m' # No Color
	echo -e "$(sed -e "s/MACHINE NAME/${RED_SED}MACHINE NAME${NC_SED}/g" -e "s/USER/${RED_SED}USER${NC_SED}/g" -e "s/IP/${RED_SED}IP${NC_SED}/g" -e "s/SSH_PORT/${RED_SED}SSH_PORT${NC_SED}/g" <<< "$DATA")"

	echo ""

	read chosen_machine
	chosen_machine_array_number=$(($chosen_machine - 1))
}
function ssh_add(){
	echo ""
	echo -e -n "${RED}PROVIDE USER NAME: ${NC}"
	read user_name
	echo -e -n "${RED}PROVIDE MACHINE IP: ${NC}"
	read machine
	echo -e -n "${RED}PROVIDE PORT: ${NC}"
	read port
	echo -e -n "${RED}PROVIDE NICKNAME FOR MACHINE: ${NC}"
	read name
	echo -e -n "${RED}PROVIDE NOTES (hit enter) ${NC}"
	read asdcasdcasdc
	nano $notes_dir/$user_name"@"$machine
	echo $user_name"@"$machine:$port"|"$name >> $machines_file
	ssh-keygen -t rsa -q -N '' -f $keys_dir/$user_name"@"$machine
	ssh-copy-id -p $port -i $keys_dir/$user_name"@"$machine.pub $user_name@$machine
	echo ssh_menu
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
	echo -e -n "${RED}ARE YOU SHURE YOU WAND TO DELETE ${NC}$name_to_del:$ip_to_del ${RED}(Y/y)? ${NC}"
	read REPLY
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
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
		echo ""
		echo -e "${RED}MACHINE ${NC}$name_to_del $ip_to_del:$port_to_del${RED} DELETED !!!${NC}"
		echo ""
	fi
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
	args_at_end=""
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
	echo "Provide remote server from where to fork traffic:"
		frk_srv
	echo "Provide remote server port where to fork traffic:"
		frk_srv_prt
	args_at_end="socat TCP-LISTEN:$lcl_prt,fork TCP:$frk_srv:$frk_srv_prt"
	ssh_connect_run
}
function forward_srv_to_arm(){
	echo "Provide port at SRV you want to forward to ARM:"
		read port_remote
	echo "Provide local ARM port to use:"
		read port_local
	read -p "Background ssh session? (y/n)" choice
	case "$choice" in
	  y|Y ) args_at_start="-M -S my-socket-name -fNT -L $port_local:0.0.0.0:$port_remote";;
	  n|N ) args_at_start="-M -S my-socket-name -L $port_local:0.0.0.0:$port_remote";;
	  * ) echo "invalid";;
	esac
	ssh_connect_run
}
function forward_arm_to_srv(){
	echo "Provide port on ARM you want to forward to SRV:"
		read port_local
	echo "Provide SRV port to use:"
		read port_remote
	read -p "Background ssh session? (y/n)" choice
	case "$choice" in
	  y|Y ) args_at_start="-M -S my-socket-name -fNT -R $port_remote:0.0.0.0:$port_local";;
	  n|N ) args_at_start="-M -S my-socket-name -R $port_remote:0.0.0.0:$port_local";;
	  * ) echo "invalid";;
	esac
	read -p "Add UFW rule on SRV to accept connections to port? (y/n)" choice
	case "$choice" in
	  y|Y ) args_at_end="ufw allow "$port_remote" && ufw reload" && ssh_connect_run;;
	  n|N ) nop=nop;;
	  * ) echo "invalid";;
	esac
	ssh_connect_run
}
function list_users(){
	args_at_end="awk -F: '{ print \$1}' /etc/passwd"
	ssh_connect_run
}
function list_fw(){
	args_at_end="ufw status numbered"
	ssh_connect_run
}
function allow_port_fw(){
	echo "What port to open?"
		read port_to_open
	args_at_end="ufw allow $port_to_open && ufw reload && ufw status numbered"
	ssh_connect_run
}
function disallow_port_fw(){
	echo "What port to open?"
		read port_to_open
	args_at_end="ufw deny $port_to_open && ufw reload && ufw status numbered"
	ssh_connect_run
}
function del_rule_fw(){
	args_at_end="ufw status numbered"
	ssh_connect_run
	echo "What rule to del?"
		read rule_to_del
	args_at_end="ufw delete "$rule_to_del
	echo -e ${BLUE}
	ssh $args_at_start ${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]} -p ${ports[$chosen_machine_array_number]} -i $keys_dir/${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]} $args_at_end
	echo -e ${NC}
}
function wipe_db(){
	nop=nop
	#rm -rf ./Database
}
function enum_stuff(){
	machines=($(sed "s/|.*//" $machines_file))
	machines_count=${#machines[@]}
	machine_niks=($(sed "s/.*|//" $machines_file))
	users=($(sed "s/@.*//" $machines_file))
	names=($(sed "s/.*|//" $machines_file))
	ips=($(cat $machines_file | sed 's/.*@//' | sed 's/:.*//'))
	ports=($(cat $machines_file | sed 's/.*://' | sed 's/|.*//'))
}
function add_root_user(){
	rand_pwd_gen
	rand_name_gen
	args_at_end="adduser --quiet --disabled-password --force-badname $randname && usermod -aG sudo $randname && echo $randname:$randpwd | chpasswd"
	echo ""
	ssh_connect_run && args_at_end=""
	echo "" && echo -e "${RED}NEW USER ADDED${NC}"
	echo -e "${RED}USERNAME: ${NC}"$randname
	echo -e "${RED}PASSWORD: ${NC}"$randpwd
	echo ""
	echo -e -n "${RED}GEN AND ADD KEY FOR USER? ${NC}$randname ${RED}(Y/y)? ${NC}"
		read REPLY
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		_username=$randname
		_machine_nik=${machine_niks[$chosen_machine_array_number]}
		_ip=${ips[$chosen_machine_array_number]}
		_port=${ports[$chosen_machine_array_number]}
		echo "####################" >> $notes_dir/$_username"@"$_ip
		echo "USER ADDED $(date +%m-%d-%Y)" >> $notes_dir/$_username"@"$_ip
		echo "USERNAME: $randname (sudoers)" >> $notes_dir/$_username"@"$_ip
		echo "PASSWORD: $randpwd" >> $notes_dir/$_username"@"$_ip
		echo "" >> $notes_dir/$_username"@"$_ip
		echo "####################" >> $notes_dir/$_username"@"$_ip
		echo -e -n "${RED}PROVIDE NOTES (hit enter) ${NC}"
			read asdcasdcasdc
		nano $notes_dir/$_username"@"$_ip

		echo $_username"@"$_ip:$_port"|"$_machine_nik >> $machines_file
		echo ""
		ssh-keygen -t rsa -q -N '' -f $keys_dir/$_username"@"$_ip
		ssh-copy-id -p $_port -i $keys_dir/$_username"@"$_ip.pub $_username@$_ip
		ssh_menu
	fi
	randname=""
	randpwd=""
}
function add_fwd_user(){
	rand_pwd_gen
	rand_name_gen
	echo -e -n "${RED}TO WHAT PORT ON WHAT INTERFACE PROVIDE ACCESS (Ex: 127.0.0.1:9050)${NC}:"
		read allowed_port
	args_at_end="adduser --quiet --disabled-password --force-badname $randname && echo Match User $randname >> /etc/ssh/sshd_config && echo PermitOpen $allowed_port >> /etc/ssh/sshd_config && echo X11Forwarding no >> /etc/ssh/sshd_config &&echo AllowAgentForwarding no >> /etc/ssh/sshd_config && echo ForceCommand /bin/false >> /etc/ssh/sshd_config && server ssh restart && echo $randname:$randpwd | chpasswd"
	echo ""
	ssh_connect_run && args_at_end=""
	echo "" && echo -e "${RED}NEW USER ADDED${NC}"
	echo -e "${RED}USERNAME: ${NC}"$randname
	echo -e "${RED}PASSWORD: ${NC}"$randpwd
	echo ""
	echo -e -n "${RED}GEN AND ADD KEY FOR USER? ${NC}$randname ${RED}(Y/y)? ${NC}"
		read REPLY
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		_username=$randname
		_machine_nik=${machine_niks[$chosen_machine_array_number]}
		_ip=${ips[$chosen_machine_array_number]}
		_port=${ports[$chosen_machine_array_number]}
		echo "####################" >> $notes_dir/$_username"@"$_ip
		echo "USER ADDED $(date +%m-%d-%Y)" >> $notes_dir/$_username"@"$_ip
		echo "USERNAME: $randname (sudoers)" >> $notes_dir/$_username"@"$_ip
		echo "PASSWORD: $randpwd" >> $notes_dir/$_username"@"$_ip
		echo "" >> $notes_dir/$_username"@"$_ip
		echo "####################" >> $notes_dir/$_username"@"$_ip
		echo -e -n "${RED}PROVIDE NOTES (hit enter) ${NC}"
			read asdcasdcasdc
		nano $notes_dir/$_username"@"$_ip

		echo $_username"@"$_ip:$_port"|"$_machine_nik >> $machines_file
		echo ""
		ssh-keygen -t rsa -q -N '' -f $keys_dir/$_username"@"$_ip
		ssh-copy-id -p $_port -i $keys_dir/$_username"@"$_ip.pub $_username@$_ip
		ssh_menu
	fi
	randname=""
	randpwd=""
}
function rename_machine(){
	machine_choose
	echo -e -n "${RED}PROVIDE NEW NICKNAME: ${NC}:"
		read new_nickname
	#rename in machines_file
	#rename all keys
	#rename notes
}
function implant_redirector_tcp(){
	echo -e -n "${RED}PROVIDE C2 ADRESS${NC}: "
		read c2adress
	echo -e -n "${RED}PROVIDE C2 PORT${NC}: "
		read c2port
	echo -e -n "${RED}PROVIDE PORT ON SRV TO ACT FOR REDIRECTING: ${NC}"
		read redirectorport
	args_at_end="apt update" && 	ssh_connect_run
	args_at_end="apt-get -y install socat" && 	ssh_connect_run
	args_at_end="echo \"@reboot socat TCP4-LISTEN:$redirectorport,fork TCP4:$c2adress:$c2port\" >> /etc/cron.d/mdadm" && 	ssh_connect_run
	args_at_end="init 6" && 	ssh_connect_run
	echo -e -n "${YELLOW}REDIRECTOR SETUP, WAIT A BIT CUZ SERVER RELOADING${NC}"

}
function implant_redirector_nginx(){
	machine_choose
	scp -P${ports[$chosen_machine_array_number]} -i $keys_dir/${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]} $scripts_dir/europeanhare/europeanhare.sh ${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]}:/tmp/
	args_at_end="chmod +x /tmp/europeanhare.sh"
	echo -e ${BLUE}
	ssh $args_at_start ${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]} -p ${ports[$chosen_machine_array_number]} -i $keys_dir/${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]} $args_at_end
	echo -e ${NC}
	args_at_end=""
	args_at_end="/tmp/europeanhare.sh"
	echo -e ${BLUE}
	ssh $args_at_start ${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]} -p ${ports[$chosen_machine_array_number]} -i $keys_dir/${users[$chosen_machine_array_number]}@${ips[$chosen_machine_array_number]} $args_at_end
	echo -e ${NC}
	args_at_end=""
}

function ssh_menu(){
	enum_stuff
		options=(
		"ADM.	--->	CONNECT" 									\
		"ADM.	--->	ADD MACHINE" 								\
		"ADM.	--->	DELETE MACHINE" 							\
		"ADM.	--->	RENAME MACHINE" 							\

		"ADM.	--->	WIPE DB" 									\
		"SRVCS.	--->	LIST SERVICES AT SRV" 						\
		"SRVCS.	--->	STOP SERVICE AT SRV BY PORT" 					\
		"PRTFWD.	--->	FORWARD PORT FROM SRV TO ARM" 				\
		"PRTFWD.	--->	FORWARD PORT FROM ARM TO SRV" 				\
		"PRTFWD.	--->	FORWARD PORT FROM ANOTHER SERVER TO SRV (SOCAT)" 	\
		"PRTFWD.	--->	LIST ARM FWDS" 							\

		"C2.		--->	IMPLANT REDIRECTOR ( TCP ) MODE ON HOST"		\
		"C2.		--->	IMPLANT NGINX REDIRECTOR ( HTTP/HTTPS )" 		\

		"USERS.	--->	LIST USERS ON SRV" 							\
		"USERS.	--->	ADD ROOT USER TO SRV" 						\
		"USERS.	--->	ADD  USER FOR PRTFWD " 						\
		"FW.		--->	LIST RULES ON SRV" 							\
		"FW.		--->	ALLOW PORT ON SRV" 							\
		"FW.		--->	DENY PORT ON SRV" 							\
		"FW.		--->	DEL FW RULE ON SRV")

	echo "$title"
	PS10="$prompt "
	select opt in "${options[@]}"; do
	    case "$REPLY" in
	    1 ) if [ "$machines_count" -eq "0" ]; then echo -e "\n${RED}SORRY 0 MACHINES WAS ADDED TO SURGAT${NC}\n"; continue; else ssh_connect; fi; break;;
	    2 ) ssh_add; break;;
	    3 ) if [ "$machines_count" -eq "0" ]; then echo -e "\n${RED}SORRY 0 MACHINES WAS ADDED TO SURGAT${NC}\n"; continue; else ssh_delete; fi; break;;
	    4 ) wipe_db; break;;
	    5 ) rename_machine; break;;
	    6 ) srv_list_service; break;;
	    7 ) srv_stop_service; break;;
	    8 ) forward_srv_to_arm; break;;
	    9 ) forward_arm_to_srv; break;;
	    10 ) socat_fwd_on_srv_tcp; break;;
	    11 ) list_arm_fwds; break;;
	    12 ) implant_redirector_tcp; break;;
	    13 ) implant_redirector_nginx; break;;
	    14 ) list_users; break;;
	    15 ) add_root_user; break;;
	    16 ) add_fwd_user; break;;
	    17 ) list_fw; break;;
	    18 ) allow_port_fw; break;;
	    19 ) disallow_port_fw; break;;
	    20 ) del_rule_fw; break;;
	    $(( ${#options[@]}+1 )) ) echo "Invalid option. Try another one.";continue;;
	    *) echo "Invalid option. Try another one.";continue;;
	    esac
	done
}
echo -e ${RED}$banner${NC}
if [[ ! -d "$ssh_dir" ]]; then mkdir $ssh_dir; fi
if [[ ! -d "$keys_dir" ]]; then mkdir $keys_dir; fi
if [[ ! -d $fastactions_dir ]]; then mkdir $fastactions_dir; fi
if [[ ! -f $ssh_dir/machines ]]; then touch $ssh_dir/machines; fi
if [[ ! -d $ssh_dir/notes ]]; then	mkdir $ssh_dir/notes; fi
ssh_menu
