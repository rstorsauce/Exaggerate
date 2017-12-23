#!/bin/sh

if [ -f /tmp/ex_pid ]; then
  pid=`cat /tmp/ex_pid`
  kill -KILL "$pid"
  rm /tmp/ex_pid
fi
