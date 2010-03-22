module gb.tools.HashTest.tests.insert_integer_random;

import gb.tools.HashTest.harness;
import tango.math.random.Kiss;

class Insert_Integer_Random : Test
{
    size_t insertions = 100_000u;
    size_t seed = 0u;

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
            seed = to!(size_t)(args[1]);
        }
        if( args.length > 2 )
            foreach( i, arg ; args[1..$] )
                log.info("ignoring argument {}: \"{}\"", i+1, arg);
    }

    override char[] toString()
    {
        return nameLower
            ~"("~to!(char[])(insertions)
            ~","~to!(char[])(seed)
            ~")";
    }

    private size_t[] keys;

    override void init()
    {
        keys = new size_t[](insertions);
        Kiss rng;
        rng.seed(seed);

        foreach( ref k ; keys )
            k = rng.natural;
    }

    override void cleanup()
    {
        delete keys;
    }

    override double run()
    {
        auto aa = hmInit!(size_t, size_t);
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
    registerTest!(Insert_Integer_Random);
}

