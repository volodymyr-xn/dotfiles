#!/usr/bin/env bash

device=$(xsetwacom --list | grep -i "pad" |  awk '{print $(NF-2)}')

xsetwacom --set "$device" button 1 "key ctrl z"
xsetwacom --set "$device" button 2 "key b"
xsetwacom --set "$device" button 3 "key e"
xsetwacom --set "$device" button 8 "key i"
# xsetwacom --get "$device" button 4

xsetwacom --set "$device" button 9 "key t"
xsetwacom --set "$device" button 10 "key y"
xsetwacom --set "$device" button 11 "key u"
xsetwacom --set "$device" button 12 "key w"

xsetwacom --set "$device" 'AbsWheelUp' 'key z'
xsetwacom --set "$device" 'AbsWheelDown' 'key x'
xsetwacom --set "$device" 'AbsWheel2Up' 'key c'
xsetwacom --set "$device" 'AbsWheel2Down' 'key v'
xsetwacom --set "$device" 'RelWheelUp' 'key b'
xsetwacom --set "$device" 'RelWheelDown' 'key n'


# xsetwacom --set "$device" button 5 "key t"
# xsetwacom --set "$device" button 2 "key shift ctrl s"
# xsetwacom --set "$device" button 8 "key shift ctrl l"
echo "Ok --- all set on device $device."
