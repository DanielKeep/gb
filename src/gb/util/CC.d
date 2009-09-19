/**
 * Contains conditional compilation-related stuff.
 * 
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.util.CC;

import gb.ctfe.Integer;

template Version(char[] name)
{
    mixin("version("~name~") const Version = true; else const Version = false;");
}

template Version(int level)
{
    mixin("version(" ~ format_ctfe(level) ~ ")"
            "const Version = true;"
            "else const Version = false;");
}

template Debug()
{
    debug const Debug = true; else const Debug = false;
}

template Debug(int level)
{
    mixin("debug(" ~ format_ctfe(level) ~ ")"
            "const Debug = true;"
            "else const Debug = false;");
}

version( Unittest )
{
    static assert( Version!("Unittest") );
    
    version( Foo )
        static assert( Version!("Foo") );
    else
        static assert( ! Version!("Foo") );
    
    debug
        static assert( Debug!() );
    else
        static assert( ! Debug!() );
    
    version = Blah;
    static assert( Version!("Blah") );
}
