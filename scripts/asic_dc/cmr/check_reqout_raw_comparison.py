from run_remote_cmr_noc16_sdf import connect
import sys
client = connect()
try:
    ch = client.get_transport().open_session(timeout=180)
    if "--transport" in sys.argv:
        command = "bjobs -a 14948201 14948301; cd /home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r4_transport_eventprobe; tail -n 22 raw_thin/contention.log raw_c1p4/contention.log"
    else:
        command = "bjobs -a 14946901 14947001; cd /home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r2; tail -n 38 thin/probe.log c1p4/probe.log; tail -n 8 thin/compile.log c1p4/compile.log"
    ch.exec_command(command)
    print(ch.makefile().read().decode())
    print(ch.makefile_stderr().read().decode())
finally:
    client.close()
