**Disclaimer**

This script was created for personal/educational purposes.

**Description**

A bash script that performs a basic or full scan on a host or network of hosts for TCP/UDP services. Basic scan performs scan of targets for TCP/UDP services and brute forces Telnet, SSH, RDP or FTP services. Full scan performs basic + vulnerability scan using searchsploit attempts to run metasploit backdoor exploits.

**How to use**

Running the script will check for required applications.
![image](https://github.com/user-attachments/assets/77737cfa-8767-4b60-a77c-09cd24505de1)


If apps are installed, user to choose between basic or full scan, and enter a directory name to save the scan information.
![image](https://github.com/user-attachments/assets/93a44b27-e35c-4c3a-825b-d53f12f79257)


User to enter the target(s) in the accepted formats; 10.0.0.1-255 or 10.0.0.0/24 or any single IP.
Script will scan the targets using nmap and masscan.

![image](https://github.com/user-attachments/assets/90f7a907-f5d0-4bde-8d26-bd7265f3c22b)

Brute force (SSH, RDP, FTP and Telnet) will start after the scan is completed. 
![image](https://github.com/user-attachments/assets/85be768d-b5ee-45db-ad09-14eaaeb1f1c1)

Vulnerability scan will start after brute force is complete. This will take place only if the user selected Full scan.
![image](https://github.com/user-attachments/assets/877ab9a7-2548-4952-9dca-3ba9fb5be940)





For certain backdoor vulnerabilities found, script will attempt to exploit using metasploit backdoor.
![image](https://github.com/user-attachments/assets/021a5a08-956d-4e7f-b859-cf76d05ab3ca)



User can choose to view the reports or exit the script.
![image](https://github.com/user-attachments/assets/9ef76723-21d0-43c1-a63e-4d2a67ca0854)
