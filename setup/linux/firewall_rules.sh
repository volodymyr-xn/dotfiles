# KDE Connect uses dynamic ports in the range 1714-1764 for UDP and TCP. So if
# you are behind a firewall, make sure to open this port range for both TCP and
# UDP. Otherwise, make sure your network is not blocking UDP broadcast packets.

# For UFW firewall
sudo ufw allow 1714:1764/udp
sudo ufw allow 1714:1764/tcp
sudo ufw allow 42000:42000/tcp
sudo ufw allow 42000:42000/udp

sudo ufw allow Samba

sudo ufw reload

# For firewalld
# sudo firewall-cmd --zone=public --permanent --add-port=1714-1764/tcp
# sudo firewall-cmd --zone=public --permanent --add-port=1714-1764/udp
#
# sudo systemctl restart firewalld.service
