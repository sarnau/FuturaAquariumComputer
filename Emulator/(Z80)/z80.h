/*	Z80 Emulator: header file	Copyright (C) 1995 G.Woigk		This file is part of Mac Spectacle and it is free software	See application.c for details				This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  */#if CMD_PROFILEextern	Boolean	count_instr;extern	UInt32	*cnt_xx;extern	UInt32	*cnt_cb;extern	UInt32	*cnt_ed;extern	UInt32	*cnt_xy;extern	UInt32	*cnt_xycb;#endif#if PC_PROFILEextern	Boolean	count_pc;extern	UInt32	*cnt_pc;#endif// -----	Accessing the Core ---------------------------------------------------------extern	UInt8		Peek	( UInt16 addr );				// read byteextern	void		Poke	( UInt16 addr, UInt8 byte );		// write byte// -----	Flag tables ----------------------------------------------------------------extern	UInt8		zlog_flags[256];	// convert:   A register  ->  z80 flags with V=parity and C=0#if !GENERATINGPOWERPCextern	UInt8		mlog_flags[256];	// convert:   A register  ->  m68 flags with V=parity and C=0extern	UInt8		z80flags[256];		// convert:   m68 flag byte  ->  Z80 flag byteextern	UInt8		m68flags[256];		// convert:   Z80 flag byte  ->  m68 flag byte#endif// -----	The Z80 core --------------------------------------------------------------extern	UInt8*	CORE;				// do not use any longer!!!extern	UInt8*	rpage[];		// mapped in pages for readingextern	UInt8*	wpage[];		// mapped in pages for writingextern	UInt8*	ram[];			// real RAM pagesextern	UInt8*	rom[];			// real ROM pages// -----	Z80 registers on entry and return of Z80() -----------------------------------typedef	union dreg{	UInt16	rr;	struct	{ UInt8 hi,lo; }	r;} dreg;typedef union pair{	UInt8		*ptr;	struct	{	UInt16 corebase; UInt16 reg; }	rr;	struct	{	UInt16 corebase; UInt8 hi,lo; }	r;} pair;typedef struct z80 z80;struct z80{	pair		bc,de,hl,ix,iy,pc,sp;		// registers	UInt16	bc2,de2,hl2;			// registers	UInt8		aa2,a2,aa,a;			// A2 & A are stuffed in one long register inside Z80_68k()	UInt8		ff2, f2, ff, f;		// F2  & F are stuffed in one long register inside Z80_68k()	UInt8		i, irptcmd;				// irpt vector: i register & byte read from data bus	UInt8		iff1,iff2;				// interrupt enable flip flops	UInt8		exit,wuff;				// watchdog flag & nmi/irpt flags	UInt8		r, im;						// refresh counter & interrupt mode: 0 ... 2	long		cycles;						// processor T states (count down for interrupt)	long		total;						// T states since start of Z80 (overflows approx. every 20')};extern	z80		zreg;			// all z80 registers, flags and bits are stored in this struct// -----	definitions to ease the use of the z80 registers & core:#define	CYCLES	zreg.cycles		// processor T states (count down for interrupt)#define	TOTAL		zreg.total		// T states since start of Z80 (overflows approx. every 20')#define	WUFF		zreg.wuff			// watchdog flag#define	EXIT		zreg.exit			// nmi & irpt flags#define	IFF1		zreg.iff1			// irpt flip flop#define	IFF2		zreg.iff2			// iff1 copy during nmi processing#define	IM			zreg.im				// interrupt mode: 0 ... 2#define	RR			zreg.r				// 7 bit DRAM refresh counter#define	RI			zreg.i				// hi byte of interrupt vector: i register#define	IRPTCMD	zreg.irptcmd	// lo byte of interrupt vector: read from bus#define	IRPTVEK	*(UInt16*)&RI	// interrupt vector in interrupt mode 2#define	RA		zreg.a			// Z80() uses register variable 'a'#define	RF		zreg.f			// Z80() uses register variable 'f'#define	RA2		zreg.a2#define	RF2		zreg.f2#define	BC2		zreg.bc2#define	DE2		zreg.de2#define	HL2		zreg.hl2#define	ABC		zreg.bc.ptr#define	BC		zreg.bc.rr.reg#define	RB		zreg.bc.r.hi#define	RC		zreg.bc.r.lo#define	ADE		zreg.de.ptr#define	DE		zreg.de.rr.reg#define	RD		zreg.de.r.hi#define	RE		zreg.de.r.lo#define	AHL		zreg.hl.ptr#define	HL		zreg.hl.rr.reg#define	RH		zreg.hl.r.hi#define	RL		zreg.hl.r.lo#define	AIX		zreg.ix.ptr#define	IX		zreg.ix.rr.reg#define	XH		zreg.ix.r.hi#define	XL		zreg.ix.r.lo#define	AIY		zreg.iy.ptr#define	IY		zreg.iy.rr.reg#define	YH		zreg.iy.r.hi#define	YL		zreg.iy.r.lo#define	APC		zreg.pc.ptr	#define	PC		zreg.pc.rr.reg#define	PCH		zreg.pc.r.hi#define	PCL		zreg.pc.r.lo#define	ASP		zreg.sp.ptr#define	SP		zreg.sp.rr.reg#define	SPH		zreg.sp.r.hi#define	SPL		zreg.sp.r.lo#define	disabled	0x00			// irpt flags#define	enabled		0xFF			// irpt flags// bits in WUFF:#define	is_nmi		0x80			// non maskable interrupt: handled inside Z80()#define	is_irpt		0x7F			// normal interrupt counter: handled inside Z80()// -----	Return values of Z80() -----------------------------------------------------#define	watchdog_irpt	0			// watchdog exception#define	nimp_instr		1			// not implemented instruction at pc -> stop engine#define	halt_instr		2			// halt instruction encountered at pc-1 -> execute it!#define	rst0_instr		3			// rst 0 instruction encountered at pc-1 -> execute it!#define	irpt_error		4			// not supported interrupt mode/instruction -> stop engine#define	ill_instr2		5			// info:	illegal instruction executed at pc-2:#define	ill_instr3		6			//		SLL and usual XL,XH,YL,YH opcodes#define	ill_instr4		7			//#define	weird_instr1	8			// info:	unusual illegal instruction executed at pc-1: #define	weird_instr2	9			//		all other illegals#define	weird_instr3	10		//#define	weird_instr4	11		//// -----	Procedures -------------------------------------------------------------------extern	short	Z80_PPC();		// same as Z80_T() but written in C// -----	The following procedures must be supplied by the application program ---------------extern	void	Do_Output(UInt16 addr, UInt8 n);	// Output byte to port				UInt8	Do_Input(UInt16 addr);						// Input byte from portextern	void	Do_Cycles();											// Count down for T cycles reached 0extern	void	Z80_Info(SInt32 cc, UInt16 ip);extern	void	Z80_Info_Irpt(SInt32 cc);								// info call to debugger if INFO_IRPT==onextern	void	Z80_Info_NMI(SInt32 cc);								// info call to debugger if INFO_NMI==onextern	void	Z80_1st_Loc(SInt32 cc, UInt16 ip);			// info call to debugger if PC_PROFILE==onextern	void	Z80_1st_Instr(SInt32 cc, UInt16 ip);		// info call to debugger if CMD_PROFILE==on