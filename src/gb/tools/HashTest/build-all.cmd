@ECHO OFF

set XF_FLAGS=-I../../.. -g -release -inline -O
set TESTS=tests/insert_integer_random.d tests/insert_integer_sequential.d tests/insert_string_sequential.d

echo builtin:
xfbuild +oHashTest-builtin +D.deps.builtin +O.objs.builtin %XF_FLAGS% -version=UseBuiltin entry.d %TESTS%

echo tango:
xfbuild +oHashTest-tango +D.deps.tango +O.objs.tango %XF_FLAGS% -version=UseTango entry.d %TESTS%

echo gb:
xfbuild +oHashTest-gb +D.deps.gb +O.objs.gb %XF_FLAGS% -version=UseGB entry.d %TESTS%

