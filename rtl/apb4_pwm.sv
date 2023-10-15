// Copyright (c) 2023 Beijing Institute of Open Source Chip
// timer is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

// verilog_format: off
`define PWM_CTRL 4'b0000 //BASEADDR+0x00
`define PWM_PSCR 4'b0001 //BASEADDR+0x04
`define PWM_CNT  4'b0010 //BASEADDR+0x08
`define PWM_CMP  4'b0011 //BASEADDR+0x0C
`define PWM_CR0  4'b0100 //BASEADDR+0x10
`define PWM_CR1  4'b0101 //BASEADDR+0x14
`define PWM_CR2  4'b0110 //BASEADDR+0x18
`define PWM_CR3  4'b0111 //BASEADDR+0x1C
// verilog_format: on

/* register mapping
 * PWM_CTRL:
 * BITS:   | 16:3 | 2  | 1    | 0     |
 * FIELDS: | RES  | EN | OVIE | OVIF  |
 * PERMS:  | NONE | RW | RW   | RC_W0 |
 * ------------------------------------
 * PWM_PSCR:
 * BITS:   | 16:0 |
 * FIELDS: | PSCR |
 * PERMS:  | W    |
 * ------------------------------------
 * PWM_CNT:
 * BITS:   | 16:0 |
 * FIELDS: | CNT  |
 * PERMS:  | none |
 * ------------------------------------
 * PWM_CMP:
 * BITS:   | 16:0 |
 * FIELDS: | CMP  |
 * PERMS:  | RW   |
*/

// 16bit precision
module apb4_pwm #(
    parameter int DATA_WIDTH = 16
) (
    // verilog_format: off
    apb4_if.slave apb4,
    // verilog_format: on
    output logic [3:0] pwm_o,
    output logic irq_o
);

  logic [3:0] s_apb_addr;
  logic [DATA_WIDTH-1:0] s_pwm_ctrl_d, s_pwm_ctrl_q;
  logic [DATA_WIDTH-1:0] s_pwm_pscr_d, s_pwm_pscr_q;
  logic [DATA_WIDTH-1:0] s_pwm_cnt_d, s_pwm_cnt_q;
  logic [DATA_WIDTH-1:0] s_pwm_cmp_d, s_pwm_cmp_q;
  logic [DATA_WIDTH-1:0] s_pwmcrr0_d, s_pwmcrr0_q;
  logic [DATA_WIDTH-1:0] s_pwmcrr1_d, s_pwmcrr1_q;
  logic [DATA_WIDTH-1:0] s_pwmcrr2_d, s_pwmcrr2_q;
  logic [DATA_WIDTH-1:0] s_pwmcrr3_d, s_pwmcrr3_q;
  logic s_valid, s_ready, s_done, s_tc_clk;
  logic s_apb4_wr_hdshk, s_apb4_rd_hdshk, s_normal_mode;
  logic s_ov_irq;


  assign s_apb_addr      = apb.paddr[5:2];
  assign s_apb4_wr_hdshk = apb.psel && apb.penable && apb.pwrite;
  assign s_apb4_rd_hdshk = apb.psel && apb.penable && (~apb.pwrite);
  assign s_normal_mode   = s_pwm_ctrl_q[2] & s_done;
  assign s_ov_irq        = s_pwm_ctrl_q[1] & s_pwm_ctrl_q[0];
  assign irq_o           = s_ov_irq;

  always_comb begin
    s_pwm_pscr_d = s_pwm_pscr_q;
    if (s_apb4_wr_hdshk && s_apb_addr == `TIM_DIV) begin
      s_pwm_pscr_d = apb4.pwdata[DATA_WIDTH-1:0] < 2 ? 2 : abp4.pwdata;
    end
  end

  dffr #(DATA_WIDTH) u_tim_pscr_dffr (
      .clk_i  (apb4.hclk),
      .rst_n_i(apb4.hresetn),
      .dat_i  (s_pwm_pscr_d),
      .dat_o  (s_pwm_pscr_q)
  );

  assign s_valid = s_apb4_wr_hdshk && s_apb_addr == `PWM_PSCR && s_done;
  clk_int_even_div_simple u_clk_int_even_div_simple (
      .clk_i      (apb4.hclk),
      .rst_n_i    (apb4.hresetn),
      .div_i      (s_pwm_pscr_q),
      .div_valid_i(s_valid),
      .div_ready_o(s_ready),
      .div_done_o (s_done),
      .clk_o      (s_tc_clk)
  );

  always_comb begin
    s_pwm_cnt_d = s_pwm_cnt_q;
    if (s_normal_mode) begin
      if (s_pwm_cnt_q == s_pwm_cmp_q) begin
        s_pwm_cnt_d = '0;
      end else begin
        s_pwm_cnt_d = s_pwm_cnt_q + 1'b1;
      end
    end
  end

  dffr #(DATA_WIDTH) u_tim_cnt_dffr (
      s_tc_clk,
      apb4.hresetn,
      s_pwm_cnt_d,
      s_pwm_cnt_q
  );

  always_comb begin
    s_pwm_ctrl_d = s_pwm_ctrl_q;
    if (s_apb4_wr_hdshk && s_apb_addr == `PWM_CTRL) begin
      s_pwm_ctrl_d = apb4.pwdata[DATA_WIDTH-1:0];
    end else if (s_normal_mode) begin
      if (s_pwm_cnt_q == s_pwm_cmp_q) begin
        s_pwm_ctrl_d[0] = 1'b1;
      end
    end
  end

  dffr #(DATA_WIDTH) u_tim_ctrl_dffr (
      apb4.hclk,
      apb4.hresetn,
      s_pwm_ctrl_d,
      s_pwm_ctrl_q
  );

  assign s_pwm_cmp_d = (s_apb4_wr_hdshk && s_apb_addr == `PWM_CMP) ? apb4.pwdata[DATA_WIDTH-1:0] : s_pwm_cmp_q;
  dffr #(DATA_WIDTH) u_tim_cmp_dffr (
      apb4.hclk,
      apb4.hresetn,
      s_pwm_cmp_d,
      s_pwm_cmp_q
  );

  assign s_pwmcrr0_d = (s_apb4_wr_hdshk && s_apb_addr == `PWM_CR0) ? apb4.pwdata[DATA_WIDTH-1:0] : s_pwmcrr0_q;
  dffr #(DATA_WIDTH) u_tim_crr0_dffr (
      clk_i,
      rst_n_i,
      s_pwmcrr0_d,
      s_pwmcrr0_q
  );

  assign s_pwmcrr1_d = (s_apb4_wr_hdshk && s_apb_addr == `PWM_CR1) ? apb4.pwdata[DATA_WIDTH-1:0] : s_pwmcrr1_q;
  dffr #(DATA_WIDTH) u_tim_crr1_dffr (
      clk_i,
      rst_n_i,
      s_pwmcrr1_d,
      s_pwmcrr1_q
  );

  assign s_pwmcrr2_d = (s_apb4_wr_hdshk && s_apb_addr == `PWM_CR2) ? apb4.pwdata[DATA_WIDTH-1:0] : s_pwmcrr2_q;
  dffr #(DATA_WIDTH) u_tim_crr2_dffr (
      clk_i,
      rst_n_i,
      s_pwmcrr2_d,
      s_pwmcrr2_q
  );

  assign s_pwmcrr3_d = (s_apb4_wr_hdshk && s_apb_addr == `PWM_CR3) ? apb4.pwdata[DATA_WIDTH-1:0] : s_pwmcrr3_q;
  dffr #(DATA_WIDTH) u_tim_crr3_dffr (
      clk_i,
      rst_n_i,
      s_pwmcrr3_d,
      s_pwmcrr3_q
  );

  // NOTE: need to assure the s_pwmcrrx_q less than s_pwmcmp_q
  assign pwm_o[0] = s_pwm_cnt_q > s_pwmcrr0_q;
  assign pwm_o[1] = s_pwm_cnt_q > s_pwmcrr1_q;
  assign pwm_o[2] = s_pwm_cnt_q > s_pwmcrr2_q;
  assign pwm_o[3] = s_pwm_cnt_q > s_pwmcrr3_q;

  always_comb begin
    apb.prdata = '0;
    if (s_apb4_rd_hdshk) begin
      unique case (s_apb_addr)
        `PWM_CTRL: apb.prdata[DATA_WIDTH-1:0] = s_pwm_ctrl_q;
        `PWM_PSCR: apb4.prdata[DATA_WIDTH-1:0] = s_pwm_pscr_q;
        `PWM_CMP:  apb.prdata[DATA_WIDTH-1:0] = s_pwm_cmp_q;
      endcase
    end
  end

  assign apb.pready  = 1'b1;
  assign apb.pslverr = 1'b0;
endmodule
