module gb.tools.HashTest.tests.insert_sequential;

import gb.tools.HashTest.harness;

class Insert_Sequential : Test
{
    size_t insertions = 1_000_000u;
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

    override double run()
    {
        auto aa = hmInit!(int, int);
        scope(exit) hmClear(aa);

        auto n = insertions;
        auto j = stride;

        StopWatch sw;
        sw.start;
        {
            if( stride == 1u )
            {
                for( size_t i=0; i<n; ++i )
                    aa[i] = i;
            }
            else
            {
                for( size_t i=0; i<n; i += j )
                    aa[i] = i;
            }
        }
        return sw.stop / ((cast(real)n)/j);
    }
}

static this()
{
    registerTest!(Insert_Sequential);
}

