/**
 * CTFE Integer routines.
 * 
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.ctfe.Integer;

import gb.util.CC : Version;
import gb.util.Endianness : Endianness;

/**
 * Formats an integer as a string.  You can optionally specify a different
 * base; any value between 2 and 16 inclusive is supported.
 * 
 * Params:
 *     v = value to format.
 *     base = base to use; defaults to 10.
 * Returns:
 *      integer formatted as a string.
 */

char[] format_ctfe(intT)(intT v, int base = 10)
{
    static if( !is( intT == ulong ) ) 
    {
        return (v < 0)
            ? "-" ~ format_ctfe(cast(ulong) -v, base)
            : format_ctfe(cast(ulong) v, base);
    }
    else
    {
        assert( 2 <= base && base <= 16,
                "base must be between 2 and 16; got " ~ format_ctfe(base, 10) );
        
        char[] r = "";
        do
        {
            r = INT_CHARS[v % base] ~ r;
            v /= base;
        }
        while( v > 0 );
        return r;
    }
}

/**
 * Parses an integer value from a string.  You can optionally specify a
 * different base; any value between 2 and 16 inclusive is supported.
 * 
 * Note that this does not fail if it cannot consume the entire string;
 * use returnUsed to determine the number of characters consumed.
 * 
 * Params:
 *     str = string to parse.
 *     returnUsed = defaults to false; if set to true, returns the number of
 *                  characters consumed from the string instead of the
 *                  parsed value.
 *     base = base to use; defaults to 10.
 * Returns:
 *      either the parsed integer or the number of characters consumed,
 *      depending on the value of returnUsed.
 */

intT parse_ctfe(intT)(char[] str, bool returnUsed = false, int base = 10)
{
    auto origStr = str;
    
    assert( 2 <= base && base <= 16,
        "base must be between 2 and 16; got " ~ format_ctfe(base, 10) );

    bool neg = false;
    if( str.length > 0 && str[0] == '-' )
    {
        neg = true;
        str = str[1..$];
    }
    
    if( intT.min == 0 && neg )
        assert(false, "underwhile while parsing \"" ~ origStr
                ~ "\" as a " ~ intT.stringof ~ ": cannot represent negative "
                ~ "values");
    
    intT r = 0;
    size_t used = 0;
    
    foreach( c ; str )
    {
        int cv = -1;
        
        if( '0' <= c && c <= '9' )
            cv = c - '0';
        
        else if( 'A' <= c && c <= 'Z' )
            cv = 10 + c - 'A';
        
        else if( 'a' <= c && c <= 'z' )
            cv = 10 + c - 'a';
        
        if( cv >= base || cv < 0 )
            break;
        
        auto oldR = r;
        r = r*base + cast(intT) cv;
        ++ used;
        
        if( r < oldR )
            assert(false, "overflow while parsing \"" ~ origStr
                    ~ "\" as a " ~ intT.stringof);
    }
    
    if( neg )
    {
        r = -r;
        ++used;
    }
    
    if( returnUsed )
    {
        assert( used < intT.max, "overflow attempting to return "
                ~ "number of characters consumed in a " ~ intT.stringof );
        
        return used;
    }
    else
        return r;
}

/**
 * Like parse_ctfe, except it will raise an error if the provided string
 * cannot be parsed in its entirety.
 * 
 * Params:
 *     str = the string to parse.
 *     base = base to use; defaults to 10.
 * Returns:
 *      the parsed integer.
 */

intT parseAll_ctfe(intT)(char[] str, int base = 10)
{
    auto used = parse_ctfe!(intT)(str, true, base);
    assert( used == str.length, "could not parse entire string \"" ~ str
            ~ "\"" );
    return parse_ctfe!(int)(str, false, base);
}

private
{
    const INT_CHARS = "0123456789abcdef";
}

version( Unittest )
{
    static assert( format_ctfe(0) == "0", "got: " ~ format_ctfe(0) );
    static assert( format_ctfe(1) == "1" );
    static assert( format_ctfe(-1) == "-1" );
    static assert( format_ctfe(42) == "42" );
    static assert( format_ctfe(0xf00, 16) == "f00" );
    static assert( format_ctfe(0123, 8) == "123" );
    
    static assert( parse_ctfe!(long)("0") == 0 );
    static assert( parse_ctfe!(long)("1") == 1 );
    static assert( parse_ctfe!(long)("-1") == -1 );
    static assert( parse_ctfe!(long)("42") == 42 );
    static assert( parse_ctfe!(long)("f00", false, 16) == 0xf00 );
    static assert( parse_ctfe!(long)("123", false, 8) == 0123 );
    static assert( parse_ctfe!(long)("123ax", true) == 3 );
    static assert( parse_ctfe!(long)("123ax", true, 16) == 4 );
    
    static assert( parseAll_ctfe!(long)("123") == 123 );
}

/**
 * Reinterprets a string as an integer value.  Note that the output of this
 * (obviously) depends on endianness.  If you don't specify an endianness, it
 * uses whatever endianness the target system has.
 */

intT recastAsInteger_ctfe(intT)(char[] str, Endianness bo = Endianness.Auto)
{
    if( str.length != intT.sizeof )
        assert(false, "Cannot recast '"~str~"' as an "~intT.stringof
                ~": wrong size.");
    
    if( bo == Endianness.Auto )
        bo = Version!(BigEndian) ? Endianness.Big : Endianness.Little;

    intT v = 0;

    foreach( dchar c ; str )
    {
        v <<= 8;

        if( c > 0x7f )
            assert(false, "Cannot recast '"~str~"' as an "~intT.stringof
                    ~": contains non-ASCII characters.");

        v |= cast(intT) c;
    }

    if( bo == Endianness.Big )
    {
        intT tmp = v;
        v = 0;

        for( int i = (intT.sizeof - 1) * 8; i >= 0; i -= 8 )
        {
            v <<= 8;
            v |= (tmp>>i) & 0xff;
        }
    }

    return v;
}

version( Unittest )
{
    static assert( recastAsInteger!(uint)("ABCD") == 0x41424344 );
}

