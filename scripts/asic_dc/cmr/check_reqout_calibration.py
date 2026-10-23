from run_remote_cmr_noc16_sdf import connect

client = connect()
try:
    channel = client.get_transport().open_session(timeout=180)
    channel.exec_command("bjobs -a 14944501 14944601; "
        "ls -ld /home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r1; "
        "cd /home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r1; "
        "tail -n 15 thin/baseline_0.log thin/baseline_1.log c1p4/baseline_0.log c1p4/baseline_1.log; "
        "cat thin/events_0.csv thin/events_1.csv c1p4/events_0.csv c1p4/events_1.csv; "
        "head -n 4 thin/CMRRouter.v c1p4/CMRRouter.v; cat run_thin.sh")
    print(channel.makefile().read().decode(errors="replace"))
    print(channel.makefile_stderr().read().decode(errors="replace"))
    print("REMOTE_EXIT", channel.recv_exit_status())
finally:
    client.close()
