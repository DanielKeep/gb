/**
 * Interval structure.
 *
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.interval;

private
{
    import tango.core.Traits : isIntegerType;
    import tango.text.convert.Format : Format;
}

/**
 * Intervals represent a range of integer values.
 *
 * Instances of this type can be iterated, indexed, sliced and converted to an
 * array.  They also support the Range interface as a byproduct of being
 * ported from D2 code.
 */
struct Interval(T)
{
    static assert( isIntegerType!(T),
            "only intervals over the integers are supported.");

    /// This is the smallest value contained within the interval.
    T min = T.init;
    /// This is the largest value contained within the interval.
    T max = T.init-1;
    /// This is the stride, or distance between successive values in the
    /// interval.
    T stride = 1;

    /// Construct an interval given a minimum and maximum value.
    static Interval opCall(T min, T max)
    {
        Interval this_;
        
        if( max < min )
            max = min;

        this_.min = min;
        this_.max = max;
        
        return this_;
    }

    /// Construct an interval given a minimum and maximum value plus a stride.
    static Interval opCall(T min, T max, T stride)
    {
        Interval this_;
        
        // Ensure max is actually in the interval
        max = min + stride*((max-min)/stride);

        if( max < min )
            max = min;

        this_.min = min;
        this_.max = max;
        this_.stride = stride;
        
        return this_;
    }

    char[] toString()
    {
        if( stride == 1 )
            return Format("inter[{}, {}]", min, max);

        else
            return Format("inter[{}, {}] / {}", min, max, stride);
    }

    /// Determines if a given value is contained within the interval.
    bool opIn_r(T v)
    {
        if( stride == 1 )
            return (min <= v && v <= max);

        else
        {
            return (min <= v && v <= max)
                && ((v-min) % stride == 0);
        }
    }

    /// Returns an interval that contains every stride'th element.  This has
    /// the practical effect of multiplying the interval's stride.
    Interval opDiv(T stride)
    {
        if( stride == 0 )
            throw new Exception("intervals cannot have a zero stride");

        return Interval(min, max, this.stride*stride);
    }

    /// Returns an interval that contains only elements that are divisible by
    /// the given divisor.
    Interval opMod(T divisor)
    {
        auto new_stride = stride*divisor;

        return Interval(
                min + min%(new_stride),
                max,
                new_stride);
    }

    /+
    // Disabled because it's too hard to work out and I'm lazy.
    Interval opAnd(Interval other) const
    {
        auto new_min = (this.min > other.min) ? this.min : other.min;
        auto new_max = (this.max < other.max) ? this.max : other.max;

        if( this.stride == 1 && other.stride == 1 )
            return Interval(new_min, new_max);

        /*
           The problem now is determining the new stride and the new
           minimum.  Consider the following:

           (inter[0..10] / 2) & (inter[0..10] / 3)
            == [0, 2, 4, 6, 8] & [0, 3, 6, 9]
            == [0, 6]

           (inter[0..10] / 2) & (inter[1..10] / 2)
            == []

           (inter[0..10] / 2) & (inter[1..10] / 3)
            == [0, 2, 4, 6, 8] & [1, 4, 7]
            == [4]
        */
    }
    +/

    /// Returns the number of elements in the interval.
    size_t length()
    {
        if( stride == 1 )
            return (max-min) + 1;
        else
            return (max-min)/stride + 1;
    }

    /// Converts the interval to an array.
    T[] toArray()
    {
        auto arr = new T[length];
        auto p = &arr[0];
        for( T i = min; i <= max; i += stride )
            *(p++) = i;
        return arr;
    }

    /// Allows you to foreach over an interval.
    int opApply(int delegate(ref T) dg)
    {
        int r = 0;
        for( T i = min; i <= max; i += stride )
        {
            auto v = i;
            r = dg(v);
            if( r )
                break;
        }
        return r;
    }

    /*
     *
     * Range interface
     *
     */

    bool empty()
    {
        return (max<min);
    }

    T front()
    {
        return min;
    }

    T back()
    {
        return max;
    }

    void popFront()
    {
        if( min > T.max-stride )
            max -= stride;
        else
            min += stride;
    }

    void popBack()
    {
        if( max < T.min+stride )
            min += stride;
        else
            max -= stride;
    }

    T opIndex(size_t offset)
    {
        if( offset >= length )
            throw new Exception("out of bounds of interval");
        
        return min + stride*offset;
    }

    Interval opSlice(size_t a, size_t b)
    {
        auto l = length;
        if( a >= length || b >= length )
            throw new Exception("out of bounds of interval");

        return Interval(
                min + stride*a,
                max + stride*b,
                stride);
    }
}

/**
 * This is used to create a new interval.
 */
struct inter
{
    /// Create an interval over (a,b) (i.e. an exclusive range).
    static Interval!(T) opCall(T)(T a, T b)
    {
        return Interval!(T)(a+1, b-1);
    }

    /// Create an interval over [a,b] (i.e. an inclusive range).
    static Interval!(T) opIndex(T)(T a, T b)
    {
        return Interval!(T)(a, b);
    }

    /// Create an interval over [a,b) (i.e. inclusive left side, exclusive
    /// right side).
    static Interval!(T) opSlice(T)(T a, T b)
    {
        return Interval!(T)(a, b-1);
    }
}
