#!/bin/sh

export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

out () {
    printf '%s\n' "$@"
}

gen_top () {
    out "gen top list"
    # remove Microsoft Carriage Return
    # input this with ctrl v then ctrl m, or use '\r$'
    toplist='https://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip'
    curl $curl_opt $toplist -o temp/top-1m.csv.zip 2>> err.log || return
    gunzip < temp/top-1m.csv.zip |
    head -n 400000 |
    cut -d, -f2 |
    sed 's|\r$||' > temp/top.list
}

gen_cn () {
    out "gen chn top list"
    # felixonmars source
    local url files
    url='https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master'
    files='apple.china.conf,google.china.conf,accelerated-domains.china.conf'

    ( cd temp
    curl $curl_opt -Z --no-progress-meter -OOO "$url/{$files}" 2>> err.log || return
    cat $(echo $files | tr ',' ' ')
    ) | cut -d '/' -f2 |
    grep -v -e '\.cn$' -e '^cn$' -e '^[[:blank:]]*#' -e '^[[:blank:]]*$' |
    sort | uniq > temp/felix.cn.list

    # find top chinese domains in top.list
    grep -Fx -f temp/felix.cn.list temp/top.list > chn.top.list

    # add cn to cnh.top.list
    echo 'cn' >> chn.top.list

    # allow customize chn list
    cat files/custom.chn.list >> chn.top.list
}

gen_gfw () {
    out "gen gfw top list"
    local gfwlist
    gfwlist='https://github.com/gfwlist/gfwlist/raw/master/gfwlist.txt'
    curl $curl_opt $gfwlist -o temp/gfwlist.txt 2>> err.log || return
    base64 -d < temp/gfwlist.txt |
    grep -vE '^\!|\[|^@@|(https?://){0,1}[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' |
    sed -E 's#^(\|\|?)?(https?://)?##g' |
    sed -E 's#/.*$|%2F.*$##g' |
    grep -E '([a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)' |
    sed -E 's#^(([a-zA-Z0-9]*\*[-a-zA-Z0-9]*)?(\.))?([a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)(\*[a-zA-Z0-9]*)?#\4#g' > temp/gfwlist.list

    grep -v -h -e '\.cn$' -e '^cn$' -e '^[[:blank:]]*#' -e '^[[:blank:]]*$' temp/gfwlist.list files/google.list |
    sort | uniq  > temp/gfwlist.merge.list

    # find top gfw domains in top.list
    grep -Fx -f temp/gfwlist.merge.list temp/top.list > gfw.top.list

    # add blocked .cn to gfw.top.list
    grep '\.cn$' temp/gfwlist.list | sort | uniq >> gfw.top.list

    # allow customize gfw list
    cat files/custom.gfw.list >> gfw.top.list
}

gen_chn () {
    out "gen chnroute chnroute6"
    local apnic ipip
    apnic='https://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest'
    ipip='https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt'
    
    curl $curl_opt -o temp/apnic -o temp/ipip $apnic $ipip 2>> err.log || return

    # chnroute v4
    awk -F'|' '/CN\|ipv4/ { printf("%s/%d\n", $4, 32-log($5)/log(2)) }' temp/apnic > temp/apnic.v4
    ip-dedup -4 -o chnroute temp/ipip temp/apnic.v4

    # chnroute v6
    awk -F'|' '/CN\|ipv6/ { printf("%s/%d\n", $4, $5) }' temp/apnic | ip-dedup -6 -o chnroute6
}

git_cp () {
    git pull # in case modified from github web
    git commit -a -m "$*"
    git push
}

now=$(date '+%F %T')
curl_opt="--connect-timeout 10 -sSfL"

cd ${0%/*} # must run with full path
mkdir -p temp files
out "$now" >> err.log
gen_top
gen_cn
gen_gfw
gen_chn
git_cp "update : $now"
