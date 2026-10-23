from run_remote_cmr_noc16_sdf import connect
from pathlib import Path
client = connect()
try:
    sftp = client.open_sftp()
    with sftp.file("/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r5_lane_trace/trace.log") as f:
        trace = f.read().decode()
    sftp.close()
    output = Path("results/rtl_reqout_calibration_20261022_r2/c1p4_lane_trace.log")
    output.write_text(trace)
    print(trace[-20000:])
finally:
    client.close()
