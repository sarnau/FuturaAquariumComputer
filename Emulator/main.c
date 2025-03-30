#include <stdio.h>#include <stdlib.h>#include <string.h>#include <assert.h>#include "Z80.h"UInt8		*CORE;		// Ptr auf den 64kb Adre�raum des Z80Z80			zregs;static void MyDelay(int value){int		i;	for(i=0; i<value; i++)		SystemTask();}UInt8		gRTC[16] = { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };UInt8		gDA[4] = { 80, 90, 100, 110 };UInt8		gDosen;UInt8		gReadIndex;UInt8		gBitcount;typedef enum {	WaitingInit,	WaitingStart,	WaitingBit0,	WaitingBit1,	WaitingData,	WaitingInput,	WaitingHandshake} Waiting;Waiting	gSComm;UInt8		gSCommCount;UInt8		g8000Index;UInt8		g6000Flag;UInt8		gIOMatrix[20];UInt8		gIOMatrixNotChanged[20];WindowPtr	gWindow;void		PatchZ80(register Z80 *R){#pragma unused(R)}void		OutZ80(register word Port,register byte Value){	printf("OUT($%4.4lx, $%2.2lx)\n", (UInt32)Port, (UInt32)Value);fflush(stdout);}byte		InZ80(register word Port){#pragma unused(Port)	if(g8000Index) {	// Tastatur auslesen?		return gIOMatrix[g8000Index];	} else {		if(gSComm == WaitingInput) {			if(gBitcount++ == 0) return 0x00;			return ((gDA[gReadIndex] >> (9 - gBitcount)) != 0) ? 0x20 : 0x00;		} else {		//	printf("IN($%4.4lx)\n", (UInt32)Port);fflush(stdout);			return 0xff;		}	}}/*INLINE*/ byte RdZ80(word A){	if(A < 0x2800)		return CORE[A];	switch(A) {	case 0x4000:	// Read RTC Register					return gRTC[CORE[0x4001]] | 0xf0;	default:					printf("PEEK($%4.4lx) = $%2.2lx\n", (UInt32)A, (long)CORE[A]);fflush(stdout);					return CORE[A];	}}void		WrZ80(register word Addr,register byte Value){	if(Addr < 0x2000) return;	// <8kb ist ROM	CORE[Addr] = Value;				// den Rest k�nnen wir direkt wegschreiben	if(Addr < 0x2800)	return;	// dann folgen 2kb RAM	switch(Addr) {	case 0x4001:	// Select RTC Register					break;	case 0x4002:	// Write RTC Register					gRTC[CORE[0x4001]] = Value;					break;	case 0x6000:					g6000Flag = true;					break;	case 0x8000:					g8000Index++;					break;	case 0xa000:					if(g6000Flag) {						g6000Flag = false;						if(gIOMatrix[g8000Index] != Value) {							gIOMatrix[g8000Index] = Value;							gIOMatrixNotChanged[g8000Index] = false;						}					}					g8000Index = 0;					break;	case 0xc000:	// Watchdog					break;	case 0xe000:	// Serielle Kommunikation					gDosen = Value;					if(gDosen & 0x80) {						gSComm = WaitingInit;						gSCommCount = 0;						gBitcount = 0;						break;					}					gSCommCount++;					switch(gSComm) {					case WaitingInit:								if(gDosen & 0x20) {									gSComm = WaitingStart;									gSCommCount = 0;								}								break;					case WaitingStart:								if(gSCommCount == 3) {									gSComm = WaitingBit0;									gSCommCount = 0;								}								break;					case WaitingBit0:								if(gSCommCount == 3) {									gSComm = WaitingBit1;									gSCommCount = 0;								}								if(gSCommCount == 2) {									gReadIndex = (gDosen & 0x20) ? 1 : 0;								}								break;					case WaitingBit1:								if(gSCommCount == 3) {									gSComm = WaitingData;									gSCommCount = 0;								}								if(gSCommCount == 2) {									gReadIndex |= (gDosen & 0x20) ? 2 : 0;								}								break;					case WaitingData:								if(gDosen & 0x20) {									gSComm = WaitingInput;									gSCommCount = 0;									gBitcount = 0;								}								break;					}					break;	default:					printf("POKE($%lx, $%lx)\n", (UInt32)Addr, (UInt32)Value);fflush(stdout);					break;	}}static void		DrawLCD(int iIndex){Point	p;UInt8	val;	if(gIOMatrixNotChanged[iIndex + 11]) return;	gIOMatrixNotChanged[iIndex + 11] = true;	val = gIOMatrix[iIndex + 11];	SetPort(gWindow);	PenNormal();	PenSize(2,2);	switch(iIndex) {	case 0:		p.h = 10;		p.v = 60;		ForeColor((val & 0x01) ? redColor : yellowColor); MoveTo(p.h + 10, p.v +  0); Line( 1, 0);		ForeColor((val & 0x02) ? redColor : yellowColor); MoveTo(p.h + 10, p.v +  5); Line( 1, 0);		ForeColor((val & 0x04) ? redColor : yellowColor); MoveTo(p.h + 10, p.v + 10); Line( 1, 0);		ForeColor((val & 0x08) ? redColor : yellowColor); MoveTo(p.h + 10, p.v + 15); Line( 1, 0);		ForeColor((val & 0x10) ? redColor : yellowColor); MoveTo(p.h +  0, p.v +  0); Line( 1, 0);		ForeColor((val & 0x20) ? redColor : yellowColor); MoveTo(p.h +  0, p.v +  5); Line( 1, 0);		ForeColor((val & 0x40) ? redColor : yellowColor); MoveTo(p.h +  0, p.v + 10); Line( 1, 0);		ForeColor((val & 0x80) ? redColor : yellowColor); MoveTo(p.h +  0, p.v + 15); Line( 1, 0);		break;	case 1:		p.h = 30;		p.v = 60;		ForeColor((val & 0x01) ? redColor : yellowColor); MoveTo(p.h + 10, p.v +  0); Line( 1, 0);		ForeColor((val & 0x02) ? redColor : yellowColor); MoveTo(p.h + 10, p.v +  5); Line( 1, 0);		ForeColor((val & 0x04) ? redColor : yellowColor); MoveTo(p.h + 10, p.v + 10); Line( 1, 0);		ForeColor((val & 0x08) ? redColor : yellowColor); MoveTo(p.h + 10, p.v + 15); Line( 1, 0);		ForeColor((val & 0x10) ? redColor : yellowColor); MoveTo(p.h +  0, p.v +  0); Line( 1, 0);		ForeColor((val & 0x20) ? redColor : yellowColor); MoveTo(p.h +  0, p.v +  5); Line( 1, 0);		ForeColor((val & 0x40) ? redColor : yellowColor); MoveTo(p.h +  0, p.v + 10); Line( 1, 0);		ForeColor((val & 0x80) ? redColor : yellowColor); MoveTo(p.h +  0, p.v + 15); Line( 1, 0);		break;	case 2:		p.h = 10;		p.v = 10;		ForeColor((val & 0x01) ? redColor : yellowColor); MoveTo(p.h + 10, p.v +  0); Line( 1, 0);		ForeColor((val & 0x02) ? redColor : yellowColor); MoveTo(p.h + 10, p.v +  5); Line( 1, 0);		ForeColor((val & 0x04) ? redColor : yellowColor); MoveTo(p.h + 10, p.v + 10); Line( 1, 0);		ForeColor((val & 0x08) ? redColor : yellowColor); MoveTo(p.h +  0, p.v +  0); Line( 1, 0);		ForeColor((val & 0x10) ? redColor : yellowColor); MoveTo(p.h +  0, p.v +  5); Line( 1, 0);		ForeColor((val & 0x20) ? redColor : yellowColor); MoveTo(p.h +  0, p.v + 10); Line( 1, 0);		break;	default:		p.h = (iIndex - 3) * 25 + 40;		p.v = 10;		ForeColor((val & 0x01) ? redColor : blackColor); MoveTo(p.h +  0, p.v +  0); Line(20, 0);		ForeColor((val & 0x02) ? redColor : blackColor); MoveTo(p.h + 20, p.v +  0); Line( 0,20);		ForeColor((val & 0x04) ? redColor : blackColor); MoveTo(p.h + 20, p.v + 20); Line( 0,20);		ForeColor((val & 0x08) ? redColor : blackColor); MoveTo(p.h +  0, p.v + 40); Line(20, 0);		ForeColor((val & 0x10) ? redColor : blackColor); MoveTo(p.h +  0, p.v + 20); Line( 0,20);		ForeColor((val & 0x20) ? redColor : blackColor); MoveTo(p.h +  0, p.v +  0); Line( 0,20);		ForeColor((val & 0x40) ? redColor : blackColor); MoveTo(p.h +  2, p.v + 20); Line(16, 0);		ForeColor((val & 0x80) ? redColor : blackColor); MoveTo(p.h + 20, p.v + 44); Line( 1, 0);		break;	}}#define IsPressed(k)	((((Ptr)theMap)[(k)>>3] >> ((k) & 7))&1)word		LoopZ80(register Z80 *R){	UInt32	secs;	DateTimeRec	dtrs;	GetDateTime(&secs);	SecondsToDate(secs, &dtrs);	gRTC[0] = dtrs.second % 10;	gRTC[1] = dtrs.second / 10;	gRTC[2] = dtrs.minute % 10;	gRTC[3] = dtrs.minute / 10;	gRTC[4] = dtrs.hour % 10;	gRTC[5] = (dtrs.hour / 10) | 8;	gRTC[7] = dtrs.day % 10;	gRTC[8] = dtrs.day / 10;	gRTC[9] = dtrs.month % 10;	gRTC[10] = dtrs.month / 10;	gRTC[11] = dtrs.year % 10;	gRTC[12] = (dtrs.year % 100) / 10;//	if(Button()) return INT_QUIT;	{		KeyMap				theMap;		int						i;		static UInt8	ConvTab[0x80] = { 0x31, 0x41, 0x51, 0x61, 0xff, 0xff, 0x30, 0x40,	// 0x00																		0x50, 0x60, 0xff, 0xff, 0x32, 0x42, 0x52, 0x62,	// 0x08																		0xff, 0xff, 0x33, 0x43, 0x53, 0x63, 0xff, 0xff,	// 0x10																		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,	// 0x18																		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,	// 0x20																		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x90,	// 0x28																		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,	// 0x30																		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,	// 0x38																		0xff, 0x90, 0xff, 0x70, 0xff, 0xff, 0xff, 0xff,	// 0x40																		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,	// 0x48																		0xff, 0xff, 0x80, 0x71, 0x81, 0x91, 0x72, 0x82,	// 0x50																		0x92, 0x73, 0xff, 0x83, 0x93, 0xff, 0xff, 0xff,	// 0x58																		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,	// 0x60																		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,	// 0x68																		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,	// 0x70																		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff};// 0x78		GetKeys(theMap);		if(IsPressed(0x35))			// ESC => raus!			return INT_QUIT;		if(IsPressed(0x75)) {		// Delete			return INT_NMI;				// NMI ausl�sen		}		memset(&gIOMatrix[3], 0xff, 7);		for(i=0; i<0x80; i++) {			if(!IsPressed(i))				continue;			{				UInt8	k = ConvTab[i];				if(k != 0xff)					gIOMatrix[k >> 4] &= ~(1 << (k & 0xf));			}		}	}	{	int			i;		for(i=0; i<9; i++)			DrawLCD(i);	}	R->IPeriod = 32767;	return INT_IRQ;}void	main(){extern short Z80_PPC();	MaxApplZone();	InitGraf(&qd.thePort);	InitFonts();	InitWindows();	InitMenus();	TEInit();	InitDialogs(nil);	InitCursor();	{	Rect	rBounds = { 100, 100, 180, 300 };	gWindow = NewCWindow(nil, &rBounds, "\pFutura", true, rDocProc, (WindowPtr)-1L, true, 0L);	BackColor(blackColor);	SetRect(&rBounds, 0, 0, 8000, 8000);	EraseRect(&rBounds);	}	CORE = malloc(0x10000L);	assert(CORE != nil);	memset(CORE, 0, 0x10000L);	{	FILE	*f = fopen("EPROM", "rb");		assert(f != nil);		fread(CORE, sizeof(UInt8), 0x2000, f);		fclose(f);	}	zregs.IPeriod = 32767;	ResetZ80(&zregs);	RunZ80(&zregs);	FlushEvents(everyEvent, 0);}