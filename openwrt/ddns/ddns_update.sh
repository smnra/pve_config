
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



