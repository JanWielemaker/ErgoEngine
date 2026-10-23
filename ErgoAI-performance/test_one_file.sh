#! /bin/sh

# test single file

# $1 is expected to have the ERGO invocation script (runergo)
ERGO=$1
FILE=$2
CMD=$3

DIR=`pwd`
BASEDIR=`basename $DIR`

echo "--------------------------------------------------------------------"
echo "Testing $BASEDIR/$FILE"

# touching so that in case XSB dumps core we'll have a *_new file and
# a discrepancy will be reported
rm -f ${FILE}_new
touch ${FILE}_new temp

# The cputime and walltime are printed as `@@time <phase> <cpu> <wall>`
# before the load, after the load and after $CMD, so the load and solve
# phases can be reported apart.
STAMP="cputime(?_C)@\\plg, walltime(?_W)@\\plg, fmt_write('@@time %s %S %S\\n', args(?_P,?_C,?_W))@\\io"

$ERGO > ${FILE}.log 2>&1 << EOF || outcome=bad
chatter{off}.
?_P = start, $STAMP.
['$FILE'].
?_P = load, $STAMP.
$CMD
?_P = solve, $STAMP.
\end.
EOF

awk '/@@time/ { sub(/.*@@time /, ""); c[$1] = $2; w[$1] = $3 }
     END {
       if ("load" in c)
         printf "  load  %8.2f s cpu  %8.2f s wall\n", c["load"]-c["start"], w["load"]-w["start"];
       if ("solve" in c)
         printf "  solve %8.2f s cpu  %8.2f s wall\n", c["solve"]-c["load"], w["solve"]-w["load"];
       else
         print  "  solve did not finish"
     }' ${FILE}.log

if [ "$outcome" = bad ]; then
    echo "CRASH OCCURRED" >> temp
fi

cp   temp ${FILE}_new
sort temp > temp_new
sort ${FILE}_old > temp_old

#-----------------------
# print out differences.
#-----------------------
status=0
# must use diff -w to ignore ^M^M under windows
diff -w temp_old temp_new || status=1
if test "$status" = 0 ; then
	echo "$BASEDIR/$FILE tested"
	rm -f ${FILE}_new
else
	echo "$BASEDIR/$FILE differ!!!"
	diff -w ${FILE}_new ${FILE}_old
fi

rm -f temp temp_old temp_new ${FILE}.log
