#!/bin/bash

## Variables
DEBUG=1
EDP_phone="XXXXXXXXXX"
bot_token="bot-TOKEN"
bot_chat_id="XXXXXXXXX"
sleep=50
date=$(date +%d.%m.%Y)
time=$(date +%H.%M.%S)
path="/root/GOIP-PHP"
exportpath="/home/user/SHARE"
file=$(ls $exportpath/Export_du_$date*)

if [ $DEBUG == 1 ]; then
	echo
	echo "EDP Phone    : "$EDP_phone
	echo "Date du jour : "$date
	echo
fi

## Test fichier export
if [ -z "$file" ]; then
	echo "PROBLEME AVEC FICHIER EXPORT"
	echo
	message="SMS : PROBLEME AVEC FICHIER EXPORT"
	wget "https://api.telegram.org/$bot_token/sendMessage?chat_id=$bot_chat_id&text=$message" > /dev/null 2>&1
	exit 1
fi

clear
echo
echo "Fichier de travail : "$file
echo

starttime=$time

## CLEAN
rm -rf export.csv
rm -rf log.$date

## Conversion
/usr/bin/iconv -f ISO-8859-1 -t UTF-8 $file -o export.csv

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
				OUTPUT="$(echo send.php $mobile "$text")"
				echo $time $pdl $mobile $OUTPUT >> log.$date
#               sleep $sleep
			else
				if [ $DEBUG != 0 ]; then
					echo "PDL : "$pdl" -- NUMERO NON GSM --- CAS 1"
                fi
                if [ $DEBUG == 2 ]; then
					echo " -- NUMERO NON GSM -- "
					echo
                fi
				echo $time $pdl "NON GSM" >> log.$date
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
				OUTPUT="$(echo send.php $mobile2 "$text")"
				echo $time $pdl $mobile2 $OUTPUT >> log.$date
#               sleep $sleep
			else
				if [ $DEBUG != 0 ]; then
					echo "PDL : "$pdl" -- NUMERO NON GSM --- CAS 2"
                fi
                if [ $DEBUG == 2 ]; then
					echo " -- NUMERO NON GSM -- "
					echo
                fi
					echo $time $pdl "NON GSM" >> log.$date
			fi

		################################# Test si numero GSM1 OK et GSM2 OK
        elif [ -n "$mobile" ] && [ -n "$mobile2" ]; then
			########### TEST si GSM1 et GSM2 sont identiques
			if [ "$mobile" == "$mobile2" ]; then
				if [ ${mobile:0:2} == '06' ] || [ ${mobile:0:2} == '07' ]; then
					if [ $DEBUG != 0 ]; then
						echo "PDL : "$pdl" -- Créneau horaire : "$heure" -- GSM : "$mobile" --- CAS 3.1"
					fi
					if [ $DEBUG == 2 ]; then
						echo $mobile "$text"
						echo
					fi
					## SEND SMS sur GSM1
					OUTPUT="$(echo send.php $mobile "$text")"
					echo $time $pdl $mobile $OUTPUT >> log.$date
#          			sleep $sleep
				else
					if [ $DEBUG != 0 ]; then
						echo "PDL : "$pdl" -- NUMERO NON GSM --- CAS 3.1"
					fi
					if [ $DEBUG == 2 ]; then
						echo " -- NUMERO NON GSM -- "
						echo
					fi
					echo $time $pdl "NON GSM" >> log.$date
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
					OUTPUT="$(echo send.php $mobile "$text")"
					echo $time $pdl $mobile $OUTPUT >> log.$date
#               	sleep $sleep
				else
					if [ $DEBUG != 0 ]; then
						echo "PDL : "$pdl" -- NUMERO 1 NON GSM --- CAS 3.2"
					fi
					if [ $DEBUG == 2 ]; then
						echo " -- NUMERO 1 NON GSM -- "
						echo
					fi
					echo $time $pdl "NON GSM" >> log.$date
				fi
				## CHECK si numero fourni est bien un GSM pour GSM2
				if [ ${mobile2:0:2} == '06' ] || [ ${mobile2:0:2} == '07' ]; then
					OUTPUT="$(echo send.php $mobile2 "$text")"
					echo $time $pdl $mobile2 $OUTPUT >> log.$date
#      				sleep $sleep
				else
					if [ $DEBUG != 0 ]; then
						echo "PDL : "$pdl" -- NUMERO 2 NON GSM --- CAS 3.2"
					fi
					if [ $DEBUG == 2 ]; then
						echo " -- NUMERO 2 NON GSM -- "
						echo
					fi
					echo $time $pdl "NON GSM" >> log.$date
				fi
			fi

		## Test si GSM KO et GSM2 KO
        ## client sans numero de GSM du tout
        elif [ -z "$mobile" ] && [ -z "$mobile2" ]; then
            if [ $DEBUG != 0 ]; then
                echo "PDL : "$pdl" -- Créneau horaire : "$heure" -- PAS DE GSM --- CAS 4"
                echo
            fi
            echo "PDL sans GSM :"$pdl
            echo $time $pdl "==PDL SANS GSM=="  >> log.$date

        ## Tout autre cas
        else
			echo "ERREUR"
			echo $time $pdl "==ERREUR=="  >> log.$date
        fi

    ##fi du test si PDL = premiere ligne
    fi

}
done

endtime=$time

## Deplace le fichier LOG dans le partage accessible par les planifs
mv log.$date $exportpath/log.$date.$time.txt

## Count line number in log file
lines=$(wc -l < $exportpath/log.$date.$time.txt)
if [ $DEBUG != 0 ]; then
	echo
	echo "Lignes : "$lines
	echo
	echo "==================================="
	echo "  Légende   : "
	echo "   CAS n°1	: GSM1 OK && GSM2 KO"
	echo "   CAS n°2	: GSM1 KO && GSM2 OK"
	echo "   CAS n°3.1	: GSM1 OK == GSM2 OK"
	echo "   CAS n°3.2	: GSM1 OK != GSM2 OK"
	echo "   CAS n°4	: GSM1 KO && GSM2 KO"
	echo "==================================="
	echo
fi


## Send Telegram message
message="Routine d'envoi des SMS Ok !"
wget "https://api.telegram.org/$bot_token/sendMessage?chat_id=$bot_chat_id&text=$message" > /dev/null 2>&1

message="Start : $starttime."
wget "https://api.telegram.org/$bot_token/sendMessage?chat_id=$bot_chat_id&text=$message" > /dev/null 2>&1

message="End : $endtime."
wget "https://api.telegram.org/$bot_token/sendMessage?chat_id=$bot_chat_id&text=$message" > /dev/null 2>&1

message="Nombre de lignes dans Log : $lines"
wget "https://api.telegram.org/$bot_token/sendMessage?chat_id=$bot_chat_id&text=$message" > /dev/null 2>&1

exit 0
