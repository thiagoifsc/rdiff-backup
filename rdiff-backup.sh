#!/bin/bash
# Script de automatizacao do rdiff-backup
# Thiago Felipe da Cunha

# data de inicio do backup
data=`date "+%d %B %Y"`

# verifica o arquivo de configuracao a ser usado
local=`echo $0 | awk -F'/' '{for (i=1; i<NF; i++) printf("%s/", $i)}'`
if [ $1 ]
then
	disklist=$1
else
	disklist=${local}"disklist"
fi
logger "rdiff_backup: Lendo arquivo de discos para backup: $disklist"

# verifica quantidade de dias de manutencao do backup incremental
if [ $2 ]
then
        dias=$2
else
        dias=`cat ${local}rdiff-backup.conf|grep dias=|cut -d\" -f2`
fi
logger "rdiff_backup: Dias para manutencao do backup incremental: $dias"

# organização
org=`cat ${local}rdiff-backup.conf|grep org=|cut -d\" -f2`
# emails para onde seram enviados os relatórios
mail=`cat ${local}rdiff-backup.conf|grep mail=|cut -d\" -f2|cut -d\" -f1|sed 's/ //g'`
# habilita/desabilita o log
log=`cat ${local}rdiff-backup.conf|grep log=|cut -d\= -f2`
# pasta onde o backup deve ser salvo
destino=`cat ${local}rdiff-backup.conf|grep destino=|cut -d\" -f2`

# verifica se ha alguma instancia do rdiff-backup rodando
verifica_instancia=`ps a | grep "/bin/bash" | grep "rdiff-backup.sh" | wc -l`
if [ $verifica_instancia -gt 2 ]
then
        logger "rdiff_backup: Abortando, outra instancia do rdiff_backup rodando"
        echo -e "Hostname: `hostname`\nOrg: $org\nData: $data\nExiste outra instancia do rdiff-backup rodando.. backup abortado" | mail -s "$org RDIFF-BACKUP ERROR FOR $data" $mail
        exit 0
else
	logger "rdiff_backup: Ok, nenhuma outra instancia rodando, \$verifica_instancia=$verifica_instancia"
fi

discos=`cat $disklist | sed '/^\( *$\| *#\)/d'| wc -l`
for (( c=1; c <= $discos; c++ ))
do
	disk_host=`cat $disklist | sed '/^\( *$\| *#\)/d'|sed ''$c'!d' |cut -d: -f1`
	host[$c-1]=`ping $disk_host -c1|grep PING|cut -d" " -f3|sed 's/(\|)//g'`
        diretorios_backup[$c-1]=`cat $disklist | sed '/^\( *$\| *#\)/d'|sed ''$c'!d' |cut -d: -f2`
	usuario[$c-1]=`cat $disklist | sed '/^\( *$\| *#\)/d'|sed ''$c'!d' |cut -d: -f4`
	diretorios_excluir[$c-1]=`cat $disklist | sed '/^\( *$\| *#\)/d'|sed ''$c'!d' |cut -d: -f3`
	qtd_excluir[$c-1]=`echo ${diretorios_excluir[$c-1]} | sed 's/,/ /g' | wc -w`
done

# verifica dependências
test -x /usr/bin/rdiff-backup || echo -e "rdiff-backup não instalado no servidor. \nTente: sudo apt-get install rdiff-backup"
test -x /usr/bin/rdiff-backup || exit 0;
test -x /usr/bin/mail || echo -e "mailutils não instalado no servidor. \nTente: sudo apt-get install mailutils"
test -x /usr/bin/mail || exit 0;

logger "rdiff_backup: Inicio do backup."

for (( i=0; i < ${#diretorios_backup[@]}; i++ ))
do
	# verifica as pastas que devem ser omitidas no backup do diretorio atual
        for (( c=1; c <= ${qtd_excluir[$i]}; c++ ))
        do
                exclui=`echo ${diretorios_excluir[$i]} | cut -d, -f$c`
                exclude="$exclude --exclude ${diretorios_backup[$i]}/$exclui"
        done

        logger "rdiff_backup: Supressão dos backups antigos do diretório ${diretorios_backup[$i]} em ${host[$i]} (>$dias dias)"
        incrementos= /usr/bin/rdiff-backup --remove-older-than "$dias"D --force $destino${host[$i]}${diretorios_backup[$i]}
        logger "rdiff_backup: Supressão dos backups antigos do diretório ${diretorios_backup[$i]} em ${host[$i]}  completa"

        logger "rdiff_backup: Backup do diretório ${diretorios_backup[$i]} em ${host[$i]} }"

	mkdir -p $destino${host[$i]}${diretorios_backup[$i]}

	ips_locais=(`/sbin/ifconfig|grep "inet end"|cut -d: -f2|cut -d" " -f2`)
	qtd_ips=`/sbin/ifconfig|grep "inet end"|cut -d: -f2|cut -d" " -f2|wc -l`
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
        logger "rdiff_backup: Backup do diretório ${diretorios_backup[$i]} em ${host[$i]} completo"

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

