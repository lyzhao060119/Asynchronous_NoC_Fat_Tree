onerror {resume}

quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {Control}
add wave -noupdate sim:/three_level_quadtree/reset

add wave -noupdate -divider {Flow f0 core0 -> core63}
add wave -noupdate sim:/three_level_quadtree/io_core_inputs_0_HS_Req
add wave -noupdate sim:/three_level_quadtree/io_core_inputs_0_HS_Ack
add wave -noupdate -radix hex sim:/three_level_quadtree/io_core_inputs_0_Data_flit
add wave -noupdate sim:/three_level_quadtree/io_core_outputs_63_HS_Req
add wave -noupdate sim:/three_level_quadtree/io_core_outputs_63_HS_Ack
add wave -noupdate -radix hex sim:/three_level_quadtree/io_core_outputs_63_Data_flit

add wave -noupdate -divider {Flow f1 core7 -> core56}
add wave -noupdate sim:/three_level_quadtree/io_core_inputs_7_HS_Req
add wave -noupdate sim:/three_level_quadtree/io_core_inputs_7_HS_Ack
add wave -noupdate -radix hex sim:/three_level_quadtree/io_core_inputs_7_Data_flit
add wave -noupdate sim:/three_level_quadtree/io_core_outputs_56_HS_Req
add wave -noupdate sim:/three_level_quadtree/io_core_outputs_56_HS_Ack
add wave -noupdate -radix hex sim:/three_level_quadtree/io_core_outputs_56_Data_flit

add wave -noupdate -divider {Flow f2 core56 -> core7}
add wave -noupdate sim:/three_level_quadtree/io_core_inputs_56_HS_Req
add wave -noupdate sim:/three_level_quadtree/io_core_inputs_56_HS_Ack
add wave -noupdate -radix hex sim:/three_level_quadtree/io_core_inputs_56_Data_flit
add wave -noupdate sim:/three_level_quadtree/io_core_outputs_7_HS_Req
add wave -noupdate sim:/three_level_quadtree/io_core_outputs_7_HS_Ack
add wave -noupdate -radix hex sim:/three_level_quadtree/io_core_outputs_7_Data_flit

add wave -noupdate -divider {Flow f3 core63 -> core0}
add wave -noupdate sim:/three_level_quadtree/io_core_inputs_63_HS_Req
add wave -noupdate sim:/three_level_quadtree/io_core_inputs_63_HS_Ack
add wave -noupdate -radix hex sim:/three_level_quadtree/io_core_inputs_63_Data_flit
add wave -noupdate sim:/three_level_quadtree/io_core_outputs_0_HS_Req
add wave -noupdate sim:/three_level_quadtree/io_core_outputs_0_HS_Ack
add wave -noupdate -radix hex sim:/three_level_quadtree/io_core_outputs_0_Data_flit

add wave -noupdate -divider {Top Outputs Must Stay Idle}
add wave -noupdate sim:/three_level_quadtree/io_top_output_0_HS_Req
add wave -noupdate sim:/three_level_quadtree/io_top_output_0_HS_Ack
add wave -noupdate sim:/three_level_quadtree/io_top_output_1_HS_Req
add wave -noupdate sim:/three_level_quadtree/io_top_output_1_HS_Ack

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {120 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 280
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {700 ns}
