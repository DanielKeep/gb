@ECHO OFF

set XF_FLAGS=-I../../.. -g -release -inline -O
set TESTS=tests/insert_integer_sequential.d

xfbuild +oHashTest-builtin +D.deps.builtin +O.objs.builtin %XF_FLAGS% -version=UseBuiltin entry.d %TESTS%
xfbuild +oHashTest-tango +D.deps.tango +O.objs.tango %XF_FLAGS% -version=UseTango entry.d %TESTS%
xfbuild +oHashTest-gb +D.deps.gb +O.objs.gb %XF_FLAGS% -version=UseGB entry.d %TESTS%

