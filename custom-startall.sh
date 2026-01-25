#!/bin/bash

./custom-killall.sh

sleep 0.5

rm -f install/var/log/open5gs/*.log

rm -rf ./install/bin && rm -rf ./install/lib && source ./custom-env.sh && meson setup build --prefix=$PWD/install && cd build && ninja -j$(nproc) && ninja install
cd ..

source ./custom-env.sh && ./install/bin/open5gs-nrfd >> install/var/log/open5gs/nrf.log 2>/dev/null &
sleep 1 && source ./custom-env.sh && ./install/bin/open5gs-scpd >> install/var/log/open5gs/scp.log 2>/dev/null &
sleep 1 && source ./custom-env.sh && ./install/bin/open5gs-amfd >> install/var/log/open5gs/amf.log 2>/dev/null &
sleep 1 && source ./custom-env.sh && ./install/bin/open5gs-smfd >> install/var/log/open5gs/smf.log 2>/dev/null &
sleep 1 && source ./custom-env.sh && ./install/bin/open5gs-ausfd >> install/var/log/open5gs/ausf.log 2>/dev/null &
sleep 1 && source ./custom-env.sh && ./install/bin/open5gs-udmd >> install/var/log/open5gs/udm.log 2>/dev/null &
sleep 1 && source ./custom-env.sh && ./install/bin/open5gs-udrd >> install/var/log/open5gs/udr.log 2>/dev/null &
sleep 1 && source ./custom-env.sh && ./install/bin/open5gs-pcfd >> install/var/log/open5gs/pcf.log 2>/dev/null &
sleep 1 && source ./custom-env.sh && ./install/bin/open5gs-nssfd >> install/var/log/open5gs/nssf.log 2>/dev/null &
sleep 1 && source ./custom-env.sh && ./install/bin/open5gs-bsfd >> install/var/log/open5gs/bsf.log 2>/dev/null &
sleep 1 && source ./custom-env.sh && sudo -E ./install/bin/open5gs-upfd 2>/dev/null | sudo tee -a install/var/log/open5gs/upf.log &
wait