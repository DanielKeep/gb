module gb.tools.HashTest.entry;

import gb.tools.HashTest.harness : Test, factories, matchTestName;
import gb.tools.HashTest.hm : hmSignature;
import gb.util.Stat;
import gb.util.String : startsWith;
import tango.io.Stdout;
import tango.io.stream.Format : FormatOutput;
import tango.util.Convert : to;

import tango.core.tools.TraceExceptions;

// This has to be quite high because the first several runs exhibit
// increasingly longer run times... before suddenly dropping back to a stable
// level.  No idea WHY...
const size_t DEFAULT_WARMUP = 10u;
const size_t DEFAULT_TIMED  = 30u;

void printUsage(char[] execName)
{
    Stdout.format(
"Usage: {0} [OPTIONS] [+TEST ARG...]...

Options:

    --cpu-info      Display CPU information.
    --help          Displays this message.
    --list-tests    Lists available tests.

    --timed N       Do N timed runs.  Defaults to {2}.
    --warmup N      Do N `dry runs' to warmup caches, etc.  Defaults to {1}.

Notes:

 - Options MUST come before the first test, or they will be interpreted as an
   argument for that test.

 - Tests can be used more than once, usually with different arguments.

 - Test names are case-insensitive.  You can also do a partial match on the
   name; for example, ins_seq matches Insert_Sequential.  Underscores can be
   replaced with `-' or `.'.

Example:

 {0} --timed 20 +Insert_Sequential 1000000 +ins-seq 10
",
        execName,
        DEFAULT_WARMUP,
        DEFAULT_TIMED).newline;
}

void main(char[][] args)
{
    auto execName = args[0];
    args = args[1..$];

    if( args.length == 0 )
    {
        Stderr(
"Excuse me, but you seem to have forgotten to provide any command-line
arguments.  Might I suggest re-running with `--help' ?"
        ).newline;
        return;
    }

    // This will contain [testname, args...] for each test.
    char[][][] tests;

    size_t warmupRuns = DEFAULT_WARMUP;
    size_t timedRuns = DEFAULT_TIMED;

    {
        // This will contain the tail of the arg list containing tests and their
        // arguments.
        char[][] testArgs = null;

        bool showCpu = false;
        bool showHelp = false;
        bool listTests = false;

        enum State
        {
            Switch,
            WarmupRuns,
            TimedRuns,
        }

        State state = State.Switch;

        // Handle args for the harness itself.
argLoop:
        foreach( i, arg ; args )
        {
            switch( state )
            {
                case State.Switch:
                    if( arg.startsWith("--") )
                    {
                        switch( arg )
                        {
                            case "--cpu-info":
                                showCpu = true;
                                break;

                            case "--help":
                                showHelp = true;
                                break;

                            case "--list-tests":
                                listTests = true;
                                break;

                            case "--warmup":
                                state = State.WarmupRuns;
                                break;

                            case "--timed":
                                state = State.TimedRuns;
                                break;

                            default:
                                throw new Exception("unknown switch \""~arg~"\"");
                        }
                    }
                    else if( arg.startsWith("+") )
                    {
                        testArgs = args[i..$];
                        break argLoop;
                    }
                    else
                        throw new Exception("unexpected argument \""~arg~"\"");

                    break;

                case State.WarmupRuns:
                    warmupRuns = to!(size_t)(arg);
                    state = State.Switch;
                    break;

                case State.TimedRuns:
                    timedRuns = to!(size_t)(arg);
                    state = State.Switch;
                    break;

                default:
                    assert(false, "bad state");
            }
        }

        // Print signature for the hashmap implementation
        Stdout("! ")(hmSignature).newline;

        if( showCpu )
        {
            printCpuInfo();
        }

        if( showHelp )
        {
            printUsage(execName);
        }

        if( listTests )
        {
            auto testNames = factories.keys;
            testNames.sort;
            Stdout("Available tests:");
            // WORKAROUND: i is NOT fucking shadowing ANYTHING!
            foreach( j, name ; testNames )
                Stdout(j==0?" ":", ")(name);
            Stdout(".").newline;
        }

        // Parse out tests and their arguments.
        if( testArgs.length > 0 )
        {
            size_t testName_mark = ~0;

            void addTest(size_t stop)
            {
                char[][] test;
                test ~= matchTestName(testArgs[testName_mark][1..$]);
                test ~= testArgs[testName_mark+1..stop];
                tests ~= test;
            }

            // WORKAROUND: fuck you, dmd.  NEITHER of these shadow ANYTHING!
            foreach( k, kArg ; testArgs )
            {
                if( kArg.startsWith("+") )
                {
                    if( matchTestName(kArg[1..$]) == "" )
                        throw new Exception("unknown test \""~kArg[1..$]~"\"");
                    
                    if( testName_mark != ~0 )
                        addTest(k);

                    testName_mark = k;
                }
            }

            if( testName_mark != ~0 )
                addTest(testArgs.length);
        }
    }

    // Run the tests!
    if( tests.length == 0 )
        return;

    // WORKAROUND: sometimes, I could just STAB Walter...
    foreach( testArgs_1 ; tests )
    {
        auto testName = testArgs_1[0];
        testArgs_1 = testArgs_1[1..$];

        scope test = factories[testName]();
        test.config(testArgs_1);

        Stdout("+ ")(test).newline;

        Stdout("- initialising...").flush;
        test.init();
        Stdout(" done").newline;

        Stdout("- warming up").flush;
        for( size_t i=0; i<warmupRuns; ++i )
        {
            test.run();
            Stdout(".").flush;
        }

        Stdout(" done").newline;

        Stat stat;
        for( size_t i=0; i<timedRuns; ++i )
        {
            auto time = test.run();
            stat ~= time;
            Stdout(". ");
            outSec(time).newline;
        }

        Stdout(": range = [");
        outSec(stat.min)(", ");
        outSec(stat.max)("]").newline();
        Stdout(": μ = ");
        outSec(stat.μ)(", σ = ");
        outSec(stat.σ).newline();
        Stdout(": 95% CI = ");
        outSec(stat.μ)(" ± ");
        outSec(stat.confDev(0.95)).newline();
        Stdout.newline;
    }
}

import Cpuid = tango.core.tools.Cpuid;

void printCpuInfo()
{
    Stdout
        .formatln("@ vendor: {}", Cpuid.vendor)
        .formatln("@ processor: {}", Cpuid.processor)
        .formatln("@ smf: {},{},{}", Cpuid.stepping, Cpuid.model, Cpuid.family);

    Stdout("@ caches:");
    foreach( i, info ; Cpuid.datacache )
    {
        if( info.size >= (4096*1024)-1 )
            break;

        Stdout(i==0?" ":"; ");
        Stdout(info.size)("kib,");
        if( info.associativity == ubyte.max )
            Stdout("*,");
        else if( info.associativity == 1 )
            Stdout("direct,");
        else
            Stdout(info.associativity)("-way,");
        Stdout(info.lineSize);
    }
    Stdout.newline();
}

// Let's hope to FSM that we never need anything larger than ""...
const PREFIXES = ["n"[], "μ", "m", "", "k", "M", "G", "T", "P", "E", "Z", "Y"];

FormatOutput!(char) outSec(double sec, FormatOutput!(char) fo = null)
{
    if( fo is null )
        fo = Stdout;

    // Convert to nano-seconds
    real v = sec * 1_000_000_000.0;
    size_t prefixInd = 0;
    while( v > 2500.0 )
    {
        v /= 1000.0;
        ++ prefixInd;
    }

    if( v >= 1000.0 )
    {
        fo.format("{},{:f2} {}s",
                cast(int)(v/1000.0),
                v-((cast(int)(v/1000.0))*1000.0),
                PREFIXES[prefixInd]);
    }
    else
    {
        fo.format("{:f2} {}s", v, PREFIXES[prefixInd]);
    }

    return fo;
}

