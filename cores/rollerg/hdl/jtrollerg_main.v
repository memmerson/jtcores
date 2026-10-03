/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-10-2026 */

module jtrollerg_main(
    input               rst,
    input               clk,
    input               cen_ref,
    output              cpu_cen,

    output      [ 7:0]  cpu_dout,
    output      [15:0]  cpu_addr,
    output              cpu_we,

    output reg  [16:0]  rom_addr,
    input       [ 7:0]  rom_data,
    output reg          rom_cs,
    input               rom_ok,
    // RAM
    output              ram_we,
    input       [ 7:0]  ram_dout,
    // cabinet I/O
    input       [ 3:0]  cab_1p,
    input       [ 3:0]  coin,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,
    // video
    input               LVBL,
    input       [ 8:0]  vdump,
    input       [ 7:0]  pal_dout, obj_dout, psac_dout, psac_data,
    input               psac_ok,
    output reg          pal_cs, objram_cs, objreg_cs, psac_cs, psacreg_cs,
    output reg          rmrd, wrap,
    // sound
    output reg          snd_irq,
    output reg          snd_cs,
    input       [ 7:0]  snd2main,
    // DIP switches
    input               dip_test,
    input               dip_pause,
    input       [23:0]  dipsw,
    // Debug
    input       [ 7:0]  debug_bus,
    output reg  [ 7:0]  st_dout
);

wire [ 7:0] lines;
wire [15:0] A, pcbad;
wire        dtack, buserror, irqn;
reg  [ 7:0] cpu_din, port_in;
reg  [ 2:0] bank;
reg         ram_cs, io_cs, latch_cs, port_cs, ccu_cs, irq_ack, berr_l;

assign cpu_addr = A;
assign ram_we   = ram_cs & cpu_we;
assign dtack    = (~rom_cs | rom_ok) & psac_ok;

always @(*) begin
    case( debug_bus[1:0] )
        0: st_dout = lines;
        1: st_dout = { 7'd0, berr_l };
        2: st_dout = pcbad[7:0];
        3: st_dout = pcbad[15:8];
    endcase
end

always @(*) begin
    bank       = lines[2:1]==3 ? {2'd0,lines[0]} : lines[2:0];
    rom_cs     = A[15:14]!=0;
    rom_addr   = A[15] ? {2'b11,A[14:0]} : {bank,A[13:0]};
    if( !rom_cs ) rom_addr[12:0] = A[12:0];
    ram_cs     = A[15:13]==1;
    pal_cs     = A[15:11]==5'b0001_1;
    objram_cs  = A[15:11]==5'b0001_0;
    psac_cs    = A[15:11]==5'b0000_1;
    io_cs      = A[15:10]==0 && A[9:8]==0;
    ccu_cs     = A[15:10]==0 && A[9:8]==1;
    psacreg_cs = A[15:10]==0 && A[9:8]==2;
    objreg_cs  = A[15:10]==0 && A[9:8]==3;
    latch_cs   = io_cs && A[7:4]==1;
    snd_cs     = io_cs && A[7:4]==3;
    snd_irq    = io_cs && A[7:4]==4 && cpu_we;
    port_cs    = io_cs && (A[7:4]==5 || A[7:4]==6);
    irq_ack    = ccu_cs && A[3:0]==4'he && cpu_we;
end

always @* begin
    cpu_din = rom_cs     ? rom_data  :
              ram_cs     ? ram_dout  :
              pal_cs     ? pal_dout  :
              objram_cs  ? obj_dout  :
              psac_cs    ? (rmrd ? psac_data : psac_dout) :
              port_cs    ? port_in   :
              snd_cs     ? snd2main  :
              ccu_cs     ? (A[0] ? vdump[7:0] : {7'd0,vdump[8]}) : 8'h00;
end

always @(posedge clk) begin
    if( rst ) begin
        port_in <= 0;
        rmrd    <= 0;
        wrap    <= 0;
        berr_l  <= 0;
    end else begin
        if( buserror ) berr_l <= 1;
        if( latch_cs && cpu_we ) { wrap, rmrd } <= { cpu_dout[5], cpu_dout[2] };
        case( {A[5],A[1:0]} )
            0: port_in <= { cab_1p[0], joystick1[3:0], joystick1[4], joystick1[5], 1'b1 };
            1: port_in <= { cab_1p[1], joystick2[3:0], joystick2[4], joystick2[5], 1'b1 };
            2: port_in <= { service, 1'b1, coin[0], coin[1], dipsw[19], dip_test, dipsw[17:16] };
            3: port_in <= dipsw[7:0];
            4: port_in <= dipsw[15:8];
            5: port_in <= 8'h7f;
            default: port_in <= 8'hff;
        endcase
    end
end

jtframe_edge #(.QSET(0)) u_irq (
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~LVBL     ),
    .clr    ( irq_ack   ),
    .q      ( irqn      )
);

jtkcpu u_cpu(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen2   ( cen_ref   ),
    .cen_out( cpu_cen   ),

    .halt   ( berr_l    ),
    .dtack  ( dtack     ),
    .nmi_n  ( 1'b1      ),
    .irq_n  ( irqn | ~dip_pause ),
    .firq_n ( 1'b1      ),
    .pcbad  ( pcbad     ),
    .buserror( buserror ),

    .din    ( cpu_din   ),
    .dout   ( cpu_dout  ),
    .addr   ({lines, A} ),
    .we     ( cpu_we    )
);

endmodule
