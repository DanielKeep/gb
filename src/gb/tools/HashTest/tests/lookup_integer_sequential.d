module gb.tools.HashTest.tests.lookup_integer_sequential;

import gb.tools.HashTest.harness;

class Lookup_Integer_Sequential : Test
{
    size_t insertions       = 100_000u,
           insertion_stride = 1u,
           lookups          = 100_000u,
           lookup_stride    = 1u;

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
            lookups = to!(size_t)(args[1]);
        }
        if( args.length > 2 )
        {
            scope(failure) log.error("expected integer, got \"{}\"", args[2]);
            insertion_stride = to!(size_t)(args[2]);
            if( insertion_stride == 0u )
            {
                insertion_stride = 1u;
                log.info("insertion stride of 0 invalid; defaulting to 1");
            }
        }
        if( args.length > 3 )
        {
            scope(failure) log.error("expected integer, got \"{}\"", args[3]);
            lookup_stride = to!(size_t)(args[3]);
            if( lookup_stride == 0u )
            {
                lookup_stride = 1u;
                log.info("lookup stride of 0 invalid; defaulting to 1");
            }
        }
        if( args.length > 4 )
            foreach( i, arg ; args[3..$] )
                log.info("ignoring argument {}: \"{}\"", i+3, arg);
    }

    override char[] toString()
    {
        return nameLower
            ~"("~to!(char[])(insertions)
            ~","~to!(char[])(lookups)
            ~","~to!(char[])(insertion_stride)
            ~","~to!(char[])(lookup_stride)
            ~")";
    }

    private HM!(uint, uint) aa;

    override void init()
    {
        aa = hmInit!(uint, uint);
        for( size_t i=0; i<insertions; i += insertion_stride )
            aa[i] = i;
    }

    override void cleanup()
    {
        hmClear(aa);
    }

    override double run()
    {
        auto n = lookups;
        auto j = lookup_stride;
        uint v = 0u;
        
        StopWatch sw;
        sw.start;
        {
            if( lookup_stride == 1u )
            {
                for( size_t i=0; i<n; ++i )
                {
                    if( auto p = i in aa )
                        v |= *p;
                }
            }
            else
            {
                for( size_t i=0; i<n; i += j )
                {
                    if( auto p = i in aa )
                        v |= *p;
                }
            }
        }
        return sw.stop / ((cast(real)n)/j);
    }
}

static this()
{
    registerTest!(Lookup_Integer_Sequential);
}

