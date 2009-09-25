/**
 * Various contract and validity-related things.
 * 
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.util.Contract;

import gb.util.Exceptions : SimpleException;

import tango.util.Convert;

/**
 * This exception is thrown when an enforced check fails.
 */

mixin SimpleException!("Enforce", "Enforcement fialure");

/**
 * This exception is thrown if a null reference is found where one is not
 * expected.
 */

mixin SimpleException!("Null", "Unexpected null reference");

/**
 * Enforces that the value of the expression passed to it is logically true.
 * If not, it throws an EnforceException.
 * 
 * You may optionally pass the file and line from which enforce is being
 * called.  It is recommended to do so, even if it is horribly tedious.
 * 
 * Params:
 *     expr = condition to test.
 *     file = filename from which enforce is being called; use __FILE__.
 *     line = line from which enforce is being called; use __LINE__.
 *     msg = optional message; ideally, this should describe what was
 *           expected and what was actually true.
 * Returns:
 *      The result of the expression.
 */
T enforce(T)(T expr, lazy char[] msg = null)
{
    if( ! expr )
    {
        if( msg !is null )
            throw new EnforceException(msg());
        
        else
            throw new EnforceException;
    }
    return expr;
}

/// ditto
T enforce(T, FileT, LineT)(T expr, FileT file, LineT line, lazy char[] msg = null)
{
    if( ! expr )
    {
        if( msg !is null )
            throw new EnforceException(msg(), file, line);
        
        else
            throw new EnforceException(file, line);
    }
    return expr;
}

version( Unittest )
{
    import tango.io.Stdout;

    unittest
    {
        Stderr.formatln("BEGIN {}:{}", __FILE__, __LINE__);
        scope(success) Stderr.formatln("SUCCESS");
        scope(failure) Stderr.formatln("FAILURE");

        assert( enforce(4) == 4 );
        assert( enforce(true, __FILE__, __LINE__) == true );
        try
        {
            enforce(false);
            assert(false);
        }
        catch( EnforceException e )
        {
        }
    }
}

version(DDoc)
{
    /**
     * Allows you to enforce a condition with a custom exception.
     * 
     * The exception class given must have a default constructor and a
     * constructor that takes a message.  If you call the variant which
     * accepts file and line numbers, the exception must have the appropriate
     * constructors.
     * 
     * Example:
     * -----
     *  enforceEx!(MyException).enforce(i <= 10);
     * -----
     * 
     * Params:
     *     test = condition.
     *     file = optional file from which enforceEx is being called; use __FILE__.
     *     line = optional line from which enforceEx is being called; use __LINE__.
     *     msg = optional message to use if enforcement fails.
     * Returns:
     *      test.
     */
    
    T enforceEx(ExceptionT, T)(T test, lazy char[] msg = null);

    /// ditto
    T enforceEx(ExceptionT, T)(T test, char[] file, long line,
            lazy char[] msg = null);
}
else
{
    template enforceEx(ExceptionT)
    {
        T enforce(T)(T test, lazy char[] msg = null)
        {
            if( !test )
            {
                if( msg !is null )
                {
                    static if( is(typeof({ new ExceptionT(msg()); }())) )
                    {
                        throw new ExceptionT(msg());
                    }
                    else
                    {
                        static assert( false, "enforceEx cannot throw"
                                " exceptions of type " ~ ExceptionT.stringof
                                ~ ": no message constructor" );
                    }
                }
                else
                {
                    static if( is(typeof({ new ExceptionT(); }())) )
                    {
                        throw new ExceptionT();
                    }
                    else
                    {
                        enforce( false, "enforceEx cannot throw"
                                " exceptions of type " ~ ExceptionT.stringof
                                ~ " without a message." );
                    }
                }
            }
            return test;
        }

        T enforce(T, FileT, LineT)(T test, FileT file, LineT line,
                lazy char[] msg = null)
        {
            if( !test )
            {
                if( msg !is null )
                {
                    static if( is(typeof({ new ExceptionT(msg(), file, line); }())) )
                    {
                        throw new ExceptionT(msg(), file, line);
                    }
                    else static if( is(typeof({ new ExceptionT(""); }())) )
                    {
                        throw new ExceptionT(msg()
                                ~ "(at "~file~":"~to!(char[])(line)~")");
                    }
                    else
                    {
                        static assert( false, "enforceEx cannot throw"
                                " exceptions of type " ~ ExceptionT.stringof
                                ~ ": no message constructor" );
                    }
                }
                else
                {
                    static if( is(typeof({ new ExceptionT(file, line); }())) )
                    {
                        throw new ExceptionT(file, line);
                    }
                    else static if( is(typeof({ new ExceptionT(""); }())) )
                    {
                        throw new ExceptionT("enforcement failure at "
                                ~ file ~ ":" ~ to!(char[])(line));
                    }
                    else
                    {
                        static assert( false, "enforceEx cannot throw"
                                " exceptions of type " ~ ExceptionT.stringof
                                ~ ": no message constructor" );
                    }
                }
            }
            return test;
        }
    }

    version( Unittest )
    {
        class DummyException : Exception
        {
            this() { super("dummy"); }
            this(char[] msg) { super(msg); }
            this(char[] file, long line) { super("dummy", file, line); }
            this(char[] msg, char[] file, long line) { super(msg, file, line); }
        }
        
        import tango.io.Stdout;

        unittest
        {
            Stderr.formatln("BEGIN {}:{}", __FILE__, __LINE__);
            scope(success) Stderr.formatln("SUCCESS");
            scope(failure) Stderr.formatln("FAILURE");

            enforceEx!(DummyException).enforce(true);
            enforceEx!(DummyException).enforce(true, "I've been kickin' ass");
            enforceEx!(DummyException).enforce(true, __FILE__, __LINE__);
            enforceEx!(DummyException).enforce(true, __FILE__, __LINE__,
                    "since the dawn of time,");
            
            try
            {
                enforceEx!(DummyException).enforce(false);
                assert(false);
            }
            catch( DummyException e )
                {}
        }
    }
}

version( DDoc )
{
    /**
     * Ensures that all references passed to it are non-null.  If any are found
     * to be null, it throws a NullException specifying the type of object that
     * was found to be null.
     * 
     * Params:
     *     file = optional file that nonNull is being called from; use __FILE__.
     *     line = optional line that nonNull is being called from; use __LINE__.
     *     refs = sequence of references to test.
     * Returns:
     *      The first reference.
     */
    RefTs[0] nonNull(RefTs...)(RefTs refs);
    /// ditto
    RefTs[0] nonNull(RefTs...)(char[] file, long line, RefTs refs);
}
else
{
    NonNullReturn!(RefTs) nonNull(RefTs...)(RefTs refs)
    {
        static if( RefTs.length >= 2
                   && is(RefTs[0] : char[]) && is(RefTs[1] == long) )
        {
            static assert( RefTs.length > 2,
                    "nonNull requires one or more arguments" );
            
            foreach( i, ref_ ; refs[2..$] )
            {
                if( ref_ is null )
                    throw new NullException(
                        "Unexpected null " ~ RefTs[i+2].stringof ~ " reference"
                        " (argument "~ to!(char[])(i) ~")");
            }
            
            return refs[2];
        }
        else
        {
            static assert( RefTs.length > 0,
                    "nonNull requires one or more arguments" );
            
            foreach( i, ref_ ; refs )
            {
                if( ref_ is null )
                    throw new NullException(
                        "Unexpected null " ~ RefTs[i].stringof ~ " reference"
                        " (argument "~ to!(char[])(i) ~")");
            }
            
            return refs[0];
        }
    }
    
    private template SafeReturnType(T)
    {
        static if( is( T U : U[] ) )
            alias U[] SafeReturnType;
        else
            alias T SafeReturnType;
    }
    
    static assert( is( SafeReturnType!(int) == int ) );
    static assert( is( SafeReturnType!(char[10]) == char[] ) );
    
    private template NonNullReturn(Ts...)
    {
        static if( Ts.length == 0 )
            alias void NonNullReturn;
        
        else static if( Ts.length >= 2
                        && is( Ts[0] : char[] ) && is( Ts[1] == long ) )
            alias NonNullReturn!(Ts[2..$]) NonNullReturn;
        
        else
            alias SafeReturnType!(Ts[0]) NonNullReturn;
    }
    
    version( Unittest )
    {
        import tango.io.Stdout;

        unittest
        {
            Stderr.formatln("BEGIN {}:{}", __FILE__, __LINE__);
            scope(success) Stderr.formatln("SUCCESS");
            scope(failure) Stderr.formatln("FAILURE");

            scope a = new Object;
            scope b = new int;
            scope c = "abc".dup;
            assert( nonNull(__FILE__,__LINE__, a, b, c) is a );
            assert( nonNull(a, b, c) is a );
            try
            {
                nonNull(cast(Object) null);
                assert(false);
            }
            catch( NullException e )
            {
            }
        }
    }
}
