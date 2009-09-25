#!/usr/bin/env rdmd
/**
 * This script will run the unittests for gb.
 * 
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module runtests;

import tango.util.Convert;
import tango.io.FileScan;
import tango.io.device.File;
import tango.io.Stdout;
import tango.sys.Process;
import tango.util.ArgParser;

class CompilerArgs
{
    bool generateSymbols = false;
    bool enableDebug = false;
    bool enableUnitTest = false;

    char[][] versions;
    
    char[] output = null;
    
    char[][] sources;
}

interface Compiler
{
    void compile(CompilerArgs);
}

class Dmd : Compiler
{
    void compile(CompilerArgs args)
    {        
        char[][] dmdArgs;
        
        dmdArgs ~= "dmd";
        
        if( args.generateSymbols ) dmdArgs ~= "-g";
        if( args.enableDebug ) dmdArgs ~= "-debug";
        if( args.enableUnitTest ) dmdArgs ~= "-unittest";

        foreach( ver ; args.versions )
            dmdArgs ~= "-version=" ~ ver;

        if( args.output != "" ) dmdArgs ~= "-of"~args.output;
        
        dmdArgs ~= args.sources;

        Stdout('+');
        foreach( arg ; dmdArgs )
        {
            Stdout(' ')(arg);
        }
        Stdout.newline;
        
        {
            scope dmdProc = new Process(dmdArgs, null);
            dmdProc.copyEnv = true;
            
            dmdProc.execute();
            Stdout.stream.copy(dmdProc.stdout);
            Stderr.stream.copy(dmdProc.stderr);
            
            auto result = dmdProc.wait;
            if( result.reason != Process.Result.Exit )
            {
                throw new Exception("compilation failed: " ~ result.toString );
            }
            else if( result.status )
            {
                throw new Exception("compilation failed with status "
                        ~ to!(char[])(result.status));
            }
        }
        
        // TODO: clean up temporary files
    }
}

Compiler compilerFromName(char[] name)
{
    switch( name )
    {
        case "dmd": return new Dmd;
        default: assert(false, "unknown compiler: " ~ name);
    }
}

// Set default compiler to whatever compiled this
version( DigitalMars )
{
    alias Dmd DefaultCompiler;
}
else
{
    pragma(msg, "I don't recognise this compiler.  Please fix me!");
    static assert(false);
}

int main(char[][] args)
{
    auto exec = args[0];
    args = args[1..$];
    
    auto mkCompiler = { return cast(Compiler) new Dmd; };
    
    {
        scope argParser = new ArgParser;
        
        argParser.bind("--", "compiler", (char[] value)
        {
            mkCompiler = { return compilerFromName(value); };
        });
        
        argParser.parse(args);
    }
    
    {
        auto compiler = mkCompiler();
        scope cargs = new CompilerArgs;
        cargs.generateSymbols = true;
        cargs.enableDebug = true;
        cargs.enableUnitTest = true;
        cargs.versions = ["Unittest"];
        
        cargs.sources ~= "utmain.d";
        
        scope scan = new FileScan;
        foreach( file ; scan( "../src", ".d").files )
        {
            cargs.sources ~= file.toString;
        }
        
        compiler.compile(cargs);
    }
    
    {
        Stdout("+ utmain").newline;
        
        scope utProc = new Process(["utmain"[]], null);
        utProc.copyEnv = true;
        
        utProc.execute();
        Stdout.stream.copy(utProc.stdout).flush;
        Stderr.stream.copy(utProc.stderr).flush;
        
        auto result = utProc.wait;
        if( result.reason != Process.Result.Exit )
        {
            Stderr("Unit tests failed to run.").newline;
            return 1;
        }
        else if( result.status )
        {
            Stderr("Unit tests failed.").newline;
            return 2;
        }
    }
    
    return 0;
}
