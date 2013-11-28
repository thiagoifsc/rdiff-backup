#!/bin/bash
# Script de automatização do rdiff-backup
# Thiago Felipe da Cunha

local=`echo $0 | awk -F'/' '{for (i=1; i<NF; i++) printf("%s/", $i)}'`

# organização
org=`cat $local/rdiff-backup.conf|grep org=|cut -d\" -f2`
# email para onde serão enviados os relatórios
mail=`cat $local/rdiff-backup.conf|grep mail=|cut -d\" -f2`
# dias de manutencao do backup incremental
dias=`cat $local/rdiff-backup.conf|grep dias=|cut -d\" -f2`
# habilita/desabilita o log
log=`cat $local/rdiff-backup.conf|grep log=|cut -d\= -f2`
# pasta onde o backup deve ser salvo
destino=`cat $local/rdiff-backup.conf|grep destino=|cut -d\" -f2`

discos=`cat $local/disklist.conf | sed '/^\( *$\| *#\)/d'| wc -l`
#c2=0
for (( c=1; c <= $discos; c++ ))
do
	host[$c-1]=`cat $local/disklist.conf | sed '/^\( *$\| *#\)/d'|sed ''$c'!d' |cut -d: -f1`
        diretorios_backup[$c-1]=`cat $local/disklist.conf | sed '/^\( *$\| *#\)/d'|sed ''$c'!d' |cut -d: -f2`
	usuario[$c-1]=`cat $local/disklist.conf | sed '/^\( *$\| *#\)/d'|sed ''$c'!d' |cut -d: -f4`
	diretorios_excluir[$c-1]=`cat disklist.conf | sed '/^\( *$\| *#\)/d'|sed ''$c'!d' |cut -d: -f3`
	qtd_excluir[$c-1]=`echo ${diretorios_excluir[$c-1]} | sed 's/,/ /g' | wc -w`
done

# verifica dependências
test -x /usr/bin/rdiff-backup || echo -e "rdiff-backup não instalado no servidor. \nTente: sudo apt-get install rdiff-backup"
test -x /usr/bin/rdiff-backup || exit 0;
test -x /usr/bin/mail || echo -e "mailutils não instalado no servidor. \nTente: sudo apt-get install mailutils"
test -x /usr/bin/mail || exit 0;

logger "rdiff_backup: Inicio do backup."

# data de inicio do backup
data=`date "+%d %B %Y"`

for (( i=0; i < ${#diretorios_backup[@]}; i++ ))
do
	# verifica as pastas que devem ser omitidas no backup do diretorio atual
        for (( c=1; c <= ${qtd_excluir[$i]}; c++ ))
        do
                exclui=`echo ${diretorios_excluir[$i]} | cut -d, -f$c`
                exclude="$exclude --exclude ${diretorios_backup[$i]}/$exclui"
        done

        logger "rdiff_backup_home: Supressão dos backups antigos do diretório ${diretorios_backup[$i]} em ${host[$i]} (>$dias dias)"
        incrementos= /usr/bin/rdiff-backup --remove-older-than "$dias"D --force $destino${host[$i]}${diretorios_backup[$i]}
        logger "rdiff_backup_home: Supressão dos backups antigos do diretório ${diretorios_backup[$i]} em ${host[$i]}  completa"

        logger "rdiff_backup_home: Backup do diretório ${diretorios_backup[$i]} em ${host[$i]} }"

	mkdir -p $destino${host[$i]}${diretorios_backup[$i]}

	ips_locais=(`ifconfig|grep "inet end"|cut -d: -f2|cut -d" " -f2`)
	qtd_ips=`ifconfig|grep "inet end"|cut -d: -f2|cut -d" " -f2|wc -l`
	qtd_ips=$((qtd_ips-1))
	# verifica se o host de backup é local ou remoto
	for (( c=0; c < ${#ips_locais[@]}; c++ ))
	do
		if [ ${ips_locais[$c]} == ${host[$i]} ]
		then
			backup="$backup\n\nHost: ${host[$i]}\nDiretório: ${diretorios_backup[$i]}$incrementos\n`/usr/bin/rdiff-backup --force --print-statistics$exclude ${diretorios_backup[$i]} $destino${host[$i]}${diretorios_backup[$i]} 2>/dev/null`"
			c=${#ips_locais[@]}
		elif [ $c -eq $qtd_ips ]
		then
			backup="$backup\n\nHost: ${host[$i]}\nDiretório: ${diretorios_backup[$i]}$incrementos\n`/usr/bin/rdiff-backup --force --print-statistics$exclude ${usuario[$i]}@${host[$i]}::${diretorios_backup[$i]} $destino${host[$i]}${diretorios_backup[$i]} 2>/dev/null`"
		fi
	done
        logger "rdiff_backup_home: Backup do diretório ${diretorios_backup[$i]} em ${host[$i]} completo"

        exclude=""
done
# envia relatório via email
echo -e "Hostname: `hostname`\nOrg: $org\nData: $data\n$backup" | mail -s "$org RDIFF-BACKUP REPORT FOR $data" $mail
# salva relatório no log
if [ $log == true ]
then
	echo -e "Hostname: `hostname`\nOrg: $org\nData: $data\n$backup" >> /var/log/rdiff.log
fi
        logger "rdiff_backup: Fim do backup."

