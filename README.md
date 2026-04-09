FOR test

bash <(curl -Ls https://raw.githubusercontent.com/acgogo2023/auto_jb/main/frp.sh) 

curl -Ls https://raw.githubusercontent.com/acgogo2023/auto_jb/main/frp.sh -o /usr/local/bin/frp && chmod +x /usr/local/bin/frp && frp
