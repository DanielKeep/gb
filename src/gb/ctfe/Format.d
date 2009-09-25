/**
 * Compile-Time String Formatting.
 * 
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.ctfe.Format;

//debug = gb_Format_verbose;

import Integer = gb.ctfe.Integer;
import String = gb.ctfe.String;

private
{
    char[] stringify(Args...)(size_t index, int alignment,
                              char[] opt, Args args)
    {
        if( index >= args.length )
            return "{invalid index " ~ Integer.format_ctfe(index) ~ "}";

        assert( alignment == 0, "non-zero alignments not supported yet" );

        foreach( i,_ ; Args )
        {
            if( i == index )
            {
                static if( is( Args[i] : long ) || is( Args[i] : ulong ) )
                {
                    int base = 10;

                    if( opt == "x" )
                        base = 16;

                    else if( opt == "o" )
                        base = 8;

                    else if( opt == "b" )
                        base = 2;

                    return Integer.format_ctfe(args[i], base);
                }
                else static if( is( Args[i] : char[] ) )
                {
                    if( opt == "x" )
                    {
                        return "x\"" ~ String.hexify_ctfe(args[i][]) ~ "\"";
                    }
                    
                    if( opt == "q" )
                    {
                        return String.escape_ctfe(args[i][]);
                    }
                    
                    // If you don't slice, then the CALLER has to slice the
                    // string, otherwise CTFE barfs.
                    return args[i][];
                }
                else
                {
                    assert(false,"cannot stringify "~Args[i].stringof);
                }
            }
        }

        assert(false);
    }

    version( Unittest )
    {
        static assert( stringify(0, 0, "", 0) == "0" );
        static assert( stringify(0, 0, "", 1, -2, "abc") == "1" );
        static assert( stringify(1, 0, "", 1, -2, "abc") == "-2" );
        static assert( stringify(2, 0, "", 1, -2, "abc") == "abc" );

        static assert( stringify(0, 0, "x", "abc") == `x"616263"` );
        static assert( stringify(0, 0, "q", "abc") == `"abc"` );

        static assert( stringify(0, 0, "x", 0x4a) == "4a" );
    }
}

/**
 * Substitutes a set of arguments into a template string.
 *
 * The template string allows for the following escape forms:
 *
 * - $$ -- Literal dollar.
 * - $* -- Next argument.
 * - $n -- nth argument; 0-9 only.
 * - ${} -- Next argument.
 * - ${:f} -- Next argument, using format options "f".
 * - ${n} -- nth argument.
 * - ${n:f} -- nth argument, using format options "f".
 *
 * Eventually, alignment and named arguments will be supported.
 *
 * Supported formatting options are:
 *
 * - x -- format integer in hexadecimal.
 * - o -- format integer in octal.
 * - b -- format integer in binary.
 *
 * Params:
 *  tmpl    = template string.
 *  args    = arguments to substitute.
 * Returns:
 *  formatted string.
 */

char[] format_ctfe(Args...)(char[] tmpl, Args args)
{
    char[] r = "";
    int argPos = 0;
    
    while( tmpl.length > 0 )
    {
        bool inExp = false;
       
        // Look for a $
        foreach( i,c ; tmpl )
        {
            if (c == '$')
            {
                inExp = true;
                r ~= tmpl[0..i];
                tmpl = tmpl[i+1..$];
                break;
            }
        }

        // If we didn't find a $, it's because we hit the end of the template.
        if( !inExp )
        {
            r ~= tmpl;
            break;
        }
        
        // So we're in an expansion/substitution.

        debug(gb_Format_verbose) r ~= "{in exp}";

        if( tmpl.length == 0 )
        {
            r ~= "{unterminated substitution}";
            break;
        }

        // c is the next character, whilst tmpl is everything left in the
        // template string.
        char c = tmpl[0];
        tmpl = tmpl[1..$];
        
        // $$ - escaped $.
        if( c == '$' )
        {
            debug(gb_Format_verbose) r ~= "{escaped $}";
            r ~= '$';
            continue;
        }

        // $n - shortcut for ${n}.
        if( '0' <= c && c <= '9' )
        {
            debug(gb_Format_verbose) r ~= "{shorthand index}";
            r ~= stringify(c-'0', 0, "", args);
            continue;
        }

        // $* - shortcut for ${}
        if( c == '*' )
        {
            debug(gb_Format_verbose) r ~= "{shorthand next}";
            r ~= stringify(argPos++, 0, "", args);
            continue;
        }

        // This means we got a $ followed by something unexpected.
        if( c != '{' )
        {
            r ~= "{malformed substitution}";
            break;
        }
        
        if( tmpl.length == 0 )
        {
            r ~= "{unterminated substitution}";
            break;
        }
        
        debug(gb_Format_verbose)
        {
            r ~= "{parse complex at '";
            r ~= c;
            r ~= "':\"" ~ tmpl ~ "\"}";
        }

        // NOTE: We haven't updated c and tmpl yet.

        {
            // arg will contain the index of the argument the user wanted
            // substituted.
            size_t arg = size_t.max;
            // fmt will contain any additional formatting options.
            char[] fmt = "";

            // If we didn't get a : or }, that means we expect an index.
            if( !( tmpl[0] == ':' || tmpl[0] == '}' ) )
            {
                // So parse it.
                auto used = Integer.parse_ctfe!(size_t)(tmpl, true);
                
                if( used == 0 )
                {
                    debug(gb_Format_verbose) r ~= "{used zero of \""~tmpl~"\"}";
                    r ~= "{invalid argument index}";
                    break;
                }
                
                arg = Integer.parse_ctfe!(size_t)(tmpl);
                tmpl = tmpl[used..$];
                
                if( tmpl.length == 0 )
                {
                    r ~= "{unterminated substitution}";
                    break;
                }
            }
            else
            {
                // Otherwise, the index was elided, which means we want to use
                // the index of the "next" argument.
                arg = argPos;
                ++ argPos;
            }

            c = tmpl[0];
            tmpl = tmpl[1..$];

            debug(gb_Format_verbose)
                r ~= "{index " ~ Integer.format_ctfe(arg) ~ "}";

            // If c is :, then we've got formatting options to parse

            if( c == ':' )
            {
                debug(gb_Format_verbose) r ~= "{fmt string}";

                // Look for the closing }.
                size_t len = 0;
                foreach( i,d ; tmpl )
                {
                    if( d == '}' )
                    {
                        len = i;
                        break;
                    }
                }
                if( len == 0 )
                {
                    r ~= "{malformed format}";
                    break;
                }
                fmt = tmpl[0..len];
                tmpl = tmpl[len..$];

                if( tmpl.length == 0 )
                {
                    r ~= "{unterminated substitution}";
                    break;
                }

                c = tmpl[0];
                tmpl = tmpl[1..$];
            }

            // At this point, we should have the closing }.  If not, someone's
            // screwed up.
            if( c != '}' )
            {
                debug(gb_Format_verbose)
                {
                    r ~= "{expected closing; got '";
                    r ~= c;
                    r ~= "':\"" ~ tmpl ~ "\"}";
                }
                r ~= "{malformed substitution}";
                break;
            }

            // Stringify that bugger.
            r ~= stringify(arg, 0, fmt, args);

            // When we fall off the end here, we'll continue with the
            // remainder of tmpl, unless it's empty in which case we're
            // finished.
        }
    }
    
    return r;
}

version( Unittest )
{
    static assert(format_ctfe("A: $$", "foo"[]) == "A: $");
    static assert(format_ctfe("B: a $$ c", "b"[]) == "B: a $ c");
    
    static assert(format_ctfe("C: ${}", "foo"[]) == "C: foo");
    static assert(format_ctfe("D: a ${} c", "b"[]) == "D: a b c");
    
    static assert(format_ctfe("E: $0", "foo"[]) == "E: foo");
    static assert(format_ctfe("F: a $0 c", "b"[]) == "F: a b c");
    
    static assert(format_ctfe("G: $*", "foo"[]) == "G: foo");
    static assert(format_ctfe("H: a $* c", "b"[]) == "H: a b c");
    
    static assert(format_ctfe("I: ${0}", "foo"[]) == "I: foo");
    static assert(format_ctfe("J: a ${0} c", "b"[]) == "J: a b c");

    static assert(format_ctfe("K: ${} ${} ${}", 1, -2, "c"[]) == "K: 1 -2 c");
    static assert(format_ctfe("L: $* $* $*", 1, -2, "c"[]) == "L: 1 -2 c");
    static assert(format_ctfe("M: $0 $1 $2", 1, -2, "c"[]) == "M: 1 -2 c");
    static assert(format_ctfe("N: ${0} ${1} ${2}", 1, -2, "c"[]) == "N: 1 -2 c");

    static assert(format_ctfe("O: ${2} ${0} ${1}", 1, -2, "c"[]) == "O: c 1 -2");

    static assert(format_ctfe("P: ${:x} ${0:x} ${0:o} ${0:b}", 42) == "P: 2a 2a 52 101010");
}

