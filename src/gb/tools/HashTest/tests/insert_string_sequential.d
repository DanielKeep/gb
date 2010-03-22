module gb.tools.HashTest.tests.insert_string_sequential;

import gb.tools.HashTest.harness;

class Insert_String_Sequential : Test
{
    size_t insertions = 100_000u;
    size_t stride = 1u;

    override void config(char[][] args)
    {
        if( args.length > 0 )
        {
            scope(failure) log.error("expected integer, got \"{}\"", args[0]);
            insertions = to!(size_t)(args[0]);
        }
        if( args.length > 1 )
        {
            scope(failure) log.error("expected integer, got \"{}\"", args[1]);
            stride = to!(size_t)(args[1]);
            if( stride == 0u )
            {
                stride = 1u;
                log.info("stride of 0 invalid; defaulting to 1");
            }
        }
        if( args.length > 2 )
            foreach( i, arg ; args[1..$] )
                log.info("ignoring argument {}: \"{}\"", i+1, arg);
    }

    override char[] toString()
    {
        return nameLower
            ~"("~to!(char[])(insertions)
            ~","~to!(char[])(stride)
            ~")";
    }

    private static void incStr(inout char[] k)
    {
        bool overflow = true;

incLoop:
        for( size_t i=0; i<k.length; ++i )
        {
            switch( k[i] )
            {
                case 'a': case 'b': case 'c': case 'd': case 'e':
                case 'f': case 'g': case 'h': case 'i': case 'j':
                case 'k': case 'l': case 'm': case 'n': case 'o':
                case 'p': case 'q': case 'r': case 's': case 't':
                case 'u': case 'v': case 'w': case 'x': case 'y':

                case 'A': case 'B': case 'C': case 'D': case 'E':
                case 'F': case 'G': case 'H': case 'I': case 'J':
                case 'K': case 'L': case 'M': case 'N': case 'O':
                case 'P': case 'Q': case 'R': case 'S': case 'T':
                case 'U': case 'V': case 'W': case 'X': case 'Y':
                
                case '0': case '1': case '2': case '3': case '4':
                case '5': case '6': case '7': case '8':
                    ++k[i];
                    overflow = false;
                    break incLoop;

                case 'z':
                    k[i] = 'A';
                    overflow = false;
                    break incLoop;

                case 'Z':
                    k[i] = '0';
                    overflow = false;
                    break incLoop;

                case '9':
                    k[i] = 'a';
                    break;
            }
        }

        if( overflow )
            k = k ~ "a";
    }

    private char[][] keys;

    override void init()
    {
        keys = new char[][](insertions);
        char[] currentKey = "a".dup;
        keys[0] = currentKey.dup;

        foreach( ref key ; keys[1..$] )
        {
            for( size_t i=0; i<stride; ++i )
                incStr(currentKey);
            key = currentKey.dup;
        }
    }

    override void cleanup()
    {
        keys = null;
        GC.collect();
    }

    override double run()
    {
        auto aa = hmInit!(char[], int);
        scope(exit) hmClear(aa);

        auto n = keys.length;

        StopWatch sw;
        sw.start;
        {
            for( size_t i=0; i<n; ++i )
                aa[keys[i]] = i;
        }
        return sw.stop / (cast(real)n);
    }
}

static this()
{
    registerTest!(Insert_String_Sequential);
}

