/**
 * Provides wrapping and common methods for the various AA/hashmap
 * implementations we can test.
 *
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.tools.HashTest.hm;

import tango.core.Memory : GC;

version( UseGB )
    version = _UseGB;
else version( UseBuiltin )
    version = _UseBuiltin;
else version( UseTango )
    version = _UseTango;
else
{
    pragma(msg, "Please compile with one of the following to specify which");
    pragma(msg, "implementation to benchmark:");
    pragma(msg, "");
    pragma(msg, " -version=UseGB      - gb.util.HashMap");
    pragma(msg, " -version=UseBuiltin - builtin D associative arrays");
    pragma(msg, " -version=UseTango   - tango.util.container.HashMap");
    pragma(msg, "");
    static assert(false, "implementation to test not specified.");
}

version( _UseGB )
{
    import gb.util.HashMap : HashMap;

    template HM(K,V)
    {
        alias HashMap!(K,V) HM;
    }

    HM!(K,V) hmInit(K,V)()
    {
        return HM!(K,V).init;
    }

    void hmClear(T)(ref T aa)
    {
        aa.clear;
    }

    size_t hmLength(T)(T aa)
    {
        return aa.length;
    }

    char[] hmSignature()
    {
        return "gb";
    }
}
else version( _UseBuiltin )
{
    template HM(K,V)
    {
        alias K[V] HM;
    }

    HM!(K,V) hmInit(K,V)()
    {
        return HM!(K,V).init;
    }

    void hmClear(T)(ref T aa)
    {
        aa = null;
        GC.collect;
    }

    size_t hmLength(T)(T aa)
    {
        return aa.length;
    }

    char[] hmSignature()
    {
        return "builtin";
    }
}
else version( _UseTango )
{
    import tango.util.container.HashMap : HashMap;

    alias HashMap HM;

    HM!(K,V) hmInit(K,V)()
    {
        return new HM!(K,V);
    }

    void hmClear(T)(ref T aa)
    {
        aa.reset();
        aa = null;
        GC.collect();
    }

    size_t hmLength(T)(T aa)
    {
        return aa.size;
    }

    char[] hmSignature()
    {
        return "tango";
    }
}

