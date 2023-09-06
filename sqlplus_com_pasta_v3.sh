#script sqlplus_com_pasta_v3.sh
#Autor: Gilberto Oliveira
#Data: 07/07/2023
#
#Modificação
#Autor: Gilberto Oliveira
#Data: 25/08/2023
#Exclusão das quebras de linhas dos resultados do comando (SQL)
#
#
#OBJETIVO:
#O objetivo desse script é dividir o resultado de um comando sql em N arquivos JSON, 
#dentro de pasta propria com X linhas informadas pelo usuário (parametro 3)
#
#PRE-REQUISITO:
#O pacote CSVTOJSON deve estar intalado.
#npm install csvtojson
#
#SINTAXE:
#./sqlplus_com_pasta_v2.sh string_cnx arquivo_script tamanho
#onde:
#string_cnx = dados necessários (usuario/senha@instancia) para realizar a conexão com o BD
#arquivo_script = nome do arquivo que contem o comando sql
#tamanho = quantidade de linhas por arquivo (pagina)
#
#exemplo: 
#O comando abaixo executara o comando contido no <<arquivo.sql>> e
#dividira o resultado em N arquivos contendo até <<300>> linhas.
#Os arquivos resultantes serao salvos na pasta /tmp/<<arquivo>> 
#e nomeados com a mascara: 
#<<arquivo>>_xxxx.json, onde xxxx corresponde a ordem de divisao do resultado.
#
#comando:
#./sqlplus_com_pasta_v2.sh usuario/senha@xepdb1 scriptdeteste.sql 300
#
#resultado esperado é:
#a pasta /tmp/scriptdeteste
#e dentro dela o resultado dividido em N arquivos (com até 300 linhas) em formato JSON
#scriptdeteste_0000.json, scriptdeteste_0001.json, ...
#

#recupera somente o nome do script(sem extensao)
NOME=${2%.*}
CAMINHO=/tmp/$NOME

#cria a pasta do script
mkdir $CAMINHO

#verifica se o script informado existe
if [[ -f $2 ]]; then
  #cria log de tempo
  echo "inicio = "&date >$CAMINHO/$NOME.log
  #cria o arquivo que sera dividido
  touch $CAMINHO/$NOME.txt

  #comando para dividir o arquivo alvo

  #criacao do script de execucao
  echo "set mark csv ON;" >> $CAMINHO/$NOME"_tmp.sql"
  echo "set feedback off;" >> $CAMINHO/$NOME"_tmp.sql"
  echo "set sqlblanklines on;" >> $CAMINHO/$NOME"_tmp.sql"
  echo "set newpage none;" >> $CAMINHO/$NOME"_tmp.sql"
  echo spool $CAMINHO/$NOME.txt >> $CAMINHO/$NOME"_tmp.sql"
  #cat $2 >> $CAMINHO/$NOME"_tmp.sql"
  sed 's/select/select/gI' $2 | sed "/select/{ s/select/select 'sql>', /;:a;n;ba }" >> $CAMINHO/$NOME"_tmp.sql"
  echo "spool off;" >> $CAMINHO/$NOME"_tmp.sql"
  echo "exit;" >> $CAMINHO/$NOME"_tmp.sql"

  #chamada do script de execucao
  sqlplus -S $1 @$CAMINHO/$NOME"_tmp.sql"
  
  #tratamento das quebras de linhas contidas no registro
  #Importante: a regra de negócio imposta permite a simples remoção 
  #das quebras de linha contidas nos registros retornados.
  tr '\n' ' ' < $CAMINHO/$NOME.txt > $CAMINHO/$NOME"2".txt
  sed -i 's/"sql>",/\n/g' $CAMINHO/$NOME"2".txt
  sed -i "s/'SQL>'//g" $CAMINHO/$NOME"2".txt
  sed 's/"",/\n/g' $CAMINHO/$NOME"2".txt > $CAMINHO/$NOME.txt

  split $CAMINHO/$NOME.txt -d -a 4 -l $3 $CAMINHO/$NOME"_" &
 
  #retira a 1a linha do arquivo 0000
  sed -i 1d $CAMINHO/$NOME"_"0000
  
  #inclui o cabecalho (campos do select) em todos os arquivos
  #exceto do arquivo 0000
  for f in $CAMINHO/$NOME"_"*; do
    if [ $a ]
      then
       sed "1s/^/$(head -1 $CAMINHO/$NOME"_"0000)\n/" $f > $f".tmp"
      else
       cp $f $f.tmp
    fi
    a=1
  done
 
  #converte os arquivos para Json
  for f in $CAMINHO/$NOME"_"*.tmp; do
    csvtojson $f > ${f%.*}.json
  done

  #limpeza dos arquivos temporários
  rm $CAMINHO/*.txt
  rm $CAMINHO/*tmp.sql*
  rm $CAMINHO/*.tmp
  rm $CAMINHO/*[0-9][0-9][0-9][0-9]
else
  #mensagem de erro
  echo "O script não foi encontrado"
fi
#finaliza log de tempo
echo "fim = "&date >>$CAMINHO/$NOME.log
echo &date

