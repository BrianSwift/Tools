#!/bin/sh

# Show "LAN host to Internet network connections" based on NAT page on AT&T U-verse 5268AC router

# set -x
rm -f nat-table.html local-name-lookup.html

# Fetch the NAT page from AT&T U-verse 5268AC router

[ -s nat-table.html ] || curl http://192.168.1.254/xslt?PAGE=C_5_5 >nat-table.html

# Reformat to table of local and remote IP addresses

grep src=192 nat-table.html | sed  -n 's/.\{1,80\}src=\([^ ]*\) dst=\([^ ]*\).*/\1 \2/p' | sort | uniq -c | sed 's/^/NAT /' >nat-table.txt

:<<nat-table.txt-EXAMPLE
NAT    1 192.168.1.64 17.249.28.24
NAT    2 192.168.1.65 108.174.10.10
NAT    1 192.168.1.65 17.188.135.186
nat-table.txt-EXAMPLE

# Generate 'hostname ether IP' table from Settings -> LAN -> Status page in router

# Fetch page
[ -s local-name-lookup.html ] || curl http://192.168.1.254/xslt?PAGE=C_2_0 >local-name-lookup.html

# Reformat
xmllint --html --xpath "/html//table[@id = 'device-table']/tr/td[1] | /html//table[@id = 'device-table']/tr/td[3] | /html//table[@id = 'device-table']/tr/td[5]" local-name-lookup.html | sed -e $'s/<td class="rowlabel">/\\\n/g' -e 's/<[/]td><td>/ /g' -e 's/<[/]td>//g' -e 's/<br>/ /g' | grep '...' | sed -e 's/^/HOST /' >local-name-lookup.txt

:<<local-name-lookup.txt-EXAMPLE
HOST unknownF8461C1E536B f8:46:1c:1e:53:6b 192.168.1.71
HOST SqueezeboxRadio 00:04:20:28:2e:88 192.168.1.79
HOST unknownEC1A59F72C21 ec:1a:59:f7:2c:21 192.168.1.77
local-name-lookup.txt-EXAMPLE

# 
cat >reformat.awk <<'EOF'
/^HOST /{
  hostName=$2; ether=$3; ipv4=$4
  if(ipv4 ~ /../){
    ipToHostName[ipv4]=hostName
#    print ipv4,ipToHostName[ipv4]
  }
}
/^NAT /{
  localIP=$3
  remoteIP=$4
  if(localIP != lastDigIP){
    cmd="dig +short -x " localIP
    cmd|getline
    close(cmd)
    localHostname=$1
    lastDigIp=localIP
  }
    cmd2="dig +short -x " remoteIP
    if(cmd2|getline == 1){
      remoteHostname=$0
    } else {
      remoteHostname="dig_failed"
    }
    close(cmd2)
  if((ipToHostName[localIP]".") != localHostname){
    print "DEBUG",localIP,ipToHostName[localIP],localHostname,remoteHostname,remoteIP
  } else {
    print localIP,localHostname,remoteHostname,remoteIP
  }
}
EOF

awk -f reformat.awk local-name-lookup.txt nat-table.txt

:<<EndSampleOutput
192.168.1.64 Megaladapis. dig_failed 17.249.28.24
192.168.1.65 HiCat. 108-174-10-10.fwd.linkedin.com. 108.174.10.10
192.168.1.65 HiCat. dig_failed 17.188.135.186
EndSampleOutput
