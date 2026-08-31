# Convert CMR paired RTC inequalities into post-route data checks.
# Rise and fall are both covered.  Dummy clocks are not used as Fmax.

proc cmr_rtc_data_check {from_pins to_pins setup_ns hold_ns label} {
  if {[sizeof_collection $from_pins] == 0 || [sizeof_collection $to_pins] == 0} {
    puts "CMR_RTC_MISS $label"
    return 0
  }
  catch { set_data_check -from $from_pins -to $to_pins -setup $setup_ns }
  catch { set_data_check -from $from_pins -to $to_pins -hold $hold_ns }
  catch { set_data_check -rise_from $from_pins -rise_to $to_pins -setup $setup_ns }
  catch { set_data_check -fall_from $from_pins -fall_to $to_pins -setup $setup_ns }
  puts "CMR_RTC_APPLIED $label from=[sizeof_collection $from_pins] to=[sizeof_collection $to_pins]"
  return 1
}

proc cmr_apply_postroute_rtc {} {
  # CMR-RCU-01: Mat at RouteSelAnd.A1 before delayed Req at Z.
  set mat [get_pins -hierarchical -quiet -filter {full_name =~ *RouteSelAnd_*/g/A1}]
  set req [get_pins -hierarchical -quiet -filter {full_name =~ *RouteSelAnd_*/g/Z}]
  cmr_rtc_data_check $mat $req 0.0 0.0 CMR-RCU-01

  # CMR-OPM-01: DataReg.D stable before E falling.
  set dpin [get_pins -hierarchical -quiet -filter {full_name =~ *OutputPortModules_*/DataReg*latch_cell/D || full_name =~ *OutputPortModules_*/DataReg*/D}]
  set epin [get_pins -hierarchical -quiet -filter {full_name =~ *OutputPortModules_*/DataReg*latch_cell/E || full_name =~ *OutputPortModules_*/DataReg*/E}]
  cmr_rtc_data_check $dpin $epin 0.0 0.0 CMR-OPM-01

  # CMR-AR-01: address D before LatchReg.E fall.
  set ad [get_pins -hierarchical -quiet -filter {full_name =~ *AddressRegister/LatchReg*latch_cell/D}]
  set ae [get_pins -hierarchical -quiet -filter {full_name =~ *AddressRegister/LatchReg*latch_cell/E}]
  cmr_rtc_data_check $ad $ae 0.0 0.0 CMR-AR-01

  # CMR-LANE-01: AckLatch D before Assigned close.
  set ld [get_pins -hierarchical -quiet -filter {full_name =~ *AckLatch*latch_cell/D}]
  set le [get_pins -hierarchical -quiet -filter {full_name =~ *AckLatch*latch_cell/E}]
  cmr_rtc_data_check $ld $le 0.0 0.0 CMR-LANE-01
}

proc cmr_report_rtc {report_dir} {
  file mkdir $report_dir
  redirect "$report_dir/rtc_data_checks.rpt" {
    catch { report_constraint -all_violators -nosplit }
    catch { report_timing -delay_type max -max_paths 50 -nosplit }
    catch { report_timing -delay_type min -max_paths 50 -nosplit }
  }
  puts "CMR_RTC_REPORT $report_dir/rtc_data_checks.rpt"
}
