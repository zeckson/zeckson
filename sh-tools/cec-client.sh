#!/usr/bin/env bash

# Settings active source — as
# Changing port number for #0 device — p 0 [1..3]


# Switch on
echo "on 0" | cec-client -s
# Switch off
echo "standby 0" | cec-client -s
