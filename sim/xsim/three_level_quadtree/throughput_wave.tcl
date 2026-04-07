log_wave -r /three_level_quadtree/*

add_wave_divider Control
add_wave /three_level_quadtree/reset

add_wave_divider {Flow f0 core0 -> core63}
add_wave /three_level_quadtree/io_core_inputs_0_HS_Req
add_wave /three_level_quadtree/io_core_inputs_0_HS_Ack
add_wave -radix hex /three_level_quadtree/io_core_inputs_0_Data_flit
add_wave /three_level_quadtree/io_core_outputs_63_HS_Req
add_wave /three_level_quadtree/io_core_outputs_63_HS_Ack
add_wave -radix hex /three_level_quadtree/io_core_outputs_63_Data_flit

add_wave_divider {Flow f1 core7 -> core56}
add_wave /three_level_quadtree/io_core_inputs_7_HS_Req
add_wave /three_level_quadtree/io_core_inputs_7_HS_Ack
add_wave -radix hex /three_level_quadtree/io_core_inputs_7_Data_flit
add_wave /three_level_quadtree/io_core_outputs_56_HS_Req
add_wave /three_level_quadtree/io_core_outputs_56_HS_Ack
add_wave -radix hex /three_level_quadtree/io_core_outputs_56_Data_flit

add_wave_divider {Flow f2 core56 -> core7}
add_wave /three_level_quadtree/io_core_inputs_56_HS_Req
add_wave /three_level_quadtree/io_core_inputs_56_HS_Ack
add_wave -radix hex /three_level_quadtree/io_core_inputs_56_Data_flit
add_wave /three_level_quadtree/io_core_outputs_7_HS_Req
add_wave /three_level_quadtree/io_core_outputs_7_HS_Ack
add_wave -radix hex /three_level_quadtree/io_core_outputs_7_Data_flit

add_wave_divider {Flow f3 core63 -> core0}
add_wave /three_level_quadtree/io_core_inputs_63_HS_Req
add_wave /three_level_quadtree/io_core_inputs_63_HS_Ack
add_wave -radix hex /three_level_quadtree/io_core_inputs_63_Data_flit
add_wave /three_level_quadtree/io_core_outputs_0_HS_Req
add_wave /three_level_quadtree/io_core_outputs_0_HS_Ack
add_wave -radix hex /three_level_quadtree/io_core_outputs_0_Data_flit

add_wave_divider {Top Outputs Should Stay Idle}
add_wave /three_level_quadtree/io_top_output_0_HS_Req
add_wave /three_level_quadtree/io_top_output_0_HS_Ack
add_wave /three_level_quadtree/io_top_output_1_HS_Req
add_wave /three_level_quadtree/io_top_output_1_HS_Ack

puts "Wave setup loaded. Next, source the throughput_3flit.tcl script from sim/xsim/three_level_quadtree."
