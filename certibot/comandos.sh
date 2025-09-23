certbot certonly -d gsior.ro
sudo certbot certonly --standalone -d your_domain.com -d www.your_domain.com

sudo certbot certonly --standalone -d *.gsior.ro

ps aux | grep nginx
killall nginx