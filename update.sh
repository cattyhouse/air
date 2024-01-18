#/bin/bash
set -x
set -o errexit
#set -o pipefail

export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

out () {
    printf '%s\n' "$@"
}

gen_top () {
    out "gen top list"
    # remove Microsoft Carriage Return
    # input this with ctrl v then ctrl m, or use '\r$'
    toplist='https://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip'
    curl -sfL $toplist |
    gunzip |
    head -n 200000 |
    cut -d, -f2 |
    sed 's|\r$||' > temp/top.list
}

gen_cn () {
    out "gen chn top list"
    # felixonmars source
    local felix_apple felix_google felix_china
    felix_apple='https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/apple.china.conf'
    felix_google='https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/google.china.conf'
    felix_china='https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf'

    curl -sfZL --no-progress-meter $felix_apple $felix_google $felix_china |
    cut -d '/' -f2 |
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
    curl -sfL $gfwlist | base64 -d |
    grep -vE '^\!|\[|^@@|(https?://){0,1}[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' |
    sed -r 's#^(\|\|?)?(https?://)?##g' |
    sed -r 's#/.*$|%2F.*$##g' |
    grep -E '([a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)' |
    sed -r 's#^(([a-zA-Z0-9]*\*[-a-zA-Z0-9]*)?(\.))?([a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)(\*[a-zA-Z0-9]*)?#\4#g' > temp/gfwlist.list

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
    
    curl -sfL -o temp/apnic -o temp/ipip $apnic $ipip

    # chnroute v4
    awk -F'|' '/CN\|ipv4/ { printf("%s/%d\n", $4, 32-log($5)/log(2)) }' temp/apnic > temp/apnic.v4
    cat temp/ipip temp/apnic.v4 | netaggregate > chnroute

    # chnroute v6
    awk -F'|' '/CN\|ipv6/ { printf("%s/%d\n", $4, $5) }' temp/apnic | netaggregate > chnroute6
}

git_cp () {
    git pull # in case modified from github web
    git commit -a -m "$*" || true
    git push
}

now=$(date '+%Y-%m-%d %H:%M:%S')

cd ${0%/*} # must run with full path
mkdir -p temp files
gen_top
gen_cn
gen_gfw
gen_chn
git_cp "update : $now"
