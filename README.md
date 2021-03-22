## Shell-Skript zum Steuern/Konfigurieren des Gast-Netzes einer FRITZ!Box

Da ich auf der Suche nach einem passenden Shell-Skript zum Steuern (an/aus)
bzw. rudimentären Konfigurieren des Gast-Netzes einer FRITZ!Box (habe selber eine
7490) nicht direkt fündig geworden bin, habe ich mir selbst eines auf Basis der
unter ``http://fritz.box:49000/tr64desc.xml`` abrufbaren SOAP-Schnittellenbeschreibung
für TR-064 zusammengebaut. Aus dem ursprünglich geplanten An/Aus-Skript ist dann
schließlich doch mehr geworden. ;-)

Bitte sicherstellen, dass TR-064 in eurer FRITZ!Box aktiviert ist. Die Option ist
etwas versteckt zu finden unter "Heimnetz" > "Netzwerk" > "Netzwerkeinstellungen" >
"Weitere Einstellungen" > "Zugriff für Anwendungen zulassen". Zudem bitte für 
das Skript unter "System" > "FRITZ!Box-Benutzer" vorzugsweise einen eigenen Nutzer
einrichten, der die Berechtigung "FRITZ!Box Einstellungen" hat. Die neu erstellte
Kennung und das hoffentlich sichere Passwort als ``USERNAME`` und ``PASSWORD``
zu Beginn des Skript eintragen.

Da Nutzer und Passwort im Klartext im Skript hinterlegt sind, solltes es auf
einem mit mehreren Nutzern geteilten System geschützt oder nur für bestimmte 
Nutzer oder Gruppen aufrufbar abgelegt werden (siehe ``chmod`` oder ``chown``).

Mit dem Kommando ``an`` bzw. ``aus`` wird das Gast-Netz ein- bzw. ausgeschaltet.
Eine Kurzinfo zum Gast-Netz mit SSID, Kanal und WPA-Schlüssel erhält man mit
``info``. Der WPA-Schlüssel kann mit ``passwort``und der Name der SSID mit
dem Befehl ``ssid`` interaktiv geändert werden. Mit ``clients`` kann man sich
eine Liste der derzeit am Gast-Netz angemeldeten Geräte ausgeben lassen.

Für Fehler und Änderungswünsche bitte wie üblich einen ``issue`` öffnen oder
auch gerne einen ``pull request``einstellen.

Dieses kleiner Helferlin wurde unter der MIT Lizenz veröffentlicht, in der 
Hoffnung, dass es vielleicht der/die eine oder andere für sich entdeckt
und nutzt.
