#!/bin/sh

for i in 30:Black 31:Red 32:Green 33:Yellow 34:Blue 35:Magenta 36:Cyan 37:White; do
  c=${i%%:*}
  n=${i#*:}
  printf "\e[${c}m%s\e[0m \e[1;${c}m%s\e[0m\n" "$n" "$n"
  printf "\e[$(($c+60))m%s\e[0m \e[1;$(($c+60))m%s\e[0m\n" "$n" "$n"
done
