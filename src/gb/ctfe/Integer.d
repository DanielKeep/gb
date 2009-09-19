/**
 * CTFE Integer routines.
 * 
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.ctfe.Integer;

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
            r = FORMAT_CHARS[v % base] ~ r;
            v /= base;
        }
        while( v > 0 );
        return r;
    }
}

private
{
    const FORMAT_CHARS = "0123456789abcdef";
}

version( Unittest )
{
    static assert( format_ctfe(0) == "0", "got: " ~ format_ctfe(0) );
    static assert( format_ctfe(1) == "1" );
    static assert( format_ctfe(-1) == "-1" );
    static assert( format_ctfe(42) == "42" );
    static assert( format_ctfe(0xf00, 16) == "f00" );
    static assert( format_ctfe(0123, 8) == "123" );
}
