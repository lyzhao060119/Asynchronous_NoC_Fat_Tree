module CMRRouter_768(
  input         clock,
  input         reset,
  input         io_inputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x0_y0_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_2_0_HS_Ack = external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_3_0_HS_Ack = external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_HS_Req = external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_Data_flit = external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_HS_Req = external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_Data_flit = external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_769(
  input         clock,
  input         reset,
  input         io_inputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x0_y1_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_1_0_HS_Ack = external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_2_0_HS_Ack = external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_3_0_HS_Ack = external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_HS_Req = external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_Data_flit = external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_HS_Req = external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_Data_flit = external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_HS_Req = external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_Data_flit = external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_770(
  input         clock,
  input         reset,
  input         io_inputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x0_y2_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_1_0_HS_Ack = external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_2_0_HS_Ack = external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_3_0_HS_Ack = external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_HS_Req = external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_Data_flit = external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_HS_Req = external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_Data_flit = external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_HS_Req = external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_Data_flit = external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_771(
  input         clock,
  input         reset,
  input         io_inputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x0_y3_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_1_0_HS_Ack = external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_2_0_HS_Ack = external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_HS_Req = external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_Data_flit = external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_HS_Req = external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_Data_flit = external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_772(
  input         clock,
  input         reset,
  input         io_inputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x1_y0_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_0_0_HS_Ack = external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_2_0_HS_Ack = external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_3_0_HS_Ack = external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_HS_Req = external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_Data_flit = external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_HS_Req = external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_Data_flit = external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_HS_Req = external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_Data_flit = external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_773(
  input         clock,
  input         reset,
  input         io_inputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x1_y1_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_0_0_HS_Ack = external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_1_0_HS_Ack = external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_2_0_HS_Ack = external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_3_0_HS_Ack = external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_HS_Req = external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_Data_flit = external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_HS_Req = external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_Data_flit = external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_HS_Req = external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_Data_flit = external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_HS_Req = external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_Data_flit = external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_774(
  input         clock,
  input         reset,
  input         io_inputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x1_y2_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_0_0_HS_Ack = external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_1_0_HS_Ack = external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_2_0_HS_Ack = external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_3_0_HS_Ack = external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_HS_Req = external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_Data_flit = external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_HS_Req = external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_Data_flit = external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_HS_Req = external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_Data_flit = external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_HS_Req = external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_Data_flit = external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_775(
  input         clock,
  input         reset,
  input         io_inputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x1_y3_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_0_0_HS_Ack = external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_1_0_HS_Ack = external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_2_0_HS_Ack = external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_HS_Req = external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_Data_flit = external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_HS_Req = external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_Data_flit = external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_HS_Req = external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_Data_flit = external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_776(
  input         clock,
  input         reset,
  input         io_inputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x2_y0_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_0_0_HS_Ack = external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_2_0_HS_Ack = external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_3_0_HS_Ack = external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_HS_Req = external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_Data_flit = external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_HS_Req = external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_Data_flit = external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_HS_Req = external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_Data_flit = external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_777(
  input         clock,
  input         reset,
  input         io_inputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x2_y1_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_0_0_HS_Ack = external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_1_0_HS_Ack = external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_2_0_HS_Ack = external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_3_0_HS_Ack = external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_HS_Req = external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_Data_flit = external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_HS_Req = external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_Data_flit = external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_HS_Req = external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_Data_flit = external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_HS_Req = external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_Data_flit = external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_778(
  input         clock,
  input         reset,
  input         io_inputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x2_y2_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_0_0_HS_Ack = external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_1_0_HS_Ack = external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_2_0_HS_Ack = external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_3_0_HS_Ack = external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_HS_Req = external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_Data_flit = external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_HS_Req = external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_Data_flit = external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_HS_Req = external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_Data_flit = external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_HS_Req = external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_Data_flit = external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_779(
  input         clock,
  input         reset,
  input         io_inputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_2_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_2_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_2_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x2_y3_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_0_0_HS_Ack = external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_1_0_HS_Ack = external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_2_0_HS_Ack = external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_HS_Req = external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_Data_flit = external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_HS_Req = external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_Data_flit = external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_HS_Req = external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_2_0_Data_flit = external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_780(
  input         clock,
  input         reset,
  input         io_inputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x3_y0_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_0_0_HS_Ack = external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_3_0_HS_Ack = external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_HS_Req = external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_Data_flit = external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_HS_Req = external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_Data_flit = external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_781(
  input         clock,
  input         reset,
  input         io_inputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x3_y1_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_0_0_HS_Ack = external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_1_0_HS_Ack = external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_3_0_HS_Ack = external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_HS_Req = external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_Data_flit = external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_HS_Req = external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_Data_flit = external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_HS_Req = external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_Data_flit = external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_782(
  input         clock,
  input         reset,
  input         io_inputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_3_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_3_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_3_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x3_y2_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_0_0_HS_Ack = external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_1_0_HS_Ack = external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_3_0_HS_Ack = external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_HS_Req = external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_Data_flit = external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_HS_Req = external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_Data_flit = external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_HS_Req = external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_3_0_Data_flit = external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRRouter_783(
  input         clock,
  input         reset,
  input         io_inputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_inputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_inputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input  [27:0] io_inputs_parent_3_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_0_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_0_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_0_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_child_1_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_child_1_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_child_1_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_0_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_0_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_0_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_1_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_1_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_1_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_2_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_2_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_2_Data_flit, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output        io_outputs_parent_3_HS_Req, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  input         io_outputs_parent_3_HS_Ack, // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
  output [27:0] io_outputs_parent_3_Data_flit // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 72:14]
);
  wire  external_clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire  external_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  wire [27:0] external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
  CMRRouter_split_l1_c1_p4_x3_y3_m1_g4_s3_a0 external ( // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 81:26]
    .clock(external_clock),
    .reset(external_reset),
    .io_inputs_child_0_0_HS_Req(external_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(external_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(external_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(external_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(external_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(external_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(external_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(external_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(external_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(external_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(external_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(external_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(external_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(external_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(external_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(external_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(external_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(external_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(external_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(external_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(external_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(external_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(external_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(external_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(external_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(external_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(external_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(external_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(external_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(external_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(external_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(external_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(external_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(external_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(external_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(external_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(external_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(external_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(external_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(external_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(external_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(external_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(external_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(external_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(external_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(external_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(external_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(external_io_outputs_parent_3_Data_flit)
  );
  assign io_inputs_child_0_0_HS_Ack = external_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_child_1_0_HS_Ack = external_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_0_HS_Ack = external_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_1_HS_Ack = external_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_2_HS_Ack = external_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_inputs_parent_3_HS_Ack = external_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_HS_Req = external_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_0_0_Data_flit = external_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_HS_Req = external_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_child_1_0_Data_flit = external_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_HS_Req = external_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_0_Data_flit = external_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_HS_Req = external_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_1_Data_flit = external_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_HS_Req = external_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_2_Data_flit = external_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_HS_Req = external_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign io_outputs_parent_3_Data_flit = external_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_clock = clock; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 92:23]
  assign external_reset = reset; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 93:32]
  assign external_io_inputs_child_0_0_HS_Req = io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_0_0_Data_flit = io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_HS_Req = io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_1_0_Data_flit = io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_2_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_HS_Req = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_child_3_0_Data_flit = 28'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_HS_Req = io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_0_Data_flit = io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_HS_Req = io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_1_Data_flit = io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_HS_Req = io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_2_Data_flit = io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_HS_Req = io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_inputs_parent_3_Data_flit = io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_2_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_child_3_0_HS_Ack = 1'h0; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_1_HS_Ack = io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_2_HS_Ack = io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
  assign external_io_outputs_parent_3_HS_Ack = io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\Router_Architecture\\CMR\\CMRRouter.scala 94:20]
endmodule

module CMRTopMesh(
  input         clock,
  input         reset,
  input         io_local_inputs_0_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_0_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_0_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_0_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_0_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_0_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_0_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_0_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_0_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_0_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_0_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_0_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_1_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_1_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_1_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_1_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_1_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_1_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_1_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_1_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_1_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_1_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_1_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_1_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_2_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_2_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_2_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_2_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_2_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_2_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_2_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_2_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_2_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_2_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_2_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_2_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_3_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_3_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_3_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_3_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_3_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_3_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_3_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_3_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_3_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_3_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_3_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_3_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_4_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_4_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_4_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_4_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_4_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_4_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_4_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_4_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_4_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_4_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_4_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_4_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_5_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_5_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_5_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_5_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_5_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_5_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_5_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_5_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_5_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_5_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_5_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_5_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_6_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_6_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_6_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_6_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_6_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_6_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_6_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_6_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_6_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_6_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_6_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_6_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_7_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_7_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_7_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_7_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_7_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_7_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_7_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_7_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_7_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_7_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_7_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_7_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_8_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_8_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_8_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_8_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_8_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_8_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_8_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_8_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_8_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_8_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_8_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_8_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_9_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_9_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_9_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_9_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_9_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_9_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_9_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_9_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_9_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_9_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_9_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_9_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_10_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_10_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_10_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_10_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_10_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_10_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_10_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_10_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_10_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_10_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_10_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_10_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_11_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_11_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_11_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_11_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_11_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_11_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_11_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_11_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_11_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_11_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_11_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_11_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_12_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_12_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_12_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_12_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_12_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_12_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_12_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_12_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_12_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_12_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_12_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_12_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_13_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_13_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_13_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_13_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_13_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_13_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_13_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_13_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_13_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_13_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_13_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_13_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_14_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_14_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_14_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_14_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_14_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_14_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_14_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_14_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_14_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_14_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_14_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_14_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_15_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_15_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_15_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_15_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_15_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_15_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_15_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_15_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_15_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_inputs_15_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_inputs_15_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input  [27:0] io_local_inputs_15_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_0_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_0_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_0_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_0_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_0_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_0_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_0_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_0_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_0_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_0_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_0_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_0_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_1_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_1_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_1_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_1_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_1_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_1_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_1_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_1_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_1_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_1_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_1_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_1_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_2_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_2_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_2_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_2_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_2_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_2_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_2_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_2_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_2_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_2_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_2_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_2_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_3_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_3_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_3_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_3_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_3_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_3_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_3_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_3_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_3_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_3_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_3_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_3_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_4_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_4_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_4_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_4_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_4_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_4_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_4_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_4_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_4_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_4_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_4_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_4_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_5_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_5_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_5_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_5_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_5_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_5_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_5_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_5_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_5_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_5_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_5_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_5_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_6_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_6_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_6_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_6_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_6_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_6_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_6_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_6_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_6_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_6_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_6_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_6_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_7_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_7_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_7_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_7_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_7_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_7_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_7_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_7_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_7_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_7_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_7_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_7_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_8_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_8_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_8_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_8_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_8_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_8_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_8_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_8_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_8_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_8_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_8_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_8_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_9_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_9_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_9_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_9_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_9_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_9_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_9_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_9_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_9_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_9_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_9_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_9_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_10_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_10_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_10_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_10_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_10_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_10_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_10_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_10_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_10_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_10_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_10_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_10_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_11_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_11_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_11_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_11_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_11_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_11_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_11_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_11_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_11_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_11_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_11_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_11_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_12_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_12_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_12_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_12_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_12_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_12_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_12_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_12_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_12_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_12_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_12_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_12_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_13_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_13_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_13_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_13_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_13_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_13_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_13_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_13_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_13_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_13_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_13_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_13_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_14_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_14_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_14_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_14_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_14_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_14_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_14_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_14_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_14_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_14_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_14_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_14_3_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_15_0_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_15_0_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_15_0_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_15_1_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_15_1_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_15_1_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_15_2_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_15_2_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_15_2_Data_flit, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output        io_local_outputs_15_3_HS_Req, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  input         io_local_outputs_15_3_HS_Ack, // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
  output [27:0] io_local_outputs_15_3_Data_flit // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 36:14]
);
  wire  topMesh_0_0_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_0_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_0_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_0_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_0_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_0_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_0_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_0_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_0_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_0_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_0_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_0_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_0_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_0_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_1_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_1_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_2_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_2_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_3_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_3_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_3_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_3_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_3_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_3_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_3_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_3_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_3_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_3_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_3_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_0_3_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_0_3_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_0_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_0_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_1_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_1_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_2_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_2_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_1_3_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_1_3_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_0_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_0_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_1_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_1_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_2_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_2_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_inputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_2_3_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_2_3_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_0_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_0_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_0_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_0_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_0_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_0_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_0_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_0_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_0_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_0_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_0_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_0_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_0_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_1_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_1_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_inputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_2_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_2_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_clock; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_reset; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_inputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_3_io_inputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_inputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_3_io_inputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_inputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_3_io_inputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_inputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_3_io_inputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_inputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_3_io_inputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_inputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_3_io_inputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_outputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_3_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_outputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_3_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_outputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_3_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_outputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_3_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_outputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_3_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire  topMesh_3_3_io_outputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  wire [27:0] topMesh_3_3_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
  CMRRouter_768 topMesh_0_0 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_0_0_clock),
    .reset(topMesh_0_0_reset),
    .io_inputs_child_2_0_HS_Req(topMesh_0_0_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(topMesh_0_0_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(topMesh_0_0_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(topMesh_0_0_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(topMesh_0_0_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(topMesh_0_0_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_0_0_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_0_0_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_0_0_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_0_0_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_0_0_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_0_0_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_0_0_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_0_0_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_0_0_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_0_0_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_0_0_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_0_0_io_inputs_parent_3_Data_flit),
    .io_outputs_child_2_0_HS_Req(topMesh_0_0_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(topMesh_0_0_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(topMesh_0_0_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(topMesh_0_0_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(topMesh_0_0_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(topMesh_0_0_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_0_0_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_0_0_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_0_0_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_0_0_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_0_0_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_0_0_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_0_0_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_0_0_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_0_0_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_0_0_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_0_0_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_0_0_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_769 topMesh_0_1 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_0_1_clock),
    .reset(topMesh_0_1_reset),
    .io_inputs_child_1_0_HS_Req(topMesh_0_1_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(topMesh_0_1_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(topMesh_0_1_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(topMesh_0_1_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(topMesh_0_1_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(topMesh_0_1_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(topMesh_0_1_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(topMesh_0_1_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(topMesh_0_1_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_0_1_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_0_1_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_0_1_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_0_1_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_0_1_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_0_1_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_0_1_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_0_1_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_0_1_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_0_1_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_0_1_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_0_1_io_inputs_parent_3_Data_flit),
    .io_outputs_child_1_0_HS_Req(topMesh_0_1_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(topMesh_0_1_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(topMesh_0_1_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(topMesh_0_1_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(topMesh_0_1_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(topMesh_0_1_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(topMesh_0_1_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(topMesh_0_1_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(topMesh_0_1_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_0_1_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_0_1_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_0_1_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_0_1_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_0_1_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_0_1_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_0_1_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_0_1_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_0_1_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_0_1_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_0_1_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_0_1_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_770 topMesh_0_2 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_0_2_clock),
    .reset(topMesh_0_2_reset),
    .io_inputs_child_1_0_HS_Req(topMesh_0_2_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(topMesh_0_2_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(topMesh_0_2_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(topMesh_0_2_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(topMesh_0_2_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(topMesh_0_2_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(topMesh_0_2_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(topMesh_0_2_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(topMesh_0_2_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_0_2_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_0_2_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_0_2_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_0_2_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_0_2_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_0_2_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_0_2_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_0_2_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_0_2_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_0_2_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_0_2_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_0_2_io_inputs_parent_3_Data_flit),
    .io_outputs_child_1_0_HS_Req(topMesh_0_2_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(topMesh_0_2_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(topMesh_0_2_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(topMesh_0_2_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(topMesh_0_2_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(topMesh_0_2_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(topMesh_0_2_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(topMesh_0_2_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(topMesh_0_2_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_0_2_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_0_2_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_0_2_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_0_2_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_0_2_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_0_2_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_0_2_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_0_2_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_0_2_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_0_2_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_0_2_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_0_2_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_771 topMesh_0_3 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_0_3_clock),
    .reset(topMesh_0_3_reset),
    .io_inputs_child_1_0_HS_Req(topMesh_0_3_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(topMesh_0_3_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(topMesh_0_3_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(topMesh_0_3_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(topMesh_0_3_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(topMesh_0_3_io_inputs_child_2_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_0_3_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_0_3_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_0_3_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_0_3_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_0_3_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_0_3_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_0_3_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_0_3_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_0_3_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_0_3_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_0_3_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_0_3_io_inputs_parent_3_Data_flit),
    .io_outputs_child_1_0_HS_Req(topMesh_0_3_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(topMesh_0_3_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(topMesh_0_3_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(topMesh_0_3_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(topMesh_0_3_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(topMesh_0_3_io_outputs_child_2_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_0_3_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_0_3_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_0_3_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_0_3_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_0_3_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_0_3_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_0_3_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_0_3_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_0_3_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_0_3_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_0_3_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_0_3_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_772 topMesh_1_0 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_1_0_clock),
    .reset(topMesh_1_0_reset),
    .io_inputs_child_0_0_HS_Req(topMesh_1_0_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(topMesh_1_0_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(topMesh_1_0_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(topMesh_1_0_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(topMesh_1_0_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(topMesh_1_0_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(topMesh_1_0_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(topMesh_1_0_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(topMesh_1_0_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_1_0_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_1_0_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_1_0_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_1_0_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_1_0_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_1_0_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_1_0_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_1_0_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_1_0_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_1_0_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_1_0_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_1_0_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(topMesh_1_0_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(topMesh_1_0_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(topMesh_1_0_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(topMesh_1_0_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(topMesh_1_0_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(topMesh_1_0_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(topMesh_1_0_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(topMesh_1_0_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(topMesh_1_0_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_1_0_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_1_0_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_1_0_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_1_0_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_1_0_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_1_0_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_1_0_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_1_0_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_1_0_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_1_0_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_1_0_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_1_0_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_773 topMesh_1_1 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_1_1_clock),
    .reset(topMesh_1_1_reset),
    .io_inputs_child_0_0_HS_Req(topMesh_1_1_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(topMesh_1_1_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(topMesh_1_1_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(topMesh_1_1_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(topMesh_1_1_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(topMesh_1_1_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(topMesh_1_1_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(topMesh_1_1_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(topMesh_1_1_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(topMesh_1_1_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(topMesh_1_1_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(topMesh_1_1_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_1_1_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_1_1_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_1_1_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_1_1_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_1_1_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_1_1_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_1_1_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_1_1_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_1_1_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_1_1_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_1_1_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_1_1_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(topMesh_1_1_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(topMesh_1_1_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(topMesh_1_1_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(topMesh_1_1_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(topMesh_1_1_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(topMesh_1_1_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(topMesh_1_1_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(topMesh_1_1_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(topMesh_1_1_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(topMesh_1_1_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(topMesh_1_1_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(topMesh_1_1_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_1_1_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_1_1_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_1_1_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_1_1_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_1_1_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_1_1_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_1_1_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_1_1_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_1_1_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_1_1_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_1_1_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_1_1_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_774 topMesh_1_2 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_1_2_clock),
    .reset(topMesh_1_2_reset),
    .io_inputs_child_0_0_HS_Req(topMesh_1_2_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(topMesh_1_2_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(topMesh_1_2_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(topMesh_1_2_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(topMesh_1_2_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(topMesh_1_2_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(topMesh_1_2_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(topMesh_1_2_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(topMesh_1_2_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(topMesh_1_2_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(topMesh_1_2_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(topMesh_1_2_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_1_2_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_1_2_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_1_2_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_1_2_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_1_2_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_1_2_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_1_2_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_1_2_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_1_2_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_1_2_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_1_2_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_1_2_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(topMesh_1_2_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(topMesh_1_2_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(topMesh_1_2_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(topMesh_1_2_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(topMesh_1_2_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(topMesh_1_2_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(topMesh_1_2_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(topMesh_1_2_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(topMesh_1_2_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(topMesh_1_2_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(topMesh_1_2_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(topMesh_1_2_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_1_2_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_1_2_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_1_2_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_1_2_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_1_2_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_1_2_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_1_2_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_1_2_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_1_2_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_1_2_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_1_2_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_1_2_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_775 topMesh_1_3 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_1_3_clock),
    .reset(topMesh_1_3_reset),
    .io_inputs_child_0_0_HS_Req(topMesh_1_3_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(topMesh_1_3_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(topMesh_1_3_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(topMesh_1_3_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(topMesh_1_3_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(topMesh_1_3_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(topMesh_1_3_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(topMesh_1_3_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(topMesh_1_3_io_inputs_child_2_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_1_3_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_1_3_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_1_3_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_1_3_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_1_3_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_1_3_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_1_3_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_1_3_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_1_3_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_1_3_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_1_3_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_1_3_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(topMesh_1_3_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(topMesh_1_3_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(topMesh_1_3_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(topMesh_1_3_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(topMesh_1_3_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(topMesh_1_3_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(topMesh_1_3_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(topMesh_1_3_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(topMesh_1_3_io_outputs_child_2_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_1_3_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_1_3_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_1_3_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_1_3_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_1_3_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_1_3_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_1_3_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_1_3_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_1_3_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_1_3_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_1_3_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_1_3_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_776 topMesh_2_0 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_2_0_clock),
    .reset(topMesh_2_0_reset),
    .io_inputs_child_0_0_HS_Req(topMesh_2_0_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(topMesh_2_0_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(topMesh_2_0_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(topMesh_2_0_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(topMesh_2_0_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(topMesh_2_0_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(topMesh_2_0_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(topMesh_2_0_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(topMesh_2_0_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_2_0_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_2_0_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_2_0_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_2_0_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_2_0_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_2_0_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_2_0_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_2_0_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_2_0_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_2_0_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_2_0_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_2_0_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(topMesh_2_0_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(topMesh_2_0_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(topMesh_2_0_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(topMesh_2_0_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(topMesh_2_0_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(topMesh_2_0_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(topMesh_2_0_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(topMesh_2_0_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(topMesh_2_0_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_2_0_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_2_0_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_2_0_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_2_0_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_2_0_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_2_0_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_2_0_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_2_0_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_2_0_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_2_0_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_2_0_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_2_0_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_777 topMesh_2_1 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_2_1_clock),
    .reset(topMesh_2_1_reset),
    .io_inputs_child_0_0_HS_Req(topMesh_2_1_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(topMesh_2_1_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(topMesh_2_1_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(topMesh_2_1_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(topMesh_2_1_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(topMesh_2_1_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(topMesh_2_1_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(topMesh_2_1_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(topMesh_2_1_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(topMesh_2_1_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(topMesh_2_1_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(topMesh_2_1_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_2_1_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_2_1_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_2_1_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_2_1_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_2_1_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_2_1_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_2_1_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_2_1_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_2_1_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_2_1_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_2_1_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_2_1_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(topMesh_2_1_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(topMesh_2_1_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(topMesh_2_1_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(topMesh_2_1_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(topMesh_2_1_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(topMesh_2_1_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(topMesh_2_1_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(topMesh_2_1_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(topMesh_2_1_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(topMesh_2_1_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(topMesh_2_1_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(topMesh_2_1_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_2_1_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_2_1_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_2_1_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_2_1_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_2_1_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_2_1_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_2_1_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_2_1_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_2_1_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_2_1_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_2_1_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_2_1_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_778 topMesh_2_2 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_2_2_clock),
    .reset(topMesh_2_2_reset),
    .io_inputs_child_0_0_HS_Req(topMesh_2_2_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(topMesh_2_2_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(topMesh_2_2_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(topMesh_2_2_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(topMesh_2_2_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(topMesh_2_2_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(topMesh_2_2_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(topMesh_2_2_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(topMesh_2_2_io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(topMesh_2_2_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(topMesh_2_2_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(topMesh_2_2_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_2_2_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_2_2_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_2_2_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_2_2_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_2_2_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_2_2_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_2_2_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_2_2_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_2_2_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_2_2_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_2_2_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_2_2_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(topMesh_2_2_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(topMesh_2_2_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(topMesh_2_2_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(topMesh_2_2_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(topMesh_2_2_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(topMesh_2_2_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(topMesh_2_2_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(topMesh_2_2_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(topMesh_2_2_io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(topMesh_2_2_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(topMesh_2_2_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(topMesh_2_2_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_2_2_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_2_2_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_2_2_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_2_2_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_2_2_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_2_2_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_2_2_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_2_2_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_2_2_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_2_2_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_2_2_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_2_2_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_779 topMesh_2_3 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_2_3_clock),
    .reset(topMesh_2_3_reset),
    .io_inputs_child_0_0_HS_Req(topMesh_2_3_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(topMesh_2_3_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(topMesh_2_3_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(topMesh_2_3_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(topMesh_2_3_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(topMesh_2_3_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(topMesh_2_3_io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(topMesh_2_3_io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(topMesh_2_3_io_inputs_child_2_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_2_3_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_2_3_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_2_3_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_2_3_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_2_3_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_2_3_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_2_3_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_2_3_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_2_3_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_2_3_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_2_3_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_2_3_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(topMesh_2_3_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(topMesh_2_3_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(topMesh_2_3_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(topMesh_2_3_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(topMesh_2_3_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(topMesh_2_3_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(topMesh_2_3_io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(topMesh_2_3_io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(topMesh_2_3_io_outputs_child_2_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_2_3_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_2_3_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_2_3_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_2_3_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_2_3_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_2_3_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_2_3_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_2_3_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_2_3_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_2_3_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_2_3_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_2_3_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_780 topMesh_3_0 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_3_0_clock),
    .reset(topMesh_3_0_reset),
    .io_inputs_child_0_0_HS_Req(topMesh_3_0_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(topMesh_3_0_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(topMesh_3_0_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(topMesh_3_0_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(topMesh_3_0_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(topMesh_3_0_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_3_0_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_3_0_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_3_0_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_3_0_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_3_0_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_3_0_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_3_0_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_3_0_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_3_0_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_3_0_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_3_0_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_3_0_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(topMesh_3_0_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(topMesh_3_0_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(topMesh_3_0_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(topMesh_3_0_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(topMesh_3_0_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(topMesh_3_0_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_3_0_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_3_0_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_3_0_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_3_0_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_3_0_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_3_0_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_3_0_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_3_0_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_3_0_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_3_0_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_3_0_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_3_0_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_781 topMesh_3_1 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_3_1_clock),
    .reset(topMesh_3_1_reset),
    .io_inputs_child_0_0_HS_Req(topMesh_3_1_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(topMesh_3_1_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(topMesh_3_1_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(topMesh_3_1_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(topMesh_3_1_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(topMesh_3_1_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(topMesh_3_1_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(topMesh_3_1_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(topMesh_3_1_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_3_1_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_3_1_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_3_1_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_3_1_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_3_1_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_3_1_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_3_1_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_3_1_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_3_1_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_3_1_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_3_1_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_3_1_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(topMesh_3_1_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(topMesh_3_1_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(topMesh_3_1_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(topMesh_3_1_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(topMesh_3_1_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(topMesh_3_1_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(topMesh_3_1_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(topMesh_3_1_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(topMesh_3_1_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_3_1_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_3_1_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_3_1_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_3_1_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_3_1_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_3_1_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_3_1_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_3_1_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_3_1_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_3_1_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_3_1_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_3_1_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_782 topMesh_3_2 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_3_2_clock),
    .reset(topMesh_3_2_reset),
    .io_inputs_child_0_0_HS_Req(topMesh_3_2_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(topMesh_3_2_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(topMesh_3_2_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(topMesh_3_2_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(topMesh_3_2_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(topMesh_3_2_io_inputs_child_1_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(topMesh_3_2_io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(topMesh_3_2_io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(topMesh_3_2_io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_3_2_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_3_2_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_3_2_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_3_2_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_3_2_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_3_2_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_3_2_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_3_2_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_3_2_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_3_2_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_3_2_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_3_2_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(topMesh_3_2_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(topMesh_3_2_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(topMesh_3_2_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(topMesh_3_2_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(topMesh_3_2_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(topMesh_3_2_io_outputs_child_1_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(topMesh_3_2_io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(topMesh_3_2_io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(topMesh_3_2_io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_3_2_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_3_2_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_3_2_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_3_2_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_3_2_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_3_2_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_3_2_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_3_2_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_3_2_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_3_2_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_3_2_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_3_2_io_outputs_parent_3_Data_flit)
  );
  CMRRouter_783 topMesh_3_3 ( // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 42:24]
    .clock(topMesh_3_3_clock),
    .reset(topMesh_3_3_reset),
    .io_inputs_child_0_0_HS_Req(topMesh_3_3_io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(topMesh_3_3_io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(topMesh_3_3_io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(topMesh_3_3_io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(topMesh_3_3_io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(topMesh_3_3_io_inputs_child_1_0_Data_flit),
    .io_inputs_parent_0_HS_Req(topMesh_3_3_io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(topMesh_3_3_io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(topMesh_3_3_io_inputs_parent_0_Data_flit),
    .io_inputs_parent_1_HS_Req(topMesh_3_3_io_inputs_parent_1_HS_Req),
    .io_inputs_parent_1_HS_Ack(topMesh_3_3_io_inputs_parent_1_HS_Ack),
    .io_inputs_parent_1_Data_flit(topMesh_3_3_io_inputs_parent_1_Data_flit),
    .io_inputs_parent_2_HS_Req(topMesh_3_3_io_inputs_parent_2_HS_Req),
    .io_inputs_parent_2_HS_Ack(topMesh_3_3_io_inputs_parent_2_HS_Ack),
    .io_inputs_parent_2_Data_flit(topMesh_3_3_io_inputs_parent_2_Data_flit),
    .io_inputs_parent_3_HS_Req(topMesh_3_3_io_inputs_parent_3_HS_Req),
    .io_inputs_parent_3_HS_Ack(topMesh_3_3_io_inputs_parent_3_HS_Ack),
    .io_inputs_parent_3_Data_flit(topMesh_3_3_io_inputs_parent_3_Data_flit),
    .io_outputs_child_0_0_HS_Req(topMesh_3_3_io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(topMesh_3_3_io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(topMesh_3_3_io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(topMesh_3_3_io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(topMesh_3_3_io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(topMesh_3_3_io_outputs_child_1_0_Data_flit),
    .io_outputs_parent_0_HS_Req(topMesh_3_3_io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(topMesh_3_3_io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(topMesh_3_3_io_outputs_parent_0_Data_flit),
    .io_outputs_parent_1_HS_Req(topMesh_3_3_io_outputs_parent_1_HS_Req),
    .io_outputs_parent_1_HS_Ack(topMesh_3_3_io_outputs_parent_1_HS_Ack),
    .io_outputs_parent_1_Data_flit(topMesh_3_3_io_outputs_parent_1_Data_flit),
    .io_outputs_parent_2_HS_Req(topMesh_3_3_io_outputs_parent_2_HS_Req),
    .io_outputs_parent_2_HS_Ack(topMesh_3_3_io_outputs_parent_2_HS_Ack),
    .io_outputs_parent_2_Data_flit(topMesh_3_3_io_outputs_parent_2_Data_flit),
    .io_outputs_parent_3_HS_Req(topMesh_3_3_io_outputs_parent_3_HS_Req),
    .io_outputs_parent_3_HS_Ack(topMesh_3_3_io_outputs_parent_3_HS_Ack),
    .io_outputs_parent_3_Data_flit(topMesh_3_3_io_outputs_parent_3_Data_flit)
  );
  assign io_local_inputs_0_0_HS_Ack = topMesh_0_0_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_0_1_HS_Ack = topMesh_0_0_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_0_2_HS_Ack = topMesh_0_0_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_0_3_HS_Ack = topMesh_0_0_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_1_0_HS_Ack = topMesh_1_0_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_1_1_HS_Ack = topMesh_1_0_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_1_2_HS_Ack = topMesh_1_0_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_1_3_HS_Ack = topMesh_1_0_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_2_0_HS_Ack = topMesh_2_0_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_2_1_HS_Ack = topMesh_2_0_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_2_2_HS_Ack = topMesh_2_0_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_2_3_HS_Ack = topMesh_2_0_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_3_0_HS_Ack = topMesh_3_0_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_3_1_HS_Ack = topMesh_3_0_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_3_2_HS_Ack = topMesh_3_0_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_3_3_HS_Ack = topMesh_3_0_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_4_0_HS_Ack = topMesh_0_1_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_4_1_HS_Ack = topMesh_0_1_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_4_2_HS_Ack = topMesh_0_1_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_4_3_HS_Ack = topMesh_0_1_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_5_0_HS_Ack = topMesh_1_1_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_5_1_HS_Ack = topMesh_1_1_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_5_2_HS_Ack = topMesh_1_1_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_5_3_HS_Ack = topMesh_1_1_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_6_0_HS_Ack = topMesh_2_1_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_6_1_HS_Ack = topMesh_2_1_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_6_2_HS_Ack = topMesh_2_1_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_6_3_HS_Ack = topMesh_2_1_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_7_0_HS_Ack = topMesh_3_1_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_7_1_HS_Ack = topMesh_3_1_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_7_2_HS_Ack = topMesh_3_1_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_7_3_HS_Ack = topMesh_3_1_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_8_0_HS_Ack = topMesh_0_2_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_8_1_HS_Ack = topMesh_0_2_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_8_2_HS_Ack = topMesh_0_2_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_8_3_HS_Ack = topMesh_0_2_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_9_0_HS_Ack = topMesh_1_2_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_9_1_HS_Ack = topMesh_1_2_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_9_2_HS_Ack = topMesh_1_2_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_9_3_HS_Ack = topMesh_1_2_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_10_0_HS_Ack = topMesh_2_2_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_10_1_HS_Ack = topMesh_2_2_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_10_2_HS_Ack = topMesh_2_2_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_10_3_HS_Ack = topMesh_2_2_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_11_0_HS_Ack = topMesh_3_2_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_11_1_HS_Ack = topMesh_3_2_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_11_2_HS_Ack = topMesh_3_2_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_11_3_HS_Ack = topMesh_3_2_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_12_0_HS_Ack = topMesh_0_3_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_12_1_HS_Ack = topMesh_0_3_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_12_2_HS_Ack = topMesh_0_3_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_12_3_HS_Ack = topMesh_0_3_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_13_0_HS_Ack = topMesh_1_3_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_13_1_HS_Ack = topMesh_1_3_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_13_2_HS_Ack = topMesh_1_3_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_13_3_HS_Ack = topMesh_1_3_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_14_0_HS_Ack = topMesh_2_3_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_14_1_HS_Ack = topMesh_2_3_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_14_2_HS_Ack = topMesh_2_3_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_14_3_HS_Ack = topMesh_2_3_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_15_0_HS_Ack = topMesh_3_3_io_inputs_parent_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_15_1_HS_Ack = topMesh_3_3_io_inputs_parent_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_15_2_HS_Ack = topMesh_3_3_io_inputs_parent_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_inputs_15_3_HS_Ack = topMesh_3_3_io_inputs_parent_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign io_local_outputs_0_0_HS_Req = topMesh_0_0_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_0_0_Data_flit = topMesh_0_0_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_0_1_HS_Req = topMesh_0_0_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_0_1_Data_flit = topMesh_0_0_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_0_2_HS_Req = topMesh_0_0_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_0_2_Data_flit = topMesh_0_0_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_0_3_HS_Req = topMesh_0_0_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_0_3_Data_flit = topMesh_0_0_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_1_0_HS_Req = topMesh_1_0_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_1_0_Data_flit = topMesh_1_0_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_1_1_HS_Req = topMesh_1_0_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_1_1_Data_flit = topMesh_1_0_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_1_2_HS_Req = topMesh_1_0_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_1_2_Data_flit = topMesh_1_0_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_1_3_HS_Req = topMesh_1_0_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_1_3_Data_flit = topMesh_1_0_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_2_0_HS_Req = topMesh_2_0_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_2_0_Data_flit = topMesh_2_0_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_2_1_HS_Req = topMesh_2_0_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_2_1_Data_flit = topMesh_2_0_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_2_2_HS_Req = topMesh_2_0_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_2_2_Data_flit = topMesh_2_0_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_2_3_HS_Req = topMesh_2_0_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_2_3_Data_flit = topMesh_2_0_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_3_0_HS_Req = topMesh_3_0_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_3_0_Data_flit = topMesh_3_0_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_3_1_HS_Req = topMesh_3_0_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_3_1_Data_flit = topMesh_3_0_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_3_2_HS_Req = topMesh_3_0_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_3_2_Data_flit = topMesh_3_0_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_3_3_HS_Req = topMesh_3_0_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_3_3_Data_flit = topMesh_3_0_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_4_0_HS_Req = topMesh_0_1_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_4_0_Data_flit = topMesh_0_1_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_4_1_HS_Req = topMesh_0_1_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_4_1_Data_flit = topMesh_0_1_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_4_2_HS_Req = topMesh_0_1_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_4_2_Data_flit = topMesh_0_1_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_4_3_HS_Req = topMesh_0_1_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_4_3_Data_flit = topMesh_0_1_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_5_0_HS_Req = topMesh_1_1_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_5_0_Data_flit = topMesh_1_1_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_5_1_HS_Req = topMesh_1_1_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_5_1_Data_flit = topMesh_1_1_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_5_2_HS_Req = topMesh_1_1_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_5_2_Data_flit = topMesh_1_1_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_5_3_HS_Req = topMesh_1_1_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_5_3_Data_flit = topMesh_1_1_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_6_0_HS_Req = topMesh_2_1_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_6_0_Data_flit = topMesh_2_1_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_6_1_HS_Req = topMesh_2_1_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_6_1_Data_flit = topMesh_2_1_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_6_2_HS_Req = topMesh_2_1_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_6_2_Data_flit = topMesh_2_1_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_6_3_HS_Req = topMesh_2_1_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_6_3_Data_flit = topMesh_2_1_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_7_0_HS_Req = topMesh_3_1_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_7_0_Data_flit = topMesh_3_1_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_7_1_HS_Req = topMesh_3_1_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_7_1_Data_flit = topMesh_3_1_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_7_2_HS_Req = topMesh_3_1_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_7_2_Data_flit = topMesh_3_1_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_7_3_HS_Req = topMesh_3_1_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_7_3_Data_flit = topMesh_3_1_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_8_0_HS_Req = topMesh_0_2_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_8_0_Data_flit = topMesh_0_2_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_8_1_HS_Req = topMesh_0_2_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_8_1_Data_flit = topMesh_0_2_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_8_2_HS_Req = topMesh_0_2_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_8_2_Data_flit = topMesh_0_2_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_8_3_HS_Req = topMesh_0_2_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_8_3_Data_flit = topMesh_0_2_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_9_0_HS_Req = topMesh_1_2_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_9_0_Data_flit = topMesh_1_2_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_9_1_HS_Req = topMesh_1_2_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_9_1_Data_flit = topMesh_1_2_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_9_2_HS_Req = topMesh_1_2_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_9_2_Data_flit = topMesh_1_2_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_9_3_HS_Req = topMesh_1_2_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_9_3_Data_flit = topMesh_1_2_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_10_0_HS_Req = topMesh_2_2_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_10_0_Data_flit = topMesh_2_2_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_10_1_HS_Req = topMesh_2_2_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_10_1_Data_flit = topMesh_2_2_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_10_2_HS_Req = topMesh_2_2_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_10_2_Data_flit = topMesh_2_2_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_10_3_HS_Req = topMesh_2_2_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_10_3_Data_flit = topMesh_2_2_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_11_0_HS_Req = topMesh_3_2_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_11_0_Data_flit = topMesh_3_2_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_11_1_HS_Req = topMesh_3_2_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_11_1_Data_flit = topMesh_3_2_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_11_2_HS_Req = topMesh_3_2_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_11_2_Data_flit = topMesh_3_2_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_11_3_HS_Req = topMesh_3_2_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_11_3_Data_flit = topMesh_3_2_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_12_0_HS_Req = topMesh_0_3_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_12_0_Data_flit = topMesh_0_3_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_12_1_HS_Req = topMesh_0_3_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_12_1_Data_flit = topMesh_0_3_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_12_2_HS_Req = topMesh_0_3_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_12_2_Data_flit = topMesh_0_3_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_12_3_HS_Req = topMesh_0_3_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_12_3_Data_flit = topMesh_0_3_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_13_0_HS_Req = topMesh_1_3_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_13_0_Data_flit = topMesh_1_3_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_13_1_HS_Req = topMesh_1_3_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_13_1_Data_flit = topMesh_1_3_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_13_2_HS_Req = topMesh_1_3_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_13_2_Data_flit = topMesh_1_3_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_13_3_HS_Req = topMesh_1_3_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_13_3_Data_flit = topMesh_1_3_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_14_0_HS_Req = topMesh_2_3_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_14_0_Data_flit = topMesh_2_3_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_14_1_HS_Req = topMesh_2_3_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_14_1_Data_flit = topMesh_2_3_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_14_2_HS_Req = topMesh_2_3_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_14_2_Data_flit = topMesh_2_3_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_14_3_HS_Req = topMesh_2_3_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_14_3_Data_flit = topMesh_2_3_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_15_0_HS_Req = topMesh_3_3_io_outputs_parent_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_15_0_Data_flit = topMesh_3_3_io_outputs_parent_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_15_1_HS_Req = topMesh_3_3_io_outputs_parent_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_15_1_Data_flit = topMesh_3_3_io_outputs_parent_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_15_2_HS_Req = topMesh_3_3_io_outputs_parent_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_15_2_Data_flit = topMesh_3_3_io_outputs_parent_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_15_3_HS_Req = topMesh_3_3_io_outputs_parent_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign io_local_outputs_15_3_Data_flit = topMesh_3_3_io_outputs_parent_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_0_clock = clock;
  assign topMesh_0_0_reset = reset;
  assign topMesh_0_0_io_inputs_child_2_0_HS_Req = topMesh_1_0_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_0_0_io_inputs_child_2_0_Data_flit = topMesh_1_0_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_0_0_io_inputs_child_3_0_HS_Req = topMesh_0_1_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_0_0_io_inputs_child_3_0_Data_flit = topMesh_0_1_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_0_0_io_inputs_parent_0_HS_Req = io_local_inputs_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_0_io_inputs_parent_0_Data_flit = io_local_inputs_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_0_io_inputs_parent_1_HS_Req = io_local_inputs_0_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_0_io_inputs_parent_1_Data_flit = io_local_inputs_0_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_0_io_inputs_parent_2_HS_Req = io_local_inputs_0_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_0_io_inputs_parent_2_Data_flit = io_local_inputs_0_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_0_io_inputs_parent_3_HS_Req = io_local_inputs_0_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_0_io_inputs_parent_3_Data_flit = io_local_inputs_0_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_0_io_outputs_child_2_0_HS_Ack = topMesh_1_0_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_0_0_io_outputs_child_3_0_HS_Ack = topMesh_0_1_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_0_0_io_outputs_parent_0_HS_Ack = io_local_outputs_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_0_io_outputs_parent_1_HS_Ack = io_local_outputs_0_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_0_io_outputs_parent_2_HS_Ack = io_local_outputs_0_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_0_io_outputs_parent_3_HS_Ack = io_local_outputs_0_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_1_clock = clock;
  assign topMesh_0_1_reset = reset;
  assign topMesh_0_1_io_inputs_child_1_0_HS_Req = topMesh_0_0_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_0_1_io_inputs_child_1_0_Data_flit = topMesh_0_0_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_0_1_io_inputs_child_2_0_HS_Req = topMesh_1_1_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_0_1_io_inputs_child_2_0_Data_flit = topMesh_1_1_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_0_1_io_inputs_child_3_0_HS_Req = topMesh_0_2_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_0_1_io_inputs_child_3_0_Data_flit = topMesh_0_2_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_0_1_io_inputs_parent_0_HS_Req = io_local_inputs_4_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_1_io_inputs_parent_0_Data_flit = io_local_inputs_4_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_1_io_inputs_parent_1_HS_Req = io_local_inputs_4_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_1_io_inputs_parent_1_Data_flit = io_local_inputs_4_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_1_io_inputs_parent_2_HS_Req = io_local_inputs_4_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_1_io_inputs_parent_2_Data_flit = io_local_inputs_4_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_1_io_inputs_parent_3_HS_Req = io_local_inputs_4_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_1_io_inputs_parent_3_Data_flit = io_local_inputs_4_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_1_io_outputs_child_1_0_HS_Ack = topMesh_0_0_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_0_1_io_outputs_child_2_0_HS_Ack = topMesh_1_1_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_0_1_io_outputs_child_3_0_HS_Ack = topMesh_0_2_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_0_1_io_outputs_parent_0_HS_Ack = io_local_outputs_4_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_1_io_outputs_parent_1_HS_Ack = io_local_outputs_4_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_1_io_outputs_parent_2_HS_Ack = io_local_outputs_4_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_1_io_outputs_parent_3_HS_Ack = io_local_outputs_4_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_2_clock = clock;
  assign topMesh_0_2_reset = reset;
  assign topMesh_0_2_io_inputs_child_1_0_HS_Req = topMesh_0_1_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_0_2_io_inputs_child_1_0_Data_flit = topMesh_0_1_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_0_2_io_inputs_child_2_0_HS_Req = topMesh_1_2_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_0_2_io_inputs_child_2_0_Data_flit = topMesh_1_2_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_0_2_io_inputs_child_3_0_HS_Req = topMesh_0_3_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_0_2_io_inputs_child_3_0_Data_flit = topMesh_0_3_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_0_2_io_inputs_parent_0_HS_Req = io_local_inputs_8_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_2_io_inputs_parent_0_Data_flit = io_local_inputs_8_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_2_io_inputs_parent_1_HS_Req = io_local_inputs_8_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_2_io_inputs_parent_1_Data_flit = io_local_inputs_8_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_2_io_inputs_parent_2_HS_Req = io_local_inputs_8_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_2_io_inputs_parent_2_Data_flit = io_local_inputs_8_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_2_io_inputs_parent_3_HS_Req = io_local_inputs_8_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_2_io_inputs_parent_3_Data_flit = io_local_inputs_8_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_2_io_outputs_child_1_0_HS_Ack = topMesh_0_1_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_0_2_io_outputs_child_2_0_HS_Ack = topMesh_1_2_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_0_2_io_outputs_child_3_0_HS_Ack = topMesh_0_3_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_0_2_io_outputs_parent_0_HS_Ack = io_local_outputs_8_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_2_io_outputs_parent_1_HS_Ack = io_local_outputs_8_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_2_io_outputs_parent_2_HS_Ack = io_local_outputs_8_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_2_io_outputs_parent_3_HS_Ack = io_local_outputs_8_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_3_clock = clock;
  assign topMesh_0_3_reset = reset;
  assign topMesh_0_3_io_inputs_child_1_0_HS_Req = topMesh_0_2_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_0_3_io_inputs_child_1_0_Data_flit = topMesh_0_2_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_0_3_io_inputs_child_2_0_HS_Req = topMesh_1_3_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_0_3_io_inputs_child_2_0_Data_flit = topMesh_1_3_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_0_3_io_inputs_parent_0_HS_Req = io_local_inputs_12_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_3_io_inputs_parent_0_Data_flit = io_local_inputs_12_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_3_io_inputs_parent_1_HS_Req = io_local_inputs_12_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_3_io_inputs_parent_1_Data_flit = io_local_inputs_12_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_3_io_inputs_parent_2_HS_Req = io_local_inputs_12_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_3_io_inputs_parent_2_Data_flit = io_local_inputs_12_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_3_io_inputs_parent_3_HS_Req = io_local_inputs_12_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_3_io_inputs_parent_3_Data_flit = io_local_inputs_12_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_0_3_io_outputs_child_1_0_HS_Ack = topMesh_0_2_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_0_3_io_outputs_child_2_0_HS_Ack = topMesh_1_3_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_0_3_io_outputs_parent_0_HS_Ack = io_local_outputs_12_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_3_io_outputs_parent_1_HS_Ack = io_local_outputs_12_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_3_io_outputs_parent_2_HS_Ack = io_local_outputs_12_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_0_3_io_outputs_parent_3_HS_Ack = io_local_outputs_12_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_0_clock = clock;
  assign topMesh_1_0_reset = reset;
  assign topMesh_1_0_io_inputs_child_0_0_HS_Req = topMesh_0_0_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_1_0_io_inputs_child_0_0_Data_flit = topMesh_0_0_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_1_0_io_inputs_child_2_0_HS_Req = topMesh_2_0_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_1_0_io_inputs_child_2_0_Data_flit = topMesh_2_0_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_1_0_io_inputs_child_3_0_HS_Req = topMesh_1_1_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_1_0_io_inputs_child_3_0_Data_flit = topMesh_1_1_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_1_0_io_inputs_parent_0_HS_Req = io_local_inputs_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_0_io_inputs_parent_0_Data_flit = io_local_inputs_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_0_io_inputs_parent_1_HS_Req = io_local_inputs_1_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_0_io_inputs_parent_1_Data_flit = io_local_inputs_1_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_0_io_inputs_parent_2_HS_Req = io_local_inputs_1_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_0_io_inputs_parent_2_Data_flit = io_local_inputs_1_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_0_io_inputs_parent_3_HS_Req = io_local_inputs_1_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_0_io_inputs_parent_3_Data_flit = io_local_inputs_1_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_0_io_outputs_child_0_0_HS_Ack = topMesh_0_0_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_1_0_io_outputs_child_2_0_HS_Ack = topMesh_2_0_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_1_0_io_outputs_child_3_0_HS_Ack = topMesh_1_1_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_1_0_io_outputs_parent_0_HS_Ack = io_local_outputs_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_0_io_outputs_parent_1_HS_Ack = io_local_outputs_1_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_0_io_outputs_parent_2_HS_Ack = io_local_outputs_1_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_0_io_outputs_parent_3_HS_Ack = io_local_outputs_1_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_1_clock = clock;
  assign topMesh_1_1_reset = reset;
  assign topMesh_1_1_io_inputs_child_0_0_HS_Req = topMesh_0_1_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_1_1_io_inputs_child_0_0_Data_flit = topMesh_0_1_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_1_1_io_inputs_child_1_0_HS_Req = topMesh_1_0_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_1_1_io_inputs_child_1_0_Data_flit = topMesh_1_0_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_1_1_io_inputs_child_2_0_HS_Req = topMesh_2_1_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_1_1_io_inputs_child_2_0_Data_flit = topMesh_2_1_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_1_1_io_inputs_child_3_0_HS_Req = topMesh_1_2_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_1_1_io_inputs_child_3_0_Data_flit = topMesh_1_2_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_1_1_io_inputs_parent_0_HS_Req = io_local_inputs_5_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_1_io_inputs_parent_0_Data_flit = io_local_inputs_5_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_1_io_inputs_parent_1_HS_Req = io_local_inputs_5_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_1_io_inputs_parent_1_Data_flit = io_local_inputs_5_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_1_io_inputs_parent_2_HS_Req = io_local_inputs_5_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_1_io_inputs_parent_2_Data_flit = io_local_inputs_5_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_1_io_inputs_parent_3_HS_Req = io_local_inputs_5_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_1_io_inputs_parent_3_Data_flit = io_local_inputs_5_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_1_io_outputs_child_0_0_HS_Ack = topMesh_0_1_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_1_1_io_outputs_child_1_0_HS_Ack = topMesh_1_0_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_1_1_io_outputs_child_2_0_HS_Ack = topMesh_2_1_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_1_1_io_outputs_child_3_0_HS_Ack = topMesh_1_2_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_1_1_io_outputs_parent_0_HS_Ack = io_local_outputs_5_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_1_io_outputs_parent_1_HS_Ack = io_local_outputs_5_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_1_io_outputs_parent_2_HS_Ack = io_local_outputs_5_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_1_io_outputs_parent_3_HS_Ack = io_local_outputs_5_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_2_clock = clock;
  assign topMesh_1_2_reset = reset;
  assign topMesh_1_2_io_inputs_child_0_0_HS_Req = topMesh_0_2_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_1_2_io_inputs_child_0_0_Data_flit = topMesh_0_2_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_1_2_io_inputs_child_1_0_HS_Req = topMesh_1_1_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_1_2_io_inputs_child_1_0_Data_flit = topMesh_1_1_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_1_2_io_inputs_child_2_0_HS_Req = topMesh_2_2_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_1_2_io_inputs_child_2_0_Data_flit = topMesh_2_2_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_1_2_io_inputs_child_3_0_HS_Req = topMesh_1_3_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_1_2_io_inputs_child_3_0_Data_flit = topMesh_1_3_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_1_2_io_inputs_parent_0_HS_Req = io_local_inputs_9_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_2_io_inputs_parent_0_Data_flit = io_local_inputs_9_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_2_io_inputs_parent_1_HS_Req = io_local_inputs_9_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_2_io_inputs_parent_1_Data_flit = io_local_inputs_9_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_2_io_inputs_parent_2_HS_Req = io_local_inputs_9_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_2_io_inputs_parent_2_Data_flit = io_local_inputs_9_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_2_io_inputs_parent_3_HS_Req = io_local_inputs_9_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_2_io_inputs_parent_3_Data_flit = io_local_inputs_9_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_2_io_outputs_child_0_0_HS_Ack = topMesh_0_2_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_1_2_io_outputs_child_1_0_HS_Ack = topMesh_1_1_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_1_2_io_outputs_child_2_0_HS_Ack = topMesh_2_2_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_1_2_io_outputs_child_3_0_HS_Ack = topMesh_1_3_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_1_2_io_outputs_parent_0_HS_Ack = io_local_outputs_9_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_2_io_outputs_parent_1_HS_Ack = io_local_outputs_9_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_2_io_outputs_parent_2_HS_Ack = io_local_outputs_9_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_2_io_outputs_parent_3_HS_Ack = io_local_outputs_9_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_3_clock = clock;
  assign topMesh_1_3_reset = reset;
  assign topMesh_1_3_io_inputs_child_0_0_HS_Req = topMesh_0_3_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_1_3_io_inputs_child_0_0_Data_flit = topMesh_0_3_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_1_3_io_inputs_child_1_0_HS_Req = topMesh_1_2_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_1_3_io_inputs_child_1_0_Data_flit = topMesh_1_2_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_1_3_io_inputs_child_2_0_HS_Req = topMesh_2_3_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_1_3_io_inputs_child_2_0_Data_flit = topMesh_2_3_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_1_3_io_inputs_parent_0_HS_Req = io_local_inputs_13_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_3_io_inputs_parent_0_Data_flit = io_local_inputs_13_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_3_io_inputs_parent_1_HS_Req = io_local_inputs_13_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_3_io_inputs_parent_1_Data_flit = io_local_inputs_13_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_3_io_inputs_parent_2_HS_Req = io_local_inputs_13_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_3_io_inputs_parent_2_Data_flit = io_local_inputs_13_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_3_io_inputs_parent_3_HS_Req = io_local_inputs_13_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_3_io_inputs_parent_3_Data_flit = io_local_inputs_13_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_1_3_io_outputs_child_0_0_HS_Ack = topMesh_0_3_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_1_3_io_outputs_child_1_0_HS_Ack = topMesh_1_2_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_1_3_io_outputs_child_2_0_HS_Ack = topMesh_2_3_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_1_3_io_outputs_parent_0_HS_Ack = io_local_outputs_13_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_3_io_outputs_parent_1_HS_Ack = io_local_outputs_13_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_3_io_outputs_parent_2_HS_Ack = io_local_outputs_13_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_1_3_io_outputs_parent_3_HS_Ack = io_local_outputs_13_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_0_clock = clock;
  assign topMesh_2_0_reset = reset;
  assign topMesh_2_0_io_inputs_child_0_0_HS_Req = topMesh_1_0_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_2_0_io_inputs_child_0_0_Data_flit = topMesh_1_0_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_2_0_io_inputs_child_2_0_HS_Req = topMesh_3_0_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_2_0_io_inputs_child_2_0_Data_flit = topMesh_3_0_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_2_0_io_inputs_child_3_0_HS_Req = topMesh_2_1_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_2_0_io_inputs_child_3_0_Data_flit = topMesh_2_1_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_2_0_io_inputs_parent_0_HS_Req = io_local_inputs_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_0_io_inputs_parent_0_Data_flit = io_local_inputs_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_0_io_inputs_parent_1_HS_Req = io_local_inputs_2_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_0_io_inputs_parent_1_Data_flit = io_local_inputs_2_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_0_io_inputs_parent_2_HS_Req = io_local_inputs_2_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_0_io_inputs_parent_2_Data_flit = io_local_inputs_2_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_0_io_inputs_parent_3_HS_Req = io_local_inputs_2_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_0_io_inputs_parent_3_Data_flit = io_local_inputs_2_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_0_io_outputs_child_0_0_HS_Ack = topMesh_1_0_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_2_0_io_outputs_child_2_0_HS_Ack = topMesh_3_0_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_2_0_io_outputs_child_3_0_HS_Ack = topMesh_2_1_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_2_0_io_outputs_parent_0_HS_Ack = io_local_outputs_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_0_io_outputs_parent_1_HS_Ack = io_local_outputs_2_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_0_io_outputs_parent_2_HS_Ack = io_local_outputs_2_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_0_io_outputs_parent_3_HS_Ack = io_local_outputs_2_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_1_clock = clock;
  assign topMesh_2_1_reset = reset;
  assign topMesh_2_1_io_inputs_child_0_0_HS_Req = topMesh_1_1_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_2_1_io_inputs_child_0_0_Data_flit = topMesh_1_1_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_2_1_io_inputs_child_1_0_HS_Req = topMesh_2_0_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_2_1_io_inputs_child_1_0_Data_flit = topMesh_2_0_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_2_1_io_inputs_child_2_0_HS_Req = topMesh_3_1_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_2_1_io_inputs_child_2_0_Data_flit = topMesh_3_1_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_2_1_io_inputs_child_3_0_HS_Req = topMesh_2_2_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_2_1_io_inputs_child_3_0_Data_flit = topMesh_2_2_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_2_1_io_inputs_parent_0_HS_Req = io_local_inputs_6_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_1_io_inputs_parent_0_Data_flit = io_local_inputs_6_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_1_io_inputs_parent_1_HS_Req = io_local_inputs_6_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_1_io_inputs_parent_1_Data_flit = io_local_inputs_6_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_1_io_inputs_parent_2_HS_Req = io_local_inputs_6_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_1_io_inputs_parent_2_Data_flit = io_local_inputs_6_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_1_io_inputs_parent_3_HS_Req = io_local_inputs_6_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_1_io_inputs_parent_3_Data_flit = io_local_inputs_6_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_1_io_outputs_child_0_0_HS_Ack = topMesh_1_1_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_2_1_io_outputs_child_1_0_HS_Ack = topMesh_2_0_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_2_1_io_outputs_child_2_0_HS_Ack = topMesh_3_1_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_2_1_io_outputs_child_3_0_HS_Ack = topMesh_2_2_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_2_1_io_outputs_parent_0_HS_Ack = io_local_outputs_6_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_1_io_outputs_parent_1_HS_Ack = io_local_outputs_6_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_1_io_outputs_parent_2_HS_Ack = io_local_outputs_6_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_1_io_outputs_parent_3_HS_Ack = io_local_outputs_6_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_2_clock = clock;
  assign topMesh_2_2_reset = reset;
  assign topMesh_2_2_io_inputs_child_0_0_HS_Req = topMesh_1_2_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_2_2_io_inputs_child_0_0_Data_flit = topMesh_1_2_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_2_2_io_inputs_child_1_0_HS_Req = topMesh_2_1_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_2_2_io_inputs_child_1_0_Data_flit = topMesh_2_1_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_2_2_io_inputs_child_2_0_HS_Req = topMesh_3_2_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_2_2_io_inputs_child_2_0_Data_flit = topMesh_3_2_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_2_2_io_inputs_child_3_0_HS_Req = topMesh_2_3_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_2_2_io_inputs_child_3_0_Data_flit = topMesh_2_3_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_2_2_io_inputs_parent_0_HS_Req = io_local_inputs_10_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_2_io_inputs_parent_0_Data_flit = io_local_inputs_10_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_2_io_inputs_parent_1_HS_Req = io_local_inputs_10_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_2_io_inputs_parent_1_Data_flit = io_local_inputs_10_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_2_io_inputs_parent_2_HS_Req = io_local_inputs_10_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_2_io_inputs_parent_2_Data_flit = io_local_inputs_10_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_2_io_inputs_parent_3_HS_Req = io_local_inputs_10_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_2_io_inputs_parent_3_Data_flit = io_local_inputs_10_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_2_io_outputs_child_0_0_HS_Ack = topMesh_1_2_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_2_2_io_outputs_child_1_0_HS_Ack = topMesh_2_1_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_2_2_io_outputs_child_2_0_HS_Ack = topMesh_3_2_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_2_2_io_outputs_child_3_0_HS_Ack = topMesh_2_3_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_2_2_io_outputs_parent_0_HS_Ack = io_local_outputs_10_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_2_io_outputs_parent_1_HS_Ack = io_local_outputs_10_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_2_io_outputs_parent_2_HS_Ack = io_local_outputs_10_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_2_io_outputs_parent_3_HS_Ack = io_local_outputs_10_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_3_clock = clock;
  assign topMesh_2_3_reset = reset;
  assign topMesh_2_3_io_inputs_child_0_0_HS_Req = topMesh_1_3_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_2_3_io_inputs_child_0_0_Data_flit = topMesh_1_3_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_2_3_io_inputs_child_1_0_HS_Req = topMesh_2_2_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_2_3_io_inputs_child_1_0_Data_flit = topMesh_2_2_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_2_3_io_inputs_child_2_0_HS_Req = topMesh_3_3_io_outputs_child_0_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_2_3_io_inputs_child_2_0_Data_flit = topMesh_3_3_io_outputs_child_0_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_2_3_io_inputs_parent_0_HS_Req = io_local_inputs_14_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_3_io_inputs_parent_0_Data_flit = io_local_inputs_14_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_3_io_inputs_parent_1_HS_Req = io_local_inputs_14_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_3_io_inputs_parent_1_Data_flit = io_local_inputs_14_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_3_io_inputs_parent_2_HS_Req = io_local_inputs_14_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_3_io_inputs_parent_2_Data_flit = io_local_inputs_14_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_3_io_inputs_parent_3_HS_Req = io_local_inputs_14_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_3_io_inputs_parent_3_Data_flit = io_local_inputs_14_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_2_3_io_outputs_child_0_0_HS_Ack = topMesh_1_3_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_2_3_io_outputs_child_1_0_HS_Ack = topMesh_2_2_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_2_3_io_outputs_child_2_0_HS_Ack = topMesh_3_3_io_inputs_child_0_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_2_3_io_outputs_parent_0_HS_Ack = io_local_outputs_14_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_3_io_outputs_parent_1_HS_Ack = io_local_outputs_14_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_3_io_outputs_parent_2_HS_Ack = io_local_outputs_14_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_2_3_io_outputs_parent_3_HS_Ack = io_local_outputs_14_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_0_clock = clock;
  assign topMesh_3_0_reset = reset;
  assign topMesh_3_0_io_inputs_child_0_0_HS_Req = topMesh_2_0_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_3_0_io_inputs_child_0_0_Data_flit = topMesh_2_0_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_3_0_io_inputs_child_3_0_HS_Req = topMesh_3_1_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_3_0_io_inputs_child_3_0_Data_flit = topMesh_3_1_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_3_0_io_inputs_parent_0_HS_Req = io_local_inputs_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_0_io_inputs_parent_0_Data_flit = io_local_inputs_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_0_io_inputs_parent_1_HS_Req = io_local_inputs_3_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_0_io_inputs_parent_1_Data_flit = io_local_inputs_3_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_0_io_inputs_parent_2_HS_Req = io_local_inputs_3_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_0_io_inputs_parent_2_Data_flit = io_local_inputs_3_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_0_io_inputs_parent_3_HS_Req = io_local_inputs_3_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_0_io_inputs_parent_3_Data_flit = io_local_inputs_3_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_0_io_outputs_child_0_0_HS_Ack = topMesh_2_0_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_3_0_io_outputs_child_3_0_HS_Ack = topMesh_3_1_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_3_0_io_outputs_parent_0_HS_Ack = io_local_outputs_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_0_io_outputs_parent_1_HS_Ack = io_local_outputs_3_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_0_io_outputs_parent_2_HS_Ack = io_local_outputs_3_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_0_io_outputs_parent_3_HS_Ack = io_local_outputs_3_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_1_clock = clock;
  assign topMesh_3_1_reset = reset;
  assign topMesh_3_1_io_inputs_child_0_0_HS_Req = topMesh_2_1_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_3_1_io_inputs_child_0_0_Data_flit = topMesh_2_1_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_3_1_io_inputs_child_1_0_HS_Req = topMesh_3_0_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_3_1_io_inputs_child_1_0_Data_flit = topMesh_3_0_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_3_1_io_inputs_child_3_0_HS_Req = topMesh_3_2_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_3_1_io_inputs_child_3_0_Data_flit = topMesh_3_2_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_3_1_io_inputs_parent_0_HS_Req = io_local_inputs_7_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_1_io_inputs_parent_0_Data_flit = io_local_inputs_7_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_1_io_inputs_parent_1_HS_Req = io_local_inputs_7_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_1_io_inputs_parent_1_Data_flit = io_local_inputs_7_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_1_io_inputs_parent_2_HS_Req = io_local_inputs_7_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_1_io_inputs_parent_2_Data_flit = io_local_inputs_7_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_1_io_inputs_parent_3_HS_Req = io_local_inputs_7_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_1_io_inputs_parent_3_Data_flit = io_local_inputs_7_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_1_io_outputs_child_0_0_HS_Ack = topMesh_2_1_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_3_1_io_outputs_child_1_0_HS_Ack = topMesh_3_0_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_3_1_io_outputs_child_3_0_HS_Ack = topMesh_3_2_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_3_1_io_outputs_parent_0_HS_Ack = io_local_outputs_7_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_1_io_outputs_parent_1_HS_Ack = io_local_outputs_7_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_1_io_outputs_parent_2_HS_Ack = io_local_outputs_7_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_1_io_outputs_parent_3_HS_Ack = io_local_outputs_7_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_2_clock = clock;
  assign topMesh_3_2_reset = reset;
  assign topMesh_3_2_io_inputs_child_0_0_HS_Req = topMesh_2_2_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_3_2_io_inputs_child_0_0_Data_flit = topMesh_2_2_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_3_2_io_inputs_child_1_0_HS_Req = topMesh_3_1_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_3_2_io_inputs_child_1_0_Data_flit = topMesh_3_1_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_3_2_io_inputs_child_3_0_HS_Req = topMesh_3_3_io_outputs_child_1_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_3_2_io_inputs_child_3_0_Data_flit = topMesh_3_3_io_outputs_child_1_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_3_2_io_inputs_parent_0_HS_Req = io_local_inputs_11_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_2_io_inputs_parent_0_Data_flit = io_local_inputs_11_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_2_io_inputs_parent_1_HS_Req = io_local_inputs_11_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_2_io_inputs_parent_1_Data_flit = io_local_inputs_11_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_2_io_inputs_parent_2_HS_Req = io_local_inputs_11_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_2_io_inputs_parent_2_Data_flit = io_local_inputs_11_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_2_io_inputs_parent_3_HS_Req = io_local_inputs_11_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_2_io_inputs_parent_3_Data_flit = io_local_inputs_11_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_2_io_outputs_child_0_0_HS_Ack = topMesh_2_2_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_3_2_io_outputs_child_1_0_HS_Ack = topMesh_3_1_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_3_2_io_outputs_child_3_0_HS_Ack = topMesh_3_3_io_inputs_child_1_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_3_2_io_outputs_parent_0_HS_Ack = io_local_outputs_11_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_2_io_outputs_parent_1_HS_Ack = io_local_outputs_11_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_2_io_outputs_parent_2_HS_Ack = io_local_outputs_11_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_2_io_outputs_parent_3_HS_Ack = io_local_outputs_11_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_3_clock = clock;
  assign topMesh_3_3_reset = reset;
  assign topMesh_3_3_io_inputs_child_0_0_HS_Req = topMesh_2_3_io_outputs_child_2_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_3_3_io_inputs_child_0_0_Data_flit = topMesh_2_3_io_outputs_child_2_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 77:42]
  assign topMesh_3_3_io_inputs_child_1_0_HS_Req = topMesh_3_2_io_outputs_child_3_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_3_3_io_inputs_child_1_0_Data_flit = topMesh_3_2_io_outputs_child_3_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 89:42]
  assign topMesh_3_3_io_inputs_parent_0_HS_Req = io_local_inputs_15_0_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_3_io_inputs_parent_0_Data_flit = io_local_inputs_15_0_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_3_io_inputs_parent_1_HS_Req = io_local_inputs_15_1_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_3_io_inputs_parent_1_Data_flit = io_local_inputs_15_1_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_3_io_inputs_parent_2_HS_Req = io_local_inputs_15_2_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_3_io_inputs_parent_2_Data_flit = io_local_inputs_15_2_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_3_io_inputs_parent_3_HS_Req = io_local_inputs_15_3_HS_Req; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_3_io_inputs_parent_3_Data_flit = io_local_inputs_15_3_Data_flit; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 71:37]
  assign topMesh_3_3_io_outputs_child_0_0_HS_Ack = topMesh_2_3_io_inputs_child_2_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 83:42]
  assign topMesh_3_3_io_outputs_child_1_0_HS_Ack = topMesh_3_2_io_inputs_child_3_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 95:42]
  assign topMesh_3_3_io_outputs_parent_0_HS_Ack = io_local_outputs_15_0_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_3_io_outputs_parent_1_HS_Ack = io_local_outputs_15_1_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_3_io_outputs_parent_2_HS_Ack = io_local_outputs_15_2_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
  assign topMesh_3_3_io_outputs_parent_3_HS_Ack = io_local_outputs_15_3_HS_Ack; // @[\\src\\main\\scala\\NoC\\CMR\\CMRTopMesh.scala 72:38]
endmodule
