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






################################################################################
echo "修改/dev/sda3挂载为 /data, 当前 分区挂载情况:"
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



################################################################################
# 清理残联的docker文件
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



################################################################################
echo "创建目录 /data/temp, /data/log, /data/app/ddns, /data/docker/docker_home, /data/docker/docker_data"
mkdir -p /data/temp
mkdir -p /data/log
mkdir -p /data/app/ddns
mkdir -p /data/docker/docker_home
mkdir -p /data/docker/docker_data



################################################################################
# /etc/config/dockerd
echo "配置docker."
uci set dockerd.globals.data_root='/data/docker/docker_home'
uci add_list dockerd.globals.registry_mirrors='https://registry.docker-cn.com'
uci add_list dockerd.globals.registry_mirrors='https://docker.mirrors.ustc.edu.cn'
uci add_list dockerd.globals.registry_mirrors='https://hub-mirror.c.163.com'
uci add_list dockerd.globals.registry_mirrors='https://mirror.baidubce.com'
uci add_list dockerd.globals.registry_mirrors='https://ccr.ccs.tencentyun.com'
uci commit dockerd




################################################################################
echo 'opkg update'
opkg update

echo '无线网卡 mt7921e 软件包安装.   bypass'
# opkg install iw-full kmod-mt7921e hostapd-openssl

opkg install wol etherwake luci-app-wol luci-i18n-wol-zh-cn
opkg install iptvhelper
# opkg install zerotier luci-app-zerotier
# opkg install headscale
# opkg install vlmcsd luci-app-vlmcsd
##################################################################################################




#################################
echo '设置中文语言'
uci set luci.main.lang='zh_cn'
uci commit luci





#####################################################################################
echo "设置 web访问 控制列表"
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





################################################################################################

echo '开机启动 /etc/rc.local'
result=`strInFile 'ddns_update.sh' '/etc/rc.local'`
echo result: ${result}
if [ ${result} == 1 ]
then
    echo '开始修改 /etc/rc.local'
    echo '
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

sleep 10

# 修改 ZeroTier 接口mac地址  无效
ip link set dev ztc25dx6ge down
ip link set dev ztc25dx6ge address 00:11:22:33:44:02
ip link set dev ztc25dx6ge up

#DDNS 更新
ping  127.0.0.1 -c 60 && sh /root/ddns_update.sh  >> /data/log/ddns_update.log &


exit 0
' > /etc/rc.local
else
    echo '已找到rc.local 未修改/etc/rc.local'
fi






##################################################################################
echo '添加到光猫的接口lan_gpon,并配置为dhcp获取ip,并设置mac地址:00:11:22:33:44:01.'
result=`strInFile "config interface 'lan_gpon'" '/etc/config/network'`
echo result: ${result}
if [ ${result} == 1 ]
then
    echo "
config interface 'lan_gpon'
    option proto 'dhcp'
    option device 'eth1'
    option mtu '1500'
    option macaddr '00:11:22:33:44:01'
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







########################################################################################

echo '设置 zerotier的接口 ztc25dx6ge mac地址:00:11:22:33:44:02, mtu:1500,  貌似无效'

result=`strInFile "config interface 'ztc25dx6ge'" '/etc/config/network'`
echo result: ${result}
if [ ${result} == 1 ]
then
    echo "

config device
    option name 'ztc25dx6ge'
    option mtu '1500'
    option macaddr '00:11:22:33:44:02'

" >> /etc/config/network
else
    echo "已找到 config interface 'lan_gpon' ,未修改 /etc/config/network" >> /root/系统初始化设置.log
fi

/etc/init.d/network restart










########################################################################################################

echo '添加静态路由'
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




###########################################################################################


echo 'dhcp 静态地址'
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








#######################################################################
echo '防火墙规则'
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
    option src_dport '8002'
    option dest_port '8006'
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
    option src_dport '8204'
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
    option name 'twonav'
    option src 'wan'
    option src_dport '8102'
    option dest_ip '192.168.10.1'
    option dest_port '5000'

config redirect
    option dest 'lan'
    option target 'DNAT'
    option name 'docker_flask'
    option src 'wan'
    option src_dport '8103'
    option dest_ip '192.168.10.1'
    option dest_port '8780'


" >> /etc/config/firewall



#######################################################################
echo 'DNS助手配置  /etc/config/my-dnshelper'
echo "
config my-dnshelper
    option enable '1'
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
    list url 'https://fastly.jsdelivr.net/gh/AdguardTeam/AdGuardSDNSFilter@gh-pages/Filters/filter.txt'
#    list url 'https://fastly.jsdelivr.net/gh/Cats-Team/AdRules/hosts.txt'
#    list url 'https://fastly.jsdelivr.net/gh/VeleSila/yhosts/hosts.txt'
#    list url 'https://fastly.jsdelivr.net/gh/kongfl888/ad-rules/malhosts.txt'
" > /etc/config/my-dnshelper

/etc/init.d/my-dnshelper enable
/etc/init.d/my-dnshelper start









#####################################################################################
echo "设置 wifi  /etc/config/wireless"
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

sleep 5

# 启动 wifi
wifi up
wifi reload



###############################################################################
echo '设置DDNS 更新'
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


# 获取外网接口名称（通常为 pppoe-wan ）
WAN_INTERFACE=pppoe-wan

# 提取 IPv4 地址
IPV4_ADDRESS=$(ifconfig $WAN_INTERFACE | grep "inet addr:" | cut -d: -f2 | cut -d" " -f1)

# 提取 IPv6 地址
IPV6_ADDRESS=$(ifconfig $WAN_INTERFACE | grep "inet6 addr" | grep "Global" | sed "s/^.*inet6 addr: //" | cut -d/ -f1)

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
/bin/sh /data/app/ddns/ddns_update.sh





############################################################################################################################
# 计划任务 crontab 添加ddns 每小时更新; 每天凌晨4点重启系统; 每小时释放内存;

echo 'Crontab  添加ddns 每小时更新ddns'
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







#############################################################################################
echo '配置 应用过滤 '
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
    option users 'e0:d5:5e:b7:30:83 bc:24:11:e8:4a:e3 60:be:b4:00:f3:36'

" >> /etc/config/appfilter
else
    echo "已找到 option enable '1',未修改 /etc/config/appfilter"
fi

echo "启动 appfilter"
/etc/init.d/appfilter start

##############################################################################









########################################################################
echo "设置zerotier /etc/config/zerotier"

echo "
config zerotier 'sample_config'
    option enabled '1'
    option nat '1'
        list join 'abfd31bd470a4583'
" > /etc/config/zerotier
# 启动 zerotier
/etc/init.d/zerotier start


#echo "增加设置zerotier mac地址  mtu"
#echo "
#
#config device
#    option name 'ztc25dx6ge'
#    option mtu '1500'
#    option macaddr '82:87:e5:94:d1:36'
#
#" >>/etc/config/network

# /etc/init.d/network restart








#####################################################################
echo "设置unishare  文件共享  /etc/config/unishare "

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









#####################################################################
echo "设置 bypass /etc/config/bypass"

echo "
config global
    option dports '2'
    option threads '0'
    option run_mode 'gfw'
    option dns_mode_o 'tcp'
    option gfw_mode '1'
    option dns_mode_d 'doh'
    option doh_dns_d 'alidns'
    option monitor_enable '1'
    option enable_switch '1'
    option switch_time '300'
    option switch_timeout '5'
    option switch_try_count '3'
    option adguardhome '0'
    option tcp_dns_o '8.8.8.8,8.8.4.4'
    option global_server 'cfg064a8f'
    option udp_relay_server 'same'

config socks5_proxy
    option server 'same'
    option local_port '1080'

config access_control
    option lan_ac_mode 'b'

config server_global

config server_subscribe
    option proxy '0'
    option auto_update_time '5'
    option auto_update '1'
    option filter_words '过期时间/剩余流量/QQ群/官网/防失联地址/回国'
    list subscribe_url 'https://smnra.github.io/yudoucode/v2ray/index.html'
    option switch '0'

" > /etc/config/bypass

echo "重启 bypass "
/etc/init.d/bypass restart








####################################################################################
echo "openvpn 配置"

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



echo "生成 openvpn 帐号检查脚本 /etc/openvpn/server/checkpsw.sh"
# 定义 checkpsw.sh 脚本内容
script_content=$(cat << 'EOF'
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

# 将脚本内容写入文件并设置权限
echo "$script_content" > /etc/openvpn/server/checkpsw.sh
chmod +x /etc/openvpn/server/checkpsw.sh







echo "生成 openvpn 证书自动生成脚本 /etc/openvpn/server/openvpncert.sh"
# 定义 openvpncert.sh 脚本内容
script_content=$(cat << 'EOF'
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

# 将脚本内容写入文件并设置权限
echo "$script_content" > /etc/openvpn/server/openvpncert.sh
chmod +x /etc/openvpn/server/openvpncert.sh




echo "生成 openvpn 服务启动脚本 /etc/init.d/openvpn"
# 定义openvpn 脚本内容
script_content=$(cat << 'EOF'
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
echo "$script_content" > /etc/init.d/openvpn
chmod +x /etc/init.d/openvpn


echo "生成openvpn证书"
# /bin/sh /etc/openvpncert.sh
# /bin/sh /etc/openvpncert.sh
/bin/sh /etc/openvpn/server/openvpncert.sh
sleep 10


# 启动 openvpn
/etc/init.d/openvpn restart
















#################################################################################################

reboot

exit 0
