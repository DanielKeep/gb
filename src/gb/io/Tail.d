/**
 * This module is designed to let you access files appended to the end
 * of other files.  The original motivation for this was appending .map files
 * to executables for DDL.
 * 
 * You can build a simple tailtool program by compiling this module
 * with -version=gb_io_Tail_tool.
 *
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.io.Tail;

import tango.util.Convert;
import gb.util.CC;
import gb.util.Contract;
import gb.io.Stream;

import tango.core.Exception;
import tango.io.device.Conduit : InputFilter;
import tango.io.model.IConduit : IConduit, IOStream, InputStream, OutputStream;

/**
 * The TailInput class allows you to access the contents of tails appended
 * to the end of files.
 * 
 * Note that this class expects a special footer to tell it how big the
 * appended file is.  You can create tails using tailtool.
 */

class TailInput : InputFilter
{
    /**
     * Creates a new TailInput from an existing InputStream.  This InputStream
     * must be seekable.
     */
    
    this(InputStream ins)
    {
        enforceEx!(IOException).enforce(readFooter(ins, offset, length),
                __FILE__, __LINE__, "couldn't find Tail footer");
        super(ins);
        open = true;
    }
    
    /**
     * Read from stream into a target array. The provided dst 
     * will be populated with content from the stream. 
     *
     * Returns the number of bytes read, which may be less than
     * requested in dst. Eof is returned whenever an end-of-flow 
     * condition arises.
     */

    override size_t read(void[] dst)
    {
        enforceEx!(IOException).enforce(open, __FILE__, __LINE__,
                "TailInput has been closed");

        if( length - position == 0 )
            return Eof;
        
        if( dst.length > length - position )
            dst = dst[0..(this.length-position)];
        
        auto oldPos = input.seek(offset + position, Anchor.Begin);
        scope(success) input.seek(oldPos, Anchor.Begin);
        
        auto bytes = input.read(dst);
        if( bytes != Eof )
            position += bytes;
        
        return bytes;
    }

    /**
     * Load the bits from a stream, and return them all in an
     * array. The dst array can be provided as an option, which
     * will be expanded as necessary to consume the input.
     * 
     * Returns an array representing the content, and throws
     * IOException on error
     */
    
    override void[] load(size_t max = -1)
    {
        enforceEx!(IOException).enforce(open, __FILE__, __LINE__,
                "TailInput has been closed");

        if( max == 0 )
            return null;
        
        if( max == -1 )
            max = length-position;
        
        if( max > length-position )
            max = length-position;
        
        auto dst = new ubyte[max];
        auto cur = dst;
        
        do
        {
            auto bytes = read(cur);
            enforceEx!(IOException).enforce(bytes != Eof, __FILE__, __LINE__,
                    "unexpected Eof");
            cur = cur[bytes..$];
        }
        while( cur.length > 0 )
        
        return dst;
    }

    /**
     * Move the stream position to the given offset from the 
     * provided anchor point, and return adjusted position.
     * 
     * Those conduits which don't support seeking will throw
     * an IOException
     */

    override long seek(long offset, Anchor anchor = Anchor.Begin)
    {
        enforceEx!(IOException).enforce(open, __FILE__, __LINE__,
                "TailInput has been closed");

        long newPos;
        
        switch( anchor )
        {
            case Anchor.Begin:
                newPos = offset;
                break;
                
            case Anchor.Current:
                newPos = position + offset;
                break;
                
            case Anchor.End:
                newPos = length + offset;
                break;
                
            default:
                assert(false);
        }
        
        enforceEx!(IOException).enforce(newPos >= 0, __FILE__, __LINE__,
                "can't seek to before beginning of tail");
        enforceEx!(IOException).enforce(newPos <= length, __FILE__, __LINE__,
                "can't seek to after end of tail");
        
        position = newPos;
        return position;
    }

    /**
     * Close the input.  Note that this does $(I not) close the underlying
     * stream.
     */

    override void close()
    {
        enforceEx!(IOException).enforce(open, __FILE__, __LINE__,
                "TailInput has been closed");

        open = false;
    }
    
    protected
    {
        bool open = false;
        
        long position,
             offset,
             length;
        
        invariant
        {
            assert( offset >= 0, "negative offset" );
            assert( length >= 0, "negative length" );
            assert( 0 <= position && position <= length,
                    "position out of bounds: " ~ to!(char[])(position) );
        }
    
        /**
         * Used to read a stream's tail footer.  Returns false if the file
         * doesn't have a tail footer.
         */
        static bool readFooter(InputStream ins,
                out long offset, out long length)
        in
        {
            assert( ins !is null );
        }
        body
        {
            // save/restore old position
            auto oldPos = ins.seek(0, Anchor.Current);
            scope(success) ins.seek(oldPos, Anchor.Begin);
            
            // Make sure the file is long enough
            auto insLen = ins.seek(0, Anchor.End);
            if( insLen < cast(long) TailFooter.sizeof )
                return false;

            // Read in the potential header
            TailFooter footer;
            ins.seek(-cast(long)footer.sizeof, Anchor.End);
            
            readInto(ins, footer);
            static assert( Version!("LittleEndian"), "TODO: byteswap");

            // Check magic value
            if( footer.magic != TailFooter.MAGIC_VALUE )
                return false;
            
            // Ensure length makes sense.
            if( insLen < footer.length + TailFooter.sizeof )
                return false;
            
            // Ok, we're probably on to a winner.
            offset = insLen - footer.length - TailFooter.sizeof;
            length = footer.length;
            
            return true;
        }
    }
}

/**
 * Checks the given source to see if it has a tail.
 */

bool hasTail(InputStream source)
{
    long _a, _b;
    return TailInput.readFooter(source, _a, _b);
}

/**
 * Assists in removing the tail from a source.  The second argument is a
 * delegate which will be called with the length to truncate the source to.
 */

void removeTail(InputStream source, void delegate(long) truncate)
{
    long offset, _a;
    enforceEx!(IOException).enforce(TailInput.readFooter(source, offset, _a),
            __FILE__, __LINE__,
            "cannot remove tail; provided source doesn't have one");
    truncate(offset);
}

/**
 * Appends the source data to the end of the dest stream as a tail.
 * Note that this will ignore any existing tails.
 */

void appendTail(InputStream source, OutputStream dest)
{
    dest.seek(0, OutputStream.Anchor.End);
    dest.copy(source);
    {
        TailFooter footer;
        footer.magic = TailFooter.MAGIC_VALUE;
        footer.length = source.seek(0, InputStream.Anchor.Current);
        static assert( Version!("LittleEndian"), "TODO: byte swap" );
        writeFrom(dest, footer);
    }
}

/**
 * This structure represents the footer that identifies an embedded tail
 * file.  All values are stored in little-endian.
 */
struct TailFooter
{
    const uint MAGIC_VALUE = 0x4c494154;
    uint magic; /// Should be "TAIL" or 0x4c494154
    long length; /// Size of the embedded file.
}

version( Unittest )
{
    import tango.io.device.Array;
    
    unittest
    {
        const DATA1 = "Everybody dance now!";
        const DATA2 = "Give me the music!";
        const DATA3 = DATA1 ~ DATA2 ~ "TAIL"
            ~ cast(char)(DATA2.length) ~ "\0\0\0";
        
        scope data1 = new Array(DATA1);
        scope data2 = new Array(DATA2);
        scope data3 = new Array;
        
        data3.copy(data1);
        appendTail(data2, data3);
        
        assert( cast(char[]) data3.slice == DATA3 );
        
        scope data4 = new Array(data3.slice);
        scope tins = new TailInput(data4);
        assert( cast(char[]) tins.load == DATA2 );
        
        scope data5 = new Array(data3.slice);
        removeTail(data5, (long length)
        {
            assert( length == DATA1.length );
        });
    }
}

version( gb_io_Tail_tool )
{
    import tango.io.Stdout;
    import tango.io.device.File;
    import tango.util.ArgParser;
    
    int append(char[] exec, char[][] args)
    {
        if( args.length != 2 )
        {
            Stderr.format(USAGE_EXTRACT, exec);
            return ERR_GENERAL;
        }
        
        scope srcFile = new File(args[0], File.ReadExisting);
        scope(exit) srcFile.close;
        auto ins = srcFile.input;
        
        scope tailFile = new File(args[1], File.ReadWriteExisting);
        scope(exit) tailFile.close;
        
        {
            long _1,_2;
            if( TailInput.readFooter(tailFile.input, _1,_2) )
            {
                // Hmm...
                Stderr("Error: ")(args[1])(" already has a tail.").newline;
                return ERR_TAIL_EXISTS;
            }
        }
        
        auto outs = tailFile.output;

        appendTail(ins, outs);
        
        return ERR_DONE;
    }
    
    int extract(char[] exec, char[][] args)
    {
        if( args.length != 2 )
        {
            Stderr.format(USAGE_EXTRACT, exec);
            return ERR_GENERAL;
        }
        
        scope tailFile = new File(args[0], File.ReadExisting);
        scope(exit) tailFile.close;
        scope ins = new TailInput(tailFile.input);
        
        scope destFile = new File(args[1], File.WriteCreate);
        scope(exit) destFile.close;
        auto outs = destFile.output;
        
        outs.copy(ins);
        
        return ERR_DONE;
    }
    
    int remove(char[] exec, char[][] args)
    {
        if( args.length != 1 )
        {
            Stderr.format(USAGE_REMOVE, exec);
            return ERR_GENERAL;
        }
        
        scope tailFile = new File(args[0], File.ReadWriteExisting);
        scope(exit) tailFile.close;
        
        removeTail(tailFile, &tailFile.truncate);
        
        return ERR_DONE;
    }
    
    int main(char[][] args)
    {
        auto exec = args[0];
        args = args[1..$];
        
        void showHelp()
        {
            Stderr.format(USAGE_MAIN, exec);
        }
        
        if( args == null )
        {
            showHelp;
            return ERR_GENERAL;
        }
        
        int function(char[],char[][]) handler;
        
        switch( args[0] )
        {
            case "append":  handler = &append;  break;
            case "extract": handler = &extract; break;
            case "remove":  handler = &remove;  break;
            default:
                Stderr("Unknown command \""~args[0]~"\".").newline;
                showHelp;
                return ERR_GENERAL;
        }
        
        return handler(exec, args[1..$]);
    }
    
    const USAGE_MAIN =
"Usage:\n"
"  {0} append SRCFILE TAILFILE\n"
"  {0} extract TAILFILE DESTFILE\n"
"  {0} remove TAILFILE\n"
"\n"
"Use {0} COMMAND for more information.\n";
    
    const USAGE_APPEND =
"Usage: {0} append SRCFILE TAILFILE\n"
"\n"
"Appends the first file on to the end of the second.\n";
    
    const USAGE_EXTRACT =
"Usage: {0} extract TAILFILE DESTFILE\n"
"\n"
"Extracts the tail of the first file as the second.\n";
    
    const USAGE_REMOVE =
"Usage: {0} remove TAILFILE\n"
"\n"
"Removes the tail from the specified file.\n";
    
    enum
    {
        ERR_DONE = 0,
        ERR_GENERAL,
        ERR_TAIL_EXISTS,
    }
}
