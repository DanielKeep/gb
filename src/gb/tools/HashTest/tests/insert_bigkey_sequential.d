module gb.tools.HashTest.tests.insert_bigkey_sequential;

import gb.tools.HashTest.harness;

struct BigKey
{
    ulong a, b;
    uint c, d;
    double e;
    ubyte[32] f;

    void inc()
    {
        ++ a; if( a > 0 ) return;
        ++ b; if( b > 0 ) return;
        ++ c; if( c > 0 ) return;
        ++ d; if( d > 0 ) return;
        e = cast(real) a + cast(real) b
            + cast(real) c + cast(real) d;

        auto data = (cast(ubyte*) this)[0..32];
        for( size_t i=0; i<32; ++i )
            f[i] = "I'm a lumberjack and I'm OK! ;-)"[i] ^ data[i];
    }
}

class Insert_BigKey_Sequential : Test
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

    private BigKey[] keys;

    override void init()
    {
        keys = new BigKey[](insertions);

        BigKey cur;

        for( size_t i=0; i<insertions; ++i )
        {
            for( size_t j=0; j<stride; ++j )
                cur.inc;
            keys[i] = cur;
        }
    }

    override void cleanup()
    {
        delete keys;
    }

    override double run()
    {
        auto aa = hmInit!(BigKey, int);
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
    registerTest!(Insert_BigKey_Sequential);
}

