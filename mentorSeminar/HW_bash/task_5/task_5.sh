#!/usr/bin/env bash
echo "!!! task 5 !!!"

echo "Starting three sleep commands in the background:"

sleep 10 &
echo "sleep 10 started (PID: $!)"

sleep 15 &
echo "sleep 15 started (PID: $!)"

sleep 20 &
echo "sleep 20 started (PID: $!)"

echo ""
echo "List of jobs:"
jobs

echo ""
echo "Commands for process control:"
echo "jobs - show background jobs"
echo "fg %1 - bring job 1 to the foreground (works inside an interactive session)"
echo "bg %1 - resume job 1 in the background (works inside an interactive session)"
