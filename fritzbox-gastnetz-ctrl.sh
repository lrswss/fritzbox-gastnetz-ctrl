#!/bin/bash
#
# Skript zum einfachen Steuern und Konfigurieren des Gast-Netzes
# einer FRITZ!Box per Kommandozeile (Version 1.0)
# Download unter: https://github.com/lrswss/fritzbox-gast-ctrl
#
# (c) 2021 Lars Wessels <software@bytebox.org>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject
# to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND  NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY,# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

# Hier Benutzer und Passwort für den Zugriff auf die FRITZ!Box setzen.
# Der eingestellte Benutzer benötigt Rechte für 'FRITZ!Box Einstellungen'
USERNAME="fritzbox"
PASSWORD="xxxxxxxx"

# Adresse der FRITZ!Box muss i.d.R. nicht geänder, TR64 auf Port 49000
FB_IP_PORT="fritz.box:49000"

# Zuerst prüfen, ob curl installiert ist.
CURL=`which curl`
if [ -z "$CURL" ]; then
	echo "Bitte 'curl' installieren!"
	exit 1
fi

# Kommandos können aus groß geschrieben werden
if [ $# != 0 ]; then
	CMD=`echo $1 | tr /A-Z/ /a-z/`
fi

# Kommandozeile auswerten
if [ $# == 0 ] || [ "$CMD" != "an" -a "$CMD" != "aus" -a "$CMD" != "info" \
	-a "$CMD" != "passwort" -a "$CMD" != "clients" -a "$CMD" != "ssid" ]; then
	echo "Aufruf: $0 <an|aus|info|clients|passwort|ssid>"
	exit 1
fi

# TR-064 aktiviert?
SOAPINFO=$($CURL -s http://fritz.box:49000/tr64desc.xml)
if [ -n "$(echo $SOAPINFO | grep ERR_NOT_FOUND)" ]; then
	echo "Bitte zuerst TR64-Schnittstelle in der FRITZ!Box aktivieren!"
	echo "Heimnetz > Netwerk > Netwerkeinstellungen > Weiter Einstellungen > Zugriff für Anwendungen zulassen".
	exit 1
fi

# einfache Funktion zum Parsen des XML DOM
# https://stackoverflow.com/questions/893585/how-to-parse-xml-in-bash
read_xml() { local IFS=\> ; read -d \< TAG CONTENT ;}

# FRITZ!Box Model und Firmware-Version auslesen
while read_xml; do
	if [ "$TAG" = "Minor" ]; then
		MINOR=$CONTENT
	elif [ "$TAG" = "Patch" ]; then
		PATCH=$CONTENT
	elif [ "$TAG" = "modelDescription" -a -z "$FBNAME" ]; then
		FBNAME=$(echo $CONTENT | awk '{ printf "%s %s", $1, $2 }')
	fi
done <<< $(echo $SOAPINFO)
FW_VERSION="$MINOR.$PATCH"

# SSID und aktuellen Kanal des Gast-Netzes per SOAP abfragen
RES=$($CURL -s -k --anyauth -u "${USERNAME}:${PASSWORD}" \
	http://${FB_IP_PORT}/upnp/control/wlanconfig3 \
	-H 'Content-Type: text/xml; charset="utf-8"' \
	-H 'SoapAction: urn:dslforum-org:service:WLANConfiguration:3#GetInfo' \
	-d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
			<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"
				xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">
			<s:Body>
				<u:GetInfo xmlns:u=\"urn:dslforum-org:service:WLANConfiguration:3\">
               </u:GetInfo>
			</s:Body>
		</s:Envelope>")

if [ -n "$(echo $RES | grep Unauthorized)" ]; then
	echo "Anmeldung an der FRITZ!Box fehlgeschlagen! Bitte sicherstellen, dass sich"
	echo "die Benutzerkennung '$USERNAME' mit dem Passwort '$PASSWORD' an der FRITZ!Box"
	echo "anmelden kann und die Berechtigung 'FRITZ!Box Einstellungen' hat."
	exit 1
fi

# Einige Werte aus der XML-Antworten parsen
while read_xml; do
	if [ "$TAG" = "NewSSID" ]; then
		SSID=$CONTENT
	elif [ "$TAG" = "NewChannel" ]; then
		CHANNEL=$CONTENT
	elif [ "$TAG" = "NewEnable" ]; then
		ENABLED=$CONTENT
	fi 
done <<< $(echo $RES)

# aktuelles Passwort für Gast-Netz auslesen
RES=$($CURL -s -k --anyauth -u "${USERNAME}:${PASSWORD}" \
	http://${FB_IP_PORT}/upnp/control/wlanconfig3 \
	-H 'Content-Type: text/xml; charset="utf-8"' \
	-H 'SoapAction: urn:dslforum-org:service:WLANConfiguration:3#GetSecurityKeys' \
	-d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
			<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"
				xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">
			<s:Body>
				<u:GetSecurityKeys xmlns:u=\"urn:dslforum-org:service:WLANConfiguration:3\">
               </u:GetSecurityKeys>
			</s:Body>
		</s:Envelope>")

# alle Werte für ggf. späteteres Setzen
# eines neues WPA-Schlüssels merken...
while read_xml; do
	if [ "$TAG" = "NewWEPKey0" ]; then
		WEBKEY0=$CONTENT
	elif [ "$TAG" = "NewWEPKey1" ]; then
		WEBKEY1=$CONTENT
	elif [ "$TAG" = "NewWEPKey2" ]; then
		WEBKEY2=$CONTENT
	elif [ "$TAG" = "NewWEPKey3" ]; then
		WEBKEY3=$CONTENT
	elif [ "$TAG" = "NewPreSharedKey" ]; then
		PREKEY=$CONTENT
	elif [ "$TAG" = "NewKeyPassphrase" ]; then
		WPAKEY=$CONTENT
	fi 
done <<< $(echo $RES)


# Kurzinfo zum Gast-Netz bei Kommando 'info' ausgeben
if [ "$CMD" = "info" ]; then
	echo -n "Das Gast-Netz auf der $FBNAME (FW $FW_VERSION) ist "
	[ $ENABLED = 1 ] && echo "aktviert."
	[ $ENABLED = 0 ] && echo "deaktiviert."
	echo "Netzwerkname: $SSID (auf Kanal $CHANNEL)"
	echo "WPA-Passwort: $WPAKEY"
	exit 0
fi


# Gast-Netz ein/auschalten
if [ "$CMD" = "an" -o "$CMD" = "aus" ]; then
	if [ "$CMD" = "an" ]; then
		echo -n "Gast-Netz '$SSID' wird eingeschalten..."
		ENABLE=true
	else
		echo -n "Gast-Netz '$SSID' wird abgeschaltet..."
		ENABLE=false
	fi
	RES=$($CURL -s -k --anyauth -u "${USERNAME}:${PASSWORD}" \
		http://${FB_IP_PORT}/upnp/control/wlanconfig3 \
		-H 'Content-Type: text/xml; charset="utf-8"' \
		-H 'SoapAction: urn:dslforum-org:service:WLANConfiguration:3#SetEnable' \
		-d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
			<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"
				xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">
				<s:Body>
					<u:SetEnable xmlns:u=\"urn:dslforum-org:service:WLANConfiguration:3\">
						<NewEnable>$ENABLE</NewEnable>
					</u:SetEnable>
				</s:Body>
			</s:Envelope>")

	if [ -n "$(echo $RES | grep errorCode)" ]; then
		echo "Fehler!"
	else
		echo "OK."
	fi
fi


# neue Netzwerkkennung (SSID) für das Gast-Netz einstellen
if [ "$CMD" = "ssid" ]; then
	if [ -z "$2" ]; then
		echo -n "Neue SSID eingeben: "
		read SSID
	else
		SSID=$2
	fi

	# Länge der SSID prüfen
	if [ ${#SSID} -lt 3 ]; then
		echo "Die neue SSID muss min. 3 Zeichen umfassen."
		exit 1
	elif [ ${#SSID} -gt 63 ]; then
		echo "Die neue SSID darf max. 63 Zeichen umfassen."
		exit 1
	fi

	echo -n "Setze neue Netwerkennung '$SSID'..."
	RES=$($CURL -s -k --anyauth -u "${USERNAME}:${PASSWORD}" \
		http://${FB_IP_PORT}/upnp/control/wlanconfig3 \
		-H 'Content-Type: text/xml; charset="utf-8"' \
		-H 'SoapAction: urn:dslforum-org:service:WLANConfiguration:3#SetSSID' \
		-d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
			<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"
				xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">
				<s:Body>
					<u:SetSSID xmlns:u=\"urn:dslforum-org:service:WLANConfiguration:3\">
						<NewSSID>$SSID</NewSSID>
					</u:SetSSID>
				</s:Body>
			</s:Envelope>")
	if [ -n "$(echo $RES | grep errorCode)" ]; then
		echo "Fehler!"
	else
		echo "OK."
	fi
fi


# neues WPA-Passwort per SOAP setzen
if [ "$CMD" = "passwort" ]; then
	echo "Neues WPA-Passwort für Gast-Netz '$SSID' setzen:"
	echo -n "Passwort eingebnen: "
	read -s PASS1
	echo
	echo -n "Wiederholen: "
	read -s PASS2
	echo

	if [ "$PASS1" != "$PASS2" ]; then
		echo "Die eingebenen Passwörter stimmen nicht überein!"
		exit
	fi

	# Länge des neuen Passworts prüfen (min. 8, max. 63 Zeichen)
	if [ ${#PASS1} -lt 8 ]; then
		echo "Der neue WPA-Schüssel muss min. 8 Zeichen umfassen."
		exit 1
	elif [ ${#PASS1} -gt 63 ]; then
		echo "Der neue WPA-Schüssel darf max. 63 Zeichen umfassen."
		exit 1
	fi

	echo -n "Setze neues Passwort..."
	RES=$($CURL -s -k --anyauth -u "${USERNAME}:${PASSWORD}" \
		http://${FB_IP_PORT}/upnp/control/wlanconfig3 \
		-H 'Content-Type: text/xml; charset="utf-8"' \
		-H 'SoapAction: urn:dslforum-org:service:WLANConfiguration:3#SetSecurityKeys' \
		-d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
			<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"
				xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">
				<s:Body>
					<u:SetSecurityKeys xmlns:u=\"urn:dslforum-org:service:WLANConfiguration:3\">
						<NewWEPKey0>$WEBKEY0</NewWEPKey0>
						<NewWEPKey1>$WEBKEY1</NewWEPKey1>
						<NewWEPKey2>$WEBKEY2</NewWEPKey2>
						<NewWEPKey3>$WEBKEY3</NewWEPKey3>
						<NewPreSharedKey>$PREKEY</NewPreSharedKey>
						<NewKeyPassphrase>$PASS1</NewKeyPassphrase>
					</u:SetSecurityKeys>
				</s:Body>
			</s:Envelope>")

	if [ -n "$(echo $RES | grep errorCode)" ]; then
		echo "Fehler!"
	else
		echo "OK."
	fi
fi


# Liste mit am Gast-Netz angemeldeten WLAN-Clients ausgeben
if [ "$CMD" = "clients" ]; then
	RES=$($CURL -s -k --anyauth -u "${USERNAME}:${PASSWORD}" \
		http://${FB_IP_PORT}/upnp/control/wlanconfig3 \
		-H 'Content-Type: text/xml; charset="utf-8"' \
		-H 'SoapAction: urn:dslforum-org:service:WLANConfiguration:3#GetTotalAssociations' \
		-d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
			<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"
				xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">
				<s:Body>
					<u:GetTotalAssociations xmlns:u=\"urn:dslforum-org:service:WLANConfiguration:3\">
					</u:GetTotalAssociations>
				</s:Body>
			</s:Envelope>")

	while read_xml; do
		if [ "$TAG" = "NewTotalAssociations" ]; then
			CLIENTS=$CONTENT
		fi
	done <<< $(echo $RES)

	if [ $ENABLED = 0 ]; then
		echo "Das Gast-Netz '$SSID' ist derzeit abgeschaltet."
		exit 0
	elif [ $CLIENTS -le 0 ]; then
		echo "Derzeit sind keine Geräte am Gast-Netz '$SSID' angemeldet."
		exit 0
	else 
		echo "Derzeit sind die folgenden Geräte am Gast-Netz '$SSID' angemeldet:"
	fi

	NUM=1
	while [ $NUM -le $CLIENTS ]; do
		RES=$($CURL -s -k --anyauth -u "${USERNAME}:${PASSWORD}" \
			http://${FB_IP_PORT}/upnp/control/wlanconfig3 \
			-H 'Content-Type: text/xml; charset="utf-8"' \
			-H 'SoapAction: urn:dslforum-org:service:WLANConfiguration:3#GetGenericAssociatedDeviceInfo' \
			-d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
				<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"
					xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">
					<s:Body>
						<u:GetGenericAssociatedDeviceInfo xmlns:u=\"urn:dslforum-org:service:WLANConfiguration:3\">
							<NewAssociatedDeviceIndex>$((CLIENTS-1))</NewAssociatedDeviceIndex>
						</u:GetGenericAssociatedDeviceInfo>
					</s:Body>
				</s:Envelope>")
		while read_xml; do
			if [ "$TAG" = "NewAssociatedDeviceMACAddress" ]; then
				MAC=$CONTENT
			elif [ "$TAG" = "NewAssociatedDeviceIPAddress" ]; then
				IP=$CONTENT
			elif [ "$TAG" = "NewX_AVM-DE_Speed" ]; then
				SPEED=$CONTENT
			fi
		done <<< $(echo $RES)

		# Namen des Geräts anhand der MAC abrufen
		RES_SUB=$($CURL -s -k --anyauth -u "${USERNAME}:${PASSWORD}" \
			http://${FB_IP_PORT}/upnp/control/hosts \
			-H 'Content-Type: text/xml; charset="utf-8"' \
			-H 'SoapAction: urn:dslforum-org:service:Hosts:1#GetSpecificHostEntry' \
			-d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
				<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"
					xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">
					<s:Body>
						<u:GetSpecificHostEntry xmlns:u=\"urn:dslforum-org:service:Hosts:1\">
							<NewMACAddress>$MAC</NewMACAddress>
						</u:GetSpecificHostEntry>
					</s:Body>
				</s:Envelope>")
		while read_xml; do
			if [ "$TAG" = "NewHostName" ]; then
				HOST=$CONTENT
			fi
		done <<< $(echo $RES_SUB)
		echo -e "($NUM) $HOST\t$IP ($MAC) mit $SPEED Mbit"
		NUM=$((NUM+1))
	done
fi

exit 0
