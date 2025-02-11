#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PURPLE="\033[0;35m"
CYAN='\033[0;36m'
ENDC='\033[0m'

check_wget() {
    if  [ ! -e '/usr/bin/wget' ]; then
        echo "请先安装 wget" && exit 1
    fi
}

check_bimc() {
    if  [ ! -e './bimc' ]; then
        echo "正在获取组件"
        arch=$(uname -m)
        wget --no-check-certificate -qO bimc https://bimc.gink.cc/bimc-$arch > /dev/null 2>&1
        chmod +x bimc
    fi
}

print_info() {
    echo "——————————————————————————— HyperSpeed 节点修复版—————————————————————————————"
    echo "         bash <(curl -Lso- https://is.gd/Y7iQH0)"
    echo "         项目修改自: https://bench.im/hyperspeed"
    echo "         项目修改自: https://github.com/zq/superspeed/"
    echo "         脚本更新by ChinaNet AS4134  2024/1/29"
    echo "————————————————————————————————————————————————————————————————————"
}

get_options() {
    echo -e "  测速类型:    ${GREEN}1.${ENDC} 三网测速    ${GREEN}2.${ENDC} 取消测速    ${GREEN}0.${ENDC} 港澳台日韩"
    echo -e "               ${GREEN}3.${ENDC} 电信节点    ${GREEN}4.${ENDC} 联通节点    ${GREEN}5.${ENDC} 移动节点"
    echo -e "               ${GREEN}6.${ENDC} 教育网IPv4  ${GREEN}7.${ENDC} 教育网IPv6  ${GREEN}8.${ENDC} 三网IPv6"
    while :; do read -p "  请选择测速类型(默认: 1): " selection
        if [[ "$selection" == "" ]]; then
            selection=1
            break
        elif [[ ! $selection =~ ^[0-8]$ ]]; then
            echo -e "  ${RED}输入错误${ENDC}, 请输入正确的数字!"
        else
            break   
        fi
    done
    while :; do read -p "  启用八线程测速[y/N](默认: N): " multi
        if [[ "$multi" == "y" ]]; then
            thread=" -m"
            break
        else
            thread=""
            break 
        fi
    done
}

speed_test(){
    local nodeLocation=$1
    local nodeISP=$2
    local extra=$3
    local dl=$(echo "$4"| base64 -d)
    local ul=$(echo "$5"| base64 -d)
    local name=$(./bimc -n "$nodeLocation")

    output=$(./bimc $dl $ul$thread $extra)
    local upload="$(echo "$output" | cut -n -d ',' -f1)"
    local uploadStatus="$(echo "$output" | cut -n -d ',' -f2)"
    local download="$(echo "$output" | cut -n -d ',' -f3)"
    local downloadStatus="$(echo "$output" | cut -n -d ',' -f4)"
    local latency="$(echo "$output" | cut -n -d ',' -f5)"
    local jitter="$(echo "$output" | cut -n -d ',' -f6)"

    result="${YELLOW}${nodeISP}|${GREEN}${name}${CYAN}↑${upload}${YELLOW}${uploadStatus}${CYAN} ↓${download}${YELLOW}${downloadStatus}${CYAN} ↕ ${GREEN}${latency}${CYAN} ϟ ${GREEN}${jitter}${ENDC}"
    if [ $uploadStatus = "正常" ] && [ $downloadStatus = "正常" ]; then
        printf "$result\n"
    else
        failed+=("$result")
    fi 
}

run_test() {
    [[ ${selection} == 2 ]] && exit 1

    echo "————————————————————————————————————————————————————————————————————"
    echo "测速服务器信息   ↑     上传/Mbps ↓     下载/Mbps ↕ 延迟/ms ϟ 抖动/ms"
    echo "————————————————————————————————————————————————————————————————————"
    start=$(date +%s)
    failed=( )

    if [[ ${selection} == 1 ]] || [[ ${selection} == 3 ]]; then
        speed_test '上海' '电信' '' 'aHR0cDovL3NwZWVkdGVzdDEub25saW5lLnNoLmNuOjgwODAvZG93bmxvYWQ=' 'aHR0cDovL3NwZWVkdGVzdDEub25saW5lLnNoLmNuOjgwODAvdXBsb2Fk'
        speed_test '天津' '电信' '' 'aHR0cDovL3N5LnRqdGVsZS5jb20ucHJvZC5ob3N0cy5vb2tsYXNlcnZlci5uZXQ6ODA4MC9kb3dubG9hZA==' 'aHR0cDovL3N5LnRqdGVsZS5jb20ucHJvZC5ob3N0cy5vb2tsYXNlcnZlci5uZXQ6ODA4MC91cGxvYWQ='
        speed_test '江苏镇江5G' '电信' '' 'aHR0cDovLzVnemhlbmppYW5nLnNwZWVkdGVzdC5qc2luZm8ubmV0OjgwODAvZG93bmxvYWQ=' 'aHR0cDovLzVnemhlbmppYW5nLnNwZWVkdGVzdC5qc2luZm8ubmV0OjgwODAvdXBsb2Fk'
        speed_test '江苏南京5G' '电信' '' 'aHR0cDovLzVnbmFuamluZy5zcGVlZHRlc3QuanNpbmZvLm5ldDo4MDgwL2Rvd25sb2FkCg==' 'aHR0cDovLzVnbmFuamluZy5zcGVlZHRlc3QuanNpbmZvLm5ldDo4MDgwL3VwbG9hZAo='
        speed_test '江苏苏州5G' '电信' '' 'aHR0cDovLzRnc3V6aG91MS5zcGVlZHRlc3QuanNpbmZvLm5ldDo4MDgwL2Rvd25sb2Fk' 'aHR0cDovLzRnc3V6aG91MS5zcGVlZHRlc3QuanNpbmZvLm5ldDo4MDgwL3VwbG9hZA=='
        speed_test '安徽合肥5G' '电信' '' 'aHR0cDovL3NwZWVkdGVzdDEuYWgxNjMuY29tOjgwODAvZG93bmxvYWQ=' 'aHR0cDovL3NwZWVkdGVzdDEuYWgxNjMuY29tOjgwODAvdXBsb2Fk'
        speed_test '湖南长沙5G' '电信' '' 'aHR0cDovL2hudGVsZWNvbTVnLmNuLnByb2QuaG9zdHMub29rbGFzZXJ2ZXIubmV0OjgwODAvZG93bmxvYWQ=' 'aHR0cDovL2hudGVsZWNvbTVnLmNuLnByb2QuaG9zdHMub29rbGFzZXJ2ZXIubmV0OjgwODAvdXBsb2Fk'
        speed_test '浙江宁波' '电信' '' 'aHR0cDovL2Nlc3UtbmIuemp0ZWxlY29tLmNvbS5jbi5wcm9kLmhvc3RzLm9va2xhc2VydmVyLm5ldDo4MDgwL2Rvd25sb2Fk' 'aHR0cDovL2Nlc3UtbmIuemp0ZWxlY29tLmNvbS5jbi5wcm9kLmhvc3RzLm9va2xhc2VydmVyLm5ldDo4MDgwL3VwbG9hZA=='
        speed_test '湖北武汉' '电信' '' 'aHR0cDovL3ZpcHNwZWVkdGVzdDgud3VoYW4ubmV0LmNuOjgwODAvZG93bmxvYWQ=' 'aHR0cDovL3ZpcHNwZWVkdGVzdDgud3VoYW4ubmV0LmNuOjgwODAvdXBsb2Fk'
        speed_test '四川成都' '电信' '' 'aHR0cDovL3NwZWVkdGVzdDEuc2MuMTg5LmNuLnByb2QuaG9zdHMub29rbGFzZXJ2ZXIubmV0OjgwODAvZG93bmxvYWQ=' 'aHR0cDovL3NwZWVkdGVzdDEuc2MuMTg5LmNuLnByb2QuaG9zdHMub29rbGFzZXJ2ZXIubmV0OjgwODAvdXBsb2Fk'
    fi

    if [[ ${selection} == 1 ]] || [[ ${selection} == 4 ]]; then
        speed_test '上海' '联通' '' 'aHR0cHM6Ly81Zy5zaHVuaWNvbXRlc3QuY29tLnByb2QuaG9zdHMub29rbGFzZXJ2ZXIubmV0OjgwODgvZG93bmxvYWQ=' 'aHR0cHM6Ly81Zy5zaHVuaWNvbXRlc3QuY29tLnByb2QuaG9zdHMub29rbGFzZXJ2ZXIubmV0OjgwODgvdXBsb2Fk'
        speed_test '江苏无锡' '联通' '' 'aHR0cHM6Ly9zcGVlZHRlc3QyLm5pdXRrLmNvbS5wcm9kLmhvc3RzLm9va2xhc2VydmVyLm5ldDo4MDgwL2Rvd25sb2Fk' 'aHR0cHM6Ly9zcGVlZHRlc3QyLm5pdXRrLmNvbS5wcm9kLmhvc3RzLm9va2xhc2VydmVyLm5ldDo4MDgwL3VwbG9hZA=='
        speed_test '北京' '联通' '' 'aHR0cHM6Ly9iZWlqaW5nLnVuaWNvbXRlc3QuY29tOjgwODAvZG93bmxvYWQ=' 'aHR0cHM6Ly9iZWlqaW5nLnVuaWNvbXRlc3QuY29tOjgwODAvdXBsb2Fk'
        speed_test '海南三亚' '联通' '' 'aHR0cDovL2hpbi1zYW55YTEubmV0Y3V0ZS5jb206ODA4MC9kb3dubG9hZA==' 'aHR0cDovL2hpbi1zYW55YTEubmV0Y3V0ZS5jb206ODA4MC91cGxvYWQ='
        speed_test '湖北武汉' '联通' '' 'aHR0cDovLzExMy41Ny4yNDkuMi5wcm9kLmhvc3RzLm9va2xhc2VydmVyLm5ldDo4MDgwL2Rvd25sb2Fk' 'aHR0cDovLzExMy41Ny4yNDkuMi5wcm9kLmhvc3RzLm9va2xhc2VydmVyLm5ldDo4MDgwL3VwbG9hZA=='
        speed_test '湖南长沙5G' '联通' '' 'aHR0cDovL3NwZWVkdGVzdDAxLmhuMTY1LmNvbTo4MDgwL2Rvd25sb2Fk' 'aHR0cDovL3NwZWVkdGVzdDAxLmhuMTY1LmNvbTo4MDgwL3VwbG9hZA=='
        speed_test '四川成都' '联通' '' 'aHR0cDovL2N1c2NzcGVlZC4xNjlvbC5jb20ucHJvZC5ob3N0cy5vb2tsYXNlcnZlci5uZXQ6ODA4MC9kb3dubG9hZA==' 'aHR0cDovL2N1c2NzcGVlZC4xNjlvbC5jb20ucHJvZC5ob3N0cy5vb2tsYXNlcnZlci5uZXQ6ODA4MC91cGxvYWQ='
        speed_test '福建福州' '联通' '' 'aHR0cDovL3VwbG9hZDEudGVzdHNwZWVkLmNkbjE2LmNvbTo4MDgwL2Rvd25sb2Fk' 'aHR0cDovL3VwbG9hZDEudGVzdHNwZWVkLmNkbjE2LmNvbTo4MDgwL3VwbG9hZA=='
    fi

    if [[ ${selection} == 1 ]] || [[ ${selection} == 5 ]]; then
        speed_test '江苏苏州' '移动' '' 'aHR0cDovL3NwZWVkdGVzdC5qc3FpdXlpbmcuY29tOjgwODAvZG93bmxvYWQ=' 'aHR0cDovL3NwZWVkdGVzdC5qc3FpdXlpbmcuY29tOjgwODAvdXBsb2Fk'
        speed_test '北京' '移动' '' 'aHR0cDovL3NwZWVkdGVzdC5ibWNjLmNvbS5jbjo4MDgwL2Rvd25sb2Fk' 'aHR0cDovL3NwZWVkdGVzdC5ibWNjLmNvbS5jbjo4MDgwL3VwbG9hZA=='
        speed_test '浙江杭州5G' '移动' '' 'aHR0cDovL3NwZWVkdGVzdC4xMzlwbGF5LmNvbTo4MDgwL2Rvd25sb2Fk' 'aHR0cDovL3NwZWVkdGVzdC4xMzlwbGF5LmNvbTo4MDgwL3VwbG9hZA=='
        speed_test '重庆有线' '铁通' '' 'aHR0cDovL3NwZWVkdGVzdDEuY3FjY24uY29tOjgwODAvZG93bmxvYWQ=' 'aHR0cDovL3NwZWVkdGVzdDEuY3FjY24uY29tOjgwODAvdXBsb2Fk'
    fi

    if [[ ${selection} == 6 ]]; then
        speed_test '中国科技大学' '合肥' '' 'aHR0cHM6Ly90ZXN0LnVzdGMuZWR1LmNuL2JhY2tlbmQvZ2FyYmFnZS5waHAK' 'aHR0cHM6Ly90ZXN0LnVzdGMuZWR1LmNuL2JhY2tlbmQvZW1wdHkucGhwCg=='
        speed_test '东北大学' '沈阳' '' 'aHR0cHM6Ly9pcHR2LnRzaW5naHVhLmVkdS5jbi9zdC9nYXJiYWdlLnBocAo=' 'aHR0cHM6Ly9pcHR2LnRzaW5naHVhLmVkdS5jbi9zdC9lbXB0eS5waHAK'
        speed_test '上海交通大学' '上海' '' 'aHR0cHM6Ly93c3VzLnNqdHUuZWR1LmNuL3NwZWVkdGVzdC9iYWNrZW5kL2dhcmJhZ2UucGhwCg==' 'aHR0cHM6Ly93c3VzLnNqdHUuZWR1LmNuL3NwZWVkdGVzdC9iYWNrZW5kL2VtcHR5LnBocAo='
    fi

    if [[ ${selection} == 7 ]]; then
        speed_test '中国科技大学' '合肥' '-6' 'aHR0cHM6Ly90ZXN0Ni51c3RjLmVkdS5jbi9iYWNrZW5kL2dhcmJhZ2UucGhwCg==' 'aHR0cHM6Ly90ZXN0Ni51c3RjLmVkdS5jbi9iYWNrZW5kL2VtcHR5LnBocAo='
        speed_test '东北大学' '沈阳' '-6' 'aHR0cHM6Ly9pcHR2LnRzaW5naHVhLmVkdS5jbi9zdC9nYXJiYWdlLnBocAo=' 'aHR0cHM6Ly9pcHR2LnRzaW5naHVhLmVkdS5jbi9zdC9lbXB0eS5waHAK'
        speed_test '上海交通大学' '上海' '-6' 'aHR0cHM6Ly93c3VzLnNqdHUuZWR1LmNuL3NwZWVkdGVzdC9iYWNrZW5kL2dhcmJhZ2UucGhwCg==' 'aHR0cHM6Ly93c3VzLnNqdHUuZWR1LmNuL3NwZWVkdGVzdC9iYWNrZW5kL2VtcHR5LnBocAo='
    fi

    if [[ ${selection} == 8 ]]; then
        speed_test '重庆有线' '铁通' '-6' 'aHR0cDovL3NwZWVkdGVzdDEuY3FjY24uY29tOjgwODAvZG93bmxvYWQ=' 'aHR0cDovL3NwZWVkdGVzdDEuY3FjY24uY29tOjgwODAvdXBsb2Fk'
        speed_test '上海5G' '联通' '-6' 'aHR0cDovLzVnLnNodW5pY29tdGVzdC5jb206ODA4MC9kb3dubG9hZAo=' 'aHR0cDovLzVnLnNodW5pY29tdGVzdC5jb206ODA4MC91cGxvYWQK'
    fi

    if [[ ${selection} == 0 ]]; then
        speed_test '环电宽频' '香港' '' 'aHR0cDovL29va2xhLWhpZGMuaGdjb25haXIuaGdjLmNvbS5oazo4MDgwL2Rvd25sb2FkCg==' 'aHR0cDovL29va2xhLWhpZGMuaGdjb25haXIuaGdjLmNvbS5oazo4MDgwL3VwbG9hZAo='
        speed_test '澳门电讯' '澳门' '' 'aHR0cDovL3NwZWVkdGVzdDUubWFjYXUuY3RtLm5ldDo4MDgwL2Rvd25sb2FkCg==' 'aHR0cDovL3NwZWVkdGVzdDUubWFjYXUuY3RtLm5ldDo4MDgwL3VwbG9hZAo='
        speed_test '中华电信' '台北' '' 'aHR0cDovL3RwMS5jaHRtLmhpbmV0Lm5ldDo4MDgwL2Rvd25sb2FkCg==' 'aHR0cDovL3RwMS5jaHRtLmhpbmV0Lm5ldDo4MDgwL3VwbG9hZAo='
        speed_test '乐天移动' '东京' '' 'aHR0cDovL29va2xhLm1ic3BlZWQubmV0OjgwODAvZG93bmxvYWQK' 'aHR0cDovL29va2xhLm1ic3BlZWQubmV0OjgwODAvdXBsb2FkCg=='
        speed_test 'Kdatacenter ' '首尔' '' 'aHR0cDovL3NwZWVkdGVzdC5rZGF0YWNlbnRlci5jb206ODA4MC9kb3dubG9hZAo=' 'aHR0cDovL3NwZWVkdGVzdC5rZGF0YWNlbnRlci5jb206ODA4MC91cGxvYWQK'
    fi

    end=$(date +%s)

    if [ ${#failed[@]} -ne 0 ]; then
        echo "--------------------------------------------------------------------"
        for value in "${failed[@]}"
        do
            printf "$value\n"
        done
    fi
    
    echo "————————————————————————————————————————————————————————————————————"

    if [[ "$thread" == "" ]]; then
        echo -ne "  单线程"
    else
        echo -ne "  八线程"
    fi

    time=$(( $end - $start ))
    if [[ $time -gt 60 ]]; then
        min=$(expr $time / 60)
        sec=$(expr $time % 60)
        echo -e "测试完成, 本次测速耗时: ${min} 分 ${sec} 秒"
    else
        echo -e "测试完成, 本次测速耗时: ${time} 秒"
    fi
    echo -ne "  当前时间: "
    echo $(TZ=Asia/Shanghai date --rfc-3339=seconds)
}

run_all() {
    check_wget;
    check_bimc;
    clear;
    print_info;
    get_options;
    run_test;
    rm -rf bimc;
}

LANG=C
run_all
