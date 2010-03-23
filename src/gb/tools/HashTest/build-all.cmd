@ECHO OFF

set XF_FLAGS=-I../../.. -g -release -inline -O
set TESTS=tests/insert_bigkey_sequential.d tests/insert_integer_random.d tests/insert_integer_sequential.d tests/insert_string_sequential.d tests/lookup_integer_sequential.d

echo builtin:
xfbuild +oHashTest-builtin +D.deps.builtin +O.objs.builtin %XF_FLAGS% -version=UseBuiltin entry.d %TESTS%

echo tango:
xfbuild +oHashTest-tango +D.deps.tango +O.objs.tango %XF_FLAGS% -version=UseTango entry.d %TESTS%

echo gb:
set GB_LINE=%XF_FLAGS% -version=UseGB entry.d %TESTS%
xfbuild +oHashTest-gb-m2 -version=HashMap_Growth_Multiple2 +D.deps.gb-m2 +O.objs.gb-m2 %GB_LINE%
xfbuild +oHashTest-gb-lm -version=HashMap_Growth_LogMultiple +D.deps.gb-lm +O.objs.gb-lm %GB_LINE%
xfbuild +oHashTest-gb-sp -version=HashMap_Growth_SimplePoly +D.deps.gb-sp +O.objs.gb-sp %GB_LINE%
