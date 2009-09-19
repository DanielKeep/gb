/**
 * Property stuff.
 * 
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.util.Property;

const DefaultGetter = "";
const DefaultSetter = DefaultGetter;
 
private
{
    const DEFAULT_GETTER = `return storage;`;
    const DEFAULT_SETTER = `return storage = value;`;
 
    char[] trim(char[] s)
    {
        while( s.length > 0
                && (s[0] == ' ' || s[0] == '\t'
                    || s[0] == '\f' || s[0] == '\v'
                    || s[0] == '\r' || s[0] == '\n') )
            s = s[1..$];
 
        while( s.length > 0
                && (s[$-1] == ' ' || s[$-1] == '\t'
                    || s[$-1] == '\f' || s[$-1] == '\v'
                    || s[$-1] == '\r' || s[$-1] == '\n') )
            s = s[0..$-1];
 
        return s;
    }
 
    size_t indexOf(T)(T haystack, T needle)
    {
        if( needle == "" ) return 0;
 
        size_t i = 0;
        while( haystack.length > 0 )
        {
            if( haystack.startsWith(needle) )
                return i;
            ++i;
            haystack = haystack[1..$];
        }
        return i;
    }
 
    bool startsWith(T)(T haystack, T needle)
    {
        return haystack.length >= needle.length
                && haystack[0..needle.length] == needle;
    }
 
    bool endsWith(T)(T haystack, T needle)
    {
        return haystack.length >= needle.length
                && haystack[$-needle.length..$] == needle;
    }
 
    bool contains(T)(T haystack, T needle)
    {
        if( needle.length == 0 ) return true;
 
        while( haystack.length >= needle.length )
        {
            if( haystack.startsWith(needle) )
                return true;
            haystack = haystack[1..$];
        }
 
        return false;
    }
 
    char[] propertyName(char[] name)
    {
        return name[0..name.indexOf("=")];
    }
 
    char[] propertyInitialiser(char[] name)
    {
        size_t i = name.indexOf("=");
        if( i<name.length )
            return name[i+1..$];
        
        else
            return null;
    }
 
    char[] protectionHandlerStorage(char[] prot)
    {
        return "
if( (var.startsWith(`"~prot~"`)
&& var[`"~prot~"`.length..$].trim().startsWith(`{`)
&& var.trim().endsWith(`}`)) )
{
return recurse(
var[`"~prot~"`.length..$]
.trim()[`{`.length..$][$-`}`.length..$],
DEFAULT
);
}
else if( var == `"~prot~"` )
{
return recurse(DEFAULT);
}
";
    }
 
    bool usesStorage(char[] code, char[] DEFAULT="")
    {
        code = code.trim();
        
        if( code == "" )
            return usesStorage(DEFAULT);
        
        if( code == "-" )
            return false;
 
        {
            alias usesStorage recurse;
            alias code var;
            mixin(protectionHandlerStorage("public"));
            mixin(protectionHandlerStorage("private"));
            mixin(protectionHandlerStorage("protected"));
            mixin(protectionHandlerStorage("package"));
        }
 
        return code.contains("storage");
    }
 
    char[] storageName(char[] name)
    {
        return "__storage_"~name;
    }
 
    char[] propertyStorage(char[] T, char[] name)
    {
        auto initialiser = name.propertyInitialiser();
        if( initialiser != "" )
            initialiser = " = " ~ initialiser;
 
        return "private " ~ T ~ " " ~ storageName(name.propertyName())
            ~ initialiser ~ ";\n";
    }
 
    char[] protectionHandler(char[] prot)
    {
        return "
if( (var.startsWith(`"~prot~"`)
&& var[`"~prot~"`.length..$].trim().startsWith(`{`)
&& var.trim().endsWith(`}`)) )
{
return `"~prot~" ` ~ recurse(
T,
name,
var[`"~prot~"`.length..$]
.trim()[`{`.length..$][$-`}`.length..$]
);
}
else if( var == `"~prot~"` )
{
return `"~prot~" ` ~ recurse(T, name, DEFAULT);
}
";
    }
 
    char[] propertyGetter(char[] T, char[] name, char[] getter)
    {
        getter = getter.trim();
 
        if( getter == "" )
            return propertyGetter(T, name, DEFAULT_GETTER);
        
        if( getter == "-" )
            return "";
 
        {
            alias propertyGetter recurse;
            alias getter var;
            alias DEFAULT_GETTER DEFAULT;
            mixin(protectionHandler("public"));
            mixin(protectionHandler("private"));
            mixin(protectionHandler("protected"));
            mixin(protectionHandler("package"));
        }
        auto storage = `
static if( is( typeof(`~storageName(name)~`) ) )
{
alias `~storageName(name)~` storage;
}
`;
        return
            T~` `~name~`()
{
`~storage~`
`~getter~`
}
`;
    }
 
    char[] propertySetter(char[] T, char[] name, char[] setter)
    {
        setter = setter.trim();
        
        if( setter == "" )
            return propertySetter(T, name, DEFAULT_SETTER);
        
        if( setter == "-" )
            return "";
 
        {
            alias propertySetter recurse;
            alias setter var;
            alias DEFAULT_SETTER DEFAULT;
            mixin(protectionHandler("public"));
            mixin(protectionHandler("private"));
            mixin(protectionHandler("protected"));
            mixin(protectionHandler("package"));
        }
        auto storage = `
static if( is( typeof(`~storageName(name)~`) ) )
{
alias `~storageName(name)~` storage;
}
`;
        return
            `auto `~name~`(`~T~` value)
{
`~storage~`
`~setter~`
}
`;
    }
}
 
template Property(
        T,
        char[] name,
        char[] getter=DefaultGetter,
        char[] setter=DefaultSetter)
{
    const Property =
        (usesStorage(getter, DEFAULT_GETTER)
                || usesStorage(setter, DEFAULT_SETTER)
            ? propertyStorage(T.stringof, name)
            : "")
        ~ propertyGetter(T.stringof, name.propertyName(), getter)
        ~ propertySetter(T.stringof, name.propertyName(), setter);
}

// TODO: Unit tests
