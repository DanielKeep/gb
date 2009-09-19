/**
 * Various methods for working with streams.
 */
module gb.io.Stream;

import tango.core.Exception;
import tango.io.model.IConduit : InputStream, OutputStream;

/**
 * Fills value from the given InputStream.
 * 
 * Params:
 *     ins = source stream.
 *     value = value to read into.
 *     
 * Throws:
 *      IOException if Eof is encountered while reading.
 */

void readInto(T)(InputStream ins, out T value)
in
{
    assert( ins !is null );
}
body
{
    auto mem = (cast(void*) &value)[0..T.sizeof];
    do
    {
        auto bytesRead = ins.read(mem);
        if( bytesRead == InputStream.Eof )
            throw new IOException("unexpected Eof");
        
        mem = mem[bytesRead..$];
    }
    while( mem.length > 0 )
}

/**
 * Writes value to the given OutputStream.
 * 
 * Params:
 *     outs = output stream.
 *     value = value to write.
 *     
 * Throws:
 *      IOException if Eof is encountered while writing.
 */

void writeFrom(T)(OutputStream outs, ref T value)
in
{
    assert( outs !is null );
}
body
{
    auto mem = (cast(void*) &value)[0..T.sizeof];
    do
    {
        auto bytesWritten = outs.write(mem);
        if( bytesWritten == OutputStream.Eof )
            throw new IOException("unexpected Eof");
        
        mem = mem[bytesWritten..$];
    }
    while( mem.length > 0 );
}
