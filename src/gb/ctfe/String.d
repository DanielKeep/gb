/**
 * CTFE String routines.
 * 
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.ctfe.String;

import Integer = gb.ctfe.Integer;

private
{
    const HEX_CHARS = "0123456789abcdef";
}

/**
 * Escapes a string into an equivalent string literal.
 * 
 * Params:
 *     str = string to escape.
 *     aggressive = if set, the function will escape all non-printing
 *                  characters, non-space whitespace and newlines.  Defaults
 *                  to true.
 * Returns:
 *      Escaped string literal.
 */
char[] escape_ctfe(char[] str, bool aggressive=true)
{
    char[] head = "";
    
    foreach( i,c ; str )
    {
        if( c == '"' || c == '\\' || c == '\0' )
        {
            head = "\""~str[0..i];
            str = str[i..$];
            break;
        }
        
        if( aggressive )
        {
            if( c < 0x20 || c == 0x7f )
            {
                head = "\""~str[0..i];
                str = str[i..$];
                break;
            }
        }
    }
    
    if( head.length == 0 )
        return "\"" ~ str ~ "\"";
    
    char[] tail = "";
    
    foreach( c ; str )
    {
        if( c == '"' )
            tail ~= `\"`;
        
        else if( c == '\\' )
            tail ~= `\\`;
        
        else if( c == '\0' )
            tail ~= `\0`;
        
        else if( aggressive )
        {
            switch( c )
            {                    
                case '\?':
                    tail ~= `\?`;
                    break;
                    
                case '\a':
                    tail ~= `\a`;
                    break;
                    
                case '\b':
                    tail ~= `\b`;
                    break;
                    
                case '\f':
                    tail ~= `\f`;
                    break;
                    
                case '\n':
                    tail ~= `\n`;
                    break;
                    
                case '\r':
                    tail ~= `\r`;
                    break;
                    
                case '\t':
                    tail ~= `\t`;
                    break;
                    
                case '\v':
                    tail ~= `\v`;
                    break;

                default:
                    if( c < 0x20 || c == 0x75 )
                    {
                        tail ~= `\x`;
                        tail ~= HEX_CHARS[c/0xf];
                        tail ~= HEX_CHARS[c&0xf];
                    }
                    else
                        tail ~= c;
            }
        }
        else
            tail ~= c;
    }
    
    return head ~ tail ~ "\"";
}

version( Unittest )
{
    static assert( escape_ctfe("abc") == "\"abc\"" );
    static assert( escape_ctfe("a\"c") == "\"a\\\"c\"" );
}

/**
 * Turns an array of bytes into a hexadecimal string.
 * 
 * Params:
 *     arr = array to hexify.
 *     grouping = if non-zero, specifies after how many bytes to insert a
 *                space.
 * Returns:
 *      String of hex bytes.
 */

char[] hexify_ctfe(ubyte[] arr, int grouping = 0)
{
    char[] r = "";
    int bytes = grouping;
    foreach( b ; arr )
    {
        if( bytes == 0 && grouping > 0 )
        {
            r ~= ' ';
            bytes = grouping;
        }

        auto bh = b/16;
        auto bl = b&15;
        
        assert( bh < 16 );
        assert( bl < 16 );
        
        r ~= HEX_CHARS[bh];
        r ~= HEX_CHARS[bl];
        
        if( grouping > 0 )
            -- bytes;
    }
    return r;
}

version( Unittest )
{
    static const ubyte[] DATA_1 = [0x00,0x01,0x02,0x03];
    static const ubyte[] DATA_2 = [0x0f,0x10,0xef,0xf0];

    static assert( hexify_ctfe(DATA_1) == "00010203" );
    static assert( hexify_ctfe(DATA_2) == "0f10eff0" );
    
    static assert( hexify_ctfe(DATA_1, 1) == "00 01 02 03" );
    static assert( hexify_ctfe(DATA_2, 1) == "0f 10 ef f0" );
    
    static assert( hexify_ctfe(DATA_1, 2) == "0001 0203" );
    static assert( hexify_ctfe(DATA_2, 2) == "0f10 eff0" );
    
    static assert( hexify_ctfe(DATA_1, 4) == "00010203" );
    static assert( hexify_ctfe(DATA_2, 4) == "0f10eff0" );
}

/**
 * Pads a string.  padl adds padding to the left, padr adds it to the right.
 * Params:
 *     str = string to pad.
 *     len = length to pad to.
 *     padding = character to use for padding.  Defaults to space.
 * Returns:
 *      padded string.
 */

char[] padl_ctfe(char[] str, int len, char padding = ' ')
{
    while( str.length < len )
        str = padding ~ str;
    return str;
}

/// ditto

char[] padr_ctfe(char[] str, int len, char padding = ' ')
{
    while( str.length < len )
        str ~= padding;
    return str;
}

version( Unittest )
{
    static assert( padl_ctfe("abc", 2) == "abc" );
    static assert( padl_ctfe("abc", 3) == "abc" );
    static assert( padl_ctfe("abc", 4) == " abc" );
    static assert( padl_ctfe("abc", 4, 'x') == "xabc" );

    static assert( padr_ctfe("abc", 2) == "abc" );
    static assert( padr_ctfe("abc", 3) == "abc" );
    static assert( padr_ctfe("abc", 4) == "abc " );
    static assert( padr_ctfe("abc", 4, 'x') == "abcx" );
}
