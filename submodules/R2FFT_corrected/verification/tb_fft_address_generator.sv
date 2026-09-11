`timescale 1ns/1ps

module tb_fft_address_generator;
   localparam integer FFT_N = 10;
   localparam integer STAGE_COUNT_BW = 4;

   logic clk = 1'b0;
   logic rst = 1'b1;
   logic run = 1'b0;
   logic [STAGE_COUNT_BW-1:0] stage_count = '0;
   wire done;
   wire act;
   wire [1:0] ctrl;
   wire even_odd;
   wire [FFT_N-2:0] mem_addr;
   wire [FFT_N-2:0] twiddle_addr;

   always #5 clk = ~clk;

   fftAddressGenerator #(
      .FFT_N(FFT_N),
      .STAGE_COUNT_BW(STAGE_COUNT_BW)
   ) dut (
      .clk(clk), .rst(rst), .stageCount(stage_count), .run(run), .done(done),
      .act(act), .ctrl(ctrl), .evenOdd(even_odd), .MemAddr(mem_addr),
      .twiddleFactorAddr(twiddle_addr)
   );

   function automatic [FFT_N-2:0] expected_mem(input integer count, input integer stage);
      integer lower_mask;
      integer higher_mask;
      integer result;
      begin
         if (stage < 2) begin
            result = count;
         end else begin
            lower_mask = (1 << (stage-1)) - 1;
            higher_mask = ~((1 << stage) - 1);
            result = (lower_mask & (count >> 1)) |
                     ((count & 1) << (stage-1)) |
                     (higher_mask & count);
         end
         expected_mem = result[FFT_N-2:0];
      end
   endfunction

   function automatic [FFT_N-2:0] expected_twiddle(input integer count, input integer stage);
      integer value;
      integer bit_index;
      begin
         value = count >> stage;
         expected_twiddle = '0;
         for (bit_index = 0; bit_index < FFT_N-1; bit_index = bit_index + 1)
           expected_twiddle[bit_index] = value[FFT_N-2-bit_index];
      end
   endfunction

   task automatic check_stage(input integer stage);
      integer count;
      begin
         stage_count = stage[STAGE_COUNT_BW-1:0];
         run = 1'b0;
         repeat (2) @(posedge clk);
         run = 1'b1;
         for (count = 1; count < (1 << (FFT_N-1)); count = count + 1) begin
            @(posedge clk);
            #1;
            assert (act) else $fatal(1, "act dropped at stage=%0d count=%0d", stage, count);
            assert (mem_addr == expected_mem(count, stage))
              else $fatal(1, "MemAddr mismatch stage=%0d count=%0d got=%0d exp=%0d", stage, count, mem_addr, expected_mem(count, stage));
            assert (twiddle_addr == expected_twiddle(count, stage))
              else $fatal(1, "twiddle mismatch stage=%0d count=%0d got=%0d exp=%0d", stage, count, twiddle_addr, expected_twiddle(count, stage));
         end
         run = 1'b0;
         @(posedge clk);
         #1;
         assert (done) else $fatal(1, "done missing at stage=%0d", stage);
      end
   endtask

   initial begin
      repeat (2) @(posedge clk);
      rst = 1'b0;
      for (integer stage = 0; stage < FFT_N; stage = stage + 1)
        check_stage(stage);
      $display("tb_fft_address_generator PASSED");
      $finish;
   end
endmodule
