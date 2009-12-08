module test;

import gb.util.Invoke;

extern(C)
{
    int addInts(int a, int b)
    {
        return a+b;
    }

    float addFloats(float a, float b)
    {
        return a+b;
    }

    char[] catStrings(char[] a, char[] b)
    {
        return a~b;
    }

    struct xyz
    {
        float x, y, z;
    }

    xyz getPoint(float mag)
    {
        return xyz(1.0*mag, 2.0*mag, 3.0*mag);
    }

    struct oneFloat
    {
        float value;
    }

    oneFloat getOneFloat(float v)
    {
        return oneFloat(v);
    }

    struct threeBytes
    {
        ubyte a, b, c;
    }

    threeBytes getThreeBytes(ubyte a, ubyte b, ubyte c)
    {
        return threeBytes(a, b, c);
    }

    ifloat getIFloat(float im)
    {
        return im * 1.0fi;
    }

    cfloat getCFloat(float re, float im)
    {
        return re + im*1.0fi;
    }
}

import gb.util.Invoke;
import tango.core.Variant;

T inv(T)(void* proc, ...)
{
    T result;
    result = invoke(proc, CallConv.C, typeid(T),
            Variant.fromVararg(_arguments, _argptr)).get!(T);
    return result;
}

void main()
{
    auto cc = CallConv.C;

    assert( inv!(int)(&addInts, 2, 3) == 5 );
    assert( inv!(float)(&addFloats, 2.0f, 3.0f) == 5.0f );
    assert( inv!(char[])(&catStrings, "Hello, "[], "World!"[])
            == "Hello, World!" );
    assert( inv!(oneFloat)(&getOneFloat, 7.0f).value == 7.0f );
    assert( inv!(threeBytes)(&getThreeBytes,
                cast(ubyte) 1, cast(ubyte) 2, cast(ubyte) 3)
            == threeBytes(1, 2, 3) );
    assert( inv!(ifloat)(&getIFloat, 42.0f) == 42.0fi );
    assert( inv!(cfloat)(&getCFloat, 6.0f, 9.0f) == (6.0f+9.0fi) );
}

