/**
 * Contains a class which lets you use ANSI escape sequences on any platform;
 * even Windows!
 *
 * To use low-level unformatted output, use the Aout and Aerr objects, which
 * behave exactly the same as Cout and Cerr from tango.io.Console.  To use
 * formatted output, use Ansiout and Ansierr which are standard FormatOutput
 * objects wrapping Aout and Aerr.
 *
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.ansi;

private import tango.io.Console;
private import tango.io.stream.Format;
private import tango.sys.win32.UserGdi;

version( Posix )
{
    private import tango.stdc.posix.unistd : isatty;
}

private static const DWORD[3] STD_HANDLES = [
    cast(DWORD) -10,
    cast(DWORD) -11,
    cast(DWORD) -12
];

/**
 * This conduit acts as a no-op pass-thru to the underlying standard stream on
 * all platforms except Windows.
 *
 * On Windows, it will parse and process any ANSI escape sequences it finds,
 * implementing them manually.
 *
 * Note that it can only be configured to output to either Stderr or Stdout.
 */
class AnsiConduit : Console.Conduit
{
    version( Win32 ) protected HANDLE hCon;
    protected Handle handle;
    
    this(Handle handle)
    {
        if( handle >= 3 )
            throw new Exception("invalid handle passed to AnsiConduit");

        this.handle = handle;
        super(handle);
        
        version( Win32 ) hCon = GetStdHandle(STD_HANDLES[handle]);
    }

    /* You couldn't have just made redirected protected, could you?
     * Noooo, you just HAVE to make shit private and final to make life
     * harder.  Grrr...
     */
    
    protected bool redirected()
    {
        version( Windows )
        {
            DWORD mode;
            return ! GetConsoleMode(hCon, &mode);
        }
        else
        {
            return (isatty(handle) is 0);
        }
    }
    
    version( Win32 )
    {
        /* We only need to override write for Windows, since it's the only OS
         * that doesn't understand ANSI.  The ONE spot where 9x is better than
         * NT...
         */
        
        override size_t write(void[] src)
        {
            if( redirected )
                // Do nothing
                return super.write(src);
            
            char[] data = cast(char[]) src;
            size_t off = 0;
            size_t mark = 0;
            
writeLoop:  while( off < data.length )
            {
                char b = data[off];
                
                if( b == '\033' && (off+1)<data.length && data[off+1] == '[' )
                {
                    // Probably an escape sequence
                    char[] seq = data[off+2..$];
                    if( seq.length < 1 )
                    {
                        // ... yeah, probably not.
                        ++ off;
                        continue;
                    }
                    
                    // Parse out the escape sequence.
                    // We'll extract the parameter portion, and the combined
                    // intermediate,final portion.  We'll call the latter the
                    // "term" since final is a keyword.  We'll also grab the
                    // remaining input for convenience.
                    
                    char[] param, term, rest;
                    size_t term_start;
                    
                    enum State { P, I };
                    State state;
        parseLoop:  foreach( i,c ; seq )
                    {
                        switch( state )
                        {
                        case State.P:
                            // Did we get an intermediate or final byte?
                            if( (0x20 <= c && c <= 0x2f) )
                            {
                                param = seq[0..i];
                                term_start = i;
                                state = State.I;
                            }
                            else if( (0x40 <= c && c <= 0x7e) )
                            {
                                param = seq[0..i];
                                term = seq[i..i+1];
                                rest = seq[i+1..$];
                                break parseLoop;
                            }
                            /* The other possibility is that we DIDN'T get a
                             * parameter byte.  In that case, we've got a
                             * malformed escape sequence.  ECMA-048 doesn't
                             * appear to specify what to do in this case.
                             * 
                             * We'll just pass the sequence through unchanged.
                             */
                            else if( !(0x30 <= c && c <= 0x3f) )
                            {
                                ++ off;
                                continue writeLoop;
                            }
                            break;
                            
                        case State.I:
                            // Did we get an intermediate or final byte?
                            if( (0x20 <= c && c <= 0x2f) )
                            {
                                // noop
                            }
                            else if( (0x40 <= c && c <= 0x7e ) )
                            {
                                term = seq[term_start..i+1];
                                rest = seq[i+1..$];
                                break parseLoop;
                            }
                            /* If we got something else, we have an invalid
                             * escape sequence.
                             */
                            else
                            {
                                ++ off;
                                continue writeLoop;
                            }
                        }
                    }
                    
                    /* Ok, we got our escape sequence.  Before we do anything
                     * else, we need to write out whatever came before this
                     * sequence.
                     */
                    auto leftToWrite = data[mark..off].length;
                    if( leftToWrite > 0 )
                        do
                        {
                            auto count = super.write(data[mark..off]);
                            if( count == 0 )
                            {
                                // Uh oh, failed to write.  Give up for now.
                                // Tell the caller how much we DID write.
                                return off-leftToWrite;
                            }
                            leftToWrite -= count;
                        }
                        while( leftToWrite > 0 );
                        
                    // Process it.
                    processEscSeq(term, param);
                    
                    // Keep going with the rest of the string.
                    mark = rest.ptr - data.ptr;
                    off = mark;
                }
                else
                    ++ off;
            }
            
            // Write remainder
            return mark + super.write(data[mark..$]);
        }
        
        private void processEscSeq(char[] seq, char[] param)
        {
            if( (seq.length == 2 && seq[0] != ' ') || seq.length > 2 )
            {
                // Do nothing; unrecognised escape sequence.
                return;
            }
            
            void delegate(char[]) action = null;
            
            /*
             * Note that most of these codes are somewhat insane.  I'm only
             * doing the ones I actually need, because otherwise I'll be here
             * until doomsday.
             * 
             * Don't you just love standards committees?
             */
            
            if( seq.length == 1 )
                switch( seq[0] )
                {
                case 0x47: action = &ansiCHA; break;
                case 0x6d: action = &ansiSGR; break;
                    
                // Codes below here are not implemented.
                /+
                case 0x40: // ICH
                case 0x41: // CUU
                case 0x42: // CUD
                case 0x43: // CUF
                case 0x44: // CUB
                case 0x45: // CNL
                case 0x46: // CPL
                case 0x48: // CUP
                case 0x49: // CHT
                case 0x4a: // ED
                case 0x4b: // EL
                case 0x4c: // IL
                case 0x4d: // DL
                case 0x4e: // EF
                case 0x4f: // EA
                    
                case 0x50: // DCH
                case 0x51: // SSE
                case 0x52: // CPR
                case 0x53: // SU
                case 0x54: // SD
                case 0x55: // NP
                case 0x56: // PP
                case 0x57: // CTC
                case 0x58: // ECH
                case 0x59: // EVT
                case 0x5a: // EBT
                case 0x5b: // SRS
                case 0x5c: // PTX
                case 0x5d: // SDS
                case 0x5e: // SIMD
                case 0x5f: // --
                    
                case 0x60: // HPA
                case 0x61: // HPR
                case 0x62: // REP
                case 0x63: // DA
                case 0x64: // VPA
                case 0x65: // VPR
                case 0x66: // HVP
                case 0x67: // TBC
                case 0x68: // SM
                case 0x69: // MC
                case 0x6a: // HPB
                case 0x6b: // VPB
                case 0x6c: // RM
                case 0x6e: // DSR
                case 0x6f: // DAQ

                case 0x70: // --
                case 0x71: // --
                case 0x72: // --
                case 0x73: // --
                case 0x74: // --
                case 0x75: // --
                case 0x76: // --
                case 0x77: // --
                case 0x78: // --
                case 0x79: // --
                case 0x7a: // --
                case 0x7b: // --
                case 0x7c: // --
                case 0x7d: // --
                case 0x7e: // --
                +/
                default:   // invalid
                }
            
            else if( seq.length == 2 /* && seq[0] == ' '*/ )
                switch( seq[1] )
                {
                // Codes below here are not implemented
                /+
                case 0x40: // SL
                case 0x41: // SR
                case 0x42: // GSM
                case 0x43: // GSS
                case 0x44: // FNT
                case 0x45: // TSS
                case 0x46: // JFY
                case 0x47: // SPI
                case 0x48: // QUAD
                case 0x49: // SSU
                case 0x4a: // PFS
                case 0x4b: // SHS
                case 0x4c: // SVS
                case 0x4d: // IGS
                case 0x4e: // --
                case 0x4f: // IDCS
                    
                case 0x50: // PPA
                case 0x51: // PPR
                case 0x52: // PPB
                case 0x53: // SPD
                case 0x54: // DTA
                case 0x55: // SHL
                case 0x56: // SLL
                case 0x57: // FNK
                case 0x58: // SPQR
                case 0x59: // SEF
                case 0x5a: // PEC
                case 0x5b: // SSW
                case 0x5c: // SACS
                case 0x5d: // SAPV
                case 0x5e: // STAB
                case 0x5f: // GCC
                    
                case 0x60: // TATE
                case 0x61: // TALE
                case 0x62: // TAC
                case 0x63: // TCC
                case 0x64: // TSR
                case 0x65: // SCO
                case 0x66: // SRCS
                case 0x67: // SCS
                case 0x68: // SLS
                case 0x69: // --
                case 0x6a: // --
                case 0x6b: // SCP
                case 0x6c: // --
                case 0x6d: // --
                case 0x6e: // --
                case 0x6f: // --

                case 0x70: // --
                case 0x71: // --
                case 0x72: // --
                case 0x73: // --
                case 0x74: // --
                case 0x75: // --
                case 0x76: // --
                case 0x77: // --
                case 0x78: // --
                case 0x79: // --
                case 0x7a: // --
                case 0x7b: // --
                case 0x7c: // --
                case 0x7d: // --
                case 0x7e: // --
                +/
                default:   // invalid
                }
            
            if( action !is null )
            {
                this.flush();
                action(param);
            }
        }
        /*
         * ANSI sequence implementations.
         */
        
        void ansiCHA(char[] p)
        {
            uint n;
            parseN(p, n);
            
            CONSOLE_SCREEN_BUFFER_INFO info;
            
            if( GetConsoleScreenBufferInfo(hCon, &info) == 0 )
                sysex;
            
            info.dwCursorPosition.X = n;
            
            if( SetConsoleCursorPosition(hCon, info.dwCursorPosition) == 0 )
                sysex;
        }
        
        void ansiSGR(char[] p)
        {
            uint[4] ns_buffer;
            uint[] ns = parseN(p, ns_buffer);
            
            CONSOLE_SCREEN_BUFFER_INFO info;
            
            if( GetConsoleScreenBufferInfo(hCon, &info) == 0 )
                sysex;
            
            auto attr = info.wAttributes;
            
            foreach( n ; ns )
            {
                switch( n )
                {
                case 0:
                    attr &= ~(FOREGROUND_BLUE | FOREGROUND_GREEN
                              | FOREGROUND_RED | FOREGROUND_INTENSITY
                              | BACKGROUND_RED | BACKGROUND_GREEN
                              | BACKGROUND_BLUE | BACKGROUND_INTENSITY);
                    
                    attr |= FOREGROUND_BLUE
                          | FOREGROUND_GREEN
                          | FOREGROUND_RED;
                    break;
                    
                case 1:  attr |= FOREGROUND_INTENSITY; break;
                case 22: attr &= ~FOREGROUND_INTENSITY; break;
                
                case 30: case 31: case 32: case 33: case 34:
                case 35: case 36: case 37: case 38: case 39:
                {
                    attr &= ~(FOREGROUND_BLUE | FOREGROUND_GREEN
                              | FOREGROUND_RED | FOREGROUND_INTENSITY);
                    attr |= ansiColorCodeFg(n-30);
                    break;
                }
                
                case 40: case 41: case 42: case 43: case 44:
                case 45: case 46: case 47: case 48: case 49:
                {
                    attr &= ~(BACKGROUND_BLUE | BACKGROUND_GREEN
                            | BACKGROUND_RED | BACKGROUND_INTENSITY);
                    attr |= ansiColorCodeBg(n-40);
                    break;
                }
                
                case 90: case 91: case 92: case 93: case 94:
                case 95: case 96: case 97: case 98: case 99:
                {
                    attr &= ~(FOREGROUND_BLUE | FOREGROUND_GREEN
                              | FOREGROUND_RED | FOREGROUND_INTENSITY);
                    attr |= ansiColorCodeFg(n-30) | FOREGROUND_INTENSITY;
                    break;
                }
                
                case 100: case 101: case 102: case 103: case 104:
                case 105: case 106: case 107: case 108: case 109:
                {
                    attr &= ~(BACKGROUND_BLUE | BACKGROUND_GREEN
                            | BACKGROUND_RED | BACKGROUND_INTENSITY);
                    attr |= ansiColorCodeBg(n-40) | BACKGROUND_INTENSITY;
                    break;
                }
                
                default:
                    // Ignore
                }
            }
            
            if( SetConsoleTextAttribute(hCon, attr) == 0 )
                sysex;
        }
        
        /*
         * Helper functions
         */
        
        void sysex()
        {
            assert(false,"todo");
        }
        
        short ansiColorCodeFg(short code)
        {
            switch( code )
            {
            case 1: return FOREGROUND_RED;
            case 2: return FOREGROUND_GREEN;
            case 3: return FOREGROUND_RED | FOREGROUND_GREEN;
            case 4: return FOREGROUND_BLUE;
            case 5: return FOREGROUND_BLUE | FOREGROUND_RED;
            case 6: return FOREGROUND_BLUE | FOREGROUND_GREEN;
            case 7: return FOREGROUND_RED | FOREGROUND_GREEN
                            | FOREGROUND_BLUE;
            
            default: return 0;
            }
        }
        
        short ansiColorCodeBg(short code)
        {
            switch( code )
            {
            case 1: return BACKGROUND_RED;
            case 2: return BACKGROUND_GREEN;
            case 3: return BACKGROUND_RED | BACKGROUND_GREEN;
            case 4: return BACKGROUND_BLUE;
            case 5: return BACKGROUND_BLUE | BACKGROUND_RED;
            case 6: return BACKGROUND_BLUE | BACKGROUND_GREEN;
            case 7: return BACKGROUND_RED | BACKGROUND_GREEN
                            | BACKGROUND_BLUE;
            
            default: return 0;
            }
        }
        
        uint parseN(char[] param, ref uint n1)
        {
            uint v = 0;
            foreach( c ; param )
            {
                if( !( '0' <= c && c <= '9' ) )
                    return 0;
                
                v = 10*v+(c-'0');
            }
            n1 = v;
            return 1;
        }
        
        uint parseN(char[] param, ref uint n1, ref uint n2)
        {
            uint n = 0, v = 0;
            foreach( c ; param )
            {
                if( c == ';' )
                {
                    switch( n )
                    {
                        case 0:
                            n1 = v;
                            v = 0;
                            ++n;
                            break;

                        default:
                            return n;
                    }
                }

                else if( !('0' <= c && c <= '9') )
                    return n;

                else
                    v = 10 * v + (c - '0');

            }
            n2 = v;
            return 2;
        }
        
        uint[] parseN(char[] param, uint[] ns)
        {
            uint n = 0, v = 0;
            foreach( i,c ; param )
            {
                if( c == ';' )
                {
                    if( (i+1) == param.length )
                        return ns[0..n];
                    
                    if( n == ns.length )
                        ns ~= v;
                    else
                        ns[n] = v;
                    
                    v = 0;
                }
                else if( !('0' <= c && c <= '9') )
                    return ns[0..n];
                
                else
                    v = 10 * v + (c - '0');
            }
            ns[n] = v;
            return ns[0..n+1];
        }
    }
}

private import tango.io.stream.Format;
private import tango.text.convert.Layout;

private alias FormatOutput!(char) Output;

public static AnsiConduit Aout, Aerr;

public static Output Ansiout, Ansierr;

static this()
{
    Aout = new AnsiConduit(1);
    Aerr = new AnsiConduit(2);
    
    auto layout = Layout!(char).instance;
    
    Ansiout = new Output(layout, Aout);
    Ansierr = new Output(layout, Aerr);

    Ansiout.flush = !Aout.redirected;
    Ansierr.flush = !Aerr.redirected;
}

