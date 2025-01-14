#!/bin/sh
# OpenWrt系统初始化脚本.sh
# https://supes.top/?version=22.03&target=x86%2F64&id=generic





function strInFile(){
# 此函数用于判断字符串是否存在于文件中
str=$1
filename=$2
#   if cat ${filename} |grep \"${str}\" > /dev/null
    if [ `grep -c "${str}" ${filename}` -ne 0 ];then
        echo 0
        return 0;
    else
        echo 1
        return 1;
    fi
}


# 定义下载函数
download_with_retry() {
    local url=$1
    local output_file=$2
    local max_retries=${3:-5}  # 默认最大重试次数为5次
    local retry_count=0
    local success=0

    while [ $retry_count -lt $max_retries ]; do
        echo "Attempting to download $url (Attempt $((retry_count + 1))/$max_retries)"
        if wget --show-progress --progress=bar:force:noscroll -c -O "$output_file" "$url"; then
            success=1
            break
        else
            retry_count=$((retry_count + 1))
            echo "Download failed, retrying in 5 seconds... ($retry_count/$max_retries)"
            sleep 5
        fi
    done

    if [ $success -eq 1 ]; then
        echo "Download completed successfully."
    else
        echo "Failed to download after $max_retries attempts."
        return 1
    fi
}


# download_with_retry http://example.com/file.zip  /root/file.zip





########################################################################################################################
echo "修改dnsmasq配置的本地服务器地址 配置文件.  #"
# 获取 br-lan 接口的 IP 地址
BR_LAN_IP=$(ip -4 addr show br-lan | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# 检查是否成功获取 IP 地址
if [ -z "$BR_LAN_IP" ]; then
    echo "未能获取 br-lan 接口的 IP 地址"
    exit 1
fi

# 使用 sed 替换文件中的 127.0.0.1
sed -i "s/127\.0\.0\.1/${BR_LAN_IP}/g" /tmp/resolv.conf





########################################################################################################################
echo "修改/dev/sda3挂载为 /data, 当前 分区挂载情况:   #######################################################################"
lsblk -o NAME,FSTYPE,UUID,MOUNTPOINT
mkdir -p /data

result=`strInFile "option target '/data'" '/etc/config/fstab'`
if [ ${result} == 1 ]
then
    echo "修改 /etc/config/fstab 文件中的挂载点/mnt/sda3 为 /data"
    sed -i "s|option target '/mnt/sda3'|option target '/data'|"  "/etc/config/fstab"

    # 启用挂载项（如果有需要）
    sed -i "s|option enabled '0'|option enabled '1'|" "/etc/config/fstab"

    echo "卸载 umount /mnt/sda3"
    umount /mnt/sda3

    echo "应用挂载点"
    block mount
else
    echo "已找到挂载点 /data : option target '/data' ,未修改 /etc/config/network"
fi

echo "修改完成, 分区挂载情况:"
lsblk -o NAME,FSTYPE,UUID,MOUNTPOINT



########################################################################################################################
echo "# 清理残联的docker文件  #############################################################################################"
rm -rf /data/buildkit
rm -rf /data/containerd
rm -rf /data/containers
rm -rf /data/engine-id
rm -rf /data/image
rm -rf /data/lost+found
rm -rf /data/network
rm -rf /data/overlay2
rm -rf /data/plugins
rm -rf /data/runtimes
rm -rf /data/swarm
rm -rf /data/tmp
rm -rf /data/volumes



########################################################################################################################
echo "创建目录 /data/temp, /data/log, /data/app/ddns, /data/docker/docker_home, /data/docker/docker_data  ###############"
mkdir -p /data/temp
mkdir -p /data/log
mkdir -p /data/app/ddns
mkdir -p /data/docker/docker_home
mkdir -p /data/docker/docker_data




########################################################################################################################
echo "下载安装 7zip 命令 7zz  到 /data/app/7zz   ##########################################################################"
download_with_retry https://cdn.jsdelivr.net/gh/smnra/pve_config/openwrt/tools/7zip/7zz  /data/app/7zz
# 使用 cdn加速  cdn.jsdelivr.net 下载 https://smnra.github.io/pve_config/openwrt/tools/7zip/7zz
chmod +x /data/app/7zz
ln -s /data/app/7zz  /usr/bin/7zz
########################################################################################################################






########################################################################################################################
echo "安装软件包 #########################################################################################################"
echo 'opkg update'
opkg update

echo '无线网卡 mt7921e 软件包安装.'
opkg install iw-full kmod-mt7921e hostapd-openssl

echo '安装zerotier软件包'
opkg install luci-app-zerotier

echo '安装局域网唤醒.'
opkg install wol etherwake luci-app-wol luci-i18n-wol-zh-cn

echo '安装docker-compose软件包'
opkg install docker-compose

echo '安装tv助手软件包'
opkg install tvhelper

echo '安装kms软件包'
opkg install vlmcsd luci-app-vlmcsd

echo '安装统一文件共享  支持webdav协议'
opkg install luci-app-unishare

# echo '安装 luci-app-my-dnshelper DNS管理与去广告'
# opkg install luci-app-my-dnshelper
#
# echo '安装 ddns 软件包'
# opkg install luci-app-ddns
#
# echo '安装 openvpn 服务器软件包'
# opkg install luci-app-openvpn-server
#

########################################################################################################################
echo '设置中文语言'
uci set luci.main.lang='zh_cn'
uci commit luci





########################################################################################################################
echo "设置 web访问 nginx访问控制列表        ################################################################################"
echo "
    allow all;
    allow 123.138.78.0/24;
    allow 100.100.0.0/16;
    allow ::1;
    allow fc00::/7;
    allow fec0::/10;
    allow fe80::/10;
    allow 127.0.0.0/8;
    allow 10.0.0.0/8;
    allow 172.16.0.0/12;
    allow 192.168.0.0/16;
    allow 169.254.0.0/16;
    deny all;
" > /etc/nginx/restrict_locally





########################################################################################################################
echo '开机启动 /etc/rc.local      #######################################################################################'
result=`strInFile 'ddns_update.sh' '/etc/rc.local'`
echo result: ${result}
if [ ${result} == 1 ]
then
    echo '开始修改 /etc/rc.local'
    echo '
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

sleep 10

#DDNS 更新
ping  127.0.0.1 -c 60 && sh /root/ddns_update.sh  >> /data/log/ddns_update.log &


exit 0
' > /etc/rc.local
else
    echo '已找到rc.local 未修改/etc/rc.local'
fi






########################################################################################################################
echo '添加到光猫的接口lan_gpon,并配置为dhcp获取ip,并设置mac地址:00:11:22:33:00:01.     ########################################'
result=`strInFile "config interface 'lan_gpon'" '/etc/config/network'`
echo result: ${result}
if [ ${result} == 1 ]
then
    echo "
config interface 'lan_gpon'
    option proto 'dhcp'
    option device 'eth1'
    option mtu '1500'
    option macaddr '00:11:22:33:00:01'
    option defaultroute '0'

" >> /etc/config/network


    echo "lan_gpon接口防火墙区域为 lan"
    result=`strInFile "list network 'lan_gpon'" '/etc/config/firewall'`
    echo result: ${result}
    if [ ${result} == 1 ]
        then
        sed -i "s/list network 'lan'/list network 'lan'\n\tlist network 'lan_gpon' /g" /etc/config/firewall
    else
        echo "lan_gpon接口的防火墙区域已设置,不修改."
    fi

else
    echo "已找到 config interface 'lan_gpon' ,未修改 /etc/config/network" >> /root/系统初始化设置.log
fi










########################################################################################################################
echo '添加静态路由    ####################################################################################################'
result=`strInFile "option interface 'lan_gpon'" '/etc/config/network'`
if [ ${result} == 1 ]
then
    echo '开始修改 /etc/config/network'
    echo "
config route
    option interface 'vpn0'
    option target '100.100.0.0/16'
    option gateway '100.100.0.1'

config route
    option interface 'lan_gpon'
    option target '192.168.1.0/24'
    option gateway '192.168.1.1'

config route
    option interface 'lan'
    option target '100.100.1.0/24'
    option gateway '192.168.10.254'

" >> /etc/config/network
else
    echo "已找到 option interface 'lan_gpon',未修改 /etc/config/network"
fi




########################################################################################################################
echo 'dhcp 静态地址   ###################################################################################################'
result=`strInFile "option name 'pve'" '/etc/config/dhcp'`
echo result: ${result}
if [ ${result} == 1 ]
then
    echo '开始添加 /etc/config/dhcp'
    echo "
config host
    option name 'OpenWrt'
    option dns '1'
    option mac 'BC:24:11:6E:78:FE'
    option ip '192.168.10.1'

config host
    option name 'pve'
    option dns '1'
    option mac '60:be:b4:00:f3:36'
    option ip '192.168.10.2'

config host
    option name 'pve-Win10'
    option ip '192.168.10.3'
    option mac 'BC:24:11:5A:DA:15'
    option dns '1'

config host
    option name 'pve-AndroidTV'
    option ip '192.168.10.4'
    option mac 'BC:24:11:9E:82:26'
    option dns '1'

config host
    option ip '192.168.10.5'
    option mac 'BC:24:11:E8:4A:E3'
    option name 'fnOS'
    option dns '1'

config host
    option mac 'e0:d5:5e:b7:30:83'
    option ip '192.168.10.10'
    option name 'Home-PC'
    option dns '1'

config host
    option name 'Mirror-PC'
    option ip '192.168.10.201'
    option mac '14:AB:C5:E7:91:F4'
    option dns '1'

config host
    option name 'OPPO-Reno6-5G'
    option ip '192.168.10.202'
    option mac 'E4:93:6A:2B:BC:05'
    option dns '1'

config host
    option name 'liumengeideiPad'
    option ip '192.168.10.203'
    option mac '2C:F0:EE:70:10:A6'
    option dns '1'

config host
    option name 'Oneplus3T'
    option ip '192.168.10.204'
    option mac 'C0:EE:FB:E9:5C:12'
    option dns '1'

config host
    option name 'MiAiSoundbox'
    option ip '192.168.10.205'
    option mac 'E0:B6:55:66:74:23'
    option dns '1'

config host
    option name 'OPPO-Reno13'
    option ip '192.168.10.206'
    option mac '06:D1:E9:5E:62:4B'
    option dns '1'

config host
    option name 'pve-iKuai'
    option ip '192.168.10.251'
    option mac 'BC:24:11:E4:6C:FB'
    option dns '1'

config host
    option name 'pve-iRouter'
    option ip '192.168.10.254'
    option mac 'BC:24:11:DE:3F:6C'
    option dns '1'

" >> /etc/config/dhcp
else
    echo "已找到 option name 'pve',未修改 /etc/config/dhcp"
fi








########################################################################################################################
echo '防火墙规则 80** 端口为 lan 网段映射  81** 为openwrt内部端口的映射   82** 为docker端口的映射  最后一位为 ip地址尾数 ############'
echo "
config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'openwrt_web'
    option src 'wan'
    option src_dport '8001'
    option dest_ip '192.168.10.1'
    option dest_port '443'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'openwrt_ssh'
    option src 'wan'
    option src_dport '9001'
    option dest_ip '192.168.10.1'
    option dest_port '22'

config redirect
    option target 'DNAT'
    option src 'wan'
    option dest_ip '192.168.10.2'
    option name 'pve_web'
    option src_dport '8002'
    option dest_port '8006'
  list proto 'tcp'

config redirect
    option target 'DNAT'
    option src 'wan'
    option dest_ip '192.168.10.2'
    option name 'pve_ssh'
    option src_dport '9002'
    option dest_port '22'
  list proto 'tcp'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'pve-Win10_web'
    option src 'wan'
    option src_dport '8003'
    option dest_ip '192.168.10.3'
    option dest_port '443'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'pve-Win10_rdp'
    option src 'wan'
    option src_dport '9003'
    option dest_ip '192.168.10.3'
    option dest_port '3389'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'pve-AndroidTV_web'
    option src 'wan'
    option src_dport '8004'
    option dest_ip '192.168.10.4'
    option dest_port '443'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'pve-AndroidTV_adb'
    option src 'wan'
    option src_dport '9004'
    option dest_ip '192.168.10.4'
    option dest_port '5555'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'fnOS_web'
    option src 'wan'
    option src_dport '8005'
    option dest_ip '192.168.10.5'
    option dest_port '5667'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'fnOS_ssh'
    option src 'wan'
    option src_dport '9005'
    option dest_ip '192.168.10.5'
    option dest_port '22'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'iRouter_web'
    option src 'wan'
    option src_dport '8254'
    option dest_ip '192.168.10.254'
    option dest_port '443'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'iRouter_ssh'
    option src 'wan'
    option src_dport '9204'
    option dest_ip '192.168.10.254'
    option dest_port '22'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'openvpn'
    option src 'wan'
    option src_dport '1122'
    option dest_ip '192.168.10.1'
    option dest_port '1122'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'webdav'
    option src 'wan'
    option src_dport '8101'
    option dest_ip '192.168.10.1'
    option dest_port '25544'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'http_proxy'
    option src 'wan'
    option src_dport '8102'
    option dest_ip '192.168.10.1'
    option dest_port '7890'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'twonav'
    option src 'wan'
    option src_dport '8202'
    option dest_ip '192.168.10.1'
    option dest_port '8202'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'docker_flask_2222'
    option src 'wan'
    option src_dport '8203'
    option dest_ip '192.168.10.1'
    option dest_port '8203'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'docker_flask_8780'
    option src 'wan'
    option src_dport '8213'
    option dest_ip '192.168.10.1'
    option dest_port '8213'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'docker_flask_5000'
    option src 'wan'
    option src_dport '8223'
    option dest_ip '192.168.10.1'
    option dest_port '8223'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'mi-gpt'
    option src 'wan'
    option src_dport '8204'
    option dest_ip '192.168.10.1'
    option dest_port '8204'

" >> /etc/config/firewall










########################################################################################################################
echo "设置 wifi  /etc/config/wireless   ################################################################################"
echo "
config wifi-device 'radio0'
    option type 'mac80211'
    option path 'pci0000:00/0000:00:10.0'
    option htmode 'VHT40'
    option country 'US'
    option mu_beamformer '1'
    option cell_density '3'
    option noscan '1'
    option vendor_vht '1'
    option band '5g'
    option channel '40'
    option txpower '27'

config wifi-iface 'wifinet0'
    option device 'radio0'
    option mode 'ap'
    option ssid 'OpenWrt'
    option encryption 'psk2'
    option key 'smnra000'
    option network 'lan'
" > /etc/config/wireless

sleep 10

# 启动 wifi
wifi up
wifi reload






########################################################################################################################
echo '配置 应用过滤 ######################################################################################################'
result=`strInFile "option enable '1'" '/etc/config/appfilter'`
if [ ${result} == 1 ]
then
    echo '开始修改 /etc/config/appfilter'
    echo "
config global 'global'
    option enable '1'
    option work_mode '0'

config appfilter 'appfilter'
    option gameapps '2001 2002 2003 2015 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2016 2017 2023 2025 2026 2033 2034 2041 2042 2040 2067 2068 2069 2070 2071 2072 2073 2074 2075 2050 2051 2080'
    option videoapps '3001 3002 3003 3004 3005 3006 3008 3009 3010 3011 3012 3013 3014 3016 3017 3018 3019 3020 3021 3022 3023 3024 3025 3026 3027 3028 3029 3030'
    option shoppingapps '4001 4002 4003 4004 4010 4011 4012 4021 4005 4006 4007 4008 4009 4013 4014 4015 4016 4017 4018 4019 4020 4023 4024 4025 4026'
    option chatapps '1003 1004 1005 1006 1007 1008 1009 1010'
    option musicapps '5001 5002 5003 5004 5005 5006 5007 5008 5009 5010 5011 5012'
    option employeeapps '6001 6002 6003 6004 6005 6006 6007 6008 6009 6010 6011 6012 6013 6014'
    option downloadapps '7001 7002 7003 7004 7005 7006 7007 7008 7009 7010 7011 7020 7030 7031 7032 7035'
    option websiteapps '8001 8002 8003 8004 8005 8006 8007 8008 8009 8010 8011 8012 8013 8014 8015 8016 8017 8018 8019 8020 8021 8022 8023 8024 8025 8026 8027 8028 8029 8030 8031 8032 8033 8034 8035 8036 8037 8038 8039 8040 8041 8042 8043 8044 8046 8047 8048 8049 8050 8051 8052 8053 8054 8055 8056 8057 8058 8059 8060 8061 8062 8063 8064 8065 8066 8067 8068 8069 8070 8071 8072 8073 8074 8075 8076'

config feature 'feature'
    option update '0'
    option format 'v2.0'

config time 'time'
    option time_mode '0'
    option days '0 1 2 3 4 5 6'
    option start_time '00:00'
    option end_time '23:59'

config user 'user'
    option users 'e0:d5:5e:b7:30:83 bc:24:11:e8:4a:e3 60:be:b4:00:f3:36 e0:d5:5e:b7:30:83 E4:93:6A:2B:BC:05 2C:F0:EE:70:10:A6 E0:B6:55:66:74:23 06:D1:E9:5E:62:4B'

" >> /etc/config/appfilter
else
    echo "已找到 option enable '1',未修改 /etc/config/appfilter"
fi

echo "启动 appfilter"
/etc/init.d/appfilter start

########################################################################################################################









########################################################################################################################
echo "设置zerotier /etc/config/zerotier   secret 选项可能是控制 mac 地址的，需要固定  ########################################"

echo "
config zerotier 'sample_config'
    option enabled '1'
    option nat '1'
    list join 'abfd31bd470a4583'
    option secret 'a4ca7924e3:0:5c7fe1a2582db378d2fd18356f0f48c416747cc2b49462b4e2cd1d5b1cac5b11c4cc33d169377fddfb8473fab3193bfe41942550dbc6c75c2c59af284ec1b110:dd546f95119c1f97e388d0731624f33ba852e909635c73c2a92befb74d31bb797a688c0227de3124332978e307b4e17d87ee23a73617c34eae1f18344f2f055e'

" > /etc/config/zerotier
# 启动 zerotier
/etc/init.d/zerotier start






########################################################################################################################
echo 'DNS助手配置  /etc/config/my-dnshelper   ############################################################################'
echo "
config my-dnshelper
    option enable '0'
    option autoupdate '1'
    option flash '1'
    option use_doh '0'
    option block_ios '1'
    option block_games '0'
    option block_short '0'
    option block_google '0'
    option dns_detect '1'
    option app_test '1'
    option dns_cache '600'
    option dns_check '1'
    option filter_aaaa '0'
    option use_mul '0'
    option use_sec '0'
    option dnsmasq_log '0'
    option dnslog_path '/var/log/dnsmasq.log'
    option dns_log '0'
    option rev_log '0'
    option my_github '1'
    option time_update '24'
    option app_check '1'
    list url 'https://fastly.jsdelivr.net/gh/privacy-protection-tools/anti-AD@master/adblock-for-dnsmasq.conf'
#    list url 'https://fastly.jsdelivr.net/gh/AdguardTeam/AdGuardSDNSFilter@gh-pages/Filters/filter.txt'
#    list url 'https://fastly.jsdelivr.net/gh/Cats-Team/AdRules/hosts.txt'
#    list url 'https://fastly.jsdelivr.net/gh/VeleSila/yhosts/hosts.txt'
#    list url 'https://fastly.jsdelivr.net/gh/kongfl888/ad-rules/malhosts.txt'
" > /etc/config/my-dnshelper

# /etc/init.d/my-dnshelper enable
# /etc/init.d/my-dnshelper start





########################################################################################################################
echo "设置unishare  文件共享  /etc/config/unishare #######################################################################"

echo "
config global
    option enabled '1'
    option anonymous '0'
    option webdav_port '25544'

config share
    option path '/data'
    option name 'data'
    list rw 'users'
    list ro 'users'
    list proto 'samba'
    list proto 'webdav'

config user
    option username 'smnra'
    option password 'smnra000'

" > /etc/config/unishare

echo "启动 unishare"
/etc/init.d/unishare enable
/etc/init.d/unishare restart






########################################################################################################################
echo '设置DDNS 更新 #####################################################################################################'
# 删除源有配置
uci del ddns.myddns_ipv4
uci del ddns.myddns_ipv6

# 新增 花生壳  ipv4 ddns
uci set ddns.my_ipv4_ddns=service
uci set ddns.my_ipv4_ddns.service_name='oray.com'
uci set ddns.my_ipv4_ddns.use_ipv6='0'
uci set ddns.my_ipv4_ddns.enabled='1'
uci set ddns.my_ipv4_ddns.lookup_host='smnra.oicp.net'
uci set ddns.my_ipv4_ddns.domain='smnra.oicp.net'
uci set ddns.my_ipv4_ddns.username='smnra'
uci set ddns.my_ipv4_ddns.password='F_st84080081'
uci set ddns.my_ipv4_ddns.ip_source='network'
uci set ddns.my_ipv4_ddns.ip_network='wan'
uci set ddns.my_ipv4_ddns.interface='wan'
uci set ddns.my_ipv4_ddns.force_ipversion='1'
uci set ddns.my_ipv4_ddns.use_syslog='2'
uci set ddns.my_ipv4_ddns.check_interval='10'
uci set ddns.my_ipv4_ddns.check_unit='minutes'
uci set ddns.my_ipv4_ddns.force_interval='60'
uci set ddns.my_ipv4_ddns.force_unit='minutes'
uci set ddns.my_ipv4_ddns.retry_max_count='0'
uci set ddns.my_ipv4_ddns.retry_interval='2'
uci set ddns.my_ipv4_ddns.retry_unit='minutes'


# 新增 dynv6.com  ipv6 ddns
uci set ddns.my_ipv6_ddns=service
uci set ddns.my_ipv6_ddns.service_name='dynv6.com'
uci set ddns.my_ipv6_ddns.use_ipv6='1'
uci set ddns.my_ipv6_ddns.enabled='1'
uci set ddns.my_ipv6_ddns.lookup_host='smnra.dynv6.net'
uci set ddns.my_ipv6_ddns.domain='smnra.dynv6.net'
uci set ddns.my_ipv6_ddns.username='smnra123@gmail.com'
uci set ddns.my_ipv6_ddns.password='rmdTzb6Z54N1N5NrBKxwoyhonAwBoj'
uci set ddns.my_ipv6_ddns.ip_source='network'
uci set ddns.my_ipv6_ddns.ip_network='wan_6'
uci set ddns.my_ipv6_ddns.interface='wan_6'
uci set ddns.my_ipv6_ddns.force_ipversion='1'
uci set ddns.my_ipv6_ddns.use_syslog='2'
uci set ddns.my_ipv6_ddns.check_interval='10'
uci set ddns.my_ipv6_ddns.check_unit='minutes'
uci set ddns.my_ipv6_ddns.force_interval='60'
uci set ddns.my_ipv6_ddns.force_unit='minutes'
uci set ddns.my_ipv6_ddns.retry_max_count='0'
uci set ddns.my_ipv6_ddns.retry_interval='2'
uci set ddns.my_ipv6_ddns.retry_unit='minutes'



# 直接写配置文件的方式 设置ddns
echo "
config ddns 'global'
    option ddns_dateformat '%F %R'
    option ddns_loglines '250'
    option ddns_rundir '/var/run/ddns'
    option ddns_logdir '/var/log/ddns'

config service 'my_ipv4_ddns'
    option service_name 'oray.com'
    option use_ipv6 '0'
    option enabled '1'
    option lookup_host 'smnra.oicp.net'
    option domain 'smnra.oicp.net'
    option username 'smnra'
    option password 'F_st84080081'
    option ip_source 'network'
    option ip_network 'wan'
    option interface 'wan'
    option force_ipversion '1'
    option use_syslog '2'
    option check_interval '10'
    option check_unit 'minutes'
    option force_interval '60'
    option force_unit 'minutes'
    option retry_max_count '0'
    option retry_interval '2'
    option retry_unit 'minutes'

config service 'my_ipv6_ddns'
    option service_name 'dynv6.com'
    option use_ipv6 '1'
    option enabled '1'
    option lookup_host 'smnra.dynv6.net'
    option domain 'smnra.dynv6.net'
    option username 'smnra123@gmail.com'
    option password 'rmdTzb6Z54N1N5NrBKxwoyhonAwBoj'
    option ip_source 'network'
    option ip_network 'wan_6'
    option interface 'wan_6'
    option force_ipversion '1'
    option use_syslog '2'
    option check_interval '10'
    option check_unit 'minutes'
    option force_interval '60'
    option force_unit 'minutes'
    option retry_max_count '0'
    option retry_interval '2'
    option retry_unit 'minutes'


" > /etc/config/ddns


# 启动 ddns 服务
/etc/init.d/ddns restart






################################################################
echo '生成自有 DDNS 更新脚本'
echo '
#!/bin/sh
oray_ddns=smnra.oicp.net
dynv6_ddns_ipv4=smnra.dynv6.net
dynv6_ddns_ipv6=smnra.dynv6.net
# dynv6_ddns_ipv4=smnrao.dynv6.net

oray_ddns_password=F_st84080081
dynv6_ddns_password_ipv4=rmdTzb6Z54N1N5NrBKxwoyhonAwBoj
dynv6_ddns_password_ipv6=rmdTzb6Z54N1N5NrBKxwoyhonAwBoj
IPV6_ADDRESSprefix="240e:35c:7b7:d200::"

# 提取 IPv4 地址
IPV4_ADDRESS=$(ifconfig pppoe-wan | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1)

# 提取 IPv6 地址
IPV6_ADDRESS=$(ifconfig pppoe-wan | grep "inet6 addr" | grep "Global" | sed "s/^.*inet6 addr: //" | cut -d/ -f1)

echo ${IPV4_ADDRESS}
echo ${IPV6_ADDRESS}
echo -e "\n"


# 更新 smnra.oicp.net ipv4
echo "wget -nv -qO- -t 3 -4 http://smnra:${oray_ddns_password}@ddns.oray.com/ph/update?hostname=${oray_ddns}&myip=${IPV4_ADDRESS}"
echo -e `date "+%Y-%m-%d %H:%M:%S"` 更新 smnra.oicp.net ipv4:
wget -nv -qO- -t 3 -4 "http://smnra:${oray_ddns_password}@ddns.oray.com/ph/update?hostname=${oray_ddns}&myip=${IPV4_ADDRESS}"
echo -e "\n"

# 更新 smnra.dynv6.net ipv4
echo "wget -nv -qO- -t 3 -4 http://dynv6.com/api/update?hostname=${dynv6_ddns_ipv4}&token=${dynv6_ddns_password_ipv4}&ipv4=${IPV4_ADDRESS}"
echo -e `date "+%Y-%m-%d %H:%M:%S"` 更新 smnra.dynv6.net ipv4:
wget -nv -qO-  -t 3 -4 "http://dynv6.com/api/update?hostname=${dynv6_ddns_ipv4}&token=${dynv6_ddns_password_ipv4}&ipv4=${IPV4_ADDRESS}"
echo -e "\n"

# 更新 smnra.dynv6.net  ipv6
echo "wget -nv -qO- -t 3 -6 http://dynv6.com/api/update?hostname=${dynv6_ddns_ipv6}&token=${dynv6_ddns_password_ipv6}&ipv6=${IPV6_ADDRESS}&ipv6prefix=${IPV6_ADDRESSprefix}"
echo -e `date "+%Y-%m-%d %H:%M:%S"` 更新 smnra.dynv6.net  ipv6:
wget -nv -qO- -t 3 -6 "http://dynv6.com/api/update?hostname=${dynv6_ddns_ipv6}&token=${dynv6_ddns_password_ipv6}&ipv6=${IPV6_ADDRESS}&ipv6prefix=${IPV6_ADDRESSprefix}"
echo -e "\n"


' > /data/app/ddns/ddns_update.sh

# 将脚本内容写入文件并设置权限
chmod +x /data/app/ddns/ddns_update.sh

echo "启动 ddns 脚本内容"
sleep 10
/bin/bash /data/app/ddns/ddns_update.sh





########################################################################################################################
# 计划任务 crontab 添加ddns 每小时更新; 每天凌晨4点重启系统; 每小时释放内存;
echo "crontab   添加计划任务  ############################################################################################"
echo 'Crontab  添加ddns 每小时更新ddns '
result=`strInFile "ddns_update.sh" '/etc/crontabs/root'`
if [ ${result} == 1 ]
then
    echo "
0  0 * * * /bin/sh /data/app/ddns/ddns_update.sh  >> /data/log/ddns_update.log &" >> /etc/crontabs/root
fi

echo 'Crontab 添加 每小时释放内存;'
result=`strInFile "ram_release" '/etc/crontabs/root'`
if [ ${result} == 1 ]
then
    echo "
00 03 * * * /usr/bin/ram_release.sh release" >> /etc/crontabs/root
fi

echo 'Crontab 添加 每天凌晨4点重启系统;'
result=`strInFile "reboot" '/etc/crontabs/root'`
if [ ${result} == 1 ]
then
    echo "
00 4 * * * sleep 10 && touch /etc/banner && reboot" >> /etc/crontabs/root
fi

















########################################################################################################################
echo "openvpn 配置    ###################################################################################################"
echo "创建openvpn证书文件目录 /etc/openvpn/pki"
mkdir -p /etc/openvpn/pki


echo "生成 openvpn 帐号检查脚本 /etc/openvpn/server/checkpsw.sh"
# 定义 checkpsw.sh 脚本内容
checkpsw_content=$(cat << 'EOF'
#!/bin/sh
###########################################################
# checkpsw.sh (C) 2004 Mathias Sundman
#
# This script will authenticate OpenVPN users against
# a plain text file. The passfile should simply contain
# one row per user with the username first followed by
# one or more space(s) or tab(s) and then the password.

PASSFILE="/etc/openvpn/server/psw-file"
LOG_FILE="/etc/openvpn/openvpn-password.log"
TIME_STAMP=`date "+%Y-%m-%d %T"`

###########################################################

if [ ! -r "${PASSFILE}" ]; then
  echo "${TIME_STAMP}: Could not open password file \"${PASSFILE}\" for reading." >> ${LOG_FILE}
  exit 1
fi

CORRECT_PASSWORD=`awk '!/^;/&&!/^#/&&$1=="'${username}'"{print $2;exit}' ${PASSFILE}`

if [ "${CORRECT_PASSWORD}" = "" ]; then
  echo "${TIME_STAMP}: User does not exist: username=\"${username}\", password=\"${password}\"." >> ${LOG_FILE}
  exit 1
fi

if [ "${password}" = "${CORRECT_PASSWORD}" ]; then
  echo "${TIME_STAMP}: Successful authentication: username=\"${username}\"." >> ${LOG_FILE}
  exit 0
fi

echo "${TIME_STAMP}: Incorrect password: username=\"${username}\", password=\"${password}\"." >> ${LOG_FILE}
exit 1

EOF
)




echo "生成 openvpn 证书自动生成脚本 /etc/openvpn/server/openvpncert.sh"
# 定义 openvpncert.sh 脚本内容
openvpncert_content=$(cat << 'EOF'
#!/bin/sh

function rand_str() {
  (base64 /dev/urandom | tr -dc 'A-Za-z' | head -c $1) 2>/dev/null
}

function rand_str_upper() {
  (rand_str $1 | tr 'a-z' 'A-Z') 2>/dev/null
}

function rand_str_lower() {
  (rand_str $1 | tr 'A-Z' 'a-z') 2>/dev/null
}

function rand_easy_rsa_vars() {
  local KEY_PROVINCE="$(rand_str_upper 6)"
  local KEY_CITY="$(rand_str 8)"
  local KEY_ORG="$(rand_str 8)"
  local KEY_EMAIL="$(rand_str_lower 8)@$(rand_str_lower 4).$(rand_str_lower 3)"
  local KEY_OU="$(rand_str 8)"
  sed -i \
    -e "s/^[[:space:]]*set_var[[:space:]]\+EASYRSA_REQ_COUNTRY[[:space:]]\+\".*\"$/set_var EASYRSA_REQ_COUNTRY\t\"$KEY_PROVINCE\"/" \
    -e "s/^[[:space:]]*set_var[[:space:]]\+EASYRSA_REQ_PROVINCE[[:space:]]\+\".*\"$/set_var EASYRSA_REQ_PROVINCE\t\"$KEY_CITY\"/" \
    -e "s/^[[:space:]]*set_var[[:space:]]\+EASYRSA_REQ_CITY[[:space:]]\+\".*\"$/set_var EASYRSA_REQ_CITY\t\"$KEY_ORG\"/" \
    -e "s/^[[:space:]]*set_var[[:space:]]\+EASYRSA_REQ_ORG[[:space:]]\+\".*\"$/set_var EASYRSA_REQ_ORG\t\"$KEY_ORG\"/" \
    -e "s/^[[:space:]]*set_var[[:space:]]\+EASYRSA_REQ_EMAIL[[:space:]]\+\".*\"$/set_var EASYRSA_REQ_EMAIL\t\"$KEY_EMAIL\"/" \
    -e "s/^[[:space:]]*set_var[[:space:]]\+EASYRSA_REQ_OU[[:space:]]\+\".*\"$/set_var EASYRSA_REQ_OU\t\"$KEY_OU\"/" \
    /etc/easy-rsa/vars
}

rand_easy_rsa_vars
rm -rf /root/pki

export EASYRSA_PKI="/etc/easy-rsa/pki"
export EASYRSA_VARS_FILE="/etc/easy-rsa/vars"
export EASYRSA_CLI="easyrsa --batch"

echo -en "yes\nyes\n" | $EASYRSA_CLI init-pki
# Generate DH
$EASYRSA_CLI gen-dh

# Generate for the CA
$EASYRSA_CLI build-ca nopass

# Generate for the server
$EASYRSA_CLI build-server-full server nopass

# Generate for the client
$EASYRSA_CLI build-client-full client1 nopass

# Copy files
mkdir -p /etc/openvpn/pki
cp /etc/easy-rsa/pki/ca.crt /etc/openvpn/pki/
cp /etc/easy-rsa/pki/dh.pem /etc/openvpn/pki/
cp /etc/easy-rsa/pki/issued/server.crt /etc/openvpn/pki/
cp /etc/easy-rsa/pki/private/server.key /etc/openvpn/pki/
cp /etc/easy-rsa/pki/issued/client1.crt /etc/openvpn/pki/
cp /etc/easy-rsa/pki/private/client1.key /etc/openvpn/pki/
echo "OpenVPN Cert renew successfully"

EOF
)



echo "生成 openvpn 服务启动脚本 /etc/init.d/openvpn"
# 定义openvpn 脚本内容
openvpn_content=$(cat << 'EOF'
#!/bin/sh /etc/rc.common
# Copyright (C) 2008-2013 OpenWrt.org
# Copyright (C) 2008 Jo-Philipp Wich
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.

START=90
STOP=10

USE_PROCD=1
PROG=/usr/sbin/openvpn

PATH_INSTANCE_DIR="/etc/openvpn"
LIST_SEP="
"

UCI_STARTED=
UCI_DISABLED=

append_param() {
  local s="$1"
  local v="$2"
  case "$v" in
    *_*_*_*) v=${v%%_*}-${v#*_}; v=${v%%_*}-${v#*_}; v=${v%%_*}-${v#*_} ;;
    *_*_*)   v=${v%%_*}-${v#*_}; v=${v%%_*}-${v#*_} ;;
    *_*)     v=${v%%_*}-${v#*_} ;;
  esac
  echo -n "$v" >> "/var/etc/openvpn-$s.conf"
  return 0
}

append_bools() {
  local p; local v; local s="$1"; shift
  for p in $*; do
    config_get_bool v "$s" "$p"
    [ "$v" = 1 ] && append_param "$s" "$p" && echo >> "/var/etc/openvpn-$s.conf"
  done
}

append_params() {
  local p; local v; local s="$1"; shift
  for p in $*; do
    config_get v "$s" "$p"
    IFS="$LIST_SEP"
    for v in $v; do
      [ "$v" = "frames_only" ] && [ "$p" = "compress" ] && unset v && append_param "$s" "$p" && echo >> "/var/etc/openvpn-$s.conf"
      [ -n "$v" ] && [ "$p" != "push" ] && append_param "$s" "$p" && echo " $v" >> "/var/etc/openvpn-$s.conf"
      [ -n "$v" ] && [ "$p" = "push" ] && append_param "$s" "$p" && echo " \"$v\"" >> "/var/etc/openvpn-$s.conf"
    done
    unset IFS
  done
}

append_list() {
  local p; local v; local s="$1"; shift

  list_cb_append() {
    v="${v}:$1"
  }

  for p in $*; do
    unset v
    config_list_foreach "$s" "$p" list_cb_append
    [ -n "$v" ] && append_param "$s" "$p" && echo " ${v:1}" >> "/var/etc/openvpn-$s.conf"
  done
}

section_enabled() {
  config_get_bool enable  "$1" 'enable'  0
  config_get_bool enabled "$1" 'enabled' 0
  [ $enable -gt 0 ] || [ $enabled -gt 0 ]
}

create_temp_file() {
  mkdir -p "$(dirname "$1")"
  rm -f "$1"
  touch "$1"
  chown root "$1"
  chmod 0600 "$1"
}

openvpn_get_dev() {
  local dev dev_type
  local name="$1"
  local conf="$2"

  # Do override only for configurations with config_file
  config_get config_file "$name" config
  [ -n "$config_file" ] || return

  # Check there is someething to override
  config_get dev "$name" dev
  config_get dev_type "$name" dev_type
  [ -n "$dev" ] || return

  # If there is a no dev_type, try to guess it
  if [ -z "$dev_type" ]; then
    . /lib/functions/openvpn.sh

    local odev odev_type
    get_openvpn_option "$conf" odev dev
    get_openvpn_option "$conf" odev_type dev-type
    [ -n "$odev_type" ] || odev_type="$odev"

    case "$odev_type" in
      tun*) dev_type="tun" ;;
      tap*) dev_type="tap" ;;
      *) return;;
    esac
  fi

  # Return overrides
  echo "--dev-type $dev_type --dev $dev"
}

openvpn_get_credentials() {
  local name="$1"
  local ret=""

  config_get cert_password "$name" cert_password
  config_get password "$name" password
  config_get username "$name" username

  if [ -n "$cert_password" ]; then
    create_temp_file /var/run/openvpn.$name.pass
    echo "$cert_password" > /var/run/openvpn.$name.pass
    ret=" --askpass /var/run/openvpn.$name.pass "
  fi

  if [ -n "$username" ]; then
    create_temp_file /var/run/openvpn.$name.userpass
    echo "$username" > /var/run/openvpn.$name.userpass
    echo "$password" >> /var/run/openvpn.$name.userpass
    ret=" --auth-user-pass /var/run/openvpn.$name.userpass "
  fi

  # Return overrides
  echo "$ret"
}

openvpn_add_instance() {
  local name="$1"
  local dir="$2"
  local conf=$(basename "$3")
  local security="$4"
  local up="$5"
  local down="$6"
  local route_up="$7"
  local route_pre_down="$8"
  local ipchange="$9"
  local client=$(grep -qEx "client|tls-client" "$dir/$conf" && echo 1)

  procd_open_instance "$name"
  procd_set_param command "$PROG"  \
    --syslog "openvpn($name)" \
    --status "/var/run/openvpn.$name.status" \
    --cd "$dir" \
    --config "$conf"
  # external scripts can only be called on script-security 2 or higher
  if [ "${security:-2}" -lt 2 ]; then
    logger -t "openvpn(${name})" "not adding hotplug scripts due to script-security ${security:-2}"
  else
    procd_append_param command \
      --up "/usr/libexec/openvpn-hotplug up $name" \
      --down "/usr/libexec/openvpn-hotplug down $name" \
      --route-up "/usr/libexec/openvpn-hotplug route-up $name" \
      --route-pre-down "/usr/libexec/openvpn-hotplug route-pre-down $name" \
      ${client:+--ipchange "/usr/libexec/openvpn-hotplug ipchange $name"} \
      ${up:+--setenv user_up "$up"} \
      ${down:+--setenv user_down "$down"} \
      ${route_up:+--setenv user_route_up "$route_up"} \
      ${route_pre_down:+--setenv user_route_pre_down "$route_pre_down"} \
      ${client:+${ipchange:+--setenv user_ipchange "$ipchange"}}
  fi
  procd_append_param command \
    --script-security "${security:-2}" \
    $(openvpn_get_dev "$name" "$conf") \
    $(openvpn_get_credentials "$name" "$conf")
  procd_set_param file "$dir/$conf"
  procd_set_param term_timeout 15
  procd_set_param respawn
  procd_append_param respawn 3600
  procd_append_param respawn 5
  procd_append_param respawn -1
  procd_close_instance
}

start_uci_instance() {
  local s="$1"

  config_get config "$s" config
  config="${config:+$(readlink -f "$config")}"

  section_enabled "$s" || {
    append UCI_DISABLED "$config" "$LIST_SEP"
    return 1
  }

  local up down route_up route_pre_down ipchange script_security
  config_get up "$s" up
  config_get down "$s" down
  config_get route_up "$s" route_up
  config_get route_pre_down "$s" route_pre_down
  config_get ipchange "$s" ipchange
  config_get script_security "$s" script_security

  [ ! -d "/var/run" ] && mkdir -p "/var/run"

  if [ ! -z "$config" ]; then
    append UCI_STARTED "$config" "$LIST_SEP"
    [ -n "$script_security" ] || get_openvpn_option "$config" script_security script-security
    [ -n "$up" ] || get_openvpn_option "$config" up up
    [ -n "$down" ] || get_openvpn_option "$config" down down
    [ -n "$route_up" ] || get_openvpn_option "$config" route_up route-up
    [ -n "$route_pre_down" ] || get_openvpn_option "$config" route_pre_down route-pre-down
    [ -n "$ipchange" ] || get_openvpn_option "$config" ipchange ipchange
    openvpn_add_instance "$s" "${config%/*}" "$config" "$script_security" "$up" "$down" "$route_up" "$route_pre_down" "$ipchange"
    return
  fi

  create_temp_file "/var/etc/openvpn-$s.conf"

  append_bools "$s" $OPENVPN_BOOLS
  append_params "$s" $OPENVPN_PARAMS
  append_list "$s" $OPENVPN_LIST

  openvpn_add_instance "$s" "/var/etc" "openvpn-$s.conf" "$script_security" "$up" "$down" "$route_up" "$route_pre_down" "$ipchange"
}

start_path_instances() {
  local path name

  for path in ${PATH_INSTANCE_DIR}/*.conf; do
    [ -f "$path" ] && {
      name="${path##*/}"
      name="${name%.conf}"
      start_path_instance "$name"
    }
  done
}

start_path_instance() {
  local name="$1"

  local path name up down route_up route_pre_down ipchange

  path="${PATH_INSTANCE_DIR}/${name}.conf"

  # don't start configs again that are already started by uci
  if echo "$UCI_STARTED" | grep -qxF "$path"; then
    logger -t openvpn "$name.conf already started"
    return
  fi

  # don't start configs which are set to disabled in uci
  if echo "$UCI_DISABLED" | grep -qxF "$path"; then
    logger -t openvpn "$name.conf is disabled in /etc/config/openvpn"
    return
  fi

  get_openvpn_option "$path" up up || up=""
  get_openvpn_option "$path" down down || down=""
  get_openvpn_option "$path" route_up route-up || route_up=""
  get_openvpn_option "$path" route_pre_down route-pre-down || route_pre_down=""
  get_openvpn_option "$path" ipchange ipchange || ipchange=""

  openvpn_add_instance "$name" "${path%/*}" "$path" "" "$up" "$down" "$route_up" "$route_pre_down" "$ipchange"
}

start_service() {
  local instance="$1"
  local instance_found=0

  config_cb() {
    local type="$1"
    local name="$2"
    if [ "$type" = "openvpn" ]; then
      if [ -n "$instance" -a "$instance" = "$name" ]; then
        instance_found=1
      fi
    fi
  }

  . /lib/functions/openvpn.sh
  . /usr/share/openvpn/openvpn.options
  config_load 'openvpn'

  if [ -n "$instance" ]; then
    if [ "$instance_found" -gt 0 ]; then
      start_uci_instance "$instance"
    elif [ -f "${PATH_INSTANCE_DIR}/${instance}.conf" ]; then
      start_path_instance "$instance"
    fi
  else
    config_foreach start_uci_instance 'openvpn'

    auto="$(uci_get openvpn globals autostart 1)"
    if [ "$auto" = "1" ]; then
      start_path_instances
    else
      logger -t openvpn "Autostart for configs in '$PATH_INSTANCE_DIR/*.conf' disabled"
    fi
  fi
}

service_triggers() {
  procd_add_reload_trigger openvpn
}

EOF
)



# 将脚本内容写入文件并设置权限
echo "$checkpsw_content" > /etc/openvpn/server/checkpsw.sh
chmod +x /etc/openvpn/server/checkpsw.sh

# 将脚本内容写入文件并设置权限
echo "$openvpncert_content" > /etc/openvpn/server/openvpncert.sh
chmod +x /etc/openvpn/server/openvpncert.sh

# 将脚本内容写入文件并设置权限
echo "$openvpn_content" > /etc/init.d/openvpn
chmod +x /etc/init.d/openvpn




echo "创建openvpn证书文件."
echo "-----BEGIN CERTIFICATE-----
MIICRjCCAa+gAwIBAgIUaPGGqlLX/6mVpksL+rOxixXA0VAwDQYJKoZIhvcNAQEL
BQAwFjEUMBIGA1UEAwwLRWFzeS1SU0EgQ0EwHhcNMjUwMTA5MTE1NDIzWhcNMzUw
MTA3MTE1NDIzWjAWMRQwEgYDVQQDDAtFYXN5LVJTQSBDQTCBnzANBgkqhkiG9w0B
AQEFAAOBjQAwgYkCgYEAov7mq4YBg8nVwrJiv3BT3o9sbCi7YISdourmGjEIYwYr
QQ/UXXGR5L84F4D6P/O+X9zCIBbPvXMCm48JSsqe9qDHlt4d9tk1JWvTD3OsITeD
a6HTwndv/EUTCvj2ofVjvmOkZMAxJh3D2sUmQJmt5ti8dOipFCSu3y7hCBvMuLUC
AwEAAaOBkDCBjTAMBgNVHRMEBTADAQH/MB0GA1UdDgQWBBSVujqVZb0AKXaFmYsd
7UBFSvZAHjBRBgNVHSMESjBIgBSVujqVZb0AKXaFmYsd7UBFSvZAHqEapBgwFjEU
MBIGA1UEAwwLRWFzeS1SU0EgQ0GCFGjxhqpS1/+plaZLC/qzsYsVwNFQMAsGA1Ud
DwQEAwIBBjANBgkqhkiG9w0BAQsFAAOBgQATAWTVOBvpUSIitiWmohTdU1TFAvgv
0iQl4H8GYQjP9ZJTEAuQOmUaf2miRl0Z3j0Q/itG3emCE4BzPwAptBI4X17sQNPT
4riGb16d2hXKFaYPgmt1UxK/TGG+LVmS+gVD+j2RRgVGNLTgksPxmbcY7vbs0hpC
nEg4HOUw7ZHw1Q==
-----END CERTIFICATE-----
" > /etc/openvpn/pki/ca.crt



echo "-----BEGIN DH PARAMETERS-----
MIGHAoGBANsQaSr+DLYeGLw8+Ck6zTYiYr4UERrQs/84kZ5oBgHEy/WEcd9gHOG4
y8XRGfOcIIsSQvRvCSOip2f9dVa7PmK/oeDt0iDrNUp7VWXt4Iz/cdmlNln9sh/5
kyalsYpsbQOaMyaSlCxCh8be6qCUSDrguBQsqMbnZ4Zr2OlpTEHfAgEC
-----END DH PARAMETERS-----
" > /etc/openvpn/pki/dh.pem



echo "-----BEGIN PRIVATE KEY-----
MIICdQIBADANBgkqhkiG9w0BAQEFAASCAl8wggJbAgEAAoGBAMIbrvqQqJ57+AR9
JFFff0UHMtcGmpiSmZBspIbyN+HZniZdkEtsbT+8phIahTZyTmoP6iNnsbVw5V0L
4H6lcIKjm2hyQt14VVhak91paMFn4Yv1WfkeGpvwVahCS8xtdQ472UXtbhB0xj90
OvcpiiTTgQVyHLAHYoTJcTqflhx9AgMBAAECgYAHjvxpVWi7gyhNRHI9mPJjxbv9
E4zBlDPWo+RkPNpgOREnfU05Iqe+a6Ir4kx9qkXTa3s6lbcd0Z+c1/GN/PM8kbMi
v+lhNz1LrgOJRNVs5i5p6wZdigAVC/cg0toTpPUfSbjrdCqOYCzqU27/cpQgm2o8
LH1hiJ3FYXDEtTYuIQJBAOcOhIHHRU+y0TVickbrhEB3PMBKzXnkZACqDQDqPSXo
d12DeDuyakmTK3WhvK6xJs3OLbZ0Efh7tAwnr+vhZxMCQQDXEA4qptETHdI/wSOs
psujeL6cjej/IkBblxA5EKhBDV4Bn+rgemQWzoOCE7keM1souU3UYWR6geZ8eEXj
kRAvAkAX94uLIq5v2+6TiQitjpSDU1r730Z9FFHDN+Btbd615e0ryA1as+EOjLN/
Wi2GOV37Dx3yxQtwKPS+Jge7gf/9AkACyGJmiuIJrUkbKhScF0xrQRS2Ud/B7V+H
z9yV4HFM5i9hNgCEBxFkeieZd0fd7CwxyrQHG3uBWkzxL104JJhhAkA3qZIHDurI
zMFvE/T8Z0YJlJkiS6vAjiHId/8mD08e+vtHAaNDmg+3e4zlIqq9ifC/Rz2YFZ4C
TUyUJOGlwjwT
-----END PRIVATE KEY-----
" > /etc/openvpn/pki/server.key




echo "Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            ae:65:aa:39:cf:f0:57:22:ae:83:75:d2:d1:0e:33:5e
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=Easy-RSA CA
        Validity
            Not Before: Jan  9 11:54:24 2025 GMT
            Not After : Jan  7 11:54:24 2035 GMT
        Subject: CN=server
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (1024 bit)
                Modulus:
                    00:c2:1b:ae:fa:90:a8:9e:7b:f8:04:7d:24:51:5f:
                    7f:45:07:32:d7:06:9a:98:92:99:90:6c:a4:86:f2:
                    37:e1:d9:9e:26:5d:90:4b:6c:6d:3f:bc:a6:12:1a:
                    85:36:72:4e:6a:0f:ea:23:67:b1:b5:70:e5:5d:0b:
                    e0:7e:a5:70:82:a3:9b:68:72:42:dd:78:55:58:5a:
                    93:dd:69:68:c1:67:e1:8b:f5:59:f9:1e:1a:9b:f0:
                    55:a8:42:4b:cc:6d:75:0e:3b:d9:45:ed:6e:10:74:
                    c6:3f:74:3a:f7:29:8a:24:d3:81:05:72:1c:b0:07:
                    62:84:c9:71:3a:9f:96:1c:7d
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Basic Constraints:
                CA:FALSE
            X509v3 Subject Key Identifier:
                9B:5E:30:8F:23:9B:DD:F2:D9:D9:0E:AE:9F:B6:62:31:65:E6:A0:31
            X509v3 Authority Key Identifier:
                keyid:95:BA:3A:95:65:BD:00:29:76:85:99:8B:1D:ED:40:45:4A:F6:40:1E
                DirName:/CN=Easy-RSA CA
                serial:68:F1:86:AA:52:D7:FF:A9:95:A6:4B:0B:FA:B3:B1:8B:15:C0:D1:50
            X509v3 Extended Key Usage:
                TLS Web Server Authentication
            X509v3 Key Usage:
                Digital Signature, Key Encipherment
            X509v3 Subject Alternative Name:
                DNS:server
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        a0:0b:3b:b4:55:95:9d:6c:06:e6:71:2d:e0:9a:ba:db:20:5a:
        06:99:de:73:6d:a4:65:32:be:10:17:fa:fc:0f:62:a5:ee:97:
        cc:36:22:57:70:7c:08:0f:15:93:68:51:90:c4:bd:6b:40:cc:
        1a:96:13:69:b5:74:12:8a:30:1a:aa:fc:e1:59:07:ce:1e:27:
        b2:97:87:63:ca:a4:0e:b8:bf:c6:d3:9c:75:33:70:55:87:88:
        fc:08:83:4a:78:bc:c5:8e:f2:61:20:99:8d:e2:e0:89:27:3d:
        50:3d:98:08:23:fb:c7:a0:a7:43:b0:22:2b:03:3f:2c:57:e6:
        74:c0
-----BEGIN CERTIFICATE-----
MIICYzCCAcygAwIBAgIRAK5lqjnP8FciroN10tEOM14wDQYJKoZIhvcNAQELBQAw
FjEUMBIGA1UEAwwLRWFzeS1SU0EgQ0EwHhcNMjUwMTA5MTE1NDI0WhcNMzUwMTA3
MTE1NDI0WjARMQ8wDQYDVQQDDAZzZXJ2ZXIwgZ8wDQYJKoZIhvcNAQEBBQADgY0A
MIGJAoGBAMIbrvqQqJ57+AR9JFFff0UHMtcGmpiSmZBspIbyN+HZniZdkEtsbT+8
phIahTZyTmoP6iNnsbVw5V0L4H6lcIKjm2hyQt14VVhak91paMFn4Yv1WfkeGpvw
VahCS8xtdQ472UXtbhB0xj90OvcpiiTTgQVyHLAHYoTJcTqflhx9AgMBAAGjgbUw
gbIwCQYDVR0TBAIwADAdBgNVHQ4EFgQUm14wjyOb3fLZ2Q6un7ZiMWXmoDEwUQYD
VR0jBEowSIAUlbo6lWW9ACl2hZmLHe1ARUr2QB6hGqQYMBYxFDASBgNVBAMMC0Vh
c3ktUlNBIENBghRo8YaqUtf/qZWmSwv6s7GLFcDRUDATBgNVHSUEDDAKBggrBgEF
BQcDATALBgNVHQ8EBAMCBaAwEQYDVR0RBAowCIIGc2VydmVyMA0GCSqGSIb3DQEB
CwUAA4GBAKALO7RVlZ1sBuZxLeCautsgWgaZ3nNtpGUyvhAX+vwPYqXul8w2Ildw
fAgPFZNoUZDEvWtAzBqWE2m1dBKKMBqq/OFZB84eJ7KXh2PKpA64v8bTnHUzcFWH
iPwIg0p4vMWO8mEgmY3i4IknPVA9mAgj+8egp0OwIisDPyxX5nTA
-----END CERTIFICATE-----
" > /etc/openvpn/pki/server.crt




echo "-----BEGIN PRIVATE KEY-----
MIICdwIBADANBgkqhkiG9w0BAQEFAASCAmEwggJdAgEAAoGBANAlxHXcLCCTPxjG
MuL8w2hA7SN7uHPcBq2wSJwRoxk7GV0+dYrfwiy6yEIIHLoGLior3sb0ZSjFKdHv
kWHQNZ1GkUydIoh7pLpyco693tMEjKoAkaGFAhR7XAwkEqaNK0ATkyDK2U6mDZ7d
e5LdQ2Cn5tIDO2pFYwsDfogctI6vAgMBAAECgYB5hKMWv+yPNAfROdz5geG/GrCX
V6KPGXRYsKMjYnSaxVMAifdrlUiyfnVtf3jt7a/D9QrBkmsAi2Ln6now5bJ2Ss57
0VNRLNgS2RKRJpVpBGQvDzmH/BW0dpcAjzPsBM/bSrY0F/qpR6vGWBDuWATBR/gb
bs6fq6MVjC1Hcx4E2QJBAO6v+ahS3tEkSM/EoQKKyBiraSx13TCPh9qO3HdjOw3s
KnnIWCcK6Q0ppMwotkvDAggQvtwCnvPmXyyvIA59amsCQQDfPrfLwUfbiZ6A6hdy
y5rS2RLu2swInXKXiBGBBG0XXVOU0UZ0PgvDXt/7IM+fMLnbP6ruColzlCX5CQR6
psXNAkAcMHRPyNm/4YUn5JUPc8yF/ViCg7kHzyvASDcJcpK65jVuBJdEpSk5AL4R
zo0ZDYLj6PZhjX2wWHjNEjG7BFzZAkEAgGvPxwJUl9G+wGHpQzwkwA3nekea/4mz
FcBMcW9eYgZpwj3wzYWztpupNQlW5jhdceZaKb0d/MLIZU3uqa+uMQJBANJhYl0Z
vBPcZ4puOBaSpICeHUeIjFxj3+aftgoV3ybn8PgunlDmwWLEv2ea2bqIFHKf+wTN
vwsUFtNsU3xBpSs=
-----END PRIVATE KEY-----
" > /etc/openvpn/pki/client1.key



echo "Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            b8:e4:57:1a:df:f4:47:42:4a:91:6f:79:38:2d:de:c7
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=Easy-RSA CA
        Validity
            Not Before: Jan  9 11:54:24 2025 GMT
            Not After : Jan  7 11:54:24 2035 GMT
        Subject: CN=client1
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (1024 bit)
                Modulus:
                    00:d0:25:c4:75:dc:2c:20:93:3f:18:c6:32:e2:fc:
                    c3:68:40:ed:23:7b:b8:73:dc:06:ad:b0:48:9c:11:
                    a3:19:3b:19:5d:3e:75:8a:df:c2:2c:ba:c8:42:08:
                    1c:ba:06:2e:2a:2b:de:c6:f4:65:28:c5:29:d1:ef:
                    91:61:d0:35:9d:46:91:4c:9d:22:88:7b:a4:ba:72:
                    72:8e:bd:de:d3:04:8c:aa:00:91:a1:85:02:14:7b:
                    5c:0c:24:12:a6:8d:2b:40:13:93:20:ca:d9:4e:a6:
                    0d:9e:dd:7b:92:dd:43:60:a7:e6:d2:03:3b:6a:45:
                    63:0b:03:7e:88:1c:b4:8e:af
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Basic Constraints:
                CA:FALSE
            X509v3 Subject Key Identifier:
                29:6A:9D:48:45:7D:22:77:92:F0:B9:7D:18:07:77:31:2C:FD:12:A6
            X509v3 Authority Key Identifier:
                keyid:95:BA:3A:95:65:BD:00:29:76:85:99:8B:1D:ED:40:45:4A:F6:40:1E
                DirName:/CN=Easy-RSA CA
                serial:68:F1:86:AA:52:D7:FF:A9:95:A6:4B:0B:FA:B3:B1:8B:15:C0:D1:50
            X509v3 Extended Key Usage:
                TLS Web Client Authentication
            X509v3 Key Usage:
                Digital Signature
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        05:c1:cc:6c:a8:ce:f8:5c:52:bc:b8:56:0a:e1:29:fc:ca:22:
        07:bf:23:25:5c:65:6a:95:d1:d5:4c:6f:da:4e:18:fe:a2:cf:
        ea:28:2a:2c:b1:3d:da:02:d3:05:ee:70:72:9a:83:65:f4:b9:
        ec:69:71:5c:0f:54:1c:be:d7:a5:d2:29:29:28:8b:00:93:31:
        80:eb:ea:1e:cb:80:99:6b:f8:d7:2b:9f:38:91:5b:e4:37:dd:
        fb:da:c5:2b:cd:7b:17:50:95:85:83:31:31:22:68:0a:c9:6b:
        25:6e:94:e1:5c:e9:bb:9a:b7:31:b9:a3:80:73:a6:f9:17:c1:
        30:e6
-----BEGIN CERTIFICATE-----
MIICUTCCAbqgAwIBAgIRALjkVxrf9EdCSpFveTgt3scwDQYJKoZIhvcNAQELBQAw
FjEUMBIGA1UEAwwLRWFzeS1SU0EgQ0EwHhcNMjUwMTA5MTE1NDI0WhcNMzUwMTA3
MTE1NDI0WjASMRAwDgYDVQQDDAdjbGllbnQxMIGfMA0GCSqGSIb3DQEBAQUAA4GN
ADCBiQKBgQDQJcR13Cwgkz8YxjLi/MNoQO0je7hz3AatsEicEaMZOxldPnWK38Is
ushCCBy6Bi4qK97G9GUoxSnR75Fh0DWdRpFMnSKIe6S6cnKOvd7TBIyqAJGhhQIU
e1wMJBKmjStAE5MgytlOpg2e3XuS3UNgp+bSAztqRWMLA36IHLSOrwIDAQABo4Gi
MIGfMAkGA1UdEwQCMAAwHQYDVR0OBBYEFClqnUhFfSJ3kvC5fRgHdzEs/RKmMFEG
A1UdIwRKMEiAFJW6OpVlvQApdoWZix3tQEVK9kAeoRqkGDAWMRQwEgYDVQQDDAtF
YXN5LVJTQSBDQYIUaPGGqlLX/6mVpksL+rOxixXA0VAwEwYDVR0lBAwwCgYIKwYB
BQUHAwIwCwYDVR0PBAQDAgeAMA0GCSqGSIb3DQEBCwUAA4GBAAXBzGyozvhcUry4
VgrhKfzKIge/IyVcZWqV0dVMb9pOGP6iz+ooKiyxPdoC0wXucHKag2X0uexpcVwP
VBy+16XSKSkoiwCTMYDr6h7LgJlr+NcrnziRW+Q33fvaxSvNexdQlYWDMTEiaArJ
ayVulOFc6buatzG5o4BzpvkXwTDm
-----END CERTIFICATE-----
" > /etc/openvpn/pki/client1.crt




echo "config openvpn 'myvpn'
    option enabled '1'
    option proto 'tcp4'
    option dev 'tun'
    option topology 'subnet'
    option server '100.100.0.0 255.255.255.0'
    option comp_lzo 'yes'
    option ca '/etc/openvpn/pki/ca.crt'
    option dh '/etc/openvpn/pki/dh.pem'
    option cert '/etc/openvpn/pki/server.crt'
    option key '/etc/openvpn/pki/server.key'
    option persist_key '1'
    option persist_tun '1'
    option max_clients '88'
    option keepalive '10 120'
    option verb '3'
    option status '/var/log/openvpn_status.log'
    option log '/tmp/openvpn.log'
    option port '1122'
    option ddns 'smnra.oicp.net'
    option auth_user_pass_verify '/etc/openvpn/server/checkpsw.sh via-env'
    option script_security '3'
    option client_to_client '1'
    option username_as_common_name '1'
    option client_cert_not_required '1'
        list push 'route 192.168.1.0 255.255.255.0'
        list push 'route 192.168.10.0 255.255.255.0'
        list push 'route 100.100.0.0 255.255.255.0'
        list push 'route 100.100.1.0 255.255.255.0'
        list push 'dhcp-option DNS 192.168.10.1'

config openvpnclient

config openvpnclientstart

config openvpnclientconf

config openvpnclientstop

" > /etc/config/openvpn


echo "生成 openvpn 客户端天健配置 "
echo "
comp-lzo
tun-mtu 1500
auth-user-pass user.txt
"> /etc/ovpnadd.conf


echo "生成 openvpn  帐号文件"
echo "smnra smnra000
" > /etc/openvpn/server/psw-file




if [ ! -f "/etc/openvpn/pki/ca.crt" ]; then
    echo "缺少ca.crt文件, 开始下载..."
    download_with_retry https://cdn.jsdelivr.net/gh/smnra/pve_config/openwrt/openvpn/pki/ca.crt /etc/openvpn/pki/ca.crt
fi

if [ ! -f "/etc/openvpn/pki/dh.pem" ]; then
    echo "缺少dh.pem文件, 开始下载..."
    download_with_retry https://cdn.jsdelivr.net/gh/smnra/pve_config/openwrt/openvpn/pki/dh.pem /etc/openvpn/pki/dh.pem
fi

if [ ! -f "/etc/openvpn/pki/server.crt" ]; then
    echo "缺少server.crt文件, 开始下载..."
    download_with_retry https://cdn.jsdelivr.net/gh/smnra/pve_config/openwrt/openvpn/pki/server.crt /etc/openvpn/pki/server.crt
fi

if [ ! -f "/etc/openvpn/pki/server.key" ]; then
    echo "缺少server.key文件, 开始下载..."
    download_with_retry https://cdn.jsdelivr.net/gh/smnra/pve_config/openwrt/openvpn/pki/server.key /etc/openvpn/pki/server.key
fi

if [ ! -f "/etc/openvpn/pki/client1.crt" ]; then
    echo "缺少client1.crt文件, 开始下载..."
    download_with_retry https://cdn.jsdelivr.net/gh/smnra/pve_config/openwrt/openvpn/pki/client1.crt /etc/openvpn/pki/client1.crt
fi

if [ ! -f "/etc/openvpn/pki/client1.key" ]; then
    echo "缺少client1.key文件, 开始下载..."
    download_with_retry https://cdn.jsdelivr.net/gh/smnra/pve_config/openwrt/openvpn/pki/client1.key /etc/openvpn/pki/client1.key
fi

sleep 5
# 启动 openvpn
/etc/init.d/openvpn restart









########################################################################################################################
echo "设置 openclash  ###################################################################################################"
mkdir -p /etc/openclash/config /etc/openclash/core

# openclash 配置文件
if [ -f /etc/openclash/config/config.yaml ]; then
    echo "/etc/openclash/config/config.yaml openclash 配置文件已存在，跳过下载"
else
    echo "下载 https://smnra.github.io/pve_config/openwrt/openclash/config.yaml 写入 /etc/openclash/config/config.yaml"
    download_with_retry https://cdn.jsdelivr.net/gh/smnra/pve_config/openwrt/openclash/config.yaml /etc/openclash/config/config.yaml
fi

# openclash 核心文件
if [ -f /etc/openclash/core/clash_meta ]; then
    echo "/etc/openclash/core/clash_meta openclash 核心文件已存在，跳过下载"
else
    echo "下载 https://smnra.github.io/pve_config/openwrt/openclash/core/clash.meta 写入 /etc/openclash/core/clash_meta"
    # 使用 cdn.jsdelivr.net  cdn加速下载 https://cdn.jsdelivr.net/gh/smnra/pve_config/openwrt/openclash/core/clash_meta
    download_with_retry https://cdn.jsdelivr.net/gh/smnra/pve_config/openwrt/openclash/core/clash_meta /etc/openclash/core/clash_meta
fi




echo "写入 /etc/config/openclash"
echo "

config openclash 'config'
	option http_port '7890'
	option dns_port '7874'
	option enable '0'
	option update '0'
	option en_mode 'redir-host'
	option auto_update '1'
	option auto_update_time '12'
	option dashboard_forward_ssl '0'
	option rule_source '0'
	option enable_custom_dns '0'
	option ipv6_enable '0'
	option ipv6_dns '0'
	option enable_custom_clash_rules '0'
	option other_rule_auto_update '1'
	option core_version 'linux-amd64'
	option enable_redirect_dns '1'
	option servers_if_update '0'
	option disable_masq_cache '1'
	option servers_update '0'
	option log_level '0'
	option proxy_mode 'rule'
	option intranet_allowed '1'
	option enable_udp_proxy '1'
	option disable_udp_quic '1'
	option lan_ac_mode '1'
	option operation_mode 'redir-host'
	option enable_rule_proxy '0'
	option redirect_dns '1'
	option cachesize_dns '1'
	option filter_aaaa_dns '0'
	option small_flash_memory '0'
	option interface_name '0'
	option common_ports '0'
	option log_size '1024'
	option tolerance '0'
	option store_fakeip '0'
	option custom_fallback_filter '0'
	option custom_fakeip_filter '0'
	option custom_host '0'
	option custom_name_policy '0'
	option append_wan_dns '0'
	option bypass_gateway_compatible '0'
	option github_address_mod '0'
	option urltest_address_mod '0'
	option urltest_interval_mod '0'
	option delay_start '0'
	option router_self_proxy '0'
	option release_branch 'master'
	option dashboard_type 'Official'
	option yacd_type 'Meta'
	option append_default_dns '0'
	option enable_respect_rules '0'
	option geo_custom_url 'https://testingcf.jsdelivr.net/gh/alecthw/mmdb_china_ip_list@release/lite/Country.mmdb'
	option chnr_custom_url 'https://ispip.clang.cn/all_cn.txt'
	option chnr6_custom_url 'https://ispip.clang.cn/all_cn_ipv6.txt'
	option dashboard_password 'smnra000'
	option default_resolvfile '/tmp/resolv.conf.d/resolv.conf.auto'
	option config_path '/etc/openclash/config/config.yaml'
	option config_auto_update_mode '0'
	option config_update_week_time '*'
	option config_reload '0'
	option core_type 'Meta'
	option dnsmasq_resolvfile '/tmp/resolv.conf.d/resolv.conf.auto'
	option enable_custom_domain_dns_server '0'
	option skip_proxy_address '1'
	option china_ip_route '1'
	list intranet_allowed_wan_name 'pppoe-wan'
	option lan_interface_name '0'
	option geo_auto_update '1'
	option geo_update_week_time '1'
	option geo_update_day_time '0'
	option geoip_auto_update '1'
	option geosite_auto_update '1'
	option chnr_auto_update '1'
	option chnr_update_week_time '1'
	option chnr_update_day_time '0'
	option auto_restart '0'
	option auto_restart_week_time '1'
	option auto_restart_day_time '0'
	option other_rule_update_week_time '1'
	option other_rule_update_day_time '0'
	option geoip_update_week_time '1'
	option geoip_update_day_time '0'
	option geoip_custom_url 'https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat'
	option geosite_update_week_time '1'
	option geosite_update_day_time '0'
	option geosite_custom_url 'https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat'
	option dnsmasq_noresolv '0'
	option dnsmasq_cachesize '600'

config dns_servers
	option type 'udp'
	option ip '114.114.114.114'
	option enabled '1'
	option group 'default'

config dns_servers
	option type 'udp'
	option ip '119.29.29.29'
	option enabled '1'
	option group 'default'

config dns_servers
	option group 'nameserver'
	option type 'udp'
	option ip '114.114.114.114'
	option enabled '1'

config dns_servers
	option type 'udp'
	option ip '223.5.5.5'
	option enabled '1'
	option group 'default'

config dns_servers
	option group 'nameserver'
	option type 'udp'
	option ip '119.29.29.29'
	option enabled '1'

config dns_servers
	option group 'nameserver'
	option type 'udp'
	option ip '119.28.28.28'
	option enabled '0'

config dns_servers
	option group 'nameserver'
	option type 'udp'
	option ip '223.5.5.5'
	option enabled '0'

config dns_servers
	option type 'https'
	option ip 'doh.pub/dns-query'
	option group 'nameserver'
	option enabled '1'

config dns_servers
	option type 'https'
	option ip 'dns.alidns.com/dns-query'
	option group 'nameserver'
	option enabled '1'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip '9.9.9.9'
	option type 'udp'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip '149.112.112.112'
	option type 'udp'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip '2620:fe::fe'
	option type 'udp'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip '2620:fe::9'
	option type 'udp'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip '8.8.8.8'
	option type 'udp'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip '8.8.4.4'
	option type 'udp'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip '2001:4860:4860::8888'
	option type 'udp'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip '2001:4860:4860::8844'
	option type 'udp'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip '2001:da8::666'
	option type 'udp'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'dns.quad9.net'
	option type 'tls'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'dns.google'
	option type 'tls'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip '1.1.1.1'
	option type 'tls'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'jp.tiar.app'
	option type 'tls'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'dot.tiar.app'
	option type 'tls'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'dns.quad9.net/dns-query'
	option type 'https'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'dns.google/dns-query'
	option type 'https'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'dns.cloudflare.com/dns-query'
	option type 'https'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip '1.1.1.1/dns-query'
	option type 'https'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'public.dns.iij.jp/dns-query'
	option type 'https'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'jp.tiar.app/dns-query'
	option type 'https'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'jp.tiarap.org/dns-query'
	option type 'https'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option type 'https'
	option ip 'doh.dnslify.com/dns-query'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'dns.twnic.tw/dns-query'
	option type 'https'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'dns.oszx.co/dns-query'
	option type 'https'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'doh.applied-privacy.net/query'
	option type 'https'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'dnsforge.de/dns-query'
	option type 'https'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'doh.ffmuc.net/dns-query'
	option type 'https'

config dns_servers
	option enabled '0'
	option group 'fallback'
	option ip 'doh.mullvad.net/dns-query'
	option type 'https'

config authentication
	option enabled '1'
	option username 'smnra'
	option password 'smnra000'

config config_subscribe
	option enabled '1'
	option name 'yudoucode'
	option address 'https://smnra.github.io/yudoucode/v2ray/index.html'
	option sub_ua 'clash.meta'
	option sub_convert '0'

" > /etc/config/openclash

# echo "重启 openclash "
#/etc/init.d/openclash restart

########################################################################################################################









########################################################################################################################
# /etc/config/dockerd
echo "配置docker.     ###################################################################################################"
uci set dockerd.globals.data_root='/data/docker/docker_home'
uci add_list dockerd.globals.registry_mirrors="https://docker.hpcloud.cloud"
uci add_list dockerd.globals.registry_mirrors="https://docker.m.daocloud.io"
uci add_list dockerd.globals.registry_mirrors="https://docker.unsee.tech"
uci add_list dockerd.globals.registry_mirrors="https://docker.1panel.live"
uci add_list dockerd.globals.registry_mirrors="http://mirrors.ustc.edu.cn"
uci add_list dockerd.globals.registry_mirrors="https://docker.chenby.cn"
uci add_list dockerd.globals.registry_mirrors="http://mirror.azure.cn"
uci add_list dockerd.globals.registry_mirrors="https://dockerpull.org"
uci add_list dockerd.globals.registry_mirrors="https://dockerhub.icu"
uci add_list dockerd.globals.registry_mirrors="https://hub.rat.dev"
uci add_list dockerd.globals.registry_mirrors="https://proxy.1panel.live"
uci add_list dockerd.globals.registry_mirrors="https://docker.1panel.top"
uci add_list dockerd.globals.registry_mirrors="https://docker.m.daocloud.io"
uci add_list dockerd.globals.registry_mirrors="https://docker.1ms.run"
uci add_list dockerd.globals.registry_mirrors="https://docker.ketches.cn"

uci set dockerd.globals.bip='172.20.0.1/16'
uci commit dockerd

/etc/init.d/dockerd restart


# echo "下载docker_data 数据包并解压"
# wget -c -O /data/docker/docker_data.7z  https://smnra.github.io/pve_config/docker/docker_data.7z
# cd /data/docker/
# 7zz x -psmnra000 /data/docker/docker_data.7z -o/data/app/
# mv /data/docker/all_docker-compose.yml /data/docker/docker_data/all_docker-compose.yml
# rm -f  /data/docker/docker_data.7z


echo "下载docker-compose 配置文件"
wget -c -O /data/docker/docker_data/all_docker-compose.yml  https://cdn.jsdelivr.net/gh/smnra/pve_config/docker/all_docker-compose.yml

echo "docker 镜像下载"
docker pull tznb/twonav:latest
docker pull idootop/mi-gpt:latest
docker pull smnrao/python_flask_docker:latest
docker pull thedrobe/iventoy-docker:latest


# echo "启动docker-compose 服务"
# cd  /data/docker/docker_data/
# docker-compose -f /data/docker/docker_data/all_docker-compose.yaml up -d
#
# echo "等待docker-compose 服务启动完成"












# reboot

exit 0
