set datafile separator ","
set xdata time
set timefmt "%Y-%m-%d-%H:%M:%S"

set key outside

set xtics rotate by -45
set xtics font ",5"
set format x '%m/%d %H:%M'

set grid ytics

filename='../temp-humi.dat'
from=system('cat '.filename. ' | cut -f 2 -d "," | sort | uniq')
select_source(w) = sprintf('< awk -F , ''{if ($2 == "%s") print }'' %s', w, filename)
translate_source(w) = \
    w eq '192.168.135.192' \
    ? 'Bedroom' \
    : (w eq '192.168.135.193' \
        ? 'Living Room' \
        : (w eq '192.168.135.191' \
            ? 'Basement' \
            : (w eq '192.168.135.190' \
                ? 'Garage' \
                : w \
            ) \
        ) \
    )

set multiplot layout 2,1

set title 'Temperature (F)'
plot for [f in from] select_source(f) using 1:3 with lines title translate_source(f)

set title 'Relative Humidity (%)'
plot for [f in from] select_source(f) using 1:5 with lines title translate_source(f)

#set title 'Vcc (mV)'
#plot for [f in from] select_source(f) using 1:7 with lines title translate_source(f)

unset multiplot
