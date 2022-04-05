#!/bin/bash
#used to automate CloudFlare using api

#Setup
_ConfFile=/whatever-the-path-to/cf.conf

_GlobalDBFile=$(grep -w Global_DataBase_Location $_ConfFile | awk {'print $3'})
_FullData=$(grep -w Database_For_Subdomains $_ConfFile | awk {'print $3'})
_SubdomainsDB=$(grep -w Database_For_Subdomains $_ConfFile | awk {'print $3'})
_LogFile=$(grep -w Logfile_Location $_ConfFile | awk {'print $3'})

_ScanResultFile=/what-ever-the-path-to/Scan_rslt.txt

_WP_Access_data=$(grep -w WP-ADMIN-PAGE $_ConfFile | sed 's/WP-ADMIN-PAGE = //g')


_api_mail=$(grep -w _API_MAIL $_ConfFile | awk {'print $3'})
_api_key=$(grep -w _API_KEY $_ConfFile | awk {'print $3'})

#End of setup

function help_ () {
  cat <<EOF
CloudFlare API Pack
  Usage:
    cf -show                Display all domains & subdomains
    cf -init                Connect to CloudFlare & Fetch all domains
    cf -build               Build Database of all subomdains available
    cf -scan                Will run complete Wp-access scan with all words in config file against all subdomains
    cf -create <domain> <name> <ip> proxy=true(or =false)
            Example: cf cglms.com test 213.52.174.21 proxy=true
    cf -purge <domain>      Will purge data
    cf -subdomains <domain> Will get all subdomains for specific domain
    cf -search <subdomain>  Will search all subdomains

EOF
}
#cf -create -domain cglms.com testik 213.52.174.21  <subbdomain name> -proxy=yes Will create a new subdomain


function show_db_ (){
  cat $_GlobalDBFile
}

function build_full_database_ () {
  > $_FullData
  while read line; do
    echo "Fetching $(echo $line | awk {'print $2'}) ..."
    get_sub_domains_ $_api_mail $_api_key $(echo $line | awk {'print $1'}) >> $_FullData
    sleep 1
done <$_GlobalDBFile

}


function buildDB_ () {
#buildDB_ <mail> <key>

  curl -s -X GET "https://api.Cloudflare.com/client/v4/zones/?per_page=100" \
    -H "X-Auth-Email: $1" \
    -H "X-Auth-Key: $2" -H "Content-Type: application/json" |  jq -r '.result[] | "\(.id) \(.name)"' > $_GlobalDBFile

}
#buildDB_ $_api_mail $_api_key $_GlobalDBFile

function domain_to_id_ (){
  echo $(grep -w $1 $_GlobalDBFile | awk {'print $1'})
}

function id_to_domain_ () {
  echo $(grep -w $1 $_GlobalDBFile | awk {'print $2'})

}

#id_to_domain_ 3df7c9e1e8a656319885a3c508291171
#domain_to_id_ cglms.com

function chk_wp_access_ () {
  >$_ScanResultFile
  touch $_ScanResultFile
  echo -e "Scanning... it may take time, Results will be in $_ScanResultFile \n"
  for i in $_WP_Access_data; do
    echo "Scanning sites against $i"
  for z in $(cat $_SubdomainsDB); do
      [[ $(curl -s -L -m 1 https://$z/$i |  grep 'Password' | wc -l) != 0 ]] && echo "https://$z/$i" | tee >> $_ScanResultFile
      echo -ne '.'
      sleep .5
  done
  sleep .5
done

}
#chk_wp_access_

function create_sub_domain_ (){
PROXIED="true"

 [[ $6 == 'proxy=false' ]] && PROXIED='false'


 curl -X POST "https://api.cloudflare.com/client/v4/zones/$3/dns_records/" \
      -H "X-Auth-Email: $1" \
      -H "X-Auth-Key: $2" \
      -H "Content-Type: application/json" \
      --data '{"type":"'"A"'","name":"'"$4"'","content":"'"$5"'","proxied":'"$PROXIED"',"ttl":'"1"'}'

}
#create_sub_domain_ <mail> <key> <zoneid> <name> <ip> <proxy=true>
#create_sub_domain_ <mail> <key> <zoneid> <name> <ip> <proxy=false>


#create_sub_domain_ $_api_mail $_api_key 3df7c9e1e8a656319885a3c508291171 test 213.52.174.58 proxy=true

function get_sub_domains_ () {
 curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$3/dns_records?type=A&per_page=100" \
   -H "X-Auth-Email: $1" \
   -H "X-Auth-Key: $2" \
   -H "Content-Type: application/json" \ | jq | grep -w name | sed 's/^[[:space:]]*//g' | awk {'print $2'} | sed 's/"//g' | sed 's/,//g'
}

#get_sub_domains_ <mail> <key> <zoneid>
#get_sub_domains_ $_api_mail $_api_key 3df7c9e1e8a656319885a3c508291171

function purge_ () {
#purge <mail> <key> <zoneid>
  curl -X POST "https://api.cloudflare.com/client/v4/zones/$3/purge_cache" \
  -H "X-Auth-Email: $1" \
  -H "X-Auth-Key: $2" \
  -H "Content-Type:application/json" \
  --data '{"purge_everything":true}'
}



[[ $# == 0 ]] && help_

case $1 in
  -show) cat $_FullData | more
  ;;
  -init) echo "Initializing..."; buildDB_ $_api_mail $_api_key; [ -s $_GlobalDBFile ] && echo "Success" || echo "Fail, Check Config file"
  ;;
  -build) echo "Building Database"; build_full_database_; echo "Added $(cat $_FullData | wc -l) Subdomains"
  ;;
  -scan) chk_wp_access_
  ;;
  -create) create_sub_domain_ $_api_mail $_api_key $(domain_to_id_ $2) $3 $4 $5
  ;;
  -purge) echo "Purging $2"; purge_ $_api_mail $_api_key $(domain_to_id_ $2)
  ;;
  -subdomains) grep "$2" $_FullData | more
  ;;
  -search) [[ $(grep $2 $_FullData | wc -l) == 0 ]] && echo "Nothing found..." || grep $2 $_FullData | more
  ;;
  *)
  echo 'Wrong argument? run cf for help'
  ;;
esac
