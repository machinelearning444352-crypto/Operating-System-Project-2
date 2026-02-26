#!/bin/bash
lldb ./build/macOSDesktop << 'LLDBEOF'
run
bt
quit
LLDBEOF
