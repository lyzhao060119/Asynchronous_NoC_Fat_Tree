from run_remote_cmr_noc16_sdf import connect
client = connect()
try:
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("bjobs -a 14948001 14948101; cd /home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r4_transport_eventprobe; head -n 40 c1p4/probe.log; tail -n 6 thin/probe.log c1p4/probe.log")
    print(ch.makefile().read().decode())
    print(ch.makefile_stderr().read().decode())
finally:
    client.close()
