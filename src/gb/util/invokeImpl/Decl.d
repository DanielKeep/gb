/**
 * Shared declarations for Invoke.
 *
 * Authors: Daniel Keep <daniel.keep@gmail.com>
 * Copyright: See LICENSE.
 */
module gb.util.invokeImpl.Decl;

/**
 * This enumeration lists the various calling conventions that can be
 * supported by the Invoke module.  Note that calling conventions might not be
 * supported by your platform; in these cases, a runtime error will be
 * generated.
 */
enum CallConv
{
    /// Platform-specific C calling convention.
    C,
    /// Pascal a.k.a stdcall a.k.a. Windows calling convention.  Used by the
    /// Windows API and COM.
    Pascal,
    StdCall = Pascal, /// ditto
    Windows = Pascal, /// ditto
    /// Register-based fastcall.
    FastCall,
    /// Class method calling convention for C++.
    ThisCall,
    /// Delphi-specific variant of Pascal for COM methods.
    SafeCall,
    /// D calling convention.
    D,
    /// Microsoft x86-64 calling convention.
    Ms64,
    /// AMD64 calling convention.
    Amd64,
}

