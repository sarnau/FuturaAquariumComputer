/*	Z80 Emulator: CB instruction handlers	Copyright (C) 1995 G.Woigk		This file is part of Mac Spectacle and it is free software	See application.c for details				This program is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  	based on fMSX; Copyright (C) Marat Fayzullin 1994,1995	Handler for CB prefixed instructions	All opcodes covered, no unsupported opcodes!*/COUNT_CB_INSTR;			// profilerincrement_r;			// prefixed instructions increment r by 2time(8);				// all register operations take 8 T cycles// =====================================================================// compact version which fit's in a 32k code segment (for 68020 version)#if COMPACT_CODEswitch(peek(pc)&0x07)		// register; b,c,d,e,h,l,(hl),a{	case 0:	c=RB; break;case 1:	c=RC; break;case 2:	c=RD; break;case 3:	c=RE; break;case 4:	c=RH; break;case 5:	c=RL; break;case 6:	more(4);c=peek(HL); break;case 7:	c=ra; break;};switch (peek(pc)>>3)		// instruction: shift/bit/res/set{case RLC_B>>3:	M_RLC(c);		break;		case RRC_B>>3: 	M_RRC(c);		break;case RL_B>>3:	M_RL(c);		break;case RR_B>>3:	M_RR(c);		break;case SLA_B>>3: 	M_SLA(c);		break;case SRA_B>>3: 	M_SRA(c);		break;case SLL_B>>3: 	M_SLL(c);#if INFO_ILLEGALS	switch(peek(pc++)&0x07)		// write back result & incr pc	{		case 0:	RB=c; loop_ill2;	case 1:	RC=c; loop_ill2;	case 2:	RD=c; loop_ill2;	case 3:	RE=c; loop_ill2;	case 4:	RH=c; loop_ill2;	case 5:	RL=c; loop_ill2;	case 6:	more(3); poke(HL,c); loop_ill2;	case 7:	ra=c; loop_ill2;	};#else								break;#endifcase SRL_B>>3:	M_SRL(c);		break;case BIT0_B>>3:	M_BIT(0x01,c);	pc++;	loop;case BIT1_B>>3:	M_BIT(0x02,c);	pc++;	loop;case BIT2_B>>3:	M_BIT(0x04,c);	pc++;	loop;case BIT3_B>>3:	M_BIT(0x08,c);	pc++;	loop;case BIT4_B>>3:	M_BIT(0x10,c);	pc++;	loop;case BIT5_B>>3:	M_BIT(0x20,c);	pc++;	loop;case BIT6_B>>3:	M_BIT(0x40,c);	pc++;	loop;case BIT7_B>>3:	M_BIT(0x80,c);	pc++;	loop;case RES0_B>>3:	c&=~0x01;		break;case RES1_B>>3:	c&=~0x02;		break;case RES2_B>>3:	c&=~0x04;		break;case RES3_B>>3:	c&=~0x08;		break;case RES4_B>>3:	c&=~0x10;		break;case RES5_B>>3:	c&=~0x20;		break;case RES6_B>>3:	c&=~0x40;		break;case RES7_B>>3:	c&=~0x80;		break;case SET0_B>>3:	c|=0x01;		break;case SET1_B>>3:	c|=0x02;		break;case SET2_B>>3:	c|=0x04;		break;case SET3_B>>3:	c|=0x08;		break;case SET4_B>>3:	c|=0x10;		break;case SET5_B>>3:	c|=0x20;		break;case SET6_B>>3:	c|=0x40;		break;case SET7_B>>3:	c|=0x80;		break;};switch(peek(pc++)&0x07)		// write back result and increment pc{	case 0:	RB=c; loop;case 1:	RC=c; loop;case 2:	RD=c; loop;case 3:	RE=c; loop;case 4:	RH=c; loop;case 5:	RL=c; loop;case 6:	more(3); poke(HL,c); loop;case 7:	ra=c; loop;};// ==== FAST VERSION ===============================================#elseswitch(n){case RLC_B:	M_RLC(RB);loop;		case RLC_C: M_RLC(RC);loop;case RLC_D:	M_RLC(RD);loop;		case RLC_E: M_RLC(RE);loop;case RLC_H: M_RLC(RH);loop;		case RLC_L: M_RLC(RL);loop;case RLC_X: more(7);c=peek(HL);M_RLC(c);poke(HL,c);loop;case RLC_A: M_RLC(ra);loop;case RRC_B: M_RRC(RB);loop;case RRC_C: M_RRC(RC);loop;case RRC_D: M_RRC(RD);loop;case RRC_E: M_RRC(RE);loop;case RRC_H: M_RRC(RH);loop;case RRC_L: M_RRC(RL);loop;case RRC_X:	more(7);c=peek(HL);M_RRC(c);poke(HL,c);loop;case RRC_A: M_RRC(ra);loop;case RL_B:	M_RL(RB);loop;case RL_C:	M_RL(RC);loop;case RL_D:	M_RL(RD);loop;case RL_E:	M_RL(RE);loop;case RL_H:	M_RL(RH);loop;case RL_L:	M_RL(RL);loop;case RL_X:	more(7);c=peek(HL);M_RL(c);poke(HL,c);loop;case RL_A:	M_RL(ra);loop;case RR_B:	M_RR(RB);loop;case RR_C:	M_RR(RC);loop;case RR_D:	M_RR(RD);loop;case RR_E:	M_RR(RE);loop;case RR_H:	M_RR(RH);loop;case RR_L:	M_RR(RL);loop;case RR_X:	more(7);c=peek(HL);M_RR(c);poke(HL,c);loop;case RR_A:	M_RR(ra);loop;case SLA_B: M_SLA(RB);loop;case SLA_C: M_SLA(RC);loop;case SLA_D: M_SLA(RD);loop;case SLA_E: M_SLA(RE);loop;case SLA_H: M_SLA(RH);loop;case SLA_L: M_SLA(RL);loop;case SLA_X: more(7);c=peek(HL);M_SLA(c);poke(HL,c);loop;case SLA_A: M_SLA(ra);loop;case SRA_B: M_SRA(RB);loop;case SRA_C: M_SRA(RC);loop;case SRA_D: M_SRA(RD);loop;case SRA_E: M_SRA(RE);loop;case SRA_H: M_SRA(RH);loop;case SRA_L: M_SRA(RL);loop;case SRA_X: more(7);c=peek(HL);M_SRA(c);poke(HL,c);loop;case SRA_A: M_SRA(ra);loop;case SLL_B: M_SLL(RB);loop_ill2;case SLL_C: M_SLL(RC);loop_ill2;case SLL_D: M_SLL(RD);loop_ill2;case SLL_E: M_SLL(RE);loop_ill2;case SLL_H: M_SLL(RH);loop_ill2;case SLL_L: M_SLL(RL);loop_ill2;case SLL_X: more(7);c=peek(HL);M_SLL(c);poke(HL,c);loop_ill2;case SLL_A: M_SLL(ra);loop_ill2;case SRL_B: M_SRL(RB);loop;case SRL_C: M_SRL(RC);loop;case SRL_D: M_SRL(RD);loop;case SRL_E: M_SRL(RE);loop;case SRL_H: M_SRL(RH);loop;case SRL_L: M_SRL(RL);loop;case SRL_X: more(7);c=peek(HL);M_SRL(c);poke(HL,c);loop;case SRL_A: M_SRL(ra);loop;    case BIT0_B:	M_BIT(0x01,RB);loop;case BIT0_C:	M_BIT(0x01,RC);loop;case BIT0_D:	M_BIT(0x01,RD);loop;case BIT0_E:	M_BIT(0x01,RE);loop;case BIT0_H:	M_BIT(0x01,RH);loop;case BIT0_L:	M_BIT(0x01,RL);loop;case BIT0_X:	more(4);c=peek(HL);M_BIT(0x01,c);loop;case BIT0_A:	M_BIT(0x01,ra);loop;case BIT1_B:	M_BIT(0x02,RB);loop;case BIT1_C:	M_BIT(0x02,RC);loop;case BIT1_D:	M_BIT(0x02,RD);loop;case BIT1_E:	M_BIT(0x02,RE);loop;case BIT1_H:	M_BIT(0x02,RH);loop;case BIT1_L:	M_BIT(0x02,RL);loop;case BIT1_X:	more(4);c=peek(HL);M_BIT(0x02,c);loop;case BIT1_A:	M_BIT(0x02,ra);loop;case BIT2_B:	M_BIT(0x04,RB);loop;case BIT2_C:	M_BIT(0x04,RC);loop;case BIT2_D:	M_BIT(0x04,RD);loop;case BIT2_E:	M_BIT(0x04,RE);loop;case BIT2_H:	M_BIT(0x04,RH);loop;case BIT2_L:	M_BIT(0x04,RL);loop;case BIT2_X:	more(4);c=peek(HL);M_BIT(0x04,c);loop;case BIT2_A:	M_BIT(0x04,ra);loop;case BIT3_B:	M_BIT(0x08,RB);loop;case BIT3_C:	M_BIT(0x08,RC);loop;case BIT3_D:	M_BIT(0x08,RD);loop;case BIT3_E:	M_BIT(0x08,RE);loop;case BIT3_H:	M_BIT(0x08,RH);loop;case BIT3_L:	M_BIT(0x08,RL);loop;case BIT3_X:	more(4);c=peek(HL);M_BIT(0x08,c);loop;case BIT3_A:	M_BIT(0x08,ra);loop;case BIT4_B:	M_BIT(0x10,RB);loop;case BIT4_C:	M_BIT(0x10,RC);loop;case BIT4_D:	M_BIT(0x10,RD);loop;case BIT4_E:	M_BIT(0x10,RE);loop;case BIT4_H:	M_BIT(0x10,RH);loop;case BIT4_L:	M_BIT(0x10,RL);loop;case BIT4_X:	more(4);c=peek(HL);M_BIT(0x10,c);loop;case BIT4_A:	M_BIT(0x10,ra);loop;case BIT5_B:	M_BIT(0x20,RB);loop;case BIT5_C:	M_BIT(0x20,RC);loop;case BIT5_D:	M_BIT(0x20,RD);loop;case BIT5_E:	M_BIT(0x20,RE);loop;case BIT5_H:	M_BIT(0x20,RH);loop;case BIT5_L:	M_BIT(0x20,RL);loop;case BIT5_X:	more(4);c=peek(HL);M_BIT(0x20,c);loop;case BIT5_A:	M_BIT(0x20,ra);loop;case BIT6_B:	M_BIT(0x40,RB);loop;case BIT6_C:	M_BIT(0x40,RC);loop;case BIT6_D:	M_BIT(0x40,RD);loop;case BIT6_E:	M_BIT(0x40,RE);loop;case BIT6_H:	M_BIT(0x40,RH);loop;case BIT6_L:	M_BIT(0x40,RL);loop;case BIT6_X:	more(4);c=peek(HL);M_BIT(0x40,c);loop;case BIT6_A:	M_BIT(0x40,ra);loop;case BIT7_B:	M_BIT(0x80,RB);loop;case BIT7_C:	M_BIT(0x80,RC);loop;case BIT7_D:	M_BIT(0x80,RD);loop;case BIT7_E:	M_BIT(0x80,RE);loop;case BIT7_H:	M_BIT(0x80,RH);loop;case BIT7_L:	M_BIT(0x80,RL);loop;case BIT7_X:	more(4);c=peek(HL);M_BIT(0x80,c);loop;case BIT7_A:	M_BIT(0x80,ra);loop;case RES0_B:	RB&=~0x01;loop;case RES0_C:	RC&=~0x01;loop;case RES0_D:	RD&=~0x01;loop;case RES0_E:	RE&=~0x01;loop;case RES0_H:	RH&=~0x01;loop;case RES0_L:	RL&=~0x01;loop;case RES0_X:	more(7);poke(HL,peek(HL)&~0x01);loop;case RES0_A:	ra&=~0x01;loop;case RES1_B:	RB&=~0x02;loop;case RES1_C:	RC&=~0x02;loop;case RES1_D:	RD&=~0x02;loop;case RES1_E:	RE&=~0x02;loop;case RES1_H:	RH&=~0x02;loop;case RES1_L:	RL&=~0x02;loop;case RES1_X:	more(7);poke(HL,peek(HL)&~0x02);loop;case RES1_A:	ra&=~0x02;loop;case RES2_B:	RB&=~0x04;loop;case RES2_C:	RC&=~0x04;loop;case RES2_D:	RD&=~0x04;loop;case RES2_E:	RE&=~0x04;loop;case RES2_H:	RH&=~0x04;loop;case RES2_L:	RL&=~0x04;loop;case RES2_X:	more(7);poke(HL,peek(HL)&~0x04);loop;case RES2_A:	ra&=~0x04;loop;case RES3_B:	RB&=~0x08;loop;case RES3_C:	RC&=~0x08;loop;case RES3_D:	RD&=~0x08;loop;case RES3_E:	RE&=~0x08;loop;case RES3_H:	RH&=~0x08;loop;case RES3_L:	RL&=~0x08;loop;case RES3_X:	more(7);poke(HL,peek(HL)&~0x08);loop;case RES3_A:	ra&=~0x08;loop;case RES4_B:	RB&=~0x10;loop;case RES4_C:	RC&=~0x10;loop;case RES4_D:	RD&=~0x10;loop;case RES4_E:	RE&=~0x10;loop;case RES4_H:	RH&=~0x10;loop;case RES4_L:	RL&=~0x10;loop;case RES4_X:	more(7);poke(HL,peek(HL)&~0x10);loop;case RES4_A:	ra&=~0x10;loop;case RES5_B:	RB&=~0x20;loop;case RES5_C:	RC&=~0x20;loop;case RES5_D:	RD&=~0x20;loop;case RES5_E:	RE&=~0x20;loop;case RES5_H:	RH&=~0x20;loop;case RES5_L:	RL&=~0x20;loop;case RES5_X:	more(7);poke(HL,peek(HL)&~0x20);loop;case RES5_A:	ra&=~0x20;loop;case RES6_B:	RB&=~0x40;loop;case RES6_C:	RC&=~0x40;loop;case RES6_D:	RD&=~0x40;loop;case RES6_E:	RE&=~0x40;loop;case RES6_H:	RH&=~0x40;loop;case RES6_L:	RL&=~0x40;loop;case RES6_X:	more(7);poke(HL,peek(HL)&~0x40);loop;case RES6_A:	ra&=~0x40;loop;case RES7_B:	RB&=~0x80;loop;case RES7_C:	RC&=~0x80;loop;case RES7_D:	RD&=~0x80;loop;case RES7_E:	RE&=~0x80;loop;case RES7_H:	RH&=~0x80;loop;case RES7_L:	RL&=~0x80;loop;case RES7_X:	more(7);poke(HL,peek(HL)&~0x80);loop;case RES7_A:	ra&=~0x80;loop;case SET0_B:	RB|=0x01;loop;case SET0_C:	RC|=0x01;loop;case SET0_D:	RD|=0x01;loop;case SET0_E:	RE|=0x01;loop;case SET0_H:	RH|=0x01;loop;case SET0_L:	RL|=0x01;loop;case SET0_X:	more(7);poke(HL,peek(HL)|0x01);loop;case SET0_A:	ra|=0x01;loop;case SET1_B:	RB|=0x02;loop;case SET1_C:	RC|=0x02;loop;case SET1_D:	RD|=0x02;loop;case SET1_E:	RE|=0x02;loop;case SET1_H:	RH|=0x02;loop;case SET1_L:	RL|=0x02;loop;case SET1_X:	more(7);poke(HL,peek(HL)|0x02);loop;case SET1_A:	ra|=0x02;loop;case SET2_B:	RB|=0x04;loop;case SET2_C:	RC|=0x04;loop;case SET2_D:	RD|=0x04;loop;case SET2_E:	RE|=0x04;loop;case SET2_H:	RH|=0x04;loop;case SET2_L:	RL|=0x04;loop;case SET2_X:	more(7);poke(HL,peek(HL)|0x04);loop;case SET2_A:	ra|=0x04;loop;case SET3_B:	RB|=0x08;loop;case SET3_C:	RC|=0x08;loop;case SET3_D:	RD|=0x08;loop;case SET3_E:	RE|=0x08;loop;case SET3_H:	RH|=0x08;loop;case SET3_L:	RL|=0x08;loop;case SET3_X:	more(7);poke(HL,peek(HL)|0x08);loop;case SET3_A:	ra|=0x08;loop;case SET4_B:	RB|=0x10;loop;case SET4_C:	RC|=0x10;loop;case SET4_D:	RD|=0x10;loop;case SET4_E:	RE|=0x10;loop;case SET4_H:	RH|=0x10;loop;case SET4_L:	RL|=0x10;loop;case SET4_X:	more(7);poke(HL,peek(HL)|0x10);loop;case SET4_A:	ra|=0x10;loop;case SET5_B:	RB|=0x20;loop;case SET5_C:	RC|=0x20;loop;case SET5_D:	RD|=0x20;loop;case SET5_E:	RE|=0x20;loop;case SET5_H:	RH|=0x20;loop;case SET5_L:	RL|=0x20;loop;case SET5_X:	more(7);poke(HL,peek(HL)|0x20);loop;case SET5_A:	ra|=0x20;loop;case SET6_B:	RB|=0x40;loop;case SET6_C:	RC|=0x40;loop;case SET6_D:	RD|=0x40;loop;case SET6_E:	RE|=0x40;loop;case SET6_H:	RH|=0x40;loop;case SET6_L:	RL|=0x40;loop;case SET6_X:	more(7);poke(HL,peek(HL)|0x40);loop;case SET6_A:	ra|=0x40;loop;case SET7_B:	RB|=0x80;loop;case SET7_C:	RC|=0x80;loop;case SET7_D:	RD|=0x80;loop;case SET7_E:	RE|=0x80;loop;case SET7_H:	RH|=0x80;loop;case SET7_L:	RL|=0x80;loop;case SET7_X:	more(7);poke(HL,peek(HL)|0x80);loop;case SET7_A:	ra|=0x80;loop;};loop;	// never used#endif