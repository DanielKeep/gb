/**
 * Dynamic function invocation.
 *
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.util.Invoke;

public import gb.util.invokeImpl.Decl : CallConv;
public import tango.core.Variant : Variant;

version( X86 )
{
    version( Win32 )
    {
        private import impl = gb.util.invokeImpl.x86.Win32;
    }
    else
    {
        static assert(false, "unsupported OS");
    }
}
else
{
    static assert(false, "unsupported platform");
}

/**
 * This will invoke a procedure/function.  It allows functions to be called at
 * runtime without needing to know their type at compile time.
 *
 * Note that this function DOES NOT do any type-checking of the arguments or
 * result.  Nor does it perform implicit casting of arguments or results.
 *
 * It is very important that the TypeInfo passed is accurate.  Certain types
 * change the way values are passed.  For example, if a function really
 * returns a 32-bit integer and you pass the TypeInfo for a 32-bit float as
 * the result type, the function will not execute correctly.
 *
 * Needless to say, this function is VERY dangerous if you don't have accurate
 * information.
 *
 * Params:
 *  proc    = pointer to the function/procedure to be invoked.
 *  conv    = calling convention the procedure uses.
 *  varargPos = if the function uses varargs, this contains the index into the
 *            argument list at which the vararg portion begins.  Important for
 *            the D calling convention.
 *  result  = TypeInfo for the result type.
 *  args    = arguments to pass to the function.
 */
Variant invoke(void* proc, CallConv conv, size_t varargPos = size_t.max,
        TypeInfo result, Variant[] args)
{
    switch( conv )
    {
        case CallConv.C:
            static if( is(typeof( &mpl.callCProc )) )
                return impl.callCProc(proc, varargPos, result, args);

            else
                assert(false, "c calling convention not supported");

        case CallConv.Pascal:
            static if( is(typeof( &impl.callPascalProc )) )
                return impl.callPascalProc(proc, varargPos, result, args);

            else
                assert(false, "pascal calling convention not supported");

        case CallConv.FastCall:
            static if( is(typeof( &impl.callFastProc )) )
                return impl.callFastProc(proc, varargPos, result, args);

            else
                assert(false, "fastcall calling convention not supported");

        case CallConv.ThisCall:
            static if( is(typeof( &impl.callThisProc )) )
                return impl.callThisProc(proc, varargPos, result, args);

            else
                assert(false, "thiscall calling convention not supported");

        case CallConv.SafeCall:
            static if( is(typeof( &impl.callSafeProc )) )
                return impl.callSafeProc(proc, varargPos, result, args);

            else
                assert(false, "safecall calling convention not supported");

        case CallConv.D:
            static if( is(typeof( &impl.callDProc )) )
                return impl.callDProc(proc, varargPos, result, args);

            else
                assert(false, "d calling convention not supported");

        case CallConv.Ms64:
            static if( is(typeof( &impl.callMs64Proc )) )
                return impl.callMs64Proc(proc, varargPos, result, args);

            else
                assert(false, "microsoft x86-64 calling convention not supported");

        case CallConv.Amd64:
            static if( is(typeof( &impl.callAmd64Proc )) )
                return impl.callAmd64Proc(proc, varargPos, result, args);

            else
                assert(false, "amd64 calling convention not supported");

        default:
            assert(false, "unsupported calling convention");
    }
}

