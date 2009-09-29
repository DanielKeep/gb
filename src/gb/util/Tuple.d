/**
 * Tuple-related stuff.
 * 
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.util.Tuple;

import tango.core.Tuple;

template Sequence(int max)
{
    static if( max <= 0 )
        alias Tuple!() Sequence;
    else
        alias Tuple!(Sequence!(max-1), max-1) Sequence;
}

version( Unittest )
{
    static assert( Sequence!(3)[0] == 0 );
    static assert( Sequence!(3)[1] == 1 );
    static assert( Sequence!(3)[2] == 2 );
    static assert( Sequence!(3).length == 3 );
}
