# Commit/ACG Start→fire control RTC.  Tdata_from_Start is 0 on the R4a
# measurement; 80 ps is the conservative Q→D / pulse-width floor, not
# Tdata × (1 + RTM).  Bind to pins, never to a DEL* collection.

proc ultra_dfire_find_pins {pat} {
  set pins [get_pins -hierarchical -quiet $pat]
  if {[sizeof_collection $pins] == 0} {
    set pins [get_pins -hierarchical -quiet -filter "full_name =~ $pat"]
  }
  if {[sizeof_collection $pins] == 0} {
    set pins [get_ports -quiet $pat]
  }
  return $pins
}

set ::ULTRA_DFIRE_CTRL_MIN_NS 0.080
set ::ULTRA_DFIRE_CTRL_MAX_NS 0.160
if {[info exists ::env(ULTRA_DFIRE_CTRL_MIN_NS)] && $::env(ULTRA_DFIRE_CTRL_MIN_NS) ne ""} {
  set ::ULTRA_DFIRE_CTRL_MIN_NS $::env(ULTRA_DFIRE_CTRL_MIN_NS)
}
if {[info exists ::env(ULTRA_DFIRE_CTRL_MAX_NS)] && $::env(ULTRA_DFIRE_CTRL_MAX_NS) ne ""} {
  set ::ULTRA_DFIRE_CTRL_MAX_NS $::env(ULTRA_DFIRE_CTRL_MAX_NS)
}

set dfire_from [ultra_dfire_find_pins "*commitController/Start"]
if {[sizeof_collection $dfire_from] == 0} {
  set dfire_from [ultra_dfire_find_pins "admission/commitController/Start"]
}
set dfire_to [ultra_dfire_find_pins "*commitController/fire_o"]
if {[sizeof_collection $dfire_to] == 0} {
  set dfire_to [ultra_dfire_find_pins "admission/commitController/fire_o"]
}

set dfire_from_n [sizeof_collection $dfire_from]
set dfire_to_n [sizeof_collection $dfire_to]
puts "ULTRA_DFIRE_CONTROL_BIND from=$dfire_from_n to=$dfire_to_n min_ns=$::ULTRA_DFIRE_CTRL_MIN_NS max_ns=$::ULTRA_DFIRE_CTRL_MAX_NS"
if {$dfire_from_n == 0 || $dfire_to_n == 0} {
  puts "ULTRA_DC_FAIL dfire_control_pin_bind from=$dfire_from_n to=$dfire_to_n"
  exit 2
}

set_min_delay $::ULTRA_DFIRE_CTRL_MIN_NS -from $dfire_from -to $dfire_to
set_max_delay $::ULTRA_DFIRE_CTRL_MAX_NS -from $dfire_from -to $dfire_to
puts "ULTRA_DFIRE_CONTROL_APPLIED min_ns=$::ULTRA_DFIRE_CTRL_MIN_NS max_ns=$::ULTRA_DFIRE_CTRL_MAX_NS"
