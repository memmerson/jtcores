/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-10-2026 */

module jtrollerg_sound(
    input           rst,
    input           clk,
    input           cen_fm,

    input           snd_irq,
    input   [ 7:0]  main_dout,
    output  [ 7:0]  main_din,
    input           main_addr,
    input           main_rnw,

    output   [14:0] rom_addr,
    output reg      rom_cs,
    input    [ 7:0] rom_data,
    input           rom_ok,

    output   [20:0] pcma_addr,
    input    [ 7:0] pcma_dout,
    output          pcma_cs,

    output   [20:0] pcmb_addr,
    input    [ 7:0] pcmb_dout,
    output          pcmb_cs,

    output   [20:0] pcmc_addr,
    input    [ 7:0] pcmc_dout,
    output          pcmc_cs,

    output   [20:0] pcmd_addr,
    input    [ 7:0] pcmd_dout,
    output          pcmd_cs,

    output signed [15:0] fm,
    output signed [15:0] pcm_l, pcm_r,

    input    [ 5:0] snd_en,
    input    [ 7:0] debug_bus
);
`ifndef NOSOUND
wire        [ 7:0]  cpu_dout, ram_dout, pcm_dout, fm_dout;
wire        [15:0]  A;
reg         [ 7:0]  cpu_din;
reg         [ 5:0]  sh_cnt;
wire                mreq_n, rd_n, wr_n, rfsh_n, nmi_n, sh1;
reg                 ram_cs, fm_cs, pcm_cs, nmi_clr, mem_acc;

assign rom_addr = A[14:0];
assign sh1      = sh_cnt[5:4]==0;

always @(*) begin
    mem_acc  = !mreq_n && rfsh_n;
    rom_cs   = mem_acc && !A[15];
    ram_cs   = mem_acc && A[15:13]==4;
    pcm_cs   = mem_acc && A[15:13]==5;
    fm_cs    = mem_acc && A[15:13]==6;
    nmi_clr  = mem_acc && A[15:13]==7 && !wr_n;
end

always @(*) begin
    case(1'b1)
        rom_cs:  cpu_din = rom_data;
        ram_cs:  cpu_din = ram_dout;
        pcm_cs:  cpu_din = pcm_dout;
        fm_cs:   cpu_din = fm_dout;
        default: cpu_din = 8'hff;
    endcase
end

always @(posedge clk) if(cen_fm) sh_cnt <= sh_cnt+1'd1;

jtframe_edge #(.QSET(0)) u_nmi (
    .rst    ( 1'b0      ),
    .clk    ( clk       ),
    .edgeof ( rst | sh1 ),
    .clr    ( nmi_clr   ),
    .q      ( nmi_n     )
);

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .cpu_cen    (           ),
    .int_n      ( ~snd_irq  ),
    .nmi_n      ( nmi_n     ),
    .busrq_n    ( 1'b1      ),
    .m1_n       (           ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     (           ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     (           ),
    .busak_n    (           ),
    .A          ( A         ),
    .cpu_din    ( cpu_din   ),
    .cpu_dout   ( cpu_dout  ),
    .ram_dout   ( ram_dout  ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);

jtopl2 u_opl(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .addr       ( A[0]      ),
    .din        ( cpu_dout  ),
    .dout       ( fm_dout   ),
    .cs_n       ( ~fm_cs    ),
    .wr_n       ( wr_n      ),
    .irq_n      (           ),
    .snd        ( fm        ),
    .sample     (           )
);

jt053260 u_pcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),

    .ma0        ( main_addr ),
    .mrdnw      ( main_rnw  ),
    .mcs        ( 1'b1      ),
    .mdin       ( main_din  ),
    .mdout      ( main_dout ),

    .addr       ( A[5:0]    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .cs         ( pcm_cs    ),
    .dout       ( pcm_dout  ),
    .din        ( cpu_dout  ),

    .roma_addr  ( pcma_addr ),
    .roma_data  ( pcma_dout ),
    .roma_cs    ( pcma_cs   ),

    .romb_addr  ( pcmb_addr ),
    .romb_data  ( pcmb_dout ),
    .romb_cs    ( pcmb_cs   ),

    .romc_addr  ( pcmc_addr ),
    .romc_data  ( pcmc_dout ),
    .romc_cs    ( pcmc_cs   ),

    .romd_addr  ( pcmd_addr ),
    .romd_data  ( pcmd_dout ),
    .romd_cs    ( pcmd_cs   ),

    .ch_en      ( {1'b0,snd_en[4:1]} ),
    .aux_l      ( 16'd0     ),
    .aux_r      ( 16'd0     ),
    .snd_l      ( pcm_l     ),
    .snd_r      ( pcm_r     ),
    .tim2       (           ),
    .sample     (           )
);
`else
initial rom_cs   = 0;
assign  pcma_cs  = 0, pcmb_cs=0, pcmc_cs=0, pcmd_cs=0;
assign  pcma_addr= 0, pcmb_addr=0, pcmc_addr=0, pcmd_addr=0;
assign  rom_addr = 0;
assign  fm       = 0;
assign  pcm_l    = 0;
assign  pcm_r    = 0;
assign  main_din = 0;
`endif
endmodule
