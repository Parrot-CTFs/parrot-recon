#!/bin/bash

#TODO
# setups come first before functions makes it more organized 

# banner
cat << "EOF"
   ___                    __        ___                  
  / _ \___ ____________  / /____   / _ \___ _______  ___ 
 / ___/ _ `/ __/ __/ _ \/ __(_-<  / , _/ -_) __/ _ \/ _ \
/_/   \_,_/_/ /_/  \___/\__/___/ /_/|_|\__/\__/\___/_//_/

   /.\                          
   |  \                  
   /   \                 
  //  /                  
  |/ /\_
 / /            
/ /     
\/ 
EOF

# env variables 
red=`tput setaf 1`
white=`tput setaf 7`
green=`tput setaf 2`
domain=$1
ipaddr=$2
working_dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
results_dir=$working_dir/results
tools_dir=$working_dir/tools


echo "[*] Domain Name: $domain"
echo "[*] IP Address:  $(host $domain | awk '/has address/ { print $4 ; exit }')"


if [ $# -eq 0 ]
then
   echo "[!] No Domain Defined"
   echo "[-] Usage: ./parrot-recon.sh <domain>"
   exit 0
fi

# root check
if [ `whoami` != "root" ]
then
   echo "[!] This Script Needs To Be Run As Root User"
   exit 0
fi

# setting up directories for recon tool
echo "[+] Setting Up Enviornment"
if [ ! -d "$results_dir" ]
then
   mkdir $results_dir
fi


##################### Parrot added 


# enumeration proccess using tools from install script

echo "$red[+] Starting URL DORK Scan$white"
bash $tools_dir/dork.sh $domain > $results_dir/$domain-dork.txt
echo "$green[+] Outputed To: $results_dir/$domain-dork.txt"

echo "$red[+] Starting Nmap TCP Scan$white"
nmap -sV -sC $domain -oA $results_dir/$domain-tcp-scan --open

echo "$red[+] Starting Nmap UDP Scan$white"
nmap -sV -sU $domain -oA $results_dir/$domain-udp-scan --open 

echo "$red[+] Starting IDS/IPS Detection $white"
wafw00f https://$domain -o $results_dir/wafw00f-$domain.txt || wafw00f http://$domain -o $results_dir/wafw00f-$domain.txt

echo "$red[+] Starting Subdomain Enumeration$white"
sublist3r -d $domain -o $results_dir/subdomains-$domain.txt 

echo "$red[+] Starting Nikto Scan$white"
nikto -h $domain -o $results_dir/nikto-$domain.txt

echo "$red[+] Starting Server Enumeration$white"


# possibly use curl in the future
echo "$red[+] Starting Request Enumeration$white"
ruby http-get-header.rb $domain > $results_dir/req.txt
echo "$green[+] Outputed To File In $results_dir/req.txt"

echo "$red[+] Starting Domain and File Brute Force$white"
dirsearch -u $domain -w /usr/share/wordlists/dirbuster/directory-list-1.0.txt -o $results_dir/$domain-server-dirs.txt

echo "$red[+] Starting CMS Enumeration$white"
cmsmap -F https://$domain -o $results_dir/cmsenum-$domain.txt || cmsmap -F http://$domain -o $results_dir/cmsenum-$domain.txt

echo "$red[+] Starting S3 Bucket Enumeration$white"
python -m $tools_dir/S3Scanner scan --buckets-file $results_dir/subdomains-$domain.txt > $results_dir/s3enumeration-$domain.txt 

echo "$red[+] Starting SSL Scans$white"
sslyze --regular $domain > $results_dir/$domain-sslyze-regular.txt
sslyze --heartbleed $domain > $results_dir/$domain-sslyze-heartbleed.txt
sslyze --robot $domain > $results_dir/$domain-sslyze-robot.txt

echo "$red[+] Starting Nuclei Scans$white"
nuclei -u $domain -o $results_dir/nuclei-$domain.txt

echo "$red[+] Starting OWASP Enumeration$white"

echo "$red[+] Starting Injection Enumeration$white"
injectx.py -u https://$domain || injectx.py -u http://$domain 

echo "$red[+] Starting CORS Enumeration$white"
python3 $tools_dir/cors_scanner.py -u https://$domain -csv $results_dir/$domain-cors.csv || python3 $tools_dir/cors_scanner.py -u http://$domain -csv $results_dir/$domain-cors.csv

echo "$red[+] Starting HTTP HEADER INJECTION Enumeration$white"
headi -u https://$domain/ > $results_dir/headi-$domain.txt || headi -u http://$domain/ > $results_dir/headi-$domain.txt

echo "$red[+] Starting GraphQL Injection Enumeration$white"
#need to work on a automation replacement
#python3 graphqlmap.py 

echo "$red[+] Starting Open Redirect Enumeration$white"
python3 $tools_dir/Injectus.py -u https://$domain -op > $results_dir/open-redirect-$domain.txt || python3 $tools_dir/Injectus.py -u http://$domain -op > $results_dir/open-redirect-$domain.txt

echo "$red[+] Starting CRLF Enumeration$white"
python3 $tools_dir/Injectus.py -u https://$domain -c > $results_dir/crlf-$domain.txt || python3 $tools_dir/Injectus.py -u http://$domain -c > $results_dir/crlf-$domain.txt

echo "$red[+] Starting XSS Enumeration$white"
python3 $tools_dir/xssi.py $domain -o $results_dir/xssi-$domain.txt 

echo "$red[+] Starting XSRF/CSRF Enumeration$white"
xsrfprobe -u $domain -o $results_dir/xsrf-csrf-$domain

echo "$red[+] Starting SQLI Enumeration$white"
python3 $tools_dir/sqli.py $domain -o $results_dir/sqli-$domain.txt

echo "$red[+] Starting JWT Enumeration$white"
read -p "ENTER A JWT TOKEN (If none press [ENTER]): " token 
python3 $tools_dir/jwt_tool.py $token > $results_dir/jwt-enumeration-$domain.txt

echo "$red[+] Starting Subdomain Takover Enumeration$white"
subzy -targets $results_dir/subdomains-$domain.txt > $results_dir/takeover-$domain.txt

echo "$red[+] Starting DIRECTORY TRAVERSAL Enumeration$white"
python3 $tools_dir/fdsploit.py -u https://$domain > $results_dir/directory-traversal-$domain.txt || python3 $tools_dir/fdsploit.py -u http://$domain > $results_dir/directory-traversal-$domain.txt

echo "$red[+] Starting XXE Enumeration$white"
# need to work on a fix for this 
# enum up top for a request 
#ruby $tools_dir/XXEinjector.rb --host=$ipaddr --output=$results_dir/xxe-injection-$domain.txt --phpfilter

echo "$red[+] Starting RFI/LFI Enumeration$white"
ffuf -c -w /usr/share/wordlists/dirb/common.txt -u  https:$domain/FUZZ -e .php,.html,.js,.asp,.sh -o $results_dir/$domain-ffuf.txt || ffuf -c -w /usr/share/wordlists/dirb/common.txt -u  http:$domain/FUZZ -e .php,.html,.js,.asp,.sh -o $results_dir/$domain-ffuf.txt

echo "$red[+] Starting OS COMMAND INJECTION Enumeration$white"
commix -u https://$domain --level 3 || commix -u http://$domain --level 3 

echo "$red[+] Starting HTTP SMUGGLING Enumeration$white"
python3 $tools_dir/smuggle.py -u https://$domain > $results_dir/smuggle-$domain.txt || python3 $tools_dir/smuggle.py -u http://$domain > $results_dir/smuggle-$domain.txt



echo "$red[+] Script Done!$white"
echo "$red[+] Check Your Results Directory For The Output!$white"