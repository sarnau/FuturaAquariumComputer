;   Futura Aquariencomputer ROM F- 1.89 (8K)
				PRINT   "Anfang..."
;Speicheraufteilung:
;0000h-1FFFh    8K EPROM
;2000h-27FFh    2K RAM
;4000h          Uhrenchip mit 4 Bit Registern
;4000h : Register lesen (0Fh = Fehler)
;4001h : Register wählen
;4002h : Register-Schreiben
;Register: 4,5: Stunden (BCD); 2,3: Minuten (BCD); 0,1: Sekunden (BCD)
;6000h          Keyboard-Spalte auf 0 zurücksetzen. Zeilendaten mit IN A,(00h) abfragen
;8000h          Port-Adresse (0...2:frei, 3...9: Keyboard, 10...15: Display)
;A000h          LED-Daten an gewähltes LED-Segment; (Port-Adresse zurücksetzen?)
;C000h          Schreibzugriff => Watchdog zurücksetzen
;E000h          Ausgangsport für die Steckdosen

ROMTop          = 1FF0h         ;bis hier wird die Prüfsumme berechnet
RAMBase         = 2000h
RAMTop          = 2800h         ;Endadresse vom RAM + 1

NewVersion      = 0             ;0 = Originalversion, 1 = neue Version

				ORG RAMBase     ;Basisadresse vom RAM. IX zeigt stets auf diese Adresse => (IX+d)
DisplayBufStart
KLED            DEFS    2       ;LEDs der Tasten
;  Bit
;   0       0:Tag-LED an
;   1       0:Nacht-LED an
;   2       0:Ein-LED an
;   3       0:Aus-LED an
;   4       0:Zeit-LED an
;   5       0:Momentan-LED an
;   6       0:Manuelle-LED an
;   7       0:Setzen-LED an
;  Bit
;   0       0:pH-LED an
;   1       0:Temp-LED an
;   2       0:Leitwert-LED an
;   3       0:Redox-LED an
;   4       0:Kanal 1-LED an
;   5       0:Kanal 2-LED an
;   6       0:Licht-LED an
;   7       0:CO2-LED an

WarnLED         DEFS    1       ;6 Warn-LEDs neben dem Display
;  Bit
;   0       0:Kanal 2 an
;   1       0:CO2 an
;   2       0:ph-Alarm an
;   3       0:Kanal 1 an
;   4       0:Heizung an
;   5       0:Temp-Alarm an
;   6       unbenutzt
;   7       unbenutzt


DisplayBuf      DEFS    6
DisplayBufEnd:

;Display-Buffer, wird bei jedem Mainloop-Durchlauf aus dem Display-RAM aufgebaut.
;Hier liegen die für die LEDs kodierten Zeichen drin.

;Font => LED-Tabelle
;    01
;    --
;20 |40| 02     low-active!
;    --
;10 |  | 04
;    --  .
;    08  80


Display         DEFS    6       ;Display-RAM

;Zeichensatz im Display:
;00 - 0   01 - 1   02 - 2   03 - 3
;04 - 4   05 - 5   06 - 6   07 - 7
;08 - 8   09 - 9   0A - A   0B - B
;0C - C   0D - D   0E - E   0F - F
;10 - H   11 - L   12 - P   13 - r
;14 - U   15 - µ   16 - u   17 - n
;18 - °   19 - o   1A - /F  1B - /A         "/" = umgedrehter Buchstabe
;1C - -   1D - _   1E - N   1F - Space

LastKey         DEFS    1       ;zuletzt gedrückte Taste (FFh = keine)

Flags           DEFS    1       ;diverse Flags
;      Bit      Aktion, wenn gesetzt
;       0       Zahleingabe an, ansonsten wird ein Wert dargestellt
;       1       zuletzt gedrückte Taste abgearbeitet. Wird erst gelöscht, wenn Taste losgelassen
;       2       Strom wurde eingeschaltet. Uhrzeit beim Einschalten blinkt.
;       3       Momentane Werte durchschalten
;       4       String im Display (0 = Zahl im Display)
;       5       (unbenutzt)
;       6       während der Kommunikation mit dem Hauptgerät (Meßwerte abholen)
;       7       Führende Zeichen aufgetreten. Nullen ab jetzt ausgeben.

DispLine        DEFS    1       ;"Rasterzeile" beim Display-Refresh
DPunkt          DEFS    1       ;Punkte im Display (Bit 0 = 6.Stelle, Bit 1 = 5.Stelle, ...)
BCDZahl         DEFS    2       ;gewandelte BCD-Zahl
CO2EinZeit      DEFS    3       ;Einschaltzeit von CO2
CO2AlarmZeit    DEFS    3       ;Alarmzeit, wenn pH-Wert nicht den Sollwert erreicht hat
LichtEin        DEFS    3       ;Uhrzeit, wann das Licht angeschaltet wird (3 Bytes: ss:mm:hh)
CO2Ein          DEFS    3       ;Uhrzeit, wann das CO2 ausgeschaltet wird (3 Bytes: ss:mm:hh)
Mult24          DEFS    3       ;Multiplikator
Mult24Erg       DEFS    3       ;Ergebnis der 24 Bit Multiplikation
LichtAus        DEFS    3       ;Uhrzeit, wann das Licht ausgeschaltet wird (3 Bytes: ss:mm:hh)
CO2Aus          DEFS    3       ;Uhrzeit, wann das CO2 ausgeschaltet wird (3 Bytes: ss:mm:hh)
TagZeit         DEFS    3       ;Uhrzeit, wann der Tag beginnt (3 Bytes: ss:mm:hh)
SollTempTag     DEFS    1       ;Temperatur für den Tag
NachtZeit       DEFS    3       ;Uhrzeit, wann die Nacht beginnt (3 Bytes: ss:mm:hh)
SollTempNacht   DEFS    1       ;Temperatur für die Nacht
ManuellZeit     DEFS    3       ;Zeit, wie lange das Licht nach Druck auf "Manuell" an bleibt
SollpH          DEFS    1       ;Soll-pH-Wert

MWpHLow         DEFS    1       ;unteres Byte des Meßwertes
MWphHigh        DEFS    1       ;oberes Byte des Meßwertes (nur 4 Bit)
IstpH           DEFS    1       ;gemessener skalierter pH-Wert (obere 8 Bits des Meßwertes)
MWTempLow       DEFS    1       ;unteres Byte des Meßwertes
MWTempHigh      DEFS    1       ;oberes Byte des Meßwertes (nur 4 Bit)
IstTemp         DEFS    1       ;gemessener skalierter Temp-Wert (obere 8 Bits des Meßwertes)
MWLeitwLow      DEFS    1       ;unteres Byte des Meßwertes
MWLeitwHigh     DEFS    1       ;oberes Byte des Meßwertes (nur 4 Bit)
IstLeitw        DEFS    1       ;gemessener skalierter Leitwert-Wert (obere 8 Bits des Meßwertes)
MWRedoxLow      DEFS    1       ;unteres Byte des Meßwertes
MWRedoxHigh     DEFS    1       ;oberes Byte des Meßwertes (nur 4 Bit)
IstRedox        DEFS    1       ;gemessener skalierter Redox-Wert (obere 8 Bits des Meßwertes)

Messcounter     DEFS    1       ;Zähler von 16 abwärts; es wird nur alle 16 Durchläufe gemessen
TempTime        DEFS    3       ;ss:mm:hh (temporäre Zeit während der Eingabeauswertung)
ManuellEinZeit  DEFS    3       ;Zeit, wann "Manuell" gedrückt wurde
Counter         DEFS    2       ;Blink-Timer (Bit 0 toggelt mit 0.5Hz; wird im IRQ abwärts gezählt)
Steckdosen      DEFS    1       ;Steckdose (Bit = 1: Steckdose an)
;      Bit      Steckdose
;       0       CO2
;       1       Heizung
;       2       Licht
;       3       Kanal 1
;       4       Kanal 2
;       5,6,7   die oberen 3 Bits dienen der Kommunikation mit dem Hauptgerät

AktTime         DEFS    3       ;aktuelle Uhrzeit (ss:mm:hh)
PowerOnZeit     DEFS    3       ;Uhrzeit beim Einschalten des Stromes
ManuellAusZeit  DEFS    3       ;Ausschaltzeit nach Druck auf "Manuell"
TempAlarmZeit   DEFS    3       ;Heizungsalarm (Einschaltzeit + 1h)
				DEFS    3
AktSchaltzeit   DEFS    1       ;aktuelle Schaltzeit der Universaltimer (1...10 sind möglich)
SollLeitwertS   DEFS    1       ;Soll-Leitwert (Süßwasser)
SollLeitwertM   DEFS    1       ;Soll-Leitwert (Meerwasser)
Uni1Flag        DEFS    1       ;55h => Kanal 1 = UNI-1
								;AAh => Kanal 1 = Redox-Regler
								;<>  => Kanal 1 = inaktiv
Uni2Flag        DEFS    1       ;55h => Kanal 2 = UNI-2
								;AAh => Kanal 2 = Leitwert-Regler
								;<>  => Kanal 2 = inaktiv
Uni2Flag2       DEFS    1       ;55h = Leitwert EIN Regelung
								;AAh = Leitwert AUS Regelung
SollRedox       DEFS    1       ;Soll-Redoxwert
LeitwertKomp    DEFS    1       ;kompensierter Leitwert
AktSollTemp     DEFS    3       ;aktuelle Solltemperatur (Tag oder Nacht)
Kanal1Uni       DEFS    11*2*3  ;Universaltimer-Zeiten von Kanal 1 (10 Stück a 3 Bytes, erst Ein-, dann Ausschaltzeiten)
Kanal2Uni       DEFS    10*2*3  ;Universaltimer-Zeiten von Kanal 1 (10 Stück a 3 Bytes, erst Ein-, dann Ausschaltzeiten)
MomentanSek     DEFS    1       ;Momentan-Sekunden-Merker für Momentan-Momentan
DelayTimer      DEFS    1       ;Variable für Verzögerungen, etc.
KeyboardMatrix  DEFS    7       ;Keyboard-Matrix-Zeilen (untere 4 Bit, gelöscht = gedrückt)
InputBuf:       DEFS    10      ;Buffer für GetNumInput()
				IF !NewVersion
LaufschriftFlag DEFS    1       ;55h = Laufschrift an
LaufschriftInit DEFS    1       ;55h = Laufschrift ist initialisiert
LaufschriftPtr  DEFS    2       ;Ptr auf eine Laufschrift
ScrollPtr       DEFS    2       ;Ptr auf das nächste Zeichen in der Laufschrift
				ENDIF
SollChecksum    DEFS    2       ;Soll-Prüfsumme über die Sollwerte
				IF !NewVersion
				DEFS    2
Dummy0:         DEFS    2       ;= 0, wird in der Init-Laufschrift ausgegeben
				ENDIF
AktROMChecksum  DEFS    2       ;Prüfsumme über das ROM _während_ der Berechnung
CalcChecksum    DEFS    2       ;letzte errechnete Prüfsumme
ChecksumFinal   DEFS    1       ;Prüfsumme in CalcChecksum ist gültig (aber evtl. falsch!)
ROMTopAdr       DEFS    2       ;Endadresse vom ROM (läuft bis 0 rückwärts während der Prüfsummenberechnung)
ErrorCode       DEFS    1       ;aufgetretener Fehler (0 = keiner)
GesamtBZeit     DEFS    5       ;Gesamt-Betriebsstunden
Kanal1BZeit     DEFS    4       ;Betriebsstunden für Kanal 1 (4 Bytes: mm:hhhhhh)
Kanal2BZeit     DEFS    4       ;Betriebsstunden für Kanal 2 (4 Bytes: mm:hhhhhh)
CO2BZeit        DEFS    4       ;Betriebsstunden für CO2 (4 Bytes: mm:hhhhhh)
TempBZeit       DEFS    4       ;Betriebsstunden für Heizung (4 Bytes: mm:hhhhhh)
LichtBZeit      DEFS    4       ;Betriebsstunden für Licht (4 Bytes: mm:hhhhhh)
				IF !NewVersion
StringBuf       DEFS    200     ;???
StringBufPtr    DEFS    2       ;???
InitLaufschr    DEFS    1       ;0xAA = Init-Laufschrift an, 0x55 = Init-Laufschrift aus
InitLaufschrSek DEFS    1       ;Sekunden-Merker für den Init-Laufschrift-Start
Dummy           DEFS    3       ;??? wird in der Init-Laufschrift ausgegeben, aber nie gesetzt
				ENDIF
				IF NewVersion
MomentanZeit    DEFS    1       ;Weiterschaltzeit für Momentan (in Sekunden)
				ENDIF
StackTop        = RAMTop        ;der Stack fängt ganz oben im RAM an

;Flags von: IN C,(C) (externe Schalter)
;       4       0:Programmiersperre an
;       5       0:Meerwasser, 1:Süßwasser

				ORG 0000h
				DI                              ;IRQs aus (an sich unnötig, sind nach einem Reset eh aus...)
				IM      1                       ;bei IRQs stets RST 38h ausführen!
				LD      SP,StackTop
				LD      (C000h),A
				LD      IX,RAMBase              ;Basisadresse vom RAM
				LD      B,FFh
				LD      (IX+DispLine),DisplayBufEnd ;Display-Refresh (im IRQ)
				IF !NewVersion
				LD      A,AAh
				LD      (InitLaufschr),A        ;Init-Laufschrift AN
				ENDIF
				EI                              ;IRQs wieder an
				LD      HL,0
				LD      (AktROMChecksum),HL     ;ROM-Prüfsumme zurücksetzen
				LD      HL,ROMTop
				LD      (ROMTopAdr),HL          ;Endadresse vom ROM
				JP      Startup

				ORG 0038h                       ;der RST 0x38 bzw. RST 7 Interrupt
				DI
				EXX
				EX      AF,AF'
				JP      DoIRQ
				IF !NewVersion
				JP      DoIRQ                   ;???
				ENDIF

				ORG 0066h                       ;der NMI-Vektor des Z80
;NMI-Routine ("Reset" = alles zurücksetzen)
DoNMI:          IF NewVersion
				CALL    ResetVars
				RETN
				ENDIF

;sämtliche Variablen zurücksetzen!
ResetVars:      PUSH    HL
				PUSH    AF
				PUSH    BC
				PUSH    DE
				LD      BC,23
				LD      HL,Kanal1BZeit
				LD      DE,Kanal1BZeit+1
				LD      (HL),0
				LDIR                            ;Betriebszeiten löschen
				LD      DE,GesamtBZeit
				LD      HL,TempTime             ;temp.Zeit übertragen
				LD      BC,3
				LDIR                            ;Gesamtbetriebszeit setzen
				IN      C,(C)
				BIT     5,C                     ;Süßwasser/Meerwasser-Schalter abfragen
				JR      Z,DoNMI1                ;Meerwasser =>
				LD      A,64                    ;Soll-pH-Wert ((64/2+38)/10 = 7.0)
				JR      DoNMI2
DoNMI1:         LD      A,90                    ;(90/2+38)/10 = 8.3
DoNMI2:         LD      (IX+SollpH),A           ;Soll-pH-Wert
				LD      A,145                   ;(145+100)/10 = 24.5°
				LD      (IX+SollTempTag),A      ;Soll-Temperatur (Tag)
				LD      A,130                   ;(130+100)/10 = 23°
				LD      (IX+SollTempNacht),A    ;Soll-Temperatur (Nacht)
				LD      A,150                   ;150/10+35.0 = 50mS
				LD      (IX+SollLeitwertM),A    ;Soll-Leitwert (Meerwasser)
				LD      A,80                    ;80*10 = 800µS
				LD      (IX+SollLeitwertS),A    ;Soll-Leitwert (Süßwasser)
				LD      A,125                   ;125*2 = 250µV
				LD      (IX+SollRedox),A        ;Soll-Redoxwert
				LD      A,0
				LD      (IX+AktSchaltzeit),A    ;keine aktuelle Schaltzeit
				LD      (IX+Uni1Flag),A         ;Kanal 1 inaktiv schalten
				LD      (IX+Uni2Flag),A         ;Kanal 2 inaktiv schalten
				LD      (IX+Uni2Flag2),A        ;Leitwert-Regelung inaktiv
				LD      HL,CO2Ein
				LD      B,3
DoNMI3:         LD      (HL),A                  ;CO2 Sperrzeit ein = 00.00.00
				INC     HL
				DJNZ    DoNMI3
				LD      HL,CO2Aus
				LD      B,3
DoNMI4:         LD      (HL),A                  ;CO2 Sperrzeit aus = 00.00.00
				INC     HL
				DJNZ    DoNMI4
				IF      NewVersion
				LD      A,7
				LD      (MomentanZeit),A        ;Momentan-Zeit : 7 Sekunden
				ENDIF
				LD      A,80h
				LD      (LichtEin+2),A
				LD      (TagZeit+2),A
				LD      A,81h
				LD      (LichtAus+2),A
				LD      (NachtZeit+2),A
				POP     DE
				POP     BC
				POP     AF
				POP     HL
				IF NewVersion
				RET
				ELSE
				RETN
				ENDIF

;IRQ-Routine für Tastatur und Display
DoIRQ:          LD      A,0
				LD      (A000h),A               ;Port-Adresse auf 0 zurücksetzen
				LD      HL,8000h
				LD      B,7                     ;7 Keyboard-Spalten
				LD      DE,KeyboardMatrix+6
				LD      (HL),A
				LD      (HL),A                  ;auf Adresse 3 weiterschalten
				LD      (HL),A
				LD      (6000h),A               ;Port auslesen
DoIRQ1:         IN      A,(00h)                 ;Keyboard-Spalte auslesen
				LD      (DE),A                  ;und merken
				LD      (HL),A                  qqww;Port-Adresse hochzählen
				DEC     DE                      ;eine Spalte nach vorne
				DJNZ    DoIRQ1                  ;alle Spalten durch? Nein =>

				LD      B,(IX+DispLine)         ;LED-Daten
				DJNZ    DoIRQ2                  ;einmal durch?
				LD      B,DisplayBufEnd         ;wieder von vorne
DoIRQ2:         LD      (IX+DispLine),B         ;aktuelle Zeile setzen
				LD      H,DisplayBufStart>>8
				LD      L,B                     ;DisplayBuf + B - 1 (DisplayBuf...DisplayBufEnd)
				DEC     L
				LD      A,(HL)                  ;Speicherzelle aus dem Display auslesen
				LD      HL,8000h
DoIRQ3:         LD      (HL),A                  ;Port-Adresse hochzählen (10...15)
				DJNZ    DoIRQ3                  ;und zwar B mal
				CPL
				LD      (A000h),A               ;und das Display-Segment setzen
				LD      HL,(Counter)
				DEC     HL                      ;IRQ-Zähler (für Display-Blinken)
				LD      (Counter),HL
				EXX
				EX      AF,AF'
				EI
				RETI


Startup:        LD      (C000h),A
				HALT                            ;Verzögerung
				DJNZ    Startup
				LD      HL,VersionNoDisp
				LD      DE,DisplayBuf
				LD      BC,6
				LDIR                            ;Versionsnummer in die LED-Anzeige "F- 1.89"
				LD      B,FFh
Startup1:       HALT
				HALT
				LD      (C000h),A               ;vierfache Verzögerung
				HALT
				HALT
				LD      (C000h),A
				DJNZ    Startup1
				CALL    KeyStern                ;Display löschen
				SET     2,(IX+Flags)            ;PowerOn-Flag setzen
				SET     6,(IX+KLED)             ;Manuell-LED aus
				LD      DE,PowerOnZeit
				LD      HL,AktTime
				LD      BC,3
				LDIR                            ;aktuelle Uhrzeit merken
				IF !NewVersion
				LD      DE,StringBuf
				LD      (StringBufPtr),DE
				LD      HL,MsgEscHEscJ
				CALL    CopyString
				LD      HL,MsgMessdaten
				CALL    CopyString
				LD      A,55h
				LD      (InitLaufschr),A        ;Init-Laufschrift AUS
				JP      DoLEDKonv
				ENDIF

; Hier beginnt die Hauptschleife...
DoLEDKonv:      LD      B,6                     ;6 LED-Anzeigen updaten
				LD      IY,Display              ;Ptr auf Display-RAM (unkodiert)
				LD      HL,DisplayBuf
				RES     7,(IX+Flags)            ;noch kein 1.Zeichen ausgegeben
				LD      C,(IX+DPunkt)           ;(6) Dezimalpunkte holen
				SLA     C
				SLA     C                       ;um 2 Bits nach oben an den "Byterand"
DoLEDKonv1:     PUSH    HL
				LD      HL,FontLEDTable         ;Ptr auf "Zeichensatz"-Tabelle
				LD      E,(IY+0)                ;Zeichen aus dem Display-RAM
				LD      D,0
				ADD     HL,DE
				LD      A,(HL)                  ;Zeichencode holen
				SLA     A                       ;A << 1
				SLA     C                       ;C << 1 (ins Carry)
				RR      A                       ;A >> 1; Carry in Bit 7
				BIT     7,(IX+Flags)            ;1.Zeichen schon ausgegeben?
				JR      NZ,DoLEDKonv3           ;Ja! =>
				CP      C0h                     ;"0"?
				JR      NZ,DoLEDKonv3           ;Nein => normal ausgeben
				LD      A,B
				CP      1                       ;letztes Anzeigeelement?
				JR      Z,DoLEDKonv2            ;Ja! =>
				LD      A,FFh                   ;LED komplett ausschalten (keine führenden Nullen ausgeben)(
				JR      DoLEDKonv4
DoLEDKonv2:     LD      A,C0h                   ;"0" darstellen
DoLEDKonv3:     SET     7,(IX+Flags)            ;1.Zeichen bereits ausgegeben
DoLEDKonv4:     POP     HL
				LD      (HL),A                  ;LED-Element neu setzen
				INC     IY                      ;weiter im Display-RAM
				INC     HL                      ;zum nächsten Element
				DJNZ    DoLEDKonv1              ;alle LEDs durch?

DoGetMess:      LD      B,(IX+Messcounter)      ;alle 16 Durchläufe umrechnen?
				DJNZ    DoGetMess2              ;Nein! =>
				LD      B,4                     ;4 Meßwerte holen (pH-Wert, Temperatur, Leitwert, Redox)
				LD      IY,MWpHLow
DoGetMess1:     LD      L,(IY+0)                ;unteres Byte lesen
				LD      H,(IY+1)                ;oberes Byte lesen
				ADD     HL,HL
				ADD     HL,HL
				ADD     HL,HL                   ;mal 8
				ADD     HL,HL
				LD      (IY+2),H                ;nur das obere Byte merken
				LD      (IY+0),0                ;Meßwert zurücksetzen
				LD      (IY+1),0
				INC     IY                      ;zum nächsten Meßwert
				INC     IY
				INC     IY
				DJNZ    DoGetMess1
				LD      B,16                    ;Durchlaufzähler neu setzen
DoGetMess2:     LD      (IX+Messcounter),B

				LD      HL,SpezKeyTable         ;Ptr auf den Tabellenanfang
DoSpezKey:      LD      DE,KeyboardMatrix
				LD      B,7                     ;7 Bytes pro Eintrag (= 7 Zeilen) (+ 2 Byte Adresse)
DoSpezKey1:     LD      A,(DE)                  ;Spaltenwert holen
				OR      F0h
				CP      (HL)                    ;Eintrag in der Tabelle?
				JR      Z,DoSpezKey3            ;Ja! => stimmen die nächsten 6 Bytes auch?
DoSpezKey2:     INC     HL
				DJNZ    DoSpezKey2              ;Eintrag überspringen
				INC     HL
				INC     HL
				LD      A,(HL)                  ;Folgebyte holen
				CP      0                       ;Tabellenende?
				JR      Z,DoKeyboard            ;Ja! =>
				JR      DoSpezKey               ;weiter vergleichen...
DoSpezKey3:     INC     DE                      ;nächste Tastaturspalte
				INC     HL
				DJNZ    DoSpezKey1              ;alle 7 Bytes gleich? Nein! => Weiter
				LD      D,(HL)
				INC     HL
				LD      E,(HL)                  ;Sprungadresse holen
				PUSH    DE                      ;Sprungadresse merken
				POP     IY
				CALL    CallIY                  ;gefundene Routine anspringen

DoKeyboard:     LD      A,0                     ;Tastencode = 0
				LD      B,7                     ;7 Tastaturspalten abklopfen
				LD      HL,KeyboardMatrix       ;Ptr auf Tastaturmatrix-Basis
DoKeyboard1:    LD      C,4                     ;maximal 4 Zeilen pro Spalte
				LD      D,(HL)                  ;Byte holen
DoKeyboard2:    RR      D
				JR      NC,DoKeyboard3          ;Bit gesetzt? (Taste gedrückt) => raus
				INC     A                       ;Tastencode++
				DEC     C                       ;alle Zeilen dieser Spalte zusammen?
				JR      NZ,DoKeyboard2          ;Nein =>
				INC     HL                      ;zur nächsten Spalte
				LD      (C000h),A
				DJNZ    DoKeyboard1             ;alle Spalten durch?
				LD      A,FFh                   ;dann keine Taste gedrückt
DoKeyboard3:    CP      (IX+LastKey)            ;mit der zuletzt gedrückten Taste vergleichen
				LD      (IX+LastKey),A          ;als letzte Taste merken
				JR      NZ,DoRecMess            ;ungleich? => ignorieren (entprellen)
				BIT     1,(IX+Flags)            ;Taste abgearbeitet?
				JR      Z,DoKeyboard4           ;Nein =>
				CP      FFh                     ;keine Taste gedrückt?
				JR      NZ,DoRecMess            ;doch! =>
				RES     1,(IX+Flags)            ;Abgearbeitet-Flag löschen
				JR      DoRecMess
DoKeyboard4:    CP      FFh                     ;keine Taste gedrückt?
				JR      Z,DoRecMess             ;genau =>
				SET     1,(IX+Flags)            ;Taste abgearbeitet!

				LD      HL,TastaturTab          ;Tastaturtabelle
				ADD     A,A
				LD      E,A
				LD      D,0
				ADD     HL,DE
				LD      D,(HL)                  ;Sonderflag
				INC     HL
				LD      E,(HL)                  ;Tastencode
				BIT     7,D                     ;normale Ziffer?
				JR      Z,DoKeyboard6           ;Nein! =>
				BIT     0,(IX+Flags)            ;Zahleingabe an?
				JR      NZ,DoKeyboard5          ;Ja! =>
				CALL    KeyStern
				SET     0,(IX+Flags)            ;Zahleingabe an!
DoKeyboard5:    LD      A,E                     ;gedrückte Ziffer
				LD      BC,5
				LD      DE,Display
				LD      HL,Display+1
				LDIR                            ;Display ein Zeichen nach links
				LD      (DE),A                  ;neues Zeichen einfügen
				SCF                             ;Carry-Flag setzen
				RL      (IX+DPunkt)             ;Punkte auch ein Zeichen nach links
				LD      (C000h),A
				JR      DoRecMess
DoKeyboard6:    PUSH    DE                      ;Sprungadresse merken
				POP     IY
				CALL    CallIY                  ;Sondertaste behandeln

;Meßwerte vom Hauptgerät empfangen
DoRecMess:      LD      B,4                     ;4 Meßwerte
				LD      IY,MWRedoxLow           ;Ptr auf den letzten Meßwert
				LD      (C000h),A
DoRecMess1:     LD      C,B
				DEC     C                       ;Meßwertnummer (0...3)
				PUSH    BC
				CALL    GetMesswert             ;empfangen
				POP     BC
				JR      C,DoRecMess2            ;ok? Ja =>
				PUSH    BC
				CALL    GetMesswert             ;nochmal probieren
				POP     BC
				JR      C,DoRecMess2            ;ok? Ja =>
				LD      A,82h
				LD      (ErrorCode),A           ;Übertragungsfehler!
				JR      DoRecMess3              ;=> zum nächsten Meßwert
DoRecMess2:     LD      H,(IY+1)                ;Highbyte vom Meßwert
				LD      L,(IY+0)                ;Lowbyte vom Meßwert
				LD      E,A                     ;Meßwert dazuaddieren
				LD      D,0
				ADD     HL,DE
				LD      (IY+1),H                ;Meßwert neu setzen
				LD      (IY+0),L
DoRecMess3:     DEC     IY
				DEC     IY
				DEC     IY
				LD      (C000h),A
				DJNZ    DoRecMess1              ;alle Meßwerte durch? Nein =>

;Uhrzeit (Uhrenchip liegt ab 4000h) auslesen
DoReadClock:    LD      IY,4000h                ;Basisadresse des Uhrenchips
				LD      DE,AktTime+2            ;Ptr auf die Stunden der Uhrzeit
				LD      B,3                     ;3 Werte (Stunden,Minuten,Sekunden)
				LD      C,5                     ;mit Register 5 geht es los
				HALT
DoReadClock1:   LD      (IY+1),C                ;Register 5 auswählen
				LD      A,(IY+0)                ;Register auslesen
				AND     0Fh                     ;nur 4 Bit-Register!
				CP      0Fh                     ;0Fh?
				JR      Z,DoReadClock3          ;Fehler =>
				ADD     A,A
				ADD     A,A
				ADD     A,A                     ;mal 16 + 0Fh
				ADD     A,A
				OR      0Fh
				DEC     C
				LD      (IY+1),C                ;Register 4 auswählen
				AND     (IY+0)                  ;unteren Teil der BCD-Zahl dazu
				PUSH    AF
				AND     0Fh
				CP      0Fh                     ;0Fh?
				JR      NZ,DoReadClock2         ;Nein => ok!
				POP     AF
				JR      DoReadClock3            ;Fehler =>
DoReadClock2:   POP     AF
				LD      (DE),A                  ;Stunden, Minuten, Sekunden merken
				DEC     DE                      ;eine Stelle weiter
				DEC     C                       ;Register 3,2 und dann Register 1,0
				DJNZ    DoReadClock1            ;alle Register durch? Nein =>
				RES     7,(IX+AktTime+2)        ;Uhrzeit fehlerfrei gelesen
				JR      DoErrorOut              ;Ok =>
DoReadClock3:   LD      A,83h
				LD      (ErrorCode),A           ;Fehler im interen Zeitschalter

DoErrorOut:     LD      (C000h),A
				LD      A,(ErrorCode)           ;Fehlercode lesen
				CP      0                       ;kein Fehler?
				JR      Z,DoFlashResTime        ;genau =>
				LD      E,A
				JP      ErrorOut

DoFlashResTime: BIT     2,(IX+Flags)            ;PowerOn-Flag gesetzt?
				JR      Z,DoPrintTime           ;Nein =>
				BIT     0,(IX+Counter+1)        ;Blink-Timer gesetzt?
				JP      Z,EraseDisplay
				LD      HL,PowerOnZeit
				CALL    PrintTime               ;Uhrzeit beim Einschalten ausgeben
				JP      DoLicht

DoPrintTime:    BIT     5,(IX+KLED)             ;"Zeit" an?
				JP      NZ,DoLicht              ;Nein =>
				BIT     4,(IX+KLED)             ;"Momentan" an?
				JR      NZ,DoDispMess           ;Nein =>
				LD      HL,AktTime
				CALL    PrintTime               ;aktuelle Uhrzeit ausgeben

DoDispMess:     LD      B,4                     ;4 Meßwerte
				LD      C,(IX+KLED+1)           ;Meßwert-Tastatur-LED auslesen
				LD      E,11h                   ;mit Fehlermeldung 11 geht es los
				LD      HL,IstpH                ;Ptr auf Ist-Wert vom pH-Wert
				LD      IY,DoDispMessTab        ;Ptr auf Sprungtabelle für die verschiedenen Meßwerte
DoDispMess1:    SRL     C                       ;LED nach unten schieben
				JR      NC,DoDispMess2          ;LED an? => ja
				INC     HL
				INC     HL                      ;zum nächsten Meßwert
				INC     HL
				INC     IY                      ;ein Eintrag weiter in der Sprungtabelle
				INC     IY
				INC     E                       ;Fehlermeldung + 2
				INC     E
				DJNZ    DoDispMess1
				JR      DoLicht                 ;keinen Meßwert darstellen
DoDispMess2:    LD      A,(HL)                  ;Meßwert auslesen
				CP      0                       ;= 0?
				JR      Z,ErrorOut              ;Meßbereich unterschritten =>
				CP      FFh
				JR      NZ,DoDispMess3          ;Meßbereich i.O. =>
				INC     E
				JR      ErrorOut                ;Meßbereich überschritten =>
DoDispMess3:    LD      D,(IY+0)                ;Sprungtabelle auslesen
				LD      E,(IY+1)
				PUSH    DE                      ;Sprungadresse merken
				POP     IY
				LD      L,A                     ;Meßwert / 2
				SRL     A
				CALL    CallIY                  ;gefundene Routine anspringen
				JR      DoLicht

CallIY:         JP      (IY)

;Fehlermeldung ausgeben, Fehlercode in E
ErrorOut:       BIT     0,(IX+Counter+1)        ;Blink-Timer gesetzt?
				JR      NZ,ErrorOut1            ;An =>
EraseDisplay:   LD      HL,Display+5
				LD      DE,Display+4
				LD      BC,5
				LD      (HL),1Fh                ;Display mit Leerzeichen füllen
				LDDR
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				SET     4,(IX+Flags)            ;keine Zahl im Display
				JR      DoLicht
ErrorOut1:      LD      A,E
				CALL    MakeErrCode

DoLicht:        LD      (C000h),A
				LD      HL,LichtEin
				LD      DE,LichtAus
				CALL    InTimeRange             ;am Tage?
				JR      NC,DoLicht9             ;ja => Licht an
				BIT     6,(IX+KLED)             ;Manuell?
				JR      NZ,DoLicht8             ;Nein => Licht aus
				LD      HL,ManuellZeit          ;Momentan-Timer-Wert (ss:mm:hh)
				LD      DE,ManuellEinZeit       ;Zeit, wann "Manuell" gedrückt wurde
				LD      BC,ManuellAusZeit
				LD      A,(DE)                  ;Sekunden der Einschaltzeit
				ADD     A,(HL)                  ;+ Sekunden der Dauer
				DAA
				INC     DE                      ;Ptr auf die Minuten
				INC     HL
				JR      NC,DoLicht2             ;ein Sekundenüberlauf? Nein =>
DoLicht1:       SUB     60h                     ;Sekunden um 60 zurücksetzen
				DAA
				SCF                             ;Carry setzen (Sekunden-Übertrag)
				JR      DoLicht3
DoLicht2:       CP      60h                     ;Sekunden-Überlauf?
				JR      NC,DoLicht1             ;Ja =>
				CCF                             ;Nein, Carry löschen
DoLicht3:       LD      (BC),A                  ;Ausschaltzeit-Sekunden
				INC     BC
				LD      A,(DE)
				ADC     A,(HL)                  ;Ausschaltzeit-Minuten (+ Sekunden-Übertrag)
				DAA
				INC     DE                      ;Ptr auf die Stunden
				INC     HL
				JR      NC,DoLicht5             ;ein Minutenüberlauf? Nein =>
DoLicht4:       SUB     60h                     ;Minuten um 60 zurücksetzen
				DAA
				SCF                             ;Carry setzen (Minuten-Übertrag)
				JR      DoLicht6
DoLicht5:       CP      60h                     ;Minuten-Überlauf?
				JR      NC,DoLicht4             ;Ja =>
				CCF                             ;Nein, Carry löschen
DoLicht6:       LD      (BC),A                  ;Ausschaltzeit-Minuten
				INC     BC
				LD      A,(DE)
				ADC     A,(HL)                  ;Ausschaltzeit-Stunden (+ Minuten-Übertrag)
				DAA
				CP      24h                     ;24h Überlauf?
				JR      C,DoLicht7              ;Nein =>
				SUB     24h                     ;Uhrzeit des nächsten Tages
				DAA
DoLicht7:       LD      (BC),A                  ;Aussschaltzeit-Stunden
				LD      HL,ManuellEinZeit
				LD      DE,ManuellAusZeit
				CALL    InTimeRange             ;im "Manuell"-Einschaltzeitraum?
				JR      NC,DoLicht9             ;Ja => Licht an
				SET     6,(IX+KLED)             ;Manuell aus
DoLicht8:       RES     2,(IX+Steckdosen)       ;Licht aus
				JR      DoKanal1
DoLicht9:       SET     2,(IX+Steckdosen)       ;Licht an

DoKanal1:       LD      HL,Kanal1Uni            ;Einschaltzeiten
				LD      DE,Kanal1Uni+30         ;Ausschaltzeiten
				CALL    Kanal1Regel
				JR      C,DoKanal11
				SET     3,(IX+Steckdosen)       ;Kanal 1 an
				RES     3,(IX+WarnLED)          ;Kanal 1-LED an
				JR      DoKanal2
DoKanal11:      RES     3,(IX+Steckdosen)       ;Kanal 1 aus
				SET     3,(IX+WarnLED)          ;Kanal 1-LED aus

DoKanal2:       LD      HL,Kanal2Uni            ;Einschaltzeiten
				LD      DE,Kanal2Uni+30         ;Ausschaltzeiten
				CALL    Kanal2Regel
				JR      C,DoKanal21
				SET     4,(IX+Steckdosen)       ;Kanal 2 an
				RES     0,(IX+WarnLED)          ;Kanal 2-LED an
				JR      DoTemp
DoKanal21:      RES     4,(IX+Steckdosen)       ;Kanal 2 aus
				SET     0,(IX+WarnLED)          ;Kanal 2-LED aus

DoTemp:         LD      HL,TagZeit
				LD      DE,NachtZeit
				CALL    InTimeRange             ;ist es Tag?
				JR      C,DoTemp1               ;Nein =>
				LD      A,(IX+SollTempTag)      ;Soll-Temperatur (Tag)
				JR      DoTemp2
DoTemp1:        LD      A,(IX+SollTempNacht)    ;Soll-Temperatur (Nacht)
DoTemp2:        PUSH    AF                      ;Soll-Temperatur merken
				LD      (IX+AktSollTemp),A      ;aktuelle Soll-Temperatur merken
				BIT     4,(IX+WarnLED)          ;Heizung-LED an?
				JR      Z,DoTemp6               ;Ja! => Heizung regeln
				CP      (IX+IstTemp)            ;Ist-Temp-Wert >= Soll-Temperatur?
				JR      C,DoTemp4               ;Ja! => Heizung ausschalten
				SET     1,(IX+Steckdosen)       ;Heizung an
				RES     4,(IX+WarnLED)          ;Heizung-LED an
				LD      HL,AktTime
				LD      DE,TempAlarmZeit
				LD      BC,3
				LDIR                            ;Einschaltzeit der Heizung merken
				DEC     DE
				LD      A,(DE)                  ;Stunden holen
				INC     A                       ;+1
				CP      24h                     ;24 Uhr?
				JR      C,DoTemp3               ;kleiner als 24 Uhr? Ja =>
				LD      A,0                     ;0 Uhr annehmen
DoTemp3:        LD      (DE),A                  ;Stunden setzen
				POP     AF
				JR      DoTemp10

DoTemp4:        POP     AF
				SET     5,(IX+WarnLED)          ;Temp.Alarm aus
DoTemp5:        SET     4,(IX+WarnLED)          ;Heizung-LED aus
				RES     1,(IX+Steckdosen)       ;Heizung aus
				JR      DoTemp10

DoTemp6:        LD      HL,AktTime
				LD      DE,TempAlarmZeit
				CALL    CompareTimes            ;eine Stunde heizen um?
				JR      NC,DoTemp7              ;Nein =>
				BIT     0,(IX+Counter+1)        ;Blink-Timer gesetzt?
				JR      Z,DoTemp7               ;Nein =>
				RES     5,(IX+WarnLED)          ;Temp.Alarm an
				JR      DoTemp8
DoTemp7:        SET     5,(IX+WarnLED)          ;Temp.Alarm aus
DoTemp8:        POP     AF                      ;Soll-Temperatur wieder vom Stack holen
				ADD     A,1
				CP      (IX+IstTemp)            ;Ist-Temp-Wert >= Soll-Temp + 0.1°?
				JR      C,DoTemp5               ;Ja =>
				SET     1,(IX+Steckdosen)       ;Heizung an

DoTemp10:       LD      A,(IX+IstTemp)          ;Ist-Temp-Wert
				SUB     8
				CP      (IX+AktSollTemp)        ;Soll-Temp >= Ist-Temp - 0.8°? (Temperatur zu kalt?)
				JR      C,DoPh                  ;Ja =>
				BIT     0,(IX+Counter+1)        ;Blink-Timer gesetzt?
				JR      Z,DoTemp11              ;Nein =>
				SET     5,(IX+WarnLED)          ;Temp.Alarm aus
				JR      DoPh
DoTemp11:       RES     5,(IX+WarnLED)          ;Temp.Alarm an

DoPh:           LD      (C000h),A
				LD      B,(IX+IstpH)            ;Ist-pH-Wert
				SRL     B
				PUSH    BC
				LD      HL,CO2Ein
				LD      DE,CO2Aus
				CALL    InTimeRange             ;CO2-Sperrzeit?
				JR      C,DoPh2                 ;Ja =>
				BIT     1,(IX+WarnLED)          ;CO2-LED an?
				JR      Z,DoPh4                 ;Ja! =>
				LD      A,(IX+SollpH)           ;Soll-pH-Wert
				POP     BC
				CP      B                       ;>= Ist-pH-Wert?
				JR      NC,DoPh3                ;zu groß =>
				RES     1,(IX+WarnLED)          ;CO2-LED an
				SET     0,(IX+Steckdosen)       ;CO2 an
				LD      HL,AktTime
				LD      DE,CO2EinZeit
				LD      BC,3
				LDIR                            ;Einschaltzeit des CO2
				LD      HL,AktTime
				LD      BC,3
				LDIR                            ;Alarmzeit des CO2
				DEC     DE
				LD      A,(DE)
				ADD     A,3                     ;= Einschaltzeit + 3h
				DAA
				CP      24h                     ;24h Überlauf?
				JR      C,DoPh1                 ;Nein =>
				SUB     24h                     ;- 24h
DoPh1:          LD      (DE),A
				JR      DoPh7

DoPh2:          POP     BC
DoPh3:          SET     2,(IX+WarnLED)          ;CO2-Alarm aus
				SET     1,(IX+WarnLED)          ;CO2-LED aus
				RES     0,(IX+Steckdosen)       ;CO2 aus
				JR      DoPh7

DoPh4:          LD      HL,CO2EinZeit
				LD      DE,CO2AlarmZeit
				CALL    InTimeRange             ;CO2 schon 3h an?
				JR      NC,DoPh5                ;Nein =>
				LD      A,(IX+IstpH)            ;Ist-pH-Wert
				SRL     A
				CP      (IX+SollpH)             ;= Soll-pH-Wert
				JR      Z,DoPh5                 ;Ja => (kein Alarm)
				BIT     0,(IX+Counter+1)        ;Blink-Timer gesetzt?
				JR      Z,DoPh5
				RES     2,(IX+WarnLED)          ;pH-Alarm an
				JR      DoPh6
DoPh5:          SET     2,(IX+WarnLED)          ;pH-Alarm aus
DoPh6:          LD      A,(IX+SollpH)           ;Soll-pH-Wert
				SUB     1                       ;- 0.05
				POP     BC
				CP      B                       ;=> Ist-pH-Wert? (Vergleich: Ist-pH-Wert < Soll-pH-Wert)
				JR      NC,DoPh3                ;zu groß => CO2 aus

DoPh7:          LD      A,(IX+IstpH)            ;Ist-pH-Wert
				SRL     A
				ADD     A,6                     ;+ 0.3
				CP      (IX+SollpH)             ;Soll-pH-Wert (Ist-pH-Wert <= Soll-pH-Wert + 0.35)
				JR      NC,DoMomentan
				BIT     0,(IX+Counter+1)        ;Blink-Timer gesetzt?
				JR      Z,DoPh8
				SET     2,(IX+WarnLED)          ;pH-Alarm aus
				JR      DoMomentan
DoPh8:          RES     2,(IX+WarnLED)          ;pH-Alarm an

DoMomentan:     CALL    TempKomp                ;Leitwert mit der Temperatur kompensieren
				LD      (C000h),A

				BIT     5,(IX+KLED)             ;"Momentan" an?
				JR      NZ,DoLaufschr           ;Nein =>
				BIT     3,(IX+Flags)            ;Momentane Werte durchschalten?
				JR      Z,DoLaufschr            ;Nein =>
				LD      HL,MomentanSek
				LD      A,(AktTime)             ;Sekunden beim letzten Durchlauf
				CP      (HL)                    ;Sekunden geändert?
				JR      Z,DoLaufschr            ;Nein =>
				LD      (HL),A                  ;letzten Sekundenstand merken
				LD      HL,DelayTimer           ;Pause für die Darstellung
				LD      A,(HL)
				INC     A
				IF      NewVersion
				PUSH    HL
				LD      HL,MomentanZeit
				CP      (HL)                    ;Momentane Sekunden abgelaufen?
				POP     HL
				ELSE
				CP      7                       ;7 Sekunden darstellen
				ENDIF
				JR      C,DoMomentan4           ;Zeit abgelaufen? Nein =>
				LD      A,(IX+KLED+1)           ;LEDs rechte Spalte auslesen
				OR      F0h
				CP      FFh                     ;alle LEDs aus?
				JR      NZ,DoMomentan1          ;Nein =>
				SET     4,(IX+KLED)             ;Uhrzeit ausschalten
				RES     0,(IX+KLED+1)           ;pH-Wert anschalten
				JR      DoMomentan3
DoMomentan1:    RLCA                            ;Anzeige weiterschalten
				BIT     4,A                     ;Überlauf?
				JR      NZ,DoMomentan2          ;Nein =>
				LD      A,(IX+KLED+1)
				OR      0Fh                     ;rechte Spalte ausschalten
				LD      (IX+KLED+1),A
				RES     4,(IX+KLED)             ;Uhrzeit anschalten
				JR      DoMomentan3
DoMomentan2:    LD      B,A                     ;rotierte Matrix merken
				LD      A,(IX+KLED+1)           ;rechte Spalte erneut auslesen
				OR      0Fh                     ;alle LEDs aus
				AND     B                       ;rotierte Matrix dazu
				LD      (IX+KLED+1),A           ;und neue LEDs anschalten
DoMomentan3:    LD      A,0                     ;Pause wieder zurücksetzen
DoMomentan4:    LD      (HL),A                  ;Delay-Timer setzen

DoLaufschr:     IF !NewVersion
				LD      (C000h),A
				LD      A,(LaufschriftFlag)
				CP      55h
				JR      NZ,DoSollChecksum       ;keine Laufschrift =>
				LD      A,(LaufschriftInit)
				CP      55h                     ;Laufschrift initialisiert?
				JR      Z,DoLaufschr1           ;Ja =>
				LD      HL,(LaufschriftPtr)
				LD      (ScrollPtr),HL          ;Laufschrift-Text setzen
				LD      A,55h
				LD      (LaufschriftInit),A     ;aktiv schalten
				LD      (IX+KLED),FFh           ;alle Tasten-LEDs aus
				LD      (IX+KLED+1),FFh

DoLaufschr1:    LD      A,(DelayTimer)
				DEC     A                       ;DelayTimer runterzählen
				LD      (DelayTimer),A
				JR      NZ,DoSollChecksum       ;noch nicht abgelaufen =>
				LD      A,12
				LD      (DelayTimer),A          ;DelayTimer neu setzen
				LD      HL,(ScrollPtr)
				LD      A,(HL)                  ;nächstes Zeichen aus dem Scrollstring
				INC     HL
				LD      (ScrollPtr),HL
				CP      40h                     ;"Display löschen"? (Stringanfang)
				JR      NZ,DoLaufschr3          ;Nein! =>
				LD      HL,Display              ;Display löschen
				LD      B,6
DoLaufschr2:    LD      (HL),1Fh                ;Leerzeichen
				INC     HL
				DJNZ    DoLaufschr2
				JR      DoSollChecksum
DoLaufschr3:    CP      42h                     ;"Leerzeichen (langsam)"?
				JR      Z,DoLaufschr4           ;Ja! =>
				CP      41h                     ;Neustart vom Anfang an? (Stringende)
				JR      NZ,DoLaufschr5          ;Nein! =>
				LD      HL,(LaufschriftPtr)
				LD      (ScrollPtr),HL
				LD      A,80
				LD      (DelayTimer),A          ;6.7-fache Pause vorher einlegen
				JR      DoSollChecksum          ;nix ausgeben =>
DoLaufschr4:    LD      A,48
				LD      (DelayTimer),A          ;4-fache Pause
				LD      A,1Fh                   ;Leerzeichen ausgeben
DoLaufschr5:    LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				LD      (IX+KLED),FFh           ;alle Tasten-LEDs aus
				LD      (IX+KLED+1),FFh
				LD      DE,Display
				LD      HL,Display+1
				LD      BC,5
				LDIR                            ;nach links scrollen
				LD      (DE),A                  ;neues Zeichen einfügen
				ENDIF

DoSollChecksum: LD      (C000h),A
				CALL    CalcSollChecksum        ;Prüfsumme über die Sollwerte errechnen
				LD      HL,(SollChecksum)       ;alte Prüfsumme holen
				XOR     A                       ;kein Fehler
				SBC     HL,DE                   ;Prüfsummen gleich?
				JR      Z,DoBetrStd             ;Ja! =>
				LD      (SollChecksum),DE       ;als neue Prüfsumme merken
				LD      A,80h                   ;Prüfsumme über die Sollwerte geändert!
				LD      (ErrorCode),A

DoBetrStd:      LD      (C000h),A
				LD      A,(IX+AktTime+2)        ;aktuelle Stunden
				LD      HL,GesamtBZeit+3
				CP      (HL)                    ;= Gesamtzeitstunden (low-Byte der Stunden)
				JR      Z,DoBetrStd1            ;Ja =>
				LD      (HL),A
				LD      HL,GesamtBZeit
				CALL    IncHour                 ;Gesamtzeit um eine Stunde erhöhen
DoBetrStd1:     LD      A,(IX+AktTime+1)        ;aktuelle Minuten
				LD      HL,GesamtBZeit+4
				CP      (HL)                    ;= Gesamtzeitminuten
				JR      Z,DoInitStr             ;Ja => (noch keine Minute rum)
				LD      (HL),A                  ;neue Minuten merken

				BIT     3,(IX+WarnLED)          ;Kanal 1-LED an?
				JR      NZ,DoBetrStd2           ;Nein =>
				LD      HL,Kanal1BZeit
				CALL    IncMinute
DoBetrStd2:     BIT     0,(IX+WarnLED)          ;Kanal 2-LED an?
				JR      NZ,DoBetrStd3           ;Nein =>
				LD      HL,Kanal2BZeit
				CALL    IncMinute
DoBetrStd3:     BIT     1,(IX+WarnLED)          ;CO2-LED an?
				JR      NZ,DoBetrStd4           ;Nein =>
				LD      HL,CO2BZeit
				CALL    IncMinute
DoBetrStd4:     BIT     4,(IX+WarnLED)          ;Heizung-LED an?
				JR      NZ,DoBetrStd5           ;Nein =>
				LD      HL,TempBZeit
				CALL    IncMinute
DoBetrStd5:     BIT     2,(IX+Steckdosen)       ;Licht an?
				JR      Z,DoInitStr             ;Nein =>
				LD      HL,LichtBZeit
				CALL    IncMinute

DoInitStr:      IF !NewVersion
				LD      (C000h),A
				LD      HL,InitLaufschrSek
				LD      A,(AktTime)             ;Sekunden auslesen
				CP      (HL)
				JP      Z,DoROMChksum           ;gleich der gemerkten Sekunden? =>
				LD      (HL),A
				LD      A,(InitLaufschr)        ;Init-Laufschrift?
				CP      55h
				JP      Z,DoROMChksum           ;gleich =>
				LD      IY,Dummy0
				LD      (IY+0),0                ;???
				LD      (IY+1),0

				LD      DE,StringBuf
				LD      A,2
				LD      (DE),A
				INC     DE
				LD      HL,AktTime
				LD      B,3
DoInitStr1:     LD      A,(HL)
				CALL    HexByteOut              ;Uhrzeit ausgeben
				INC     HL
				DJNZ    DoInitStr1
				LD      A,' '
				LD      (DE),A
				INC     DE
				LD      HL,Dummy                ;???
				LD      B,3
DoInitStr2:     LD      A,(HL)
				CALL    HexByteOut
				INC     HL
				DJNZ    DoInitStr2
				LD      A,' '
				LD      (DE),A
				INC     DE
				LD      A,(IX+IstpH)            ;Ist-pH-Wert
				SRL     A
				CALL    HexByteOut
				LD      A,' '
				LD      (DE),A
				INC     DE
				LD      A,(IX+IstTemp)          ;Ist-Temp-Wert
				CALL    HexByteOut
				LD      A,' '
				LD      (DE),A
				INC     DE
				LD      A,(IX+LeitwertKomp)     ;kompensierter Leitwert
				CALL    HexByteOut
				LD      A,' '
				LD      (DE),A
				INC     DE
				LD      A,(IX+IstRedox)         ;Ist-Redox-Wert
				CALL    HexByteOut
				LD      A,' '
				LD      (DE),A
				INC     DE
				IN      A,(C)
				AND     20h                     ;Süßwasser/Meerwasser-Schalter
				LD      B,A
				LD      A,(IX+Steckdosen)       ;Steckdosen-Status
				AND     1Fh
				OR      B
				CALL    HexByteOut
				LD      A,' '
				LD      (DE),A
				INC     DE
				LD      HL,(Dummy0)             ;= 0
				LD      A,H
				CALL    HexByteOut
				LD      A,L
				CALL    HexByteOut
				LD      A,13
				LD      (DE),A
				INC     DE
				LD      A,3
				LD      (DE),A
				LD      HL,StringBuf
				LD      (StringBufPtr),HL
				LD      A,55h
				LD      (InitLaufschr),A        ;Init-Laufschrift AUS
				ENDIF

;Prüfsummenberechnung über das ROM
DoROMChksum:    LD      (C000h),A
				LD      DE,(AktROMChecksum)     ;alte Prüfsumme lesen
				LD      HL,(ROMTopAdr)          ;Endadresse vom ROM - 1
				DEC     HL
				LD      (ROMTopAdr),HL          ;Endadresse - 1
				LD      A,L
				OR      H                       ;Adresse zusammen"OR"n
				LD      L,(HL)                  ;Speicherstelle auslesen
				LD      H,00h
				ADD     HL,DE                   ;alte Prüfsumme dazuaddieren
				LD      (AktROMChecksum),HL     ;Prüfsumme neu merken
				CP      00h                     ;Anfang vom ROM erreicht?
				JR      NZ,DoMainloop           ;Nein =>
				LD      HL,(AktROMChecksum)     ;Prüfsumme auslesen
				LD      (CalcChecksum),HL       ;errechnete Prüfsumme merken
				LD      A,0
				LD      (ChecksumFinal),A
				LD      DE,(ROMChecksum)        ;erwartete Prüfsumme
				XOR     A
				SBC     HL,DE                   ;Prüfsumme gleich?
				JR      Z,DoROMChksum1          ;Ja! =>
				LD      A,81h                   ;Programmstörung!
				LD      (ErrorCode),A
DoROMChksum1:   LD      HL,0
				LD      (AktROMChecksum),HL     ;alte Prüfsumme zurücksetzen
				LD      HL,ROMTop
				LD      (ROMTopAdr),HL          ;Ende vom ROM neu setzen

DoMainloop:     LD      (C000h),A
				JP      DoLEDKonv               ;und wieder von vorne...

; Unbenutzer Code:
				IF !NewVersion
DoComm:         LD      A,(IX+Steckdosen)       ;Steckdoses-Status
				RES     5,A
				CALL    DoComm4                 ;0??
				LD      B,7
DoComm1:        RR      C
				JR      C,DoComm2               ;8 Bits übertragen
				RES     5,A
				JR      DoComm3
DoComm2:        SET     5,A
DoComm3:        CALL    DoComm4
				DJNZ    DoComm1
				PUSH    HL
				POP     HL
				SET     5,A
				LD      (E000h),A               ;1??
				RET
DoComm4:        LD      (E000h),A
				NOP
				NOP
				NOP
				RET
				ENDIF

;Hexbyte nach DE schreiben. (IY+0/1) enthält die Prüfsumme
				IF !NewVersion
HexByteOut:
				PUSH    AF
				SRL     A
				SRL     A
				SRL     A
				SRL     A
				CALL    HexByteOut1
				POP     AF
				AND     0Fh
HexByteOut1:    CP      10                      ;größer als 10?
				JR      C,HexByteOut2           ;Nein! =>
				ADD     A,'7'                   ;+ '7' = 'A'...'F'
				JR      HexByteOut3
HexByteOut2:    ADD     A,'0'                   ;sonst + '0' = '0'...'9'
HexByteOut3:    LD      (DE),A                  ;in den Buffer schreiben
				INC     DE
				ADD     A,(IY+0)                ;alte Summe dazuaddieren
				LD      (IY+0),A                ;als neue Summe merken
				LD      (C000h),A
				RET     NC                      ;Überlauf der Prüfsumme? Nein => raus
				INC     (IY+1)                  ;Prüfsummen-Highbyte hochzählen
				RET
				ENDIF

; String ab HL nach DE bis zum "$" kopieren
				IF !NewVersion
CopyString:
				LD      (C000h),A
				LD      A,(HL)                  ;Zeichen aus dem String holen
				CP      '$'                     ;Textende erkannt?
				RET     Z                       ;dann raus =>
				LD      (DE),A                  ;Zeichen übertragen
				INC     DE
				INC     HL
				JR      CopyString

; String mit Fehlermeldung in HL (zwei ASCII-Zeichen) zusammensetzen
ErrorString:
				PUSH    HL
				LD      HL,MsgFehl              ;"FEHL." ausgeben
				CALL    CopyString
				POP     HL
				LD      A,H
				LD      (DE),A                  ;Fehlernummer übertragen
				INC     DE
				LD      A,L
				LD      (DE),A
				INC     DE
				LD      HL,Msg6Space            ;"      ",13,10,10 anhängen
				CALL    CopyString
				RET

; "." an den String anhängen
ConcatPunkt:    EX      DE,HL
				LD      (HL),'.'
				EX      DE,HL
				INC     DE
				RET
				ENDIF

; Prüfsumme über die Sollwerte berechnen, Ergebnis nach DE
CalcSollChecksum:
				PUSH    HL
				LD      HL,0
				LD      D,0
				LD      E,(IX+SollpH)           ;Soll-pH-Wert
				ADD     HL,DE
				LD      E,(IX+SollTempTag)      ;Soll-Temperatur (Tag)
				ADD     HL,DE
				LD      E,(IX+SollTempNacht)    ;Soll-Temperatur (Nacht)
				ADD     HL,DE
				LD      E,(IX+SollLeitwertS)    ;Soll-Leitwert (Süßwasser)
				ADD     HL,DE
				LD      E,(IX+SollLeitwertM)    ;Soll-Leitwert (Meerwasser)
				ADD     HL,DE
				LD      E,(IX+SollRedox)        ;Soll-Redoxwert
				ADD     HL,DE
				EX      DE,HL
				POP     HL
				LD      (C000h),A
				RET

;langer Timer (1 Byte Minuten, 3 Bytes Stunden) um eine Minute erhöhen
IncMinute:      LD      A,(HL)
				INC     A
				CP      60                      ;Sekundenüberlauf?
				JR      C,IncMinute1            ;Nein =>
				LD      (HL),0                  ;Sekunden auf 0 zurücksetzen
				INC     HL
				JR      IncHour
IncMinute1:     LD      (HL),A
				RET
IncHour:        LD      B,3                     ;3 Bytes für Stunden
IncHour1:       LD      A,(HL)
				ADD     A,1                     ;Stunden um eins erhöhen
				DAA
				LD      (HL),A
				JR      NC,IncHour2
				INC     HL
				DJNZ    IncHour1
IncHour2:       RET

;"Zeit" gedrückt
KeyZeit:        RES     0,(IX+Flags)            ;Zahleingabe aus
				LD      A,(IX+KLED)             ;Tastenlampen holen
				BIT     4,A                     ;Zeit war bereits an?
				JR      NZ,KeyZeit6             ;Nein =>
				BIT     4,(IX+KLED+1)           ;"Kanal 1"
				JR      NZ,KeyZeit1             ;Nein =>
				LD      HL,Kanal1BZeit+1
				CALL    PrintTime
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				RET
KeyZeit1:       BIT     5,(IX+KLED+1)           ;"Kanal 2"
				JR      NZ,KeyZeit2             ;Nein =>
				LD      HL,Kanal2BZeit+1
				CALL    PrintTime
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				RET
KeyZeit2:       BIT     7,(IX+KLED+1)           ;"CO2"
				JR      NZ,KeyZeit3             ;Nein =>
				LD      HL,CO2BZeit+1
				CALL    PrintTime
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				RET
KeyZeit3:       BIT     6,(IX+KLED+1)           ;"Licht"
				JR      NZ,KeyZeit4             ;Nein =>
				LD      HL,LichtBZeit+1
				CALL    PrintTime
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				RET
KeyZeit4:       BIT     1,(IX+KLED+1)           ;"Temperatur"
				JR      NZ,KeyZeit5             ;Nein =>
				LD      HL,TempBZeit+1
				CALL    PrintTime
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				RET
KeyZeit5:       LD      HL,GesamtBZeit          ;Gesamtbetriebsstunden
				CALL    PrintTime
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				RET

KeyZeit6:       RES     4,A                     ;Zeit-LED-Flag an
				OR      0Fh                     ;Tag,Nacht,Ein,Aus-LEDs aus
				LD      (IX+KLED),A             ;LED-Status setzen
				LD      A,(IX+KLED+1)
				IF NewVersion
				OR      0Fh                     ;alle LEDs aus
				ELSE
				OR      0Dh                     ;bis auf Temperatur alle LEDs aus (WARUM???)
				ENDIF
				LD      (IX+KLED+1),A
				BIT     7,(IX+KLED)             ;"Setzen" an?
				JR      NZ,KeyZeit8             ;Nein =>
				BIT     4,(IX+KLED+1)           ;"Kanal 1" an?
				JR      NZ,KeyZeit7             ;Nein! =>
				LD      (IX+Uni1Flag),55h
				LD      HL,StrLrUNI1            ;" UNI-1"
				SET     7,(IX+KLED)             ;"Setzen" aus
				JP      SetDisplayString
KeyZeit7:       BIT     5,(IX+KLED+1)           ;"Kanal 2" an?
				RET     NZ                      ;Nein =>
				LD      (IX+Uni2Flag),55h
				LD      HL,StrLrUNI2            ;" UNI-2"
				SET     7,(IX+KLED)             ;"Setzen" aus
				JP      SetDisplayString
KeyZeit8:       RET

;"Ein" gedrückt
KeyEin:         LD      HL,StrLrEIN             ;"Lr-EIn"
				LD      B,55h                   ;Ein-Flag
				RES     2,(IX+KLED)             ;Ein-LED an
				SET     3,(IX+KLED)             ;Aus-LED aus
				JR      KeyAus1

;"Aus" gedrückt
KeyAus:         LD      HL,StrLrAUS             ;"Lr-AUS"
				LD      B,AAh                   ;Aus-Flag
				RES     3,(IX+KLED)             ;Aus-LED an
				SET     2,(IX+KLED)             ;Ein-LED aus
KeyAus1:        RES     0,(IX+Flags)            ;Zahleingabe aus
				BIT     5,(IX+KLED+1)           ;"Kanal 2"
				JP      NZ,KeyAus2              ;Nein =>
				BIT     2,(IX+KLED+1)           ;"Leitwert"
				JP      NZ,KeyAus2              ;Nein =>
				BIT     7,(IX+KLED)             ;"Setzen" an?
				JP      NZ,KeyAus2              ;Nein! =>
				LD      (IX+Uni2Flag),AAh       ;Leitwert-Regelung
				LD      (IX+Uni2Flag2),B        ;Ein- oder Aus-Regelung setzen
				SET     7,(IX+KLED)             ;"Setzen"-LED aus
				JP      SetDisplayString

;Display löschen
KeyStern:       LD      HL,Display
				LD      B,6
KeyStern1:      LD      (HL),0                  ;6 mal '0' ins Display (führende Nullen werden NICHT ausgegeben)
				INC     HL
				DJNZ    KeyStern1
				INC     HL
				RES     0,(HL)                  ;Zahleingabe aus
				INC     HL
				INC     HL
				LD      (HL),FFh                ;alle Punkte im Display aus
				LD      B,A
				LD      (IX+KLED+1),FFh
				LD      A,BFh
				OR      (IX+KLED)
				LD      (IX+KLED),A             ;Bis auf manuelles Licht alle Tasten-LEDs aus
				SET     0,(IX+Flags)            ;Zahleingabe an
				RES     2,(IX+Flags)            ;PowerOn-Flag zurücksetzen
				RES     3,(IX+Flags)            ;keine Momentan-Werte durchschalten
				IF !NewVersion
				LD      A,AAh
				LD      (LaufschriftFlag),A     ;Laufschrift ausschalten
				LD      (LaufschriftInit),A
				ENDIF
				LD      A,6
				LD      (DelayTimer),A
				RES     4,(IX+Flags)            ;Zahl im Display
				LD      A,0
				LD      (ErrorCode),A           ;Fehlercode löschen
				LD      A,B
				LD      (C000h),A
				RET

;Diese Routine wird bei Druck auf "." angesprungen
KeyPunkt:       BIT     0,(IX+Flags)            ;Zahleingabe an?
				CALL    Z,KeyStern              ;Nein! => erstmal das Display löschen
				SET     0,(IX+Flags)            ;Zahleingabe aktivieren
				LD      A,(IX+DPunkt)
				XOR     01h                     ;Dezimalpunkt toggeln
				LD      (IX+DPunkt),A
				LD      (C000h),A
				RET

;pH-Taste gedrückt
KeyPh:          LD      (IX+KLED+1),FEh         ;pH-LED an
				RES     0,(IX+Flags)            ;Zahleingabe aus
				LD      A,(IX+KLED)
				OR      18h                     ;Zeit und Aus LEDs aus
				LD      (IX+KLED),A
				BIT     5,(IX+KLED)             ;"Momentan"?
				RET     Z                       ;Ja => raus
				BIT     7,(IX+KLED)             ;"Setzen" an?
				JR      Z,KeyPh1                ;Ja! =>
				JP      DispSollPh              ;Soll-pH-Wert darstellen
KeyPh1:         LD      HL,Display
				IF !NewVersion
				LD      A,0
				OR      (HL)
				INC     HL
				OR      (HL)
				INC     HL
				OR      (HL)
				JR      NZ,KeyPh2
				INC     HL
				LD      A,(HL)
				CP      1
				JR      NZ,KeyPh2               ;"15.0" eingegeben?
				INC     HL
				LD      A,(HL)
				CP      5
				JR      NZ,KeyPh2               ;Nein =>
				INC     HL
				LD      A,(HL)
				CP      0
				JR      NZ,KeyPh2
				LD      A,(IX+DPunkt)
				CP      FDh                     ;Dezimalpunkt
				JR      NZ,KeyPh2
				LD      A,55h
				LD      (LaufschriftFlag),A     ;Laufschrift an
				LD      HL,MsgBasis
				LD      (LaufschriftPtr),HL     ;Laufschrift-Text
				RET
				ENDIF
KeyPh2:         CALL    GetNumInput             ;Eingabe holen
				LD      A,D                     ;Anzahl der Dezimalpunkte holen
				CP      0
				JR      Z,KeyPh3
				CP      1                       ;0 oder 1 ist i.O.
				JR      Z,KeyPh4
				LD      A,3
				JP      MakeErrCode             ;mehrere Dezimalpunkte bei pH-Werteingabe
KeyPh3:         LD      IY,InputBuf+7           ;Ptr auf die letzte Ziffer
KeyPh4:         LD      B,E                     ;Position des Dezimalpunktes (1...6)
				LD      A,0
				INC     IY
				PUSH    IY
KeyPh5:         OR      (IY-2)                  ;alle Ziffern _VOR_ der 1.Vorkommastelle zusammen"OR"n
				DEC     IY
				DJNZ    KeyPh5
				POP     IY
				CP      0                       ;gibt es dort Ziffern <> "0"?
				JR      Z,KeyPh6                ;Nein! =>
				LD      A,1
				JP      MakeErrCode             ;pH-Wert zu groß!
KeyPh6:         CALL    ConvertInput            ;pH-Wert holen
				LD      A,L
				SUB     38                      ;3.8 ist für einen pH-Wert zu klein!
				JR      C,KeyPh7                ;< 3.8 => Fehler
				JR      Z,KeyPh7                ;= 3.8 => Fehler
				JR      KeyPh8                  ;alles ok =>
KeyPh7:         LD      A,2
				JP      MakeErrCode             ;pH-Wert zu klein
KeyPh8:         SLA     A                       ;mal 2
				LD      B,A
				LD      A,(IY+1)                ;2.Nachkommastelle holen
				CP      3
				JR      C,KeyPh10               ;<0.03? => nicht aufrunden
				CP      8
				JR      C,KeyPh9                ;<0.08? => auf 0.05 aufrunden
				INC     B                       ;>=0.08? => auf 0.10 aufrunden
KeyPh9:         INC     B
KeyPh10:        LD      (IX+SollpH),B           ;als neuen pH-Sollwert merken ((pH-Wert*10-38)*2)
				CALL    CalcSollChecksum        ;Prüfsumme über die Sollwerte errechnen
				LD      (SollChecksum),DE       ;und merken
				SET     7,(IX+KLED)             ;"Setzen" aus
				LD      (C000h),A
DispSollPh:     LD      A,(IX+SollpH)           ;neuen pH-Wert holen

;pH-Wert darstellen
DispPh:         BIT     0,A                     ;Bit 0 = 2.Nachkommastelle
				JR      Z,DispPh1
				LD      B,5                     ;gesetzt = 0.05
				JR      DispPh2
DispPh1:        LD      B,0                     ;gelöscht = 0.00
DispPh2:        LD      (IX+Display+2),B
				SRL     A                       ;(pH-Wert / 2) + 38
				ADD     A,38
				LD      E,A
				LD      D,0
				PUSH    DE
				POP     IY                      ;Zahl nach IY
				CALL    MakeBCD
				LD      HL,BCDZahl              ;Ptr auf die BCD-Zahl
				LD      A,0
				RRD     (HL)                    ;unteres Nibble ab HL nach A holen
				LD      (IX+Display+1),A        ;2.Stelle
				RRD     (HL)                    ;oberes Nibble ab HL nach A holen
				LD      (IX+Display),A          ;1.Stelle
				LD      (IX+Display+3),1Fh      ;Leerzeichen
				LD      (IX+Display+4),12h      ;"P"
				LD      (IX+Display+5),10h      ;"H"
				LD      (IX+DPunkt),DFh         ;Dezimalpunkt nach der 1.Stelle
				LD      (C000h),A
				RET

;"Setzen" gedrückt
KeySetzen:      RES     0,(IX+Flags)            ;Zahleingabe aus
				IN      A,(C)                   ;Sperre gesetzt?
				BIT     4,A                     ;Ja! =>
				JR      Z,KeySetzen1
				BIT     4,(IX+Flags)            ;Zahl im Display?
				CALL    NZ,KeyStern             ;Nein! =>
				LD      A,(IX+KLED)
				XOR     80h                     ;Setzen-toggeln
				OR      3Fh                     ;bis auf "Manuell" alle LEDs ausschalten
				LD      (IX+KLED),A
				LD      (IX+KLED+1),FFh
				LD      (C000h),A
				RET
KeySetzen1:     LD      A,99h                   ;Programmiersperre gesetzt
				JP      MakeErrCode

;"Momentan" gedrückt
KeyMomentan:    RES     0,(IX+Flags)            ;Zahleingabe aus
				BIT     5,(IX+KLED)             ;"Momentan" bereits an?
				JR      NZ,KeyMomentan1         ;Nein =>
				SET     3,(IX+Flags)            ;Momentane Werte durchschalten
				IF NewVersion
				LD      A,0
				LD      (DelayTimer),A          ;sofortige Ausgabe der Werte erzwingen
				DEC     A
				LD      (MomentanSek),A
				ENDIF
				JR      KeyMomentan2
KeyMomentan1:   RES     3,(IX+Flags)            ;Momentane Werte nicht mehr durchschalten
KeyMomentan2:   RES     5,(IX+KLED)             ;Momentan-LED an
				LD      A,(IX+KLED)
				OR      0Fh                     ;Tag, Nacht, Ein, Aus LEDs ausschalten
				LD      (IX+KLED),A
				LD      (IX+KLED+1),FFh         ;rechte LEDs ausschalten
				BIT     7,(IX+KLED)             ;"Setzen" an?
				LD      (C000h),A
				RET     NZ                      ;Nein =>
				BIT     4,(IX+KLED)             ;"Zeit" an?
				JR      Z,KeyMomentan4          ;Ja! =>
				IF NewVersion
				LD      A,0
				LD      B,4
				LD      HL,Display              ;die ersten 4 Ziffern müssen stets = 0 sein
KeyMomentan6:   OR      (HL)
				INC     HL
				DJNZ    KeyMomentan6
				JR      NZ,KeyMomentan7         ;wenn nicht => Fehler
				LD      IY,Display+5            ;Ptr auf die letzte Stelle vom Display
				CALL    ConvertInput            ;Zahl nach HL holen
				LD      A,L
				LD      HL,MomentanZeit
				LD      (HL),A                  ;aktuelle Schaltzeit merken
				SET     7,(IX+KLED)             ;Setzen-LED aus
				ENDIF
KeyMomentan3:   SET     5,(IX+KLED)             ;Momentan-LED aus
				RET
				IF NewVersion
KeyMomentan7:   LD      A,20h
				JP      MakeErrCode             ;Eingabe falsch!
				ENDIF
KeyMomentan4:   LD      BC,0A00h                ;2560 Schleifendurchläufe
KeyMomentan5:   HALT
				LD      A,(KeyboardMatrix+6)
				BIT     2,A                     ;Manuell immer noch gedrückt?
				JR      NZ,KeyMomentan3         ;Nein => Zeit nicht neu setzen
				LD      (C000h),A
				HALT
				DEC     BC                      ;Zähler runterzählen
				LD      A,B                     ;0 erreicht?
				OR      C
				JR      NZ,KeyMomentan5         ;Nein => weiter warten
				SET     5,(IX+KLED)             ;Momentan-LED aus
				JP      SetSystemTime

;"Temperatur"-Taste gedrückt
KeyTemperatur:  RES     0,(IX+Flags)            ;Zahleingabe aus
				LD      A,(IX+KLED+1)
				RES     1,A                     ;Temperatur an
				OR      FDh                     ;andere LEDs aus
				LD      (IX+KLED+1),A
				LD      A,(IX+KLED)
				OR      1Fh                     ;außer Momentan, Manuell und Setzen alles aus
				LD      (IX+KLED),A
				LD      (C000h),A
				RET

;"Kanal 1" gedrückt
KeyKanal1:      RES     0,(IX+Flags)            ;Zahleingabe aus
				LD      A,(IX+KLED)
				OR      1Fh                     ;Tag,Nacht,Ein,Aus,Zeit im linken Bereich aus
				LD      (IX+KLED),A
				LD      A,(IX+KLED+1)
				OR      FFh                     ;alle LEDs im rechten Bereich aus
				RES     4,A                     ;und "Kanal 1"-LED an
				LD      (IX+KLED+1),A
				BIT     5,(IX+KLED)             ;"Momentan" an?
				RET     NZ                      ;Nein => raus
				LD      A,(IX+Uni1Flag)         ;Zustand von Kanal 1
				CP      55h
				JR      Z,KeyKanal12            ;=> Universaltimer
				CP      AAh
				JR      Z,KeyKanal11            ;=> Redox-Regler
				LD      HL,Str6Minus            ;"------"
				JP      SetDisplayString
KeyKanal11:     LD      HL,StrrErE              ;" rE-rE"
				JP      SetDisplayString
KeyKanal12:     LD      HL,StrLrUNI1            ;" UNI-1"
				JP      SetDisplayString

;"Kanal 2" gedrückt
KeyKanal2:      RES     0,(IX+Flags)            ;Zahleingabe aus
				LD      A,(IX+KLED)
				OR      1Fh                     ;Tag,Nacht,Ein,Aus,Zeit im linken Bereich aus
				LD      (IX+KLED),A
				LD      A,(IX+KLED+1)
				OR      FFh                     ;alle LEDs im rechten Bereich aus
				RES     5,A                     ;und "Kanal 2"-LED an
				LD      (IX+KLED+1),A
				BIT     5,(IX+KLED)             ;"Momentan" an?
				RET     NZ                      ;Nein => raus
				LD      A,(IX+Uni2Flag)         ;Zustand von Kanal 2
				CP      55h
				JR      Z,KeyKanal24            ;=> Universaltimer
				CP      AAh
				JR      Z,KeyKanal21            ;=> Leitwert-Regler
				LD      HL,Str6Minus            ;"------"
				JP      SetDisplayString
KeyKanal21:     LD      A,(IX+Uni2Flag2)        ;Ein- oder Aus-Regelung?
				CP      55h
				JR      Z,KeyKanal23            ;=> Ein-Regelung
				CP      AAh
				JR      Z,KeyKanal22            ;=> Aus-Regelung
				LD      HL,Str6Minus            ;"------"
				JP      SetDisplayString
KeyKanal22:     LD      HL,StrLrAUS             ;"Lr-AUS"
				JP      SetDisplayString
KeyKanal23:     LD      HL,StrLrEIN             ;"Lr-EIN"
				JP      SetDisplayString
KeyKanal24:     LD      HL,StrLrUNI2            ;" UNI-2"
				JP      SetDisplayString

;"CO2" gedrückt
KeyCO2:         RES     0,(IX+Flags)            ;Zahleingabe aus
				LD      A,(IX+KLED+1)
				RES     7,A                     ;CO2-LED an
				OR      7Fh                     ;alle LEDs aus
				LD      (IX+KLED+1),A
				LD      A,(IX+KLED)
				OR      3Fh                     ;bis auf "Manuell" und "Setzen" alle LEDs aus
				LD      (IX+KLED),A
				LD      (C000h),A
				RET

;"Licht" gedrückt
KeyLicht:       RES     0,(IX+Flags)            ;Zahleingabe aus
				LD      A,(IX+KLED+1)
				RES     6,A                     ;Licht-LED an
				OR      BFh                     ;alle LEDs aus
				LD      (IX+KLED+1),A
				LD      A,(IX+KLED)
				OR      3Fh                     ;bis auf "Manuell" und "Setzen" alle LEDs aus
				LD      (IX+KLED),A
				LD      (C000h),A
				RET

;"Tag" gedrückt
KeyTag:         LD      HL,TagZeit              ;Ptr auf Tagdaten
				RES     0,(IX+KLED)             ;Tag an
				SET     1,(IX+KLED)             ;Nacht aus
				JR      KeyNacht1

;"Nacht" gedrückt
KeyNacht:       LD      HL,NachtZeit            ;Ptr auf Nachtdaten
				RES     1,(IX+KLED)             ;Nacht an
				SET     0,(IX+KLED)             ;Tag aus
KeyNacht1:      RES     0,(IX+Flags)            ;Zahleingabe aus
				LD      A,(IX+KLED)
				OR      2Ch                     ;Ein, Aus und Momentan aus
				LD      (IX+KLED),A
				LD      A,(IX+KLED+1)
				OR      FDh                     ;bis auf "Temperatur" alles aus
				LD      (IX+KLED+1),A
				BIT     7,(IX+KLED)             ;"Setzen" an?
				JR      Z,KeyNacht2             ;Ja! =>
				BIT     4,(IX+KLED)             ;"Zeit" an?
				JP      Z,PrintTime             ;Ja! =>
				BIT     1,(IX+KLED+1)           ;"Temperatur" an?
				JP      Z,PrintSollTemp         ;°C ausgeben
				JR      KeyNacht3
KeyNacht2:      BIT     4,(IX+KLED)             ;"Zeit" an?
				JP      Z,GetDispTime           ;Ja! => Zeit für Tag oder Nacht setzen
				BIT     1,(IX+KLED+1)           ;"Temperatur" an?
				JP      Z,SetSollTemp           ;Temperatur für Tag oder Nacht setzen =>
				SET     7,(IX+KLED)             ;"Setzen" aus
KeyNacht3:      SET     1,(IX+KLED)             ;Nacht aus
				SET     0,(IX+KLED)             ;Tag aus
				LD      (C000h),A
				RET

;"Manuell" gedrückt
KeyManuell:     RES     0,(IX+Flags)            ;Zahleingabe aus
				LD      A,(IX+KLED)
				BIT     7,A                     ;"Setzen" an?
				JR      Z,KeyManuell2           ;Ja! =>
				LD      BC,3
				LD      DE,ManuellEinZeit
				LD      HL,AktTime              ;Uhrzeit retten
				LDIR
				LD      HL,ManuellZeit
				BIT     4,A                     ;"Zeit" an?
				JR      NZ,KeyManuell1          ;Nein =>
				BIT     5,A                     ;"Momentan" an?
				JP      NZ,PrintTime            ;Nein! (Zeit an, Momentan aus) => Ausschaltzeit ausgeben
KeyManuell1:    XOR     40h
				LD      (IX+KLED),A             ;Manuell-Flag toggeln
				RET
KeyManuell2:    LD      HL,ManuellZeit
				IF !NewVersion
				CALL    GetDispTime             ;Zeit für "Manuell"-Taste setzen
				LD      A,(IX+Display)
				CP      0Fh                     ;"FEHL"er...
				RET     Z                       ;Ja => raus
				RES     4,(IX+KLED)             ;Zeit-LED an
				LD      B,6
KeyManuell3:    LD      HL,Display+5
				LD      A,(HL)
				CP      1                       ;"11.11.11" eingegeben?
				RET     NZ                      ;Nein =>
				INC     HL
				DJNZ    KeyManuell3
				LD      A,55h
				LD      (LaufschriftFlag),A     ;Laufschrift an
				LD      HL,MsgPause
				LD      (LaufschriftPtr),HL     ;Laufschrift-Text
				RET
				ENDIF

;Uhrzeit nach HL aus dem Display setzen
GetDispTime:    LD      DE,TempTime
				LD      A,(IX+DPunkt)           ;Dezimalpunkte holen
				CP      FBh                     ;hh.mm
				JR      Z,GetDispTime2
				CP      EBh                     ;hh.mm.ss
				JR      Z,GetDispTime1
				LD      A,7
				JP      MakeErrCode             ;Dezimalpunkte an falscher Position
GetDispTime1:   LD      B,2                     ;zwei Dezimalpunkte (noch zwei Zahlen holen)
				LD      C,4                     ;zuerst: Fehler bei den Sekunden
				JR      GetDispTime4
GetDispTime2:   LD      A,0
				OR      (IX+Display+1)          ;zwei Ziffern (ganz links) eingegeben?
				OR      (IX+Display)
				JR      Z,GetDispTime3          ;Nein =>
				LD      A,6
				JP      MakeErrCode             ;mehr als 23h eingegeben
GetDispTime3:   LD      (DE),A                  ;ohne Sekunden: 0 Sekunden setzen
				INC     DE
				LD      B,1                     ;ein Dezimalpunkt (noch eine Zahl holen)
				LD      C,5                     ;zuerst: Fehler bei den Minuten
GetDispTime4:   LD      IY,Display+5            ;Ptr auf die letzte Ziffer im Display
GetDispTime5:   LD      A,(IY-1)                ;Ziffer davor holen
				ADD     A,A
				ADD     A,A                     ;*16
				ADD     A,A
				ADD     A,A
				OR      (IY+0)                  ;und die Ziffer dazu (=> BCD-Zahl)
				CP      5Ah                     ;5A = 50+10 = 60!
				JR      C,GetDispTime6          ;kleiner? => ja
				SET     7,C                     ;Fehler!
GetDispTime6:   LD      (DE),A                  ;Zahl merken
				INC     DE
				DEC     IY                      ;zwei Ziffern nach vorne
				DEC     IY
				INC     C                       ;Fehlernummer hochsetzen (Sekunden => Minuten)
				DJNZ    GetDispTime5            ;alle Dezimalpunkte durch?
				LD      A,(IY-1)
				ADD     A,A
				ADD     A,A
				ADD     A,A                     ;Stunden in BCD wandeln
				ADD     A,A
				OR      (IY+0)
				CP      24h                     ;größer als 24h?
				JR      C,GetDispTime7          ;Nein =>
				SET     7,C                     ;Fehler!
GetDispTime7:   LD      (DE),A                  ;Stunden merken
				BIT     7,C                     ;ein Fehler aufgetreten?
				JR      Z,GetDispTime8          ;Nein =>
				RES     7,C                     ;Flag löschen
				LD      A,C
				JP      MakeErrCode             ;Fehler melden
GetDispTime8:   EX      DE,HL
				DEC     HL
				DEC     HL
				LD      BC,3
				LDIR                            ;Uhrzeit nach HL übertragen
				SET     7,(IX+KLED)             ;"Setzen" aus
				LD      (C000h),A
				RET

; 3 Bytes ab HL als 6 stellige Uhrzeit ausgeben
PrintTime:      LD      DE,Display+5            ;Ptr auf die letzte Stelle vom Display
				LD      B,3
				PUSH    HL
				INC     HL
				INC     HL
				LD      A,'0'
				CP      (HL)                    ;Stunden < '0'?
				POP     HL
				JR      NC,PrintTime1           ;Nein =>
				LD      HL,Str6Minus            ;"------" (Uhrzeit nicht gesetzt)
				JP      SetDisplayString
PrintTime1:     LD      A,(HL)                  ;Byte holen
				AND     0Fh
				LD      (DE),A                  ;unteres Nibble nach (DE)
				DEC     DE
				LD      A,(HL)
				RRCA
				RRCA
				RRCA
				RRCA
				AND     0Fh
				LD      (DE),A                  ;oberes Nibble nach (DE-1)
				DEC     DE
				INC     HL
				DJNZ    PrintTime1
				LD      (IX+DPunkt),EBh         ;Dezimalpunkte nach der 2. und der 4.Ziffer
				LD      (C000h),A
				RET

;Tag-/Nachttemperatur setzen
SetSollTemp:    PUSH    HL
				CALL    GetNumInput
				POP     HL
				LD      A,D                     ;Anzahl der Dezimalpunkte
				CP      0
				JR      Z,SetSollTemp1
				CP      1
				JR      Z,SetSollTemp2
				LD      A,10h
				JP      MakeErrCode             ;Dezimalpunkte bei der Temperatur...
SetSollTemp1:   LD      IY,InputBuf+7
				IF !NewVersion
				LD      A,0
				CP      (IY+0)
				JR      NZ,SetSollTemp2
				CP      (IY-1)                  ;100° C
				JR      NZ,SetSollTemp2
				LD      A,1
				CP      (IY-2)
				JR      NZ,SetSollTemp2
				LD      A,55h
				LD      (LaufschriftFlag),A     ;Laufschrift an
				LD      HL,MsgHeiss
				LD      (LaufschriftPtr),HL     ;Laufschrift-Text
				RET
				ENDIF
SetSollTemp2:   LD      B,E
				LD      A,0
				INC     IY
				PUSH    IY
SetSollTemp3:   OR      (IY-3)
				DEC     IY
				DJNZ    SetSollTemp3
				POP     IY
				CP      0
				JR      Z,SetSollTemp4
				LD      A,08h
				JP      MakeErrCode             ;eingegeben Temp. zu groß
SetSollTemp4:   PUSH    HL
				CALL    ConvertInput
				LD      A,(IY+1)
				CP      5
				JR      C,SetSollTemp5          ;<0.05°? =>
				INC     HL                      ;aufrunden (+ 0.1°)
SetSollTemp5:   LD      DE,100
				XOR     A
				SBC     HL,DE
				JR      C,SetSollTemp8          ;<10.0° =>
				JR      Z,SetSollTemp8          ;=10.0° =>
				LD      A,00h
				CP      H
				JR      NZ,SetSollTemp6         ;>(10° + 25.5°) =>
				LD      A,FFh
				CP      L
				JR      NZ,SetSollTemp7         ;<>(10° + 25.5°) =>
SetSollTemp6:   LD      A,8
				POP     HL
				JP      MakeErrCode             ;eing. Temp zu groß
SetSollTemp7:   LD      A,L
				POP     HL
				INC     HL
				INC     HL
				INC     HL
				LD      (HL),A                  ;Temperatur (10.1°...35.4°) setzen
				CALL    CalcSollChecksum        ;Prüfsumme über die Sollwerte errechnen
				LD      (SollChecksum),DE       ;und merken
				SET     7,(IX+KLED)             ;"Setzen" aus
				LD      L,A
				LD      (C000h),A
				JR      DispTemp
SetSollTemp8:   LD      A,09h
				POP     HL
				JP      MakeErrCode             ;eing. Temp zu tief

;Soll-Tag-/Nachttemperatur ausgeben
PrintSollTemp:  INC     HL
				INC     HL
				INC     HL
				LD      L,(HL)                  ;Soll-Temperatur auslesen

;Temperatur-Wert darstellen
DispTemp:       LD      H,0
				LD      DE,100
				ADD     HL,DE                   ;+10.0°
				PUSH    HL
				POP     IY
				CALL    MakeBCD
				LD      HL,(BCDZahl)
				LD      DE,Display
				LD      B,3                     ;3 Ziffern
DispTemp1:      LD      A,H
				AND     0Fh
				LD      (DE),A
				ADD     HL,HL
				ADD     HL,HL                   ;HL *= 16
				ADD     HL,HL
				ADD     HL,HL
				INC     DE
				DJNZ    DispTemp1
				EX      DE,HL
				LD      (HL),1Fh                ;Space
				INC     HL
				LD      (HL),18h                ;°
				INC     HL
				LD      (HL),0Ch                ;C
				LD      (IX+DPunkt),EFh         ;Punkt in der 2.Ziffer an
				LD      (C000h),A
				RET

;Meßwert C (0...3) vom Hauptgerät empfangen (Wert nach A)
GetMesswert:    LD      HL,E000h
				LD      A,(IX+Steckdosen)       ;Steckdosen-Bits
				AND     5Fh                     ;Bit 0...4 übernehmen, Bit 5&7 löschen
				OR      40h                     ;Bit 6 setzen
				SET     6,(IX+Flags)
				HALT
				LD      (HL),A                  ;567:010 (Bit 7 löschen = Übertragung init)
				CALL    Delay
				LD      E,A
				SET     5,E
				LD      (HL),E                  ;567:110 (Bit 5 toggeln: Übertragung start)
				CALL    Delay

;Meßwert-Nummer (2 Bits) senden
				LD      D,A
				LD      B,2                     ;2 Bits (für 4 Meßwerte) senden
				LD      (HL),D                  ;567:010
				CALL    Delay
				LD      (HL),E                  ;567:110 (1-Bit senden = Startbit)
				CALL    Delay
				LD      (HL),D                  ;567:010
GetMesswert1:   SRL     C
				JR      C,GetMesswert2          ;gesetzt =>
				RES     6,D                     ;Bit 6 löschen, wenn Carry gelöscht
				RES     6,E
				LD      (HL),D                  ;567:000
				CALL    Delay
				LD      (HL),E                  ;567:100 (0-Bit senden)
				CALL    Delay
				LD      (HL),D                  ;567:000
				DJNZ    GetMesswert1            ;alle 2 Bits übertragen? Nein =>
				JR      GetMesswert3
GetMesswert2:   SET     6,D                     ;Bit 6 setzen, wenn Carry gesetzt
				SET     6,E
				LD      (HL),D                  ;567:010
				CALL    Delay
				LD      (HL),E                  ;567:110 (1-Bit senden)
				CALL    Delay
				LD      (HL),D                  ;567:010
				DJNZ    GetMesswert1            ;alle 2 Bits übertragen? Nein =>

GetMesswert3:   LD      B,8                     ;8 Bits empfangen
				LD      (HL),E                  ;567:1?0 (Bit erwarten)
				CALL    Delay
				IN      C,(C)                   ;Bit auslesen
				BIT     5,C                     ;0-Startbit?
				JR      Z,GetMesswert4          ;Ja =>
				SET     7,E
				SET     6,E
				LD      (IX+Steckdosen),E
				LD      (HL),E                  ;567:1?1 (Übertragung beendet)
				SCF
				CCF                             ;Carry = NOT 1 = 0 (Übertragung mit Fehler)
				RET
GetMesswert4:   LD      (HL),D                  ;567:0?0 (Bit empfangen)
				CALL    Delay
				LD      A,0                     ;Bytewert = 0
				LD      (HL),E                  ;567:1?0 (Bit erwarten)
GetMesswert5:   CALL    Delay
				ADD     A,A                     ;Bytewert * 2
				IN      C,(C)
				BIT     5,C                     ;Bit abfragen
				LD      (HL),D                  ;567:0?0 (Bit empfangen)
				CALL    Delay
				JR      Z,GetMesswert6          ;Bit gelöscht =>
				SET     0,A                     ;unterstes Bit setzen
GetMesswert6:   LD      (HL),E                  ;567:1?0 (Bit erwarten)
				CALL    Delay
				DJNZ    GetMesswert5            ;alle 8 Bits empfangen? Nein =>
				SET     7,E
				SET     6,E
				LD      (IX+Steckdosen),E
				LD      (HL),E                  ;567:111 (Übertragung beendet)
				CALL    Delay
				RES     6,(IX+Flags)
				SCF                             ;Carry = 1 (Übertragung ok)
				RET

;ein paar Takte verzögern
Delay:          NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				RET

;Potential in L ausgeben
DispRedox:      LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				LD      (IX+Display+5),19h      ;o
				LD      (IX+Display+4),12h      ;P
				LD      (IX+Display+3),1Fh      ;Space
				LD      H,0
				ADD     HL,HL
				PUSH    HL
				POP     IY
				CALL    MakeBCD
				LD      HL,(BCDZahl)
				LD      DE,Display
				LD      B,3
DispRedox1:     LD      A,H
				AND     0Fh
				LD      (DE),A
				ADD     HL,HL
				ADD     HL,HL                   ;HL *= 16
				ADD     HL,HL
				ADD     HL,HL
				INC     DE
				DJNZ    DispRedox1
				LD      (C000h),A
				RET

;Systemzeit (aus dem Display) in dem RTC setzen
SetSystemTime:  LD      HL,AktTime
				CALL    GetDispTime             ;Uhrzeit aus dem Display lesen
				LD      A,(IX+Display)
				CP      0Fh                     ;"F"ehler?
				RET     Z                       ;Ja => raus
				LD      HL,AktTime
				CALL    PrintTime               ;Uhrzeit formatiert ausgeben
				LD      HL,Display
				SET     3,(HL)                  ;Bit 3 in der 1.Stundenziffer setzen (24h Format)
				LD      B,6                     ;6 Register setzen
				LD      C,5
				LD      IY,4000h                ;Adresse vom RTC
				HALT
SetSystemTime1: LD      (IY+1),C                ;Register auswählen
				LD      A,(HL)                  ;Ziffer auslesen
				LD      (IY+2),A                ;und ins RTC-Register schreiben
				INC     HL
				DEC     C                       ;Register - 1
				DJNZ    SetSystemTime1
				RES     5,(IX+KLED)             ;"Momentan"-LED ausschalten
				LD      (C000h),A
				RET

;Universaltimer-Verwaltung
UniTimer:       LD      B,10                    ;maximal 10 Zeiten
UniTimer1:      PUSH    HL
				INC     HL
				INC     HL
				BIT     7,(HL)                  ;Ende der Liste? (Einschaltzeit)
				POP     HL
				JR      Z,UniTimer2             ;Nein =>
				SCF                             ;Ja, Carry setzen und raus
				RET
UniTimer2:      PUSH    DE
				INC     DE
				INC     DE
				LD      A,(DE)                  ;Ende der Liste? (Ausschaltzeit)
				POP     DE
				BIT     7,A
				JR      Z,UniTimer3             ;Nein =>
				SCF                             ;Ja, Carry setzen und raus
				RET
UniTimer3:      PUSH    BC
				PUSH    DE
				PUSH    HL
				CALL    InTimeRange             ;im Einschaltbereich?
				POP     HL
				POP     DE
				POP     BC
				RET     NC                      ;Ja! => raus
				INC     HL
				INC     HL                      ;nächste Einschaltzeit
				INC     HL
				INC     DE
				INC     DE                      ;nächste Ausschaltzeit
				INC     DE
				DJNZ    UniTimer1               ;alle Zeiten durch?
				LD      (C000h),A
				RET

;HL: Einschaltzeit
;DE: Ausschaltzeit
;Carry = 0, wenn im Zeitraum
InTimeRange:    PUSH    DE
				PUSH    HL
				CALL    CompareTimes            ;sind die beiden Zeiten gleich?
				POP     HL
				POP     DE
				RET     Z                       ;Ja => raus
				JR      C,InTimeRange1          ;Ausschaltzeit < Einschaltzeit? => Zeiten und Logik drehen
				PUSH    DE
				LD      DE,AktTime
				CALL    CompareTimes            ;HL mit der aktuellen Uhrzeit vergleichen
				POP     DE
				RET     Z                       ;Einschaltzeit = aktuelle Zeit? => raus
				RET     C                       ;Einschaltzeit > aktuelle Zeit? => raus
				LD      HL,AktTime
				CALL    CompareTimes
				RET     C                       ;Ausschaltzeit > aktuelle Zeit? => raus
				RET     NZ                      ;Ausschaltzeit <> aktuelle Zeit? => raus
				SCF                             ;Carry = 1 (außerhalb)
				RET
InTimeRange1:   EX      DE,HL
				PUSH    DE
				LD      DE,AktTime
				CALL    CompareTimes
				POP     DE
				CCF                             ;Carry = NOT Carry
				RET     NC
				JR      NZ,InTimeRange2
				SCF                             ;Carry = 1 (außerhalb)
				RET
InTimeRange2:   LD      HL,AktTime
				CALL    CompareTimes
				RET     Z
				CCF                             ;Carry = NOT Carry
				RET

;Zeit DE und HL vergleichen, Z = 1, wenn gleich
CompareTimes:   LD      BC,0300h                ;3 Bytes (Sekunden,Minuten,Stunden) vergleichen
				XOR     A
CompareTimes1:  LD      A,(DE)
				SBC     A,(HL)
				JR      Z,CompareTimes2
				SET     0,C                     ;Flag setzen, wenn ungleich!
CompareTimes2:  INC     HL
				INC     DE
				DJNZ    CompareTimes1
				LD      (C000h),A
				BIT     0,C                     ;Z = 1, wenn gleich
				RET

;Leitwert-Wert darstellen
DispLeitw:      LD      H,0
				BIT     5,(IX+KLED)             ;"Momentan" an?
				JR      NZ,DispLeitw4           ;Nein =>
				LD      A,(IX+IstTemp)          ;Ist-Temp-Wert
				CP      FFh
				JR      Z,DispLeitw6            ;Temperatur außerhalb des Meßbereiches?
				CP      00h
				JR      Z,DispLeitw6            ;Ja =>
				LD      A,(IX+LeitwertKomp)     ;kompensierter Leitwert
				LD      L,A
				CP      FFh                     ;ungültig?
				JR      NZ,DispLeitw2           ;Nein =>
				BIT     0,(IX+Counter+1)        ;Blink-Timer gesetzt?
				JR      Z,DispLeitw1
				LD      HL,Str6Space            ;"      "
				JP      SetDisplayString
DispLeitw1:     LD      HL,StrFEHL16            ;"FEHL16"
				JP      SetDisplayString
DispLeitw2:     CP      00h                     ;Bereich unterschritten?
				JR      NZ,DispLeitw4           ;Nein =>
				BIT     0,(IX+Counter+1)        ;Blink-Timer gesetzt?
				JR      Z,DispLeitw3
				LD      HL,Str6Space            ;"      "
				JP      SetDisplayString
DispLeitw3:     LD      HL,StrFEHL15            ;"FEHL15"
				JP      SetDisplayString

DispLeitw4:     IN      C,(C)
				BIT     5,C                     ;Süßwasser/Meerwasser-Schalter abfragen
				JR      Z,DispLeitw5            ;Meerwasser =>
				LD      DE,1505h                ;"µS"
				LD      (IX+Display+3),00h      ;"0"
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				JR      DispLeitw9
DispLeitw5:     LD      DE,350                  ;35.0mS Vorgabe (Minumum bei Meerwasser-Leitwert)
				ADD     HL,DE
				LD      DE,1705h                ;"nS"
				LD      (IX+Display+3),1Fh      ;Space
				LD      (IX+DPunkt),EFh
				JR      DispLeitw9

DispLeitw6:     LD      L,(IX+IstLeitw)         ;Ist-Leitwert (nicht kompensiert)
				IN      C,(C)
				BIT     5,C                     ;Süßwasser/Meerwasser-Schalter abfragen
				JR      Z,DispLeitw7            ;Meerwasser =>
				LD      DE,1505h                ;"µS"
				LD      (IX+Display+3),00h      ;"0"
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				JR      DispLeitw8
DispLeitw7:     LD      DE,350                  ;35.0mS Vorgabe (Minumum bei Meerwasser-Leitwert)
				ADD     HL,DE
				LD      DE,1705h                ;"nS"
				LD      (IX+Display+3),1Fh      ;Space
				LD      (IX+DPunkt),EFh         ;Punkt nach der 2.Ziffer
DispLeitw8:     BIT     0,(IX+Counter+1)        ;Blink-Timer gesetzt?
				JR      Z,DispLeitw9
				LD      DE,1F1Fh                ;"  "

DispLeitw9:     LD      (IX+Display+5),E        ;Einheit setzen
				LD      (IX+Display+4),D
				PUSH    HL
				POP     IY
				CALL    MakeBCD                 ;Leitwert nach BCD wandeln
				LD      HL,(BCDZahl)            ;BCD-Zahl holen
				LD      DE,Display
				LD      B,3                     ;3 Ziffern ins Display
DispLeitw10:    LD      A,H
				AND     0Fh
				LD      (DE),A                  ;Ziffer ins Display
				ADD     HL,HL
				ADD     HL,HL                   ;HL * 16
				ADD     HL,HL
				ADD     HL,HL
				INC     DE                      ;eine Stelle weiter
				DJNZ    DispLeitw10             ;alle drei Ziffern durch? Nein =>
				LD      (C000h),A
				RET

;Fehlermeldung A für das Display zusammensetzen
MakeErrCode:    LD      HL,Display
				LD      (HL),0Fh                ;"F"
				INC     HL
				LD      (HL),0Eh                ;"E"
				INC     HL
				LD      (HL),10h                ;"H"
				INC     HL
				LD      (HL),11h                ;"L"
				LD      (IX+DPunkt),FBh         ;FBh (Bit 2 gelöscht): Punkt in der 4.Stelle setzen?!?
				LD      B,A
				AND     0Fh
				LD      (IX+Display+5),A        ;Fehlercode (untere Ziffer)
				LD      A,B
				RRCA
				RRCA
				RRCA
				RRCA
				AND     0Fh
				JR      NZ,MakeErrCode1         ;zweistellige Ziffer? Ja =>
				LD      A,1Fh                   ;Nein = Feld frei
MakeErrCode1:   LD      (IX+Display+4),A        ;erste Ziffer
				SET     4,(IX+Flags)            ;keine Zahl im Display
				LD      (C000h),A
				RET

;Eingabe (drei Ziffern) in eine binäre Zahl in HL wandeln
ConvertInput:   LD      HL,0                    ;Zahlenwert
				LD      A,(IY-2)                ;1.Ziffer holen
				CP      0                       ;= "0"?
				JR      Z,ConvertInput2         ;Ja! =>
				LD      B,A
				LD      DE,100
ConvertInput1:  ADD     HL,DE                   ;100 * Wert der 1.Ziffer addieren
				DJNZ    ConvertInput1
ConvertInput2:  LD      A,(IY-1)                ;2.Ziffer holen
				CP      0                       ;= "0"?
				JR      Z,ConvertInput4         ;Ja! =>
				LD      B,A
				LD      DE,10
ConvertInput3:  ADD     HL,DE                   ;10 * Wert der 2.Ziffer addieren
				DJNZ    ConvertInput3
ConvertInput4:  LD      E,(IY+0)                ;3.Ziffer
				LD      D,0
				ADD     HL,DE                   ;zum Wert addieren
				LD      (C000h),A
				RET

;binäre Zahl in IY nach BCDZahl in gepacktem BCD wandeln
MakeBCD:        ADD     IY,IY                   ;Zahl * 4
				ADD     IY,IY
				LD      B,14                    ;14 Bits (2 Bits sind durch * 4 weg)
				LD      HL,BinDezTableEnd-1     ;Multiplikationstabelle
				LD      DE,BCDZahl
				LD      (IX+BCDZahl),0
				LD      (IX+BCDZahl+1),0
MakeBCD1:       ADD     IY,IY                   ;Zahl * 2
				JR      C,MakeBCD2              ;Überlauf? => Ja!
				DEC     HL                      ;eine Stelle in der Mult-Tabelle zurück
				DEC     HL
				DJNZ    MakeBCD1                ;alle Stellen durch? Nein =>
				RET
MakeBCD2:       XOR     A                       ;A = 0
				LD      A,(DE)
				ADC     A,(HL)                  ;untere Bytes addieren
				DAA                             ;in gepacktes BCD wandeln
				LD      (DE),A                  ;und zurückschreiben
				DEC     HL
				INC     DE
				LD      A,(DE)                  ;obere Bytes addieren
				ADC     A,(HL)
				DAA                             ;in gepacktes BCD wandeln
				LD      (DE),A                  ;und zurückschreiben
				DEC     HL
				DEC     DE
				LD      (C000h),A
				DJNZ    MakeBCD1                ;zur nächsten Stelle
				RET

KeyAus2:        BIT     4,(IX+KLED+1)           ;"Kanal 1"
				JP      Z,KeyAus15              ;Ja =>
				BIT     5,(IX+KLED+1)           ;"Kanal 2"
				JP      Z,KeyAus16              ;Ja =>
				BIT     6,(IX+KLED+1)           ;"Licht"
				JR      NZ,KeyAus4              ;Nein =>
				BIT     2,(IX+KLED)             ;"Ein"
				JR      NZ,KeyAus3              ;Nein =>
				BIT     7,(IX+KLED)             ;"Setzen" an?
				LD      HL,LichtEin
				JP      Z,GetDispTime           ;Ja! =>
				JP      PrintTime
KeyAus3:        BIT     7,(IX+KLED)             ;"Setzen" an?
				LD      HL,LichtAus
				JP      Z,GetDispTime           ;Ja! =>
				JP      PrintTime
KeyAus4:        BIT     7,(IX+KLED+1)           ;"CO2"
				JR      NZ,KeyAus6
				BIT     2,(IX+KLED)             ;"Ein"
				JR      NZ,KeyAus5
				BIT     7,(IX+KLED)             ;"Setzen" an?
				LD      HL,CO2Ein
				JP      Z,GetDispTime           ;Ja! =>
				JP      PrintTime
KeyAus5:        BIT     7,(IX+KLED)             ;"Setzen" an?
				LD      HL,CO2Aus
				JP      Z,GetDispTime           ;Ja! =>
				JP      PrintTime
KeyAus6:        BIT     4,(IX+KLED)             ;"Zeit"
				JR      Z,KeyAus7               ;Ja =>
				LD      A,(IX+KLED)
				OR      0Ch                     ;Ein und Aus LEDs ausschalten
				LD      (IX+KLED),A
				RET
KeyAus7:        BIT     7,(IX+KLED)             ;"Setzen" an?
				JR      Z,KeyAus11              ;Ja! =>
				LD      HL,Display
				LD      B,6
KeyAus8:        LD      (HL),0                  ;Display löschen
				INC     HL
				DJNZ    KeyAus8
				LD      (IX+DPunkt),FEh         ;Dezimalpunkt in der 6.Ziffer an
				LD      A,(IX+AktSchaltzeit)    ;aktuelle Schaltzeit
				AND     0Fh
				INC     A
				CP      10
				JR      Z,KeyAus9
				LD      (IX+Display+5),A        ;1...9
				JR      KeyAus10
KeyAus9:        LD      (IX+Display+4),1        ;'10'
KeyAus10:       LD      (C000h),A
				RET
KeyAus11:       LD      A,0
				LD      B,4
				LD      HL,Display              ;die ersten 4 Ziffern müssen stets = 0 sein
KeyAus12:       OR      (HL)
				INC     HL
				DJNZ    KeyAus12
				JR      NZ,KeyAus13             ;wenn nicht => Fehler
				LD      IY,Display+5            ;Ptr auf die letzte Stelle vom Display
				CALL    ConvertInput            ;Zahl nach HL holen
				LD      A,L
				CP      0
				JR      Z,KeyAus13              ;Schaltzeiten zwischen 1 und 10
				CP      11
				JR      NC,KeyAus13
				DEC     A
				LD      (IX+AktSchaltzeit),A    ;aktuelle Schaltzeit merken
				SET     7,(IX+KLED)             ;"Setzen" aus
				LD      (C000h),A
				RET
KeyAus13:       LD      A,19h
				JP      MakeErrCode             ;ill. Nummer für die Schaltzeiten

				IF      !NewVersion
KeyAus14:       LD      A,20h
				JP      MakeErrCode             ;???
				ENDIF

KeyAus15:       LD      HL,Kanal1Uni            ;Kanal 1 Schaltzeiten
				JR      KeyAus17

KeyAus16:       LD      HL,Kanal2Uni            ;Kanal 2 Schaltzeiten
KeyAus17:       BIT     2,(IX+KLED)             ;"Ein" gedrückt?
				JR      Z,KeyAus18              ;Ja! =>
				LD      DE,30
				ADD     HL,DE                   ;Ausschaltzeiten
KeyAus18:       LD      DE,3
				LD      A,(IX+AktSchaltzeit)    ;aktuelle Schaltzeit holen
				CP      0
				JR      Z,KeyAus21              ;Schaltzeit gültig?
				CP      10                      ;Ja =>
				JR      C,KeyAus19
				LD      A,0
				LD      (IX+AktSchaltzeit),A    ;Schaltzeit löschen
				JR      KeyAus21
KeyAus19:       LD      B,A
KeyAus20:       ADD     HL,DE                   ;je 3 Bytes pro Schaltzeit
				DJNZ    KeyAus20
KeyAus21:       BIT     7,(IX+KLED)             ;"Setzen" an?
				JP      NZ,PrintTime            ;Nein! =>
				LD      A,(IX+Display)
				OR      (IX+Display+1)
				OR      (IX+Display+2)
				OR      (IX+Display+3)          ;0 als Uhrzeit eingegeben?
				OR      (IX+Display+4)
				OR      (IX+Display+5)
				JR      Z,KeyAus22              ;Ja =>
				JP      GetDispTime             ;Schaltzeit setzen
KeyAus22:       LD      A,(IX+DPunkt)           ;Dezimalpunkte?
				CP      FFh
				JP      NZ,GetDispTime          ;Ja =>
				INC     HL
				INC     HL
				SET     7,(HL)                  ;Alarmzeit ungültig machen
				LD      DE,30
				BIT     2,(IX+KLED)             ;"Ein"?
				JR      Z,KeyAus23              ;Ja =>
				XOR     A
				SBC     HL,DE                   ;Ptr auf Einschaltzeit
				JR      KeyAus24
KeyAus23:       ADD     HL,DE                   ;Ptr auf Ausschaltzeit
KeyAus24:       SET     7,(HL)                  ;entsprechende Zeit ebenfalls ausschalten
				SET     7,(IX+KLED)             ;"Setzen" aus
				LD      HL,Str6Minus            ;"------"
				JP      SetDisplayString

;"Redox"-Taste gedrückt
KeyRedox:       RES     0,(IX+Flags)            ;Zahleingabe aus
				BIT     5,(IX+KLED)             ;"Momentan"?
				JR      NZ,KeyRedox1            ;Nein =>
				LD      A,(IX+KLED)
				OR      9Fh                     ;Mometan und Manuell an lassen (Rest aus)
				LD      (IX+KLED),A
				LD      A,(IX+KLED+1)
				OR      F7h                     ;LEDs bis auf Redox ausschalten
				LD      (IX+KLED+1),A
				RES     3,(IX+KLED+1)           ;Redox anschalten
				RET
KeyRedox1:      BIT     7,(IX+KLED)             ;"Setzen" an?
				JR      Z,KeyRedox2             ;Ja! =>
				LD      A,(IX+KLED)
				OR      BFh                     ;bis auf Manuell alles ausschalten
				LD      (IX+KLED),A
				LD      A,(IX+KLED+1)
				OR      F7h                     ;bis auf Redox alles ausschalten
				LD      (IX+KLED+1),A
				RES     3,(IX+KLED+1)           ;Redox anschalten
				LD      L,(IX+SollRedox)        ;Soll-Redoxwert
				JP      DispRedox               ;Potential anzeigen
KeyRedox2:      RES     3,(IX+KLED+1)           ;Redox anschalten
				BIT     4,(IX+KLED+1)           ;"Kanal 1" an
				JR      NZ,KeyRedox3            ;Nein =>
				LD      (IX+Uni1Flag),AAh       ;Kanal 1 auf Redox-Regelung schalten
				SET     7,(IX+KLED)             ;"Setzen" aus
				LD      HL,StrrErE              ;" rE-rE"
				JP      SetDisplayString
KeyRedox3:      CALL    GetNumInput             ;Eingabe holen
				LD      A,D
				CP      0
				JR      Z,KeyRedox4             ;0 oder 1 Dezimalpunkt in der Eingabe
				CP      1
				JR      Z,KeyRedox5
				LD      A,23h
				JP      MakeErrCode             ;mehrere Dezimalpunkte bei Redox-Eingabe
KeyRedox4:      LD      IY,InputBuf+7
				LD      E,5
KeyRedox5:      LD      B,E
				DEC     B
				JR      Z,KeyRedox7
				LD      B,1
				LD      A,0
				PUSH    IY
KeyRedox6:      OR      (IY-3)                  ;Ziffern vor der erwarteten 1.Ziffer zusammen'OR'n
				DEC     IY
				DJNZ    KeyRedox6
				POP     IY
				CP      0
				JR      Z,KeyRedox7
				LD      A,21h
				JP      MakeErrCode             ;zu großer Redox-Wert eingegeben
KeyRedox7:      CALL    ConvertInput
				BIT     0,L                     ;Redox-Wert gerade?
				JR      Z,KeyRedox8             ;Ja =>
				INC     HL                      ;ansonsten aufrunden
KeyRedox8:      LD      A,L
				OR      H                       ;Redox-Wert = 0?
				JR      NZ,KeyRedox9            ;Nein =>
				LD      A,22h
				JP      MakeErrCode             ;0 Volt Redox-Wert eingegeben
KeyRedox9:      LD      DE,509                  ;509mV = maximaler Redox-Wert
				XOR     A
				PUSH    HL
				SBC     HL,DE
				POP     HL
				JR      C,KeyRedox10
				LD      A,21h
				JP      MakeErrCode             ;Redox-Wert zu groß!
KeyRedox10:     RR      H                       ;Redox-Wert / 2
				RR      L
				LD      (IX+SollRedox),L        ;Soll-Redoxwert setzen
				CALL    CalcSollChecksum        ;Prüfsumme über die Sollwerte errechnen
				LD      (SollChecksum),DE       ;und merken
				SET     7,(IX+KLED)             ;"Setzen" aus
				JP      DispRedox               ;Potential anzeigen

;"Leitwert"-Taste gedrückt
KeyLeitwert:    RES     0,(IX+Flags)            ;Zahleingabe aus
				BIT     5,(IX+KLED)             ;"Momentan"?
				JR      NZ,KeyLeitwert1         ;Nein =>
				LD      A,(IX+KLED)
				OR      9Fh                     ;Mometan und Manuell an lassen (Rest aus)
				LD      (IX+KLED),A
				LD      A,(IX+KLED+1)
				OR      FBh                     ;LEDs bis auf Leitwert ausschalten
				LD      (IX+KLED+1),A
				RES     2,(IX+KLED+1)           ;Leitwert anschalten
				LD      (C000h),A
				RET
KeyLeitwert1:   BIT     7,(IX+KLED)             ;"Setzen" an?
				JR      Z,KeyLeitwert3          ;Ja! =>
				LD      A,(IX+KLED)
				OR      3Fh                     ;bis auf Manuell und Setzen alles ausschalten
				LD      (IX+KLED),A
				LD      A,(IX+KLED+1)
				OR      EFh                     ;bis auf Kanal 1 alles ausschalten
				LD      (IX+KLED+1),A
				RES     2,(IX+KLED+1)           ;Leitwert anschalten
				IN      C,(C)
				BIT     5,C                     ;Süßwasser/Meerwasser-Schalter abfragen
				JR      Z,KeyLeitwert2          ;Meerwasser =>
				LD      L,(IX+SollLeitwertS)    ;Soll-Leitwert (Süßwasser)
				JP      DispLeitw
KeyLeitwert2:   LD      L,(IX+SollLeitwertM)    ;Soll-Leitwert (Meerwasser)
				JP      DispLeitw
KeyLeitwert3:   BIT     5,(IX+KLED+1)           ;"Kanal 2"?
				JR      NZ,KeyLeitwert4         ;Nein =>
				RES     2,(IX+KLED+1)           ;Leitwert an
				LD      (C000h),A
				RET
KeyLeitwert4:   RES     2,(IX+KLED+1)           ;Leitwert an
				LD      A,(IX+KLED)
				OR      3Fh                     ;bis auf Manuell und Setzen alles ausschalten
				LD      (IX+KLED),A
				LD      A,(IX+KLED+1)
				OR      FBh                     ;bis auf Leitwert alles ausschalten
				LD      (IX+KLED+1),A
				IN      C,(C)
				BIT     5,C                     ;Süßwasser/Meerwasser-Schalter abfragen
				JR      Z,KeyLeitwert15         ;Meerwasser =>
				LD      A,(IX+DPunkt)           ;Dezimalpunkt
				CP      DFh                     ;an 2.Stelle?
				JR      NZ,KeyLeitwert5         ;Nein =>
				LD      A,(IX+Display)
				CP      5                       ;5?
				JR      C,KeyLeitwert13
				LD      L,1
				JR      KeyLeitwert14
KeyLeitwert5:   CALL    GetNumInput
				DEC     IY
				LD      A,D
				CP      0
				JR      Z,KeyLeitwert6          ;0 oder 1 Dezimalpunkt?
				CP      1                       ;Nein =>
				JR      Z,KeyLeitwert7
				LD      A,26h
				JP      MakeErrCode             ;zu viele Dezimalpunkte beim Leitwert
KeyLeitwert6:   LD      IY,InputBuf+6
				LD      B,2
				JR      KeyLeitwert8
KeyLeitwert7:   LD      A,E
				SUB     4
				JR      Z,KeyLeitwert10
				JR      C,KeyLeitwert10
				LD      B,A
KeyLeitwert8:   LD      A,0
				PUSH    IY
KeyLeitwert9:   OR      (IY-3)                  ;Ziffern vor der erwarteten Eingabe zusammen 'OR'n
				DEC     IY
				DJNZ    KeyLeitwert9
				POP     IY
				CP      0
				JR      Z,KeyLeitwert10
				LD      A,24h
				JP      MakeErrCode             ;Leitwert zu groß!
KeyLeitwert10:  CALL    ConvertInput
				LD      A,(IY+1)                ;4.Ziffer
				CP      5                       ;>= 5?
				JR      C,KeyLeitwert11         ;Nein =>
				INC     HL                      ;aufrunden
KeyLeitwert11:  LD      DE,255
				PUSH    HL
				XOR     A
				SBC     HL,DE                   ;Leitwert >= 255? (2550 µS)
				POP     HL
				JR      C,KeyLeitwert12         ;Nein =>
				LD      A,24h
				JP      MakeErrCode             ;Leitwert zu groß!
KeyLeitwert12:  LD      A,L
				OR      H                       ;Leitwert = 0?
				JR      NZ,KeyLeitwert14        ;Nein =>
KeyLeitwert13:  LD      A,25h
				JP      MakeErrCode             ;Leitwert zu klein
KeyLeitwert14:  LD      (IX+SollLeitwertS),L    ;Soll-Leitwert (Süßwasser) setzen
				CALL    CalcSollChecksum        ;Prüfsumme über die Sollwerte errechnen
				LD      (SollChecksum),DE       ;und merken
				SET     7,(IX+KLED)             ;"Setzen" aus
				JP      DispLeitw

;Leitwert für Meerwasser:
KeyLeitwert15:  CALL    GetNumInput
				LD      A,D
				CP      0
				JR      Z,KeyLeitwert16
				CP      1
				JR      Z,KeyLeitwert17
				LD      A,26h
				JP      MakeErrCode             ;Dezimalpunktfehler beim Leitwert
KeyLeitwert16:  LD      IY,InputBuf+7
KeyLeitwert17:  LD      B,E
				LD      A,0
				INC     IY
				PUSH    IY
KeyLeitwert18:  OR      (IY-3)
				DEC     IY
				DJNZ    KeyLeitwert18
				POP     IY
				CP      0
				JR      Z,KeyLeitwert19
				LD      A,24h
				JP      MakeErrCode             ;Leitwert zu groß
KeyLeitwert19:  CALL    ConvertInput
				LD      A,(IY+1)                ;3.Ziffer
				CP      5                       ;>= 5?
				JR      C,KeyLeitwert20         ;Nein =>
				INC     HL                      ;aufrunden
KeyLeitwert20:  LD      DE,353
				XOR     A
				SBC     HL,DE                   ;35.3mS abziehen
				JR      NC,KeyLeitwert21        ;Unterlauf? Nein =>
				LD      A,25h
				JP      MakeErrCode             ;Leitwert zu klein
KeyLeitwert21:  ADC     HL,DE                   ;wieder dazuaddieren
				LD      DE,601
				XOR     A
				SBC     HL,DE                   ;60.1mS abziehen
				JR      C,KeyLeitwert22         ;Überlauf? Nein =>
				LD      A,24h
				JP      MakeErrCode             ;Leitwert zu groß
KeyLeitwert22:  ADC     HL,DE
				LD      DE,350                  ;35.0mS abziehen
				SBC     HL,DE
				LD      (IX+SollLeitwertM),L    ;Soll-Leitwert (Meerwasser)
				CALL    CalcSollChecksum        ;Prüfsumme über die Sollwerte errechnen
				LD      (SollChecksum),DE       ;und merken
				SET     7,(IX+KLED)             ;"Setzen" aus
				JP      DispLeitw

;String ab HL ins Display übertragen
SetDisplayString:
				LD      BC,6
				LD      DE,Display
				LDIR                            ;String ins Display
				INC     DE
				INC     DE
				INC     DE
				LDI                             ;Dezimalpunkte übertragen
				SET     4,(IX+Flags)            ;keine Zahl im Display
				RET

;Kanal 1-Regelung
Kanal1Regel:
				LD      A,(IX+Uni1Flag)
				CP      55h                     ;Universal-Timer?
				JP      Z,UniTimer              ;Ja =>
				CP      AAh                     ;Redox-Regelung?
				JR      Z,Kanal1Regel1          ;Ja =>
				SCF
				RET
Kanal1Regel1:   CALL    UniTimer
				RET     C                       ;nichts gefunden =>
				LD      A,(IX+SollRedox)        ;Soll-Redoxwert
				BIT     3,(IX+WarnLED)          ;Kanal 1-LED an?
				JR      NZ,Kanal1Regel2         ;Nein =>
				ADD     A,1                     ;Soll-Wert um 0.5µV erhöhen, wenn Regelung bereits an
Kanal1Regel2:   CP      (IX+IstRedox)           ;mit Sollwert vergleichen
				RET

;Kanal 2-Regelung
Kanal2Regel:
				LD      A,(IX+Uni2Flag)
				CP      55h                     ;Universal-Timer?
				JP      Z,UniTimer              ;Ja =>
				CP      AAh                     ;Leitwert-Regelung?
				JR      Z,Kanal2Regel1          ;Ja =>
				SCF
				RET
Kanal2Regel1:   CALL    UniTimer
				RET     C                       ;nichts gefunden =>
				LD      A,(IX+IstTemp)          ;Ist-Temp-Wert
				CP      FFh
				JR      Z,Kanal2Regel2          ;außerhalb des Meßbereiches?
				CP      0
				JR      Z,Kanal2Regel2          ;Ja =>
				LD      D,(IX+LeitwertKomp)     ;kompensierter Leitwert
				JR      Kanal2Regel3
Kanal2Regel2:   LD      D,(IX+IstLeitw)         ;Ist-Leitwert
Kanal2Regel3:   IN      C,(C)
				BIT     5,C                     ;Süßwasser/Meerwasser-Schalter abfragen
				JR      Z,Kanal2Regel4          ;Meerwasser =>
				LD      B,(IX+SollLeitwertS)    ;Soll-Leitwert (Süßwasser)
				JR      Kanal2Regel5
Kanal2Regel4:   LD      B,(IX+SollLeitwertM)    ;Soll-Leitwert (Meerwasser)
Kanal2Regel5:   LD      A,(IX+Uni2Flag2)
				CP      AAh                     ;Aus-Regelung
				JR      Z,Kanal2Regel8
				CP      55h                     ;Ein-Regelung
				JR      Z,Kanal2Regel6
				SCF                             ;Regelung illegal => raus
				RET
Kanal2Regel6:   LD      A,B
				BIT     0,(IX+WarnLED)          ;Kanal 2-LED an?
				JR      Z,Kanal2Regel7          ;Ja =>
				ADD     A,2                     ;Soll-Wert um 2 erhöhen, wenn Regelung bereits an
Kanal2Regel7:   CP      D                       ;mit Sollwert vergleichen
				CCF
				RET
Kanal2Regel8:   LD      A,B
				BIT     0,(IX+WarnLED)          ;Kanal 2-LED an?
				JR      NZ,Kanal2Regel9         ;Nein =>
				ADD     A,2                     ;Soll-Wert um 2 erhöhen, wenn Regelung bereits an
Kanal2Regel9:   CP      D                       ;mit Sollwert vergleichen
				RET

;Temperatur-Kompensation des Leitwertes errechnen (er weicht etwa 2% pro Grad Temperatur-Änderung
;von 25° vom Sollwert ab)
TempKomp:       LD      HL,65
				LD      (Mult24),HL
				LD      C,(IX+IstTemp)          ;Ist-Temp-Wert (= (Temperatur-10.0°)*10)
				CALL    Mult24Bit
				LD      HL,42518
				LD      DE,(Mult24Erg)          ;DE = 42518 - Ist-Temp * 65 (Ist-Temp = 25°: DE = 8000h = 1)
				XOR     A
				SBC     HL,DE                   ;DE: Bit 15 = 1, Bit 14...0 = Nachkommastellen
				LD      (Mult24),HL             ;als neuen Multiplikator merken
				PUSH    HL
				LD      C,(IX+IstLeitw)         ;Ist-Leitwert als Multiplikant
				CALL    TempKomp3               ;= 2 * Kompensations-Wert (= ganzer Anteil im oberen Byte!)
				POP     HL                      ;Leitwert = Mess-Leitwert * (1 - 2% * (Temp - 25°))
				LD      A,(IX+LeitwertKomp)     ;Kompensations-Wert holen
				CP      FFh
				RET     Z                       ;ungültig => raus
				CP      0
				RET     Z
				IN      C,(C)
				BIT     5,C                     ;Süßwasser/Meerwasser-Schalter abfragen
				RET     NZ                      ;Süßwasser => raus
				LD      C,175
				LD      (Mult24),HL
				CALL    Mult24Bit               ;(Multiplikator * 175) * 2
				LD      HL,(Mult24Erg+1)
				ADD     HL,HL
				LD      A,H
				SUB     175
				ADD     A,A                     ;((Erg/256) - 175) * 2
				JP      P,TempKomp1             ;Positiv =>
				CPL                             ;negieren
				LD      B,A
				LD      A,(IX+LeitwertKomp)     ;Temp.Kompensation holen
				SUB     B
				JR      NC,TempKomp2            ;Wert groß genug? Ja =>
				LD      A,0                     ;Unterlauf der Kompensation!
				JR      TempKomp2
TempKomp1:      ADD     A,(IX+LeitwertKomp)     ;jetzige Temp.Kompensation dazu
				JR      NC,TempKomp2            ;Überlauf? Nein =>
				LD      A,FFh
TempKomp2:      LD      (IX+LeitwertKomp),A     ;Temp.Kompensation setzen
				RET

TempKomp3:      CALL    Mult24Bit
				LD      HL,(Mult24Erg+1);16-Bit Kompensation holen
				BIT     7,H                     ;Bit 15 gesetzt (Wert zu groß)
				JR      Z,TempKomp5             ;Nein =>
TempKomp4:      LD      (IX+LeitwertKomp),FFh   ;Temp.Kompensation ungültig!
				RET
TempKomp5:      ADD     HL,HL                   ;Wert * 2
				LD      A,H                     ;oberes Byte nehmen
				CP      FFh                     ;ungültig?
				JR      Z,TempKomp4             ;Ja =>
				BIT     7,L                     ;Bit 7 gesetzt?
				JR      Z,TempKomp6             ;Nein =>
				INC     A                       ;aufrunden (auf 8 Bit)
				CP      FFh                     ;ungültig?
				JR      Z,TempKomp4             ;Ja =>
TempKomp6:      LD      (IX+LeitwertKomp),A     ;Temp.Kompensation setzen
				RET

;24 Bit Multiplikation (Mult24...Mult24+2) * C = (Mult24Erg...Mult24Erg+2)
Mult24Bit:      LD      (C000h),A
				LD      B,4
				LD      HL,Mult24Erg+2
Mult24Bit1:     LD      (HL),0                  ;Ergebniss und Buffer löschen
				DEC     HL
				DJNZ    Mult24Bit1
				LD      B,8                     ;8 Bits
Mult24Bit2:     LD      HL,Mult24               ;Multiplikator
				LD      DE,Mult24Erg            ;Ergebnis
				RRC     C                       ;Temperatur nach rechts ins Carry schieben
				JR      NC,Mult24Bit3

				LD      A,(DE)
				ADD     A,(HL)
				LD      (DE),A
				INC     HL                      ;(DE) = (DE)+(HL)   (16 Bit Addition mit 24 Bit Ergebnis)
				INC     DE
				LD      A,(DE)
				ADC     A,(HL)
				LD      (DE),A
				INC     HL
				INC     DE
				LD      A,(DE)
				ADC     A,(HL)
				LD      (DE),A

				LD      HL,Mult24
Mult24Bit3:     SLA     (HL)
				INC     HL
				RL      (HL)                    ;Summand * 2 (24 Bit)
				INC     HL
				RL      (HL)
				DJNZ    Mult24Bit2              ;8 mal durchlaufen (8 Bit Multiplikant)
				LD      (C000h),A
				RET

;Eingabe aus dem Display holen und Dezimalpunkte auswerten
;D-Register = Anzahl der Punkte
;IY zeigt auf die Nachkommastellen
GetNumInput:    LD      A,0
				LD      DE,InputBuf
				LD      (DE),A                  ;Byte 1 und 2 im Buffer löschen
				INC     DE
				LD      (DE),A
				INC     DE
				LD      HL,Display
				LD      BC,6
				LDIR                            ;Anzeige in den Buffer (Byte 3...8) übertragen
				LD      (DE),A                  ;Byte 9 und 10 im Buffer löschen
				INC     DE
				LD      (DE),A
				LD      IY,InputBuf+7           ;Ptr auf die letzte Ziffer
				LD      C,(IX+DPunkt)           ;Dezimalpunkte holen
				LD      D,0                     ;Anzahl der Punkte = 0
				LD      B,6                     ;maximal 6 Punkte auswerten
GetNumInput1:   LD      E,B                     ;Position des _letzten_ Punktes (= 6.Stelle)
				BIT     0,C                     ;Punkt gesetzt?
				JR      Z,GetNumInput2          ;Ja (low-active!) => Nachkommastellenanfang gefunden
				RR      C                       ;Punkte eine Position nach rechts
				DEC     IY                      ;IY zeigt auf die letzte Vorkommastelle
				DJNZ    GetNumInput1            ;weiter nach Dezimalpunkt suchen
				RET
GetNumInput2:   INC     D                       ;ein Dezimalpunkt mehr...
GetNumInput3:   DJNZ    GetNumInput4            ;alle Punktpositionen durch? Nein =>
				RET
GetNumInput4:   RR      C                       ;Punkte eine Position nach rechts
				BIT     0,C                     ;Punkt gesetzt?
				JR      NZ,GetNumInput3         ;Nein (low-active!) => (nächste Position)
				JR      GetNumInput2            ;Punkt zählen

StrrErE:        DEFB 1Fh,13h,0Eh,1Ch,13h,0Eh,F6h    ;" rE-rE"
StrLrEIN:       DEFB 11h,13h,1Ch,0Eh,01h,1Eh,EFh    ;"Lr-EIN"
StrLrAUS:       DEFB 11h,13h,1Ch,0Ah,14h,05h,EFh    ;"Lr-AUS"
StrLrUNI1:      DEFB 1Fh,14h,1Eh,01h,1Ch,01h,FBh    ;" UNI-1"
StrLrUNI2:      DEFB 1Fh,14h,1Eh,01h,1Ch,02h,FBh    ;" UNI-2"
Str6Space:      DEFB 1Fh,1Fh,1Fh,1Fh,1Fh,1Fh,FFh    ;"      "
				IF NewVersion
StrFEHL16:      DEFB 0Fh,0Eh,10h,11h,01h,06h,FBh    ;"FEHL16"
				ELSE
StrFEHL16:      DEFB 0Fh,0Eh,10h,11h,01h,06h,FFh    ;"FEHL16"
				ENDIF
Str6Minus:      DEFB 1Ch,1Ch,1Ch,1Ch,1Ch,1Ch,FFh    ;"------"
				IF NewVersion
StrFEHL15:      DEFB 0Fh,0Eh,10h,11h,01h,05h,FBh    ;"FEHL15"
				ELSE
StrFEHL15:      DEFB 0Fh,0Eh,10h,11h,01h,05h,FFh    ;"FEHL15"
				ENDIF

;Versionsdatum im LED-Format
				IF NewVersion
VersionNoDisp:  DEFB 8Eh,BFh,FFh,79h,90h,C0h        ;"F- 1.90"
				ELSE
VersionNoDisp:  DEFB 8Eh,BFh,FFh,79h,80h,90h        ;"F- 1.89"
				ENDIF

;Font => LED-Tabelle
;                     0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
FontLEDTable:   DEFB C0h,F9h,A4h,B0h,99h,92h,82h,F8h,80h,90h,88h,83h,C6h,A1h,86h,8Eh
				DEFB 89h,C7h,8Ch,AFh,C1h,8Dh,E3h,ABh,9Ch,A3h,87h,FEh,BFh,F7h,C8h,FFh
;                     H   L   P   r   U   µ   u   n   °   o  /F  /A   -   _   N  ' '

;Rechentabelle Binär => Dezimal
BinDezTable:    DEFW 0001h,0002h,0004h,0008h,0016h,0032h,0064h
				DEFW 0128h,0256h,0512h,1024h,2048h,4096h,8192h
BinDezTableEnd:

;Tastaturtabelle
TastaturTab:
;                     "."      "3"   "6"   "9"   "0"   "2"   "5"   "8"   "*"      "1"   "4"   "7"
				DEFW KeyPunkt,8003h,8006h,8009h,8000h,8002h,8005h,8008h,KeyStern,8001h,8004h,8007h
;                     "Re"     "Lw"        "Tp"          "pH"  "CO2"  "Li"    "K2"       "K1"
				DEFW KeyRedox,KeyLeitwert,KeyTemperatur,KeyPh,KeyCO2,KeyLicht,KeyKanal2,KeyKanal1
;                     "Aus"  "Ein"  "Nacht"  "Tag"  "Setzen"  "Manuell"  "Momentan"  "Zeit"
				DEFW KeyAus,KeyEin,KeyNacht,KeyTag,KeySetzen,KeyManuell,KeyMomentan,KeyZeit

SpezKeyTable:   DEFB FFh,FEh,FDh,FFh,FFh,FFh,FEh    ;"0" "1" "Setzen" - Seriennummer (= 283062)
				DEFB PrintSerial>>8,PrintSerial
				DEFB FBh,FEh,FFh,FFh,FFh,FFh,FEh    ;"0" "6" "Setzen" - Soll-ROM-Prüfsumme (= 5Fd6)
				DEFB PrintROMChksum>>8,PrintROMChksum
				DEFB FDh,FEh,FFh,FFh,FFh,FFh,FEh    ;"0" "3" "Setzen" - Produktionsdatum (= 692)
				DEFB PrintProdDatum>>8,PrintProdDatum
				DEFB FFh,FEh,FBh,FFh,FFh,FFh,FEh    ;"0" "4" "Setzen" - (1FF9h) = 12050
				DEFB PrintUnknown>>8,PrintUnknown
				DEFB FFh,FEh,F7h,FFh,FFh,FFh,FEh    ;"0" "7" "Setzen" - Errechnete ROM-Prüfsumme
				DEFB PrintRealChksum>>8,PrintRealChksum
SpezKeyLicht:   DEFB FFh,FEh,FFh,FFh,FDh,FFh,FEh    ;"0" "Licht" "Setzen" - alle LEDs anschalten
				DEFB CheckAllLED>>8,CheckAllLED
				DEFB FFh,FEh,FFh,FFh,FFh,FDh,FEh    ;"0" "Ein" "Setzen" - alle Relais testen
				DEFB CheckDosen>>8,CheckDosen
				IF  NewVersion
				DEFB FFh,FEh,FFh,FFh,FFh,FFh,FAh    ;"0" "Momentan" "Setzen" - Computer zurücksetzen
				DEFB ResetComputer>>8,ResetComputer
				ENDIF
				DEFB 00h

PrintSerial:    CALL    KeyStern
				LD      HL,SerialNo             ;Seriennummer des Gerätes (6 BCD-Stellen)
				CALL    PrintTime
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				RET

PrintROMChksum: CALL    KeyStern
				LD      HL,ROMChecksum          ;Prüfsumme über das ROM (binäres Wort)
				CALL    PrintTime
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				RET

PrintProdDatum: CALL    KeyStern
				LD      HL,ProduktDatum         ;Produktionsdatum (oberes Byte: Monat, unteres Byte: Jahr)
				CALL    PrintTime
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				RET

PrintUnknown:   CALL    KeyStern
				LD      HL,Unknown              ;???
				CALL    PrintTime
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				RET

PrintRealChksum:CALL    KeyStern
				LD      HL,CalcChecksum
				CALL    PrintTime
				LD      (IX+DPunkt),FFh         ;Dezimalpunkte aus
				RET

;_ALLE_ LEDs am Bedienteil an
CheckAllLED:    LD      HL,KLED
				LD      B,9
CheckAllLED1:   LD      (HL),0                  ;2000h-2008h löschen => alle LEDs an
				INC     HL
				DJNZ    CheckAllLED1
CheckAllLED2:   LD      HL,SpezKeyLicht
				LD      DE,KeyboardMatrix
				LD      B,7
CheckAllLED3:   LD      A,(DE)
				OR      F0h
				CP      (HL)
				JR      NZ,CheckAllLED4         ;anlassen, solange die Tastenkombination gedrückt wird
				INC     HL
				INC     DE
				DJNZ    CheckAllLED3
				LD      (C000h),A
				JR      CheckAllLED2
CheckAllLED4:   CALL    KeyStern                ;Display löschen
				SET     6,(IX+KLED)             ;Manuell-LED ausschalten
				RET

;_ALLE_ Steckdosen an/auschalten
CheckDosen:     IF NewVersion
				IN      A,(C)                   ;Sperre gesetzt?
				BIT     4,A                     ;Nein! =>
				JR      NZ,CheckDosen0
				JP      KeySetzen1              ;Fehler 99!
				ENDIF
CheckDosen0:    LD      A,(004Eh)               ;??? sollte wohl (IX+Steckdosen) heissen (ist eh unnötig)
				LD      C,A
				LD      A,0
				CALL    SetDoseStatus           ;alle Steckdosen aus
				LD      B,3
				LD      A,1
CheckDosen1:    CALL    SetDoseStatus           ;3 Steckdosen (CO2, Heizung, Licht) nacheinander an
				SLA     A
				DJNZ    CheckDosen1
				SLA     A
				CALL    SetDoseStatus           ;4.Steckdose (Kanal 1) an
				SRL     A
				CALL    SetDoseStatus           ;5.Steckdose (Kanal 2) an
				LD      A,1Fh
				CALL    SetDoseStatus           ;alle Steckdosen aus
				LD      A,C
				LD      (004Eh),A               ;??? sollte wohl (IX+Steckdosen) heissen (ist eh unnötig)
				RET

SetDoseStatus:  LD      (E000h),A               ;Port schreiben
				PUSH    BC
				LD      B,0
SetDoseStatus1: LD      (C000h),A               ;kleine Pause
				HALT
				DJNZ    SetDoseStatus1
				POP     BC
				RET

;Computer zurücksetzen
ResetComputer:  IF NewVersion
				IN      A,(C)                   ;Sperre gesetzt?
				BIT     4,A                     ;Nein! =>
				JR      NZ,ResetComputer1
				JP      KeySetzen1              ;Fehler 99!
ResetComputer1: JP      ResetVars
				ENDIF

;Sprungtabelle für die Ausgabe eines Meßwertes im Akku
DoDispMessTab:  DEFW DispPh,DispTemp,DispLeitw,DispRedox

				IF !NewVersion
; 40h,"PAUL UND ULLI P0PPEN HANNA UND ELLI",42h,"SIE HABEN SPASS AN BUSEN UND PO",42h,42h,"OO LA-LA",41h
MsgFutura:      DEFB 40h,12h,0Ah,14h,11h,1Fh,14h,17h,0Dh,1Fh,14h,11h,11h,01h,1Fh,12h
				DEFB 00h,12h,12h,0Eh,1Eh,1Fh,10h,0Ah,1Eh,1Eh,0Ah,1Fh,14h,17h,0Dh,1Fh
				DEFB 0Eh,11h,11h,01h,42h,05h,01h,0Eh,1Fh,10h,0Ah,0Bh,0Eh,1Eh,1Fh,05h
				DEFB 12h,0Ah,05h,05h,1Fh,0Ah,17h,1Fh,0Bh,14h,05h,0Eh,1Eh,1Fh,14h,17h
				DEFB 0Dh,1Fh,12h,00h,42h,42h,00h,10h,1Fh,11h,0Ah,1Ch,11h,0Ah,41h
; 40h,"HALLO",42h,"SIE HABEN PAUSE",41h
MsgPause:       DEFB 40h,10h,0Ah,11h,11h,00h,42h,05h,01h,0Eh,1Fh,10h,0Ah,0Bh,0Eh,1Eh
				DEFB 1Fh,12h,0Ah,14h,05h,0Eh,41h
; 40h,"HUI-",42h,"DAS S0LL ABER SEHR HEISS SEIN",41h
MsgHeiss:       DEFB 40h,10h,14h,01h,1Ch,42h,0Dh,0Ah,05h,1Fh,05h,00h,11h,11h,1Fh,0Ah
				DEFB 0Bh,0Eh,13h,1Fh,05h,0Eh,10h,13h,1Fh,10h,0Eh,01h,05h,05h,1Fh,05h
				DEFB 0Eh,01h,17h,41h
; 40h,"HUI-",42h,"DAS S0LL ABER SEHR SAUER SEIN",41h
MsgSauer:       DEFB 40h,10h,14h,01h,1Ch,42h,0Dh,0Ah,05h,1Fh,05h,00h,11h,11h,1Fh,0Ah
				DEFB 0Bh,0Eh,13h,1Fh,05h,0Eh,10h,13h,1Fh,05h,0Ah,14h,0Eh,13h,1Fh,05h
				DEFB 0Eh,01h,17h,41h
; 40h,"HUI-",42h,"DA5 S0LL ABER SEHR BASISCH SEIN",41h
MsgBasis:       DEFB 40h,10h,14h,01h,1Ch,42h,0Dh,0Ah,05h,1Fh,05h,00h,11h,11h,1Fh,0Ah
				DEFB 0Bh,0Eh,13h,1Fh,05h,0Eh,10h,13h,1Fh,0Bh,0Ah,05h,01h,05h,0Ch,10h
				DEFB 1Fh,05h,0Eh,01h,17h,41h

MsgMessdaten:   DEFM "************************** Messdatenerfassung **************************"
				DEFB 13,10,10
				DEFM "(c) By FUTURA Aquarien-Systeme, KLEVE, Kalkarer Str.24  Tel. 02821/17574"
				DEFB 13,10,10,3,'$'
MsgEscH4Lf:     DEFB 1Bh,'H',10,10,10,10,'$'
MsgEscHEscJ:    DEFB 1Bh,'H',1Bh,'J','$'
Msg6Space:      DEFM "      "
				DEFB 13,10,10,'$'
MsgZeit:        DEFM "ZEIT   : $"
MsgPhWert:      DEFM "PH-WERT: $"
MsgGrad:        DEFM "GRAD   : $"
MsgMikroS:      DEFM "MIKRO-S: $"
MsgMilliS:      DEFM "MILLI-S: $"
MsgMilliV:      DEFM "MILLI-V: $"
MsgFehl:        DEFM "FEHL.$"
MsgCopyright:   DEFM "Copyrigt (c) 1989 by Ulrich Forke & FUTURA Aquariensysteme"
				DEFB 13,10
				DEFM "4190 Kleve, Deutschland"
				DEFB 13,10
				DEFM "Die Verwendung dieses Programms oder Teilen davon ist nicht gestattet !"
				DEFB 13,10
				ENDIF

				ORG ROMTop
SerialNo:       DEFB 62h,30h,28h        ;Seriennummer (= 283062)
ROMChecksum:    DEFB D6h,5Fh,00h        ;Prüfsumme über das ROM, "5Fd6"
ProduktDatum:   DEFB 92h,06h,00h        ;Produktionsdatum 6.92
Unknown:        DEFB 50h,20h,01h        ;??? (= 12050)
				PRINT   "Ende..."
