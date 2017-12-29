#!/bin/bash

## Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

## Variables
DEBUG=1
EDP_phone="xxxxxxxxxx"
bot_token="bot-token"
bot_chat_id="xxxxxxxxx"
sleep=50
date=$(date +%d.%m.%Y)
time=$(date +%H.%M.%S)
path="/root/GOIP-PHP"
exportpath="/home/user/SHARE"
file=$(ls $exportpath/Export_du_$date*)
localIP=$(hostname -I | cut -d " " -f 1)
keepalive_port=44444
keepalive_file="/tmp/keepalive"
sms_server_IP="192.168.0.10"
logfile="/tmp/process_log.$date.$time.txt"

## Functions
timestamp() {
  date +"%T"
}

starttime=$(timestamp)

## CLEAR SCREEN
clear
echo
echo "$(timestamp).Starting Script..." > $logfile
echo "$(timestamp).Starting Script..."
echo

if [ $DEBUG != 0 ]; then
        echo -e "${GREEN}"
        echo "EDP Phone    : "$EDP_phone
        echo "Date du jour : "$date
        echo "START TIME   : "$starttime
        echo -e "${NC}"
fi

## Test fichier export
if [ -z "$file" ]; then
        echo -e "${RED}PROBLEME AVEC FICHIER EXPORT${NC}"
        echo
	echo "PROBLEME AVEC FICHIER EXPORT !!" >> $logfile
        message="SMS : PROBLEME AVEC FICHIER EXPORT"
        wget "https://api.telegram.org/$bot_token/sendMessage?chat_id=$bot_chat_id&text=$message" > /dev/null 2>&1
        mv $logfile $exportpath/ ; exit 1
fi

## Test fichier send.php
if [ -f send.php ]; then
	echo "$(timestamp).File send.php found ! Ok..." >> $logfile
else
	echo -e "${RED}$(timestamp).File send.php NOT found ! ERROR !${NC}"
	echo "$(timestamp).File send.php NOT found ! ERROR !" >> $logfile
	mv $logfile $exportpath/ ; exit 2
fi

## Test fichier settings.php.goip
if [ -f settings.php.goip ]; then
	echo "$(timestamp).File settings.php.goip found ! Ok..." >> $logfile
else
	echo -e "${RED}$(timestamp).File settings.php.goip NOT found ! ERROR !${NC}"
	echo "$(timestamp).File settings.php.goip NOT found ! ERROR !" >> $logfile
	mv $logfile $exportpath/ ; exit 3
fi

echo
echo "Fichier de travail : "$file
echo "$(timestamp).Fichier de travail : "$file >> $logfile
echo

## CLEAN
rm -rf export.csv
rm -rf log.$date

## Conversion
/usr/bin/iconv -f ISO-8859-1 -t UTF-8 $file -o export.csv

## KEEPALIVE
echo
echo "$(timestamp).Starting keepalive.php... please wait 30 seconds"
echo "$(timestamp).Starting keepalive.php... sleep 30 seconds" >> $logfile
echo
php keepalive.php $localIP $keepalive_port > $keepalive_file &
sleep 30
echo
echo "$(timestamp).keepalive done !"
echo "$(timestamp).Keepalive done !" >> $logfile
echo

## catch SMS Server port
sms_new_port=$(cat $keepalive_file | grep port | cut -d ";" -f 20 | cut -d " " -f 9 | head -1)
echo "$(timestamp).SMS Server Port : $sms_new_port" >> $logfile

## edit settings.php for port
rm -rf settings.php
cp settings.php.goip settings.php
sed -i "s|YYYY|${sms_server_IP}|" settings.php
if [ "$?" == "0" ]; then
	echo -e "${GREEN}"
	echo "SMS Server IP replacement OK !"
	echo -e "${NC}"
	echo "$(timestamp).SMS Server IP replacement OK !" >> $logfile
else
	echo -e "${RED}"
	echo "ERROR ! CAN'T REPLACE YYYY in settings.php"
	echo -e "${NC}"
	echo "$(timestamp).ERROR ! CAN'T REPLACE YYYY in settings.php" >> $logfile
	mv $logfile $exportpath/ ; exit 4
fi

sed -i "s|XXXX|${sms_new_port}|" settings.php
if [ "$?" == "0" ]; then
	echo -e "${GREEN}"
	echo "SMS Server Port replacement OK !"
	echo -e "${NC}"
	echo "$(timestamp).SMS Server Port replacement OK !" >> $logfile
else
	echo -e "${RED}"
	echo "ERROR ! CAN'T REPLACE XXXX in settings.php"
	echo -e "${NC}"
	echo "$(timestamp).ERROR ! CAN'T REPLACE XXXX in settings.php" >> $logfile
	mv $logfile $exportpath/ ; exit 5
fi

echo
echo "$(timestamp).Starting Process..." >> $logfile
echo "$(timestamp).Starting Process..."
echo

## affiche et traite chaque ligne du fichier export.csv
cat export.csv | while read -r a;
do {
        pdl=$(echo $a | cut -d ";" -f 1)
        heure=$(echo $a | cut -d ";" -f 3)
        mobile=$(echo $a | cut -d ";" -f 5)
        mobile2=$(echo $a | cut -d ";" -f 8)
        text="Bonjour ! Nous vous rappelons votre RDV de ce jour. Créneau de passage : de $heure. En cas d'empechement ou pour plus d'info, merci de contacter le $EDP_phone"

        ## SKIP FIRST LINE
        if [ "$pdl" != "Identifiant du PDL" ]; then
		if [ "$heure" != "null à null" ]; then
			################################# Test si numero GSM1 OK et GSM2 KO
                	if [ -n "$mobile" ] && [ -z "$mobile2" ]; then
                        	## CHECK si numero fourni est bien un GSM
                        	if [ ${mobile:0:2} == '06' ] || [ ${mobile:0:2} == '07' ]; then
                                if [ $DEBUG != 0 ]; then
                                        echo "PDL : "$pdl" -- Créneau horaire : "$heure" -- GSM1 : "$mobile" --- CAS 1"
                                fi
                                if [ $DEBUG == 2 ]; then
                                        echo $mobile "$text"
                                        echo
                                fi

                                ## SEND SMS sur GSM1
                                OUTPUT="$(php send.php $mobile "$text")"
                                echo $(timestamp) $pdl $mobile $OUTPUT >> log.$date
                                sleep $sleep
                        else
                                if [ $DEBUG != 0 ]; then
                                        echo "PDL : "$pdl" -- NUMERO NON GSM --- CAS 1"
                                fi
                                if [ $DEBUG == 2 ]; then
                                        echo " -- NUMERO NON GSM -- "
                                        echo
                                fi
                                echo $(timestamp) $pdl "NON GSM" >> log.$date
                        fi

                ################################# Test si numero GSM1 KO et GSM2 OK
                elif [ -z "$mobile" ] && [ -n "$mobile2" ]; then
                        ## CHECK si numero fourni est bien un GSM
                        if [ ${mobile2:0:2} == '06' ] || [ ${mobile2:0:2} == '07' ]; then
                                if [ $DEBUG != 0 ]; then
                                        echo "PDL : "$pdl" -- Créneau horaire : "$heure" -- GSM2 : "$mobile2" --- CAS 2"
                                fi
                                if [ $DEBUG == 2 ]; then
                                        echo $mobile2 "$text"
                                        echo
                                fi
                                ## SEND SMS sur GSM2
                                OUTPUT="$(php send.php $mobile2 "$text")"
                                echo $(timestamp) $pdl $mobile2 $OUTPUT >> log.$date
                                sleep $sleep
                        else
                                if [ $DEBUG != 0 ]; then
                                        echo "PDL : "$pdl" -- NUMERO NON GSM --- CAS 2"
                                fi
                                if [ $DEBUG == 2 ]; then
                                        echo " -- NUMERO NON GSM -- "
                                        echo
                                fi
                                echo $(timestamp) $pdl "NON GSM" >> log.$date
                        fi

                ################################# Test si numero GSM1 OK et GSM2 OK
                elif [ -n "$mobile" ] && [ -n "$mobile2" ]; then
                        ########### TEST si GSM1 et GSM2 sont identiques
                        if [ "$mobile" == "$mobile2" ]; then
                                if [ ${mobile:0:2} == '06' ] || [ ${mobile:0:2} == '07' ]; then
                                        if [ $DEBUG != 0 ]; then
                                                echo "PDL : "$pdl" -- Créneau horaire : "$heure" -- GSM  : "$mobile" --- CAS 3.1"
                                        fi
                                        if [ $DEBUG == 2 ]; then
                                                echo $mobile "$text"
                                                echo
                                        fi
                                        ## SEND SMS sur GSM1
                                        OUTPUT="$(php send.php $mobile "$text")"
                                        echo $(timestamp) $pdl $mobile $OUTPUT >> log.$date
                                        sleep $sleep
                                else
                                        if [ $DEBUG != 0 ]; then
                                                echo "PDL : "$pdl" -- NUMERO NON GSM --- CAS 3.1"
                                        fi
                                        if [ $DEBUG == 2 ]; then
                                                echo " -- NUMERO NON GSM -- "
                                                echo
                                        fi
                                        echo $(timestamp) $pdl "NON GSM" >> log.$date
                                fi

                        ########### TEST si GSM1 et GSM2 sont differents
                        else
                                if [ $DEBUG != 0 ]; then
                                        echo "PDL : "$pdl" -- Créneau horaire : "$heure" -- GSM1 : "$mobile" -- GSM2 : "$mobile2" --- CAS 3.2"
                                fi
                                if [ $DEBUG == 2 ]; then
                                        echo $mobile "$text"
                                        echo $mobile2 "$text"
                                        echo
                                fi
                                ## SEND SMS sur GSM1 et sur GSM2
                                ## CHECK si numero fourni est bien un GSM pour GSM1
                                if [ ${mobile:0:2} == '06' ] || [ ${mobile:0:2} == '07' ]; then
                                        OUTPUT="$(php send.php $mobile "$text")"
                                        echo $(timestamp) $pdl $mobile $OUTPUT >> log.$date
                                        sleep $sleep
                                else
                                        if [ $DEBUG != 0 ]; then
                                                echo "PDL : "$pdl" -- NUMERO 1 NON GSM --- CAS 3.2"
                                        fi
                                        if [ $DEBUG == 2 ]; then
                                                echo " -- NUMERO 1 NON GSM -- "
                                                echo
                                        fi
                                        echo $(timestamp) $pdl "NON GSM" >> log.$date
                                fi
                                ## CHECK si numero fourni est bien un GSM pour GSM2
                                if [ ${mobile2:0:2} == '06' ] || [ ${mobile2:0:2} == '07' ]; then
                                        OUTPUT="$(php send.php $mobile2 "$text")"
                                        echo $(timestamp) $pdl $mobile2 $OUTPUT >> log.$date
                                sleep $sleep
                                else
                                        if [ $DEBUG != 0 ]; then
                                                echo "PDL : "$pdl" -- NUMERO 2 NON GSM --- CAS 3.2"
                                        fi
                                        if [ $DEBUG == 2 ]; then
                                                echo " -- NUMERO 2 NON GSM -- "
                                                echo
                                        fi
                                        echo $(timestamp) $pdl "NON GSM" >> log.$date
                                fi
                        fi

                ## Test si GSM KO et GSM2 KO
                ## client sans numero de GSM du tout
                elif [ -z "$mobile" ] && [ -z "$mobile2" ]; then
                        if [ $DEBUG != 0 ]; then
                                echo "PDL : "$pdl" -- Créneau horaire : "$heure" -- PAS DE GSM --- CAS 4"
                        fi
                echo -e "${RED}PDL sans GSM : "$pdl"${NC}"
                echo $(timestamp) $pdl "==PDL SANS GSM=="  >> log.$date

                ## Tout autre cas
                else
                        echo "ERREUR"
                        echo $(timestamp) $pdl "==ERREUR=="  >> log.$date
                fi
			fi 
        ##fi du test si PDL = premiere ligne
        fi

}
done

endtime=$(timestamp)

echo "$(timestamp).Process Done !" >> $logfile
echo
echo -e "${GREEN}$(timestamp).Process Done !${NC}"


## Deplace le fichier LOG dans le partage accessible par les gens
mv log.$date $exportpath/log.$date.$time.txt

## Count line number in log file
lines=$(wc -l < $exportpath/log.$date.$time.txt)
if [ $DEBUG != 0 ]; then
        echo -e "${GREEN}"
        echo "Nombre de lignes : "$lines
        echo -e "${NC}"
        echo "========================================"
        echo "  Légende   : "
        echo "   CAS n°1        : GSM1 OK && GSM2 KO"
        echo "   CAS n°2        : GSM1 KO && GSM2 OK"
        echo "   CAS n°3.1      : GSM1 OK == GSM2 OK"
        echo "   CAS n°3.2      : GSM1 OK != GSM2 OK"
        echo "   CAS n°4        : GSM1 KO && GSM2 KO"
        echo "========================================"
        echo
fi

## Send Telegram message
message=$(echo "🔥 Routine d'envoi des SMS Ok !🔥 \nDate : $date\nStart : $starttime\nEnd : $endtime\nNombre de lignes dans Log : $lines" | sed 's:\\n:\n:g')
wget "https://api.telegram.org/$bot_token/sendMessage?chat_id=$bot_chat_id&text=$message" > /dev/null 2>&1

## SHOW ENDTIME
if [ $DEBUG != 0 ]; then
        echo -e "${GREEN}"
        echo "END TIME     : "$endtime
        echo -e "${NC}"
fi

## kill keepalive
echo
echo "$(timestamp).Killing KEEPALIVE..." >> $logfile
echo "$(timestamp).Killing KEEPALIVE..."
echo
keepalive_pid=$(ps -fu $USER | grep keepalive | grep -v grep | awk '{print $2}')
kill $keepalive_pid
if [ "$?" == "0" ]; then
	if [ $DEBUG != 0 ]; then echo "Error status : "$?; echo; fi
	echo -e "${GREEN}"
	echo "Kill KEEPALIVE Ok !"
	echo -e "${NC}"
	echo "$(timestamp).Kill KEEPALIVE Ok !" >> $logfile
else
	if [ $DEBUG != 0 ]; then echo "Error status : "$?; echo; fi
	echo -e "${RED}"
	echo "ERREUR lors du Kill du KEEPALIVE !"
	echo -e "${NC}"
	echo "$(timestamp).ERREUR lors du Kill du KEEPALIVE !" >> $logfile
fi

mv $keepalive_file $exportpath/keepalive.$date.$time.txt > /dev/null 2>&1

## END
mv $logfile $exportpath/
rm -rf sendMessage\?chat_id\=*

exit 0
