@ECHO OFF

set FLAGS=--cpu-info --timed 60
set TESTS=+i-i-r 100 +i-i-r 100000 +i-i-seq 100 +i-i-seq 100000 +i-i-seq 200000 2 +i-s-seq 100 +i-s-seq 100000 +i-s-seq 200000 2

del *.log

HashTest-builtin %FLAGS% %TESTS% >> HashTest-builtin.log
HashTest-tango   %FLAGS% %TESTS% >> HashTest-tango.log
HashTest-gb      %FLAGS% %TESTS% >> HashTest-gb.log

copy /B HashTest-builtin.log + /B HashTest-tango.log + /B HashTest-gb.log HashTest.log

