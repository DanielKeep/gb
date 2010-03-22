/**
 * Compile-Time INI parsing.
 * 
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.ctfe.Ini;

import gb.ctfe.String : isNl_ctfe, isWs_ctfe, strip_ctfe;

///

const getString_missing = "\0MISSING";

/**
 * Parses the contents of an INI-style configuration file for a given key and
 * returns its value.
 *
 * You may also specify what to return if the key is not found.  By default,
 * it returns the contents of getString_missing.
 */

char[] getString_ctfe(char[] s, char[] section, char[] name,
        char[] default_ = getString_missing)
{
    enum State
    {
        StartOfLine,
        EatComment,
        ReadSection,
        AfterSection,
        ReadName,
        ReadValue,
    }

    State state;
    char[] curSec, curName, curValue;

    char[] mark;
    size_t markLen;

    while( s.length > 0 )
    {
        switch( state )
        {
            case State.StartOfLine:
                if( s[0] == '#' || s[0] == ';' )
                {
                    state = State.EatComment;
                    s = s[1..$];
                }
                else if( s[0] == '[' )
                {
                    state = State.ReadSection;
                    s = s[1..$];
                    mark = s;
                    markLen = 0;
                }
                else if( isWs_ctfe(s[0]) )
                    s = s[1..$];

                else
                {
                    state = State.ReadName;
                    mark = s;
                    markLen = 0;
                }

                break;

            case State.EatComment:
                if( auto nl = isNl_ctfe(s) )
                {
                    state = State.StartOfLine;
                    s = s[nl..$];
                }
                else
                    s = s[1..$];

                break;

            case State.ReadSection:
                if( s[0] == ']' )
                {
                    curSec = strip_ctfe(mark[0..markLen]);
                    state = State.AfterSection;
                    s = s[1..$];
                    mark = null;
                    markLen = 0;
                }
                else
                {
                    s = s[1..$];
                    ++ markLen;
                }
                break;

            case State.AfterSection:
                if( auto nl = isNl_ctfe(s) )
                {
                    state = State.StartOfLine;
                    s = s[nl..$];
                }
                else
                    s = s[1..$];

                break;

            case State.ReadName:
                if( s[0] == '=' )
                {
                    curName = strip_ctfe(mark[0..markLen]);
                    mark = null;
                    markLen = 0;

                    if( curSec == section && curName == name )
                    {
                        state = State.ReadValue;
                        s = s[1..$];
                        mark = s;
                        markLen = 0;
                    }
                    else
                    {
                        state = State.EatComment;
                        curName = null;
                        s = s[1..$];
                    }
                }
                else
                {
                    s = s[1..$];
                    ++ markLen;
                }
                break;

            case State.ReadValue:
                if( auto nl = isNl_ctfe(s) )
                    return strip_ctfe(mark[0..markLen]);

                else
                {
                    s = s[1..$];
                    ++ markLen;
                }
                break;

            default:
                assert(false, "bad state");
        }
    }
}

/*
 * Implementation: generates either a constant declaration OR a compile-time
 * error.
 */

char[] iniConst_impl(char[] data, char[] section,
        char[] name, char[] symName = "", char[] type = "")
{
    if( symName == "" )
        symName = name;

    auto value = getString_ctfe(data, section, name);

    if( value == getString_missing )
    {
        return
        `
            pragma(msg, "Missing key \"`~section~`.`~name~`\".");
            static assert(false, "failed to load key from ini file");
        `;
    }
    else
    {
        return
        `
            const `~(type!=""?type:"")~` `~symName~` = (`~value~`);
        `;
    }
}

/**
 * Used to declare a constant which is defined in the specified file.
 *
 * Uses CTFE and string imports to load the value and define the constant.
 */

template iniConst(char[] file, char[] section, char[] name, char[] symName="")
{
    mixin(iniConst_impl(import(file), section, name, symName));
}

