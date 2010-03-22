module gb.tools.HashTest.harness;

import hm = gb.tools.HashTest.hm;
import VariantMod = tango.core.Variant;
import StopWatchMod = tango.time.StopWatch;
import Convert = tango.util.Convert;
import LogMod = tango.util.log.Log;

import tango.text.Unicode : toLower;

abstract class Test
{
    alias hm.HM HM;
    alias hm.hmInit hmInit;
    alias hm.hmClear hmClear;
    alias hm.hmLength hmLength;
    alias VariantMod.Variant Variant;
    alias StopWatchMod.StopWatch StopWatch;
    alias Convert.to to;

    this()
    {
        log = LogMod.Log.lookup("test."~this.nameLower);
    }

    private char[] _name;

    final char[] name()
    {
        if( _name is null )
        {
            auto str = this.classinfo.name;
            // HACK: this loop condition excludes the first character.  But since
            // everything ALWAYS starts with "gb.tools.blah.blah" anyway, we'll
            // stop long before then anyway.
            for( size_t i=str.length-1; i>0; --i )
                if( str[i] == '.' )
                {
                    _name = str[i+1..$];
                    break;
                }
        }
        return _name;
    }

    private char[] _nameLower;

    final char[] nameLower()
    {
        if( _nameLower is null )
        {
            _nameLower = toLower(name);
        }
        return _nameLower;
    }

    void config(char[][] args)
    {
        foreach( i, arg ; args )
            log.info("ignoring argument {}: \"{}\"", i, arg);
    }

    char[] toString()
    {
        return nameLower;
    }

    void init()
    {
    }

    void cleanup()
    {
    }

    double run();

    protected LogMod.Logger log;
}

Test function()[char[]] factories;

void registerTest(TestClass)()
{
    scope dummy = new TestClass;
    factories[dummy.nameLower] = function() { return cast(Test) new TestClass; };
}

char[] matchTestName(char[] needle)
{
testNameLoop:
    foreach( testName,_ ; factories )
    {
        size_t i = 0;

        foreach( c ; needle )
        {
            if( c == testName[i] )
                ++ i;

            else if( c == '_' || c == '-' || c == '.' )
            {
                // Skip ahead
                while( testName[i] != '_' )
                    ++ i;

                if( i == testName.length )
                    // Doesn't match
                    continue testNameLoop;

                // Skip over the _
                ++ i;
            }
            else
                continue testNameLoop;
        }

        // If we matched thus far, we'll accept it.
        return testName;
    }
}

