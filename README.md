**Disclaimer**

This script was created for personal/educational purposes. Use at your own risk.

**Description**

A bash script that performs a basic or full scan on a host or network of hosts for TCP/UDP services. Basic scan performs scan of targets for TCP/UDP services and brute forces Telnet, SSH, RDP or FTP services. Full scan performs basic + vulnerability scan using searchsploit attempts to run metasploit backdoor exploits.

**How to use**

Running the script will check for required applications.


If apps are installed, user to choose between basic or full scan, and enter a directory name to save the scan information.


User to enter the target(s) in the accepted formats; 10.0.0.1-255 or 10.0.0.0/24 or any single IP.
Script will scan the targets using nmap and masscan.

Brute force (SSH, RDP, FTP and Telnet) will start after the scan is completed. 

Vulnerability scan will start after brute force is complete. This will take place only if the user selected Full scan.





For certain backdoor vulnerabilities found, script will attempt to exploit using metasploit backdoor.



User can choose to view the reports or exit the script.
