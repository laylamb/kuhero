#!/bin/sh

# config caddy
mkdir -p /usr/share/caddy
wget -O /usr/share/caddy/index.html https://raw.githubusercontent.com/caddyserver/dist/master/welcome/index.html
cat << EOF > /etc/caddy/Caddyfile
:$PORT
root * /usr/share/caddy
file_server

@websocket_ss {
header Connection *Upgrade*
header Upgrade    websocket
path /sspath
}
reverse_proxy @websocket_ss 127.0.0.1:1234

@websocket_gost {
header Connection *Upgrade*
header Upgrade    websocket
path /gostpath
}
reverse_proxy @websocket_gost 127.0.0.1:2234

@websocket_brook {
header Connection *Upgrade*
header Upgrade    websocket
path /brookpath
}
reverse_proxy @websocket_brook 127.0.0.1:3234

@websocket_v2ray {
header Connection *Upgrade*
header Upgrade    websocket
path /v2raypath
}
reverse_proxy @websocket_v2ray 127.0.0.1:4234
EOF

# config v2ray
cat << EOF > /v2ray.json
{
    "inbounds": 
    [
        {
            "port": 4234,"listen": "127.0.0.1","protocol": "vless",
            "settings": {"clients": [{"id": "8f91b6a0-e8ee-11ea-adc1-0242ac120002"}],"decryption": "none"},
            "streamSettings": {"network": "ws","wsSettings": {"path": "/v2raypath"}}
        }
    ],
    "outbounds": [{"protocol": "freedom"}]
}	
EOF

# start tor v2ray
nohup tor &
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
/usr/bin/v2ray/v2ray -config /usr/bin/v2ray/config.json

# start
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
ss-server -s 127.0.0.1 -p 1234 -k password -m chacha20-ietf-poly1305 --plugin /usr/bin/v2ray-plugin_linux_amd64 --plugin-opts "server;path=/sspath" &
gost -L ss+ws://AEAD_CHACHA20_POLY1305:password@127.0.0.1:2234?path=/gostpath &
brook wsserver -l 127.0.0.1:3234 --path /brookpath -p password &
/v2ray -config /v2ray.json
