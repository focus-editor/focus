/*
 * This source is adapted from the utf-8 library by Rob Pike and Ken Thompson.
 *              Copyright (c) 2002 by Lucent Technologies.
 * Permission to use, copy, modify, and distribute this software for any
 * purpose without fee is hereby granted, provided that this entire notice
 * is included in all copies of any software which is or includes a copy
 * or modification of this software and in all copies of the supporting
 * documentation for such software.
 * THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED
 * WARRANTY.  IN PARTICULAR, NEITHER THE AUTHORS NOR LUCENT TECHNOLOGIES MAKE ANY
 * REPRESENTATION OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY
 * OF THIS SOFTWARE OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.
 */

#scope_module

// @ToDo: Why is this signed!?
Rune :: s32;

UTFmax		:: 4;		/* maximum bytes per rune */
Runesync	:: 0x80;		/* cannot represent part of a UTF sequence (<) */
Runeself	:: 0x80;		/* rune and UTF sequences are the same (<) */
Runeerror	:: 0xFFFD;	/* decoding error in UTF */
Runemax		: s32 : 0x10FFFF;	/* maximum rune value */

// @ToDo: Move to unicode module?
rune_from_string :: (str: string) -> Rune, len: int {
	/*
	 * one character sequence
	 *	00000-0007F => T1
	 */
	c: s32 = str[0];
	if c < Tx {
		return c, 1;
	}


	/*
	 * two character sequence
	 *	0080-07FF => T2 Tx
	 */
	if str.count < 2	return Runeerror, 0;

	c1 := cast(s32)(str[1]) ^ Tx;
	if c1 & Testx	return Runeerror, 0;

	if c < T3 {
		if c < T2	return Runeerror, 0;

		result := ((c << Bitx) | c1) & Rune2;
		if result <= Rune1	return Runeerror, 0;

		return result, 2;
	}

	/*
	 * three character sequence
	 *	0800-FFFF => T3 Tx Tx
	 */
	if str.count < 3	return Runeerror, 0;

	c2 := cast(s32)(str[2]) ^ Tx;
	if c2 & Testx	return Runeerror, 0;

	if c < T4 {
		result := ((((c << Bitx) | c1) << Bitx) | c2) & Rune3;
		if result <= Rune2	return Runeerror, 0;

		return result, 3;
	}

	/*
	 * four character sequence (21-bit value)
	 *	10000-1FFFFF => T4 Tx Tx Tx
	 */
	if str.count < 4	return Runeerror, 0;

	c3 := cast(s32)(str[3]) ^ Tx;
	if c3 & Testx	return Runeerror, 0;

	if c < T5 {
		result := ((((((c << Bitx) | c1) << Bitx) | c2) << Bitx) | c3) & Rune4;
		if result <= Rune3	return Runeerror, 0;

		return result, 4;
	}

	return Runeerror, 0;
}

bytes_from_rune :: (rune: Rune) -> [UTFmax] u8, len: int {
	/* Runes are signed, so convert to unsigned for range check. */
	c := cast(u32)rune;
	result: [UTFmax] u8;

	/*
	 * one character sequence
	 *	00000-0007F => 00-7F
	 */
	if c <= Rune1 {
		result[0] = cast(u8) c;
		return result, 1;
	}

	/*
	 * two character sequence
	 *	0080-07FF => T2 Tx
	 */
	if c <= Rune2 {
		result[0] = T2 | cast(u8)(c >> (1*Bitx));
		result[1] = Tx | cast(u8)(c & Maskx);
		return result, 2;
	}

	/*
	 * If the Rune is out of range, convert it to the error rune.
	 * Do this test here because the error rune encodes to three bytes.
	 * Doing it earlier would duplicate work, since an out of range
	 * Rune wouldn't have fit in one or two bytes.
	 */
	if c > cast(u32)Runemax {
		c = Runeerror;
	}

	/*
	 * three character sequence
	 *	0800-FFFF => T3 Tx Tx
	 */
	if c <= Rune3 {
		result[0] = T3 | cast(u8)(c >> (2*Bitx));
		result[1] = Tx | cast(u8)((c >> (1*Bitx)) & Maskx);
		result[2] = Tx | cast(u8)(c & Maskx);
		return result, 3;
	}

	/*
	 * four character sequence (21-bit value)
	 *     10000-1FFFFF => T4 Tx Tx Tx
	 */
	result[0] = T4 | cast(u8)(c >> (3*Bitx));
	result[1] = Tx | cast(u8)((c >> (2*Bitx)) & Maskx);
	result[2] = Tx | cast(u8)((c >> (1*Bitx)) & Maskx);
	result[3] = Tx | cast(u8)(c & Maskx);
	return result, 4;
}

string_from_runes :: (runes: [] Rune) -> string {
	builder: String_Builder;
	defer free_buffers(*builder);
	for runes {
		bytes, len := bytes_from_rune(it);
		append(*builder, bytes.data, len);
	}
	return builder_to_string(*builder);
}

#scope_file

Bit1	:: 7;
Bitx	:: 6;
Bit2	:: 5;
Bit3	:: 4;
Bit4	:: 3;
Bit5	:: 2;

T1	: u8 : 0b0000_0000;
Tx	: u8 : 0b1000_0000;
T2	: u8 : 0b1100_0000;
T3	: u8 : 0b1110_0000;
T4	: u8 : 0b1111_0000;
T5	: u8 : 0b1111_1000;

Rune1	:: 0b0000_0000_0111_1111;
Rune2	:: 0b0000_0111_1111_1111;
Rune3	:: 0b1111_1111_1111_1111;
Rune4	:: 0b0001_1111_1111_1111_1111_1111;

Maskx	: u8 : 0b0011_1111;
Testx	: u8 : 0b1100_0000;

