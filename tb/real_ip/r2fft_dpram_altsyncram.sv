`timescale 1 ps / 1 ps

// Real altsyncram-backed DPRAM wrapper for the 512-point / 18-bit R2FFT flow.
module dpram (
    input         clock,
    input  [35:0] data,
    input  [7:0]  rdaddress,
    input  [7:0]  wraddress,
    input         wren,
    output [35:0] q
);

    wire [35:0] sub_wire0;
    assign q = sub_wire0[35:0];

    altsyncram altsyncram_component (
        .address_a      (wraddress),
        .address_b      (rdaddress),
        .clock0         (clock),
        .data_a         (data),
        .wren_a         (wren),
        .q_b            (sub_wire0),
        .aclr0          (1'b0),
        .aclr1          (1'b0),
        .addressstall_a (1'b0),
        .addressstall_b (1'b0),
        .byteena_a      (1'b1),
        .byteena_b      (1'b1),
        .clock1         (1'b1),
        .clocken0       (1'b1),
        .clocken1       (1'b1),
        .clocken2       (1'b1),
        .clocken3       (1'b1),
        .data_b         ({36{1'b1}}),
        .eccstatus      (),
        .q_a            (),
        .rden_a         (1'b1),
        .rden_b         (1'b1),
        .wren_b         (1'b0)
    );
    defparam
        altsyncram_component.address_aclr_b                 = "NONE",
        altsyncram_component.address_reg_b                  = "CLOCK0",
        altsyncram_component.clock_enable_input_a           = "BYPASS",
        altsyncram_component.clock_enable_input_b           = "BYPASS",
        altsyncram_component.clock_enable_output_b          = "BYPASS",
        altsyncram_component.intended_device_family         = "Cyclone V",
        altsyncram_component.lpm_type                       = "altsyncram",
        altsyncram_component.numwords_a                     = 256,
        altsyncram_component.numwords_b                     = 256,
        altsyncram_component.operation_mode                 = "DUAL_PORT",
        altsyncram_component.outdata_aclr_b                 = "NONE",
        altsyncram_component.outdata_reg_b                  = "UNREGISTERED",
        altsyncram_component.power_up_uninitialized         = "FALSE",
        altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
        altsyncram_component.widthad_a                      = 8,
        altsyncram_component.widthad_b                      = 8,
        altsyncram_component.width_a                        = 36,
        altsyncram_component.width_b                        = 36,
        altsyncram_component.width_byteena_a                = 1;

endmodule
