// Observation layer (from keplertech_demo/sec/observe.vh, plus d_hiz).
// d_out is observed only while d_oe = 1: c4004_top drives the D pads with
// `D = d_oe ? d_out : 'z`, so d_out has no effect on the pins otherwise.
// `MASK_X1`: bus not observed during X1 (not used unless a run says so).
`ifdef MASK_X1
wire obs_mask = env_ph_valid & (env_ph == 3'd5);
`else
wire obs_mask = 1'b0;
`endif
assign bus_oe  = oe_raw  & ~obs_mask;
assign bus_hiz = hiz_raw | obs_mask;
assign bus_d   = bus_oe ? dout_raw : 4'd0;
