/**
 * Invoke implementation for x86+win32.
 *
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.util.invokeImpl.x86.Win32;

version(X86) { version(Win32) {

import tango.core.Variant;

debug(gb_util_invokeImpl_x86_Win32_DumpRegisters)
    debug = DumpReg;

debug(DumpReg)
    import tango.io.Stdout : Stderr;

alias callStackProc!(false).call    callCProc;
alias callStackProc!(true).call     callPascalProc;

template callStackProc(bool calleeClean)
{
    Variant call(void* proc, size_t varargPos,
            TypeInfo resultType, Variant[] args)
    {
        Registers reg;              // registers dumped for result

        // Unpack args into a vararg stack.
        /* TODO: what really needs to be done is to modify Variant so that
         * it can write the stack out directly into a given memory region.
         * That way, we don't need to do an otherwise superfluous
         * allocation.
         */
        void* argPtr;
        size_t argLen = sizeOfStack(args);
        {
            TypeInfo[] _dummy;
            Variant.toVararg(args, _dummy, argPtr);
        }

        /* Points to the hidden result allocation.  If null, then we don't
         * have a hidden result.
         */
        void* resultPtr = null;

        // Determines how many registers from the FP stack to dump.  Max
        // of 2.
        int   dumpSt = 0;

        // If we want to return a floating point type, we need to dump the
        // FP stack.
        if( resultType == typeid(float)
                || resultType == typeid(double)
                || resultType == typeid(real)
                || resultType == typeid(ifloat) 
                || resultType == typeid(idouble) 
                || resultType == typeid(ireal) )
        {
            dumpSt = 1;
        }
        else if( resultType == typeid(cfloat)
                || resultType == typeid(cdouble)
                || resultType == typeid(creal) )
        {
            dumpSt = 2;
        }

        /* If the result type is NOT a power of two of at most 8 AND it's
         * not real, the result is returned via a hidden pointer passed as
         * the first argument.  If this is the case, we need to allocate
         * storage that this pointer will point at now.
         */
        else
        {
            switch( resultType.tsize )
            {
                case 1: case 2: case 4: case 8:
                    // Returned in EAX[:EDX] or ST(0)
                    break;

                // We don't need to account for real, because we already
                // have done so above.

                default:
                    // Hidden pointer.
                    // TODO: flag for pointers.
                    resultPtr = (new ubyte[](resultType.tsize)).ptr;
            }
        }

        // Do the call
        static if( calleeClean )
            callPascalProcImpl(proc, reg, resultPtr,
                    argPtr[0..argLen], dumpSt);

        else
            callCProcImpl(proc, reg, resultPtr,
                    argPtr[0..argLen], dumpSt);

        debug(DumpReg)
        {
            Stderr
                .formatln("Registers:")
                .formatln("  EAX:   0x{:x,8}", reg.eax)
                .formatln("  EDX:   0x{:x,8}", reg.edx)
                .formatln("  ST(0): {}", reg.st0)
                .formatln("  ST(1): {}", reg.st1)
                ;
        }

        // Now we get to work out how to handle the result.

        // Hidden pointer
        if( resultPtr !is null )
        {
            // I'm SURE this should work without the `.opCall!()`... oh
            // well.
            return Variant.opCall!()(resultType, resultPtr);
        }

        // Floating-point type returned via ST(0)
        // TODO: this can probably be collapsed a bit
        else if( resultType == typeid(float) )
            return Variant(cast(float) reg.st0);

        else if( resultType == typeid(double) )
            return Variant(cast(double) reg.st0);

        else if( resultType == typeid(real) )
            return Variant(cast(real) reg.st0);

        else if( resultType == typeid(ifloat) )
            return Variant(cast(ifloat)(reg.st0 * 1.0i));

        else if( resultType == typeid(idouble) )
            return Variant(cast(idouble)(reg.st0 * 1.0i));

        else if( resultType == typeid(ireal) )
            return Variant(cast(ireal)(reg.st0 * 1.0i));

        else if( resultType == typeid(cfloat) )
            return Variant(cast(cfloat)(reg.st1 + reg.st0*1.0i));

        else if( resultType == typeid(cdouble) )
            return Variant(cast(cdouble)(reg.st1 + reg.st0*1.0i));

        else if( resultType == typeid(creal) )
            return Variant(cast(creal)(reg.st1 + reg.st0*1.0i));

        // Returned via EAX[:EDX].  And THIS is why the ordering is
        // important...
        else
        {
            static assert( reg.edx.offsetof == reg.eax.offsetof + 4 );

            switch( resultType.tsize )
            {
                case 1: case 2: case 4: case 8:
                    return Variant.opCall!()(resultType, &reg.eax);

                default:
                    assert(false);
            }
        }
    }
}

private
{
    /*
     * Registers that we (may) need to dump after calling a function in order
     * to get the result.
     *
     * DO NOT CHANGE THE LAYOUT OF THIS STRUCTURE.  It is indexed from
     * assembler.  The code also requires that (eax,edx) show up in that order
     * and packed in sequence.
     *
     * Any additions should be made at the end.
     */

    struct Registers
    {
        uint eax,   // +0
             edx;   // +4
        real st0,   // +8
             st1;   // +18
    }

    /*
     * Computes the total size of an array of values after being "unpacked"
     * into memory.  The jiggery-pokery is to ensure the stack is always
     * aligned to 4 bytes after each value.
     */
    // TODO: get this patched into Variant somewhere.

    size_t sizeOfStack(Variant[] vars)
    {
        size_t size = 0;
        foreach( ref v ; vars )
        {
            auto ti = v.type;
            size += (ti.tsize + size_t.sizeof-1) & ~(size_t.sizeof-1);
        }
        return size;
    }

    /*
     * "User-friendly" wrapper around the asm implementation.
     */

    void callCProcImpl
    (
        void* proc,
        out Registers registers,
        void* resultPtr,
        void[] args,
        int dumpSt
    )
    {
        if( proc is null )
            assert(false, "cannot call null procedure");

        callStackProcAsm(proc, &registers, args.length, args.ptr,
                dumpSt, resultPtr, 0);
    }

    /*
     * Wrapper around the asm for Pascal calls.
     */

    void callPascalProcImpl
    (
        void* proc,
        out Registers registers,
        void* resultPtr,
        void[] args,
        int dumpSt
    )
    {
        if( proc is null )
            assert(false, "cannot call null procedure");

        callStackProcAsm(proc, &registers, args.length, args.ptr,
                dumpSt, resultPtr, 1);
    }

    /*
     * There be dragons here.
     *
     * This method MUST be extern(C) -- this ensures the arguments are all on
     * the stack and not in, say, registers.
     *
     * This method is naked, so try to avoid doing any more than is absolutely
     * necessary.
     */

    extern(C) void callStackProcAsm
    (
        void*       proc,           // [EBP+8]
        Registers*  registers,      // [EBP+12]
        size_t      argsLength,     // [EBP+16]
        void*       argsPtr,        // [EBP+20]
        size_t      storeSt,        // [EBP+24]
        void*       resultPtr,      // [EBP+28]
        size_t      calleeCleanup   // [EBP+32]
    )
    {
        asm
        {
            naked;

            // prolog

            push    EBP;
            mov     EBP, ESP;

            // save registers
            push    EAX;
            push    ECX;
            push    EDX;
            push    EDI;
            push    ESI;

            /*
               First of all, we need to make enough space on the stack for the
               arguments.
            */
            mov     EAX, [argsLength];
            sub     ESP, EAX;

            /*
                We need to copy the data over now.
            */
            mov     ESI, [argsPtr];
            mov     EDI, ESP;
            mov     ECX, EAX;       // number of bytes total
            shr     ECX, 2;         // number of DWORDs total
            
            cld;
            rep;
            movsd;                  // copy ECX dwords from *ESI to *EDI

            mov     ECX, EAX;       // number of bytes total
            and     ECX, 3;         // compute remainder left un-copied

            rep;
            movsb;                  // copy ECX bytes from *ESI to *EDI

            /*
               If we were given a result pointer, push that.
            */
            mov     EAX, [resultPtr];
            cmp     EAX, 0;
            jz      DONT_PUSH_RESULT_PTR;

            push    EAX;

DONT_PUSH_RESULT_PTR:;

            /*
               Ok, we've copied the arguments into the stack.  Now we can call the
               proc.
            */
            mov     EAX, [proc];
            call    EAX;

            /*
               Rather than attempt to work out where the result has gone, we'll
               just dump any relevant registers.  Use ECX for the pointer because
               we don't want to clobber EAX or EDX.
            */
            mov     ECX, [registers];
            mov     Registers.eax[ECX], EAX;
            mov     Registers.edx[ECX], EDX;

            /*
                We only dump ST if asked.
            */
            mov     EAX, [storeSt];
            cmp     EAX, 0;
            jz      NO_MORE_STS;

            fstp    Registers.st0[ECX];

            dec     EAX;
            cmp     EAX, 0;
            jz      NO_MORE_STS;

            fstp    Registers.st1[ECX];

NO_MORE_STS:;

            /*
               Now, blow away the arguments we pushed on to the stack.  Remember
               that the result pointer might be there.

               Skip this if calleeCleanup is non-zero (such as for pascal cc).
            */
            mov     EAX, [calleeCleanup];
            cmp     EAX, 0;
            jnz     DONT_CLEAN_STACK;

            mov     EAX, [resultPtr];
            cmp     EAX, 0;
            jz      DONT_POP_RESULT_PTR;

            add     ESP, 4;

DONT_POP_RESULT_PTR:;

            mov     EAX, [argsLength];
            add     ESP, EAX;

DONT_CLEAN_STACK:;

            // epilog

            // restore registers
            pop     ESI;
            pop     EDI;
            pop     EDX;
            pop     ECX;
            pop     EAX;

            pop     EBP;
            ret;
        }
    }
}

}} // version(Win32) version(X86)

