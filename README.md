rdiff-backup
============
Implementação de backup incremental com Rdiff-backup

============
##Intalação:
Pré requisitos:
rdiff-backup git mailutils(para envio do relatório)

###Em distribuições debian like:
sudo apt-get install git rdiff-backup mailutils

###Arch Linux:
sudo pacman -S git rdiff-backup mailutils

##Download do repositório:
git clone https://github.com/thiagoifsc/rdiff-backup.git

============
##Exemplo de backup via crontab:

#### backup incremental de segunda a sexta as 20hs com log
sudo crontab -e

00 20 *  *  1-5 	/root/rdiff-backup/rdiff-backup.sh start /root/rdiff-backup/disklist.diario > /var/log/rdiff_diario.log
