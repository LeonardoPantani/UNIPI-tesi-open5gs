#!/bin/bash
sudo pkill -9 -f '[o]pen5gs-'
pkill -f 'npm run dev'
pkill -f 'mongosh'

exit 0