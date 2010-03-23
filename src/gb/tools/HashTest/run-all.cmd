@ECHO OFF

set FLAGS=--cpu-info
set TESTS=
set TESTS=%TESTS% +i-i-seq 100 +i-i-seq 100000 +i-i-seq 200000 2
set TESTS=%TESTS% +i-s-seq 100 +i-s-seq 100000 +i-s-seq 200000 2
set TESTS=%TESTS% +i-i-r 100 +i-i-r 100000
set TESTS=%TESTS% +l-i-s 100 100 +l-i-s 100000 100000 +l-i-s 100 100 2 1 +l-i-s 100000 100000 2 1
set TESTS=%TESTS% +i-b-s 100 +i-b-s 100000

del *.log

HashTest-builtin %FLAGS% %TESTS% >> HashTest-builtin.log
HashTest-tango   %FLAGS% %TESTS% >> HashTest-tango.log
HashTest-gb-m2   %FLAGS% %TESTS% >> HashTest-gb-m2.log
HashTest-gb-lm   %FLAGS% %TESTS% >> HashTest-gb-lm.log
HashTest-gb-sp   %FLAGS% %TESTS% >> HashTest-gb-sp.log

copy /B HashTest-builtin.log + /B HashTest-tango.log + /B HashTest-gb-m2.log + /B HashTest-gb-lm.log + /B HashTest-gb-sp.log HashTest.log

