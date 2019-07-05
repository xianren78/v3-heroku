#! /bin/bash
if [[ -z "${UUID}" ]]; then
  UUID="4890bd47-5180-4b1c-9a5d-3ef686543112"
fi

if [[ -z "${AlterID}" ]]; then
  AlterID="10"
fi

if [[ -z "${V2_Path}" ]]; then
  V2_Path="/FreeApp"
fi

if [[ -z "${V2_QR_Path}" ]]; then
  V2_QR_Code="1234"
fi

rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
date -R

SYS_Bit="$(getconf LONG_BIT)"
[[ "$SYS_Bit" == '32' ]] && BitVer='_linux_386.tar.gz'
[[ "$SYS_Bit" == '64' ]] && BitVer='_linux_amd64.tar.gz'

if [ "$VER" = "latest" ]; then
  V_VER=`wget -qO- "https://api.github.com/repos/v2ray/v2ray-core/releases/latest" | grep 'tag_name' | cut -d\" -f4`
else
  V_VER="v$VER"
fi

mkdir /v2raybin
cd /v2raybin
wget --no-check-certificate https://github.com/v2ray/v2ray-core/releases/download/$V_VER/v2ray-linux-64.zip
unzip v2ray-linux-64.zip v2ray v2ctl geosite.dat geoip.dat -d /v2raybin/
rm -rf ./v2ray-linux-64.zip
chmod +x /v2raybin/v2ray /v2raybin/v2ctl

C_VER=`wget -qO- "https://api.github.com/repos/mholt/caddy/releases/latest" | grep 'tag_name' | cut -d\" -f4`
mkdir /caddybin
cd /caddybin
wget --no-check-certificate -qO 'caddy.tar.gz' "https://github.com/mholt/caddy/releases/download/$C_VER/caddy_$C_VER$BitVer"
tar xvf caddy.tar.gz
rm -rf caddy.tar.gz
chmod +x caddy
cd /root
mkdir /wwwroot
cd /wwwroot

wget --no-check-certificate -qO 'demo.tar.gz' "https://github.com/xianren78/v2ray-heroku/raw/master/demo.tar.gz"
tar xvf demo.tar.gz
rm -rf demo.tar.gz

cat <<-EOF > /v2raybin/config.json
{
	"log": {
		"loglevel": "warning"
	},
	"inbounds": [
		{
			"port": 10001,
			"listen": "127.0.0.1",
			"protocol": "dokodemo-door",
			"tag": "wsdoko",
			"settings": {
				"address": "v1.mux.cool",
				"followRedirect": false,
				"network": "tcp"
			},
			"streamSettings": {
				"network": "ws",
				"wsSettings": {
					"path": "/shadow"
				}
			}
		},
		{
			"port": 9015,
			"protocol": "shadowsocks",
			"settings": {
				"method": "aes-128-gcm",
				"ota": false,
				"password": "${UUID}",
				"network": "tcp,udp"
			},
			"streamSettings": {
				"network": "domainsocket"
			}
		},
		{
      "tag": "ws",
			"port": 10000,
			"listen": "127.0.0.1",
			"protocol": "vmess",
			"settings": {
	            "clients":[
                {
                    "id":"${UUID}",
                    "level":1,
                    "alterId":${AlterID}
                },
		{
                    "id":"${UUID1}",
                    "level":1,
                    "alterId":${AlterID}
                },
		{
                    "id":"${UUID2}",
                    "level":1,
                    "alterId":${AlterID}
                },
		{
                    "id":"${UUID3}",
                    "level":1,
                    "alterId":${AlterID}
                }]
			},
			"streamSettings": {
				"network": "ws",
				"wsSettings": {
					"path": "/port"
				}
			}
		}
	],
	"outbounds": [{
		"protocol": "freedom",
		"settings": {},
		"tag": "direct"
	},
		{
			"protocol": "blackhole",
			"settings": {},
			"tag": "blocked"
		},
		{
			"protocol": "freedom",
			"tag": "ssmux",
			"streamSettings": {
				"network": "domainsocket"
			}
		}],
  "transport": {
		"dsSettings": {
			"path": "/v2raybin/ss-loop.sock"
		}
	},
	"routing": {
		"rules": [
			{
				"type": "field",
				"inboundTag": [
					"wsdoko"
				],
				"outboundTag": "ssmux"
			},
			{
				"type": "field",
				"ip": [
					"geoip:private"
				],
				"outboundTag": "blocked"
			}
		]
	}
}
EOF

cat <<-EOF > /caddybin/Caddyfile
http://0.0.0.0:${PORT}
{
	root /wwwroot
	index index.html
	timeouts none
	proxy ${V2_Path} localhost:10000 {
		websocket
		header_upstream -Origin
	}
	proxy ${SS_Path} localhost:10001 {
		websocket
		header_upstream -Origin
	}
}
EOF

cat <<-EOF > /v2raybin/vmess.json 
{
    "v": "2",
    "ps": "${AppName}.herokuapp.com",
    "add": "${AppName}.herokuapp.com",
    "port": "443",
    "id": "${UUID}",
    "aid": "${AlterID}",			
    "net": "ws",			
    "type": "none",			
    "host": "",			
    "path": "${V2_Path}",	
    "tls": "tls"			
}
EOF

if [ "$AppName" = "no" ]; then
  echo "不生成二维码"
else
  mkdir /wwwroot/$V2_QR_Path
  vmess="vmess://$(cat /v2raybin/vmess.json | base64 -w 0)" 
  Linkbase64=$(echo -n "${vmess}" | tr -d '\n' | base64 -w 0) 
  echo "${Linkbase64}" | tr -d '\n' > /wwwroot/$V2_QR_Path/index.html
  echo -n "${vmess}" | qrencode -s 6 -o /wwwroot/$V2_QR_Path/v2.png
fi

cd /v2raybin
./v2ray &
cd /caddybin
./caddy -conf="Caddyfile"
