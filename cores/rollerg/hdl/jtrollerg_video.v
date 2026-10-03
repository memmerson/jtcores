/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-10-2026 */

module jtrollerg_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,
    input             cen24,

    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,
    output     [ 8:0] vdump,

    // CPU interface
    input      [15:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    input             cpu_we,
    input             pal_cs, objram_cs, objreg_cs, psac_cs, psacreg_cs,
    input             wrap,
    output     [ 7:0] pal_dout, obj_dout, psac_dout,
    output            psac_ok,

    // SDRAM
    output     [18:0] psac_addr,
    output            psac_cs_rom,
    input             psac_rom_ok,
    input      [ 7:0] psac_data,

    output     [20:2] lyro_addr,
    output            lyro_cs,
    input             lyro_ok,
    input      [31:0] lyro_data,

    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus
);

wire [ 8:0] hdump, vrender, vrender1, obj_pxl, obj_h;
wire [ 7:0] psac_pxl;
wire [15:0] obj16_dout;
wire [ 4:0] nc;
wire        psac_blnk_n, obj_shd, nco;

assign obj_h    = hdump+9'd3;
assign obj_dout = ~cpu_addr[0] ? obj16_dout[15:8] : obj16_dout[7:0];

jtframe_vtimer #(
    .HCNT_START ( 9'h020    ),
    .HCNT_END   ( 9'h19F    ),
    .HB_START   ( 9'h199     ),
    .HB_END     ( 9'h079     ),
    .HS_START   ( 9'h034    ),

    .V_START    ( 9'h0F8    ),
    .VB_START   ( 9'h1EF    ),
    .VB_END     ( 9'h10F    ),
    .VS_START   ( 9'h1FF    ),
    .VS_END     ( 9'h0FF    ),
    .VCNT_END   ( 9'h1FF    )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .HS         ( hs        ),
    .VS         ( vs        )
);

jt051316 #(.BPP(4),.RD_DLY(9'h020),.VB_END(9'h110)) u_psac(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .cen24      ( cen24     ),
    .vs         ( vs        ),
    .hs         ( hs        ),
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    .cpu_addr   (cpu_addr[10:0]),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( cpu_we    ),
    .cpu_din    ( psac_dout ),
    .cpu_ok     ( psac_ok   ),
    .vr_cs      ( psac_cs   ),
    .io_cs      ( psacreg_cs),
    .rvo        ( 1'b0      ),
    .wrap       ( wrap      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),

    .rom_ok     ( psac_rom_ok ),
    .rom_cs     ( psac_cs_rom ),
    .rom_data   ( psac_data ),
    .rom_addr   ({nc,psac_addr}),

    .pxl        ( psac_pxl  ),
    .blnk_n     ( psac_blnk_n ),

    .ioctl_addr ( 11'd0     ),
    .ioctl_ram  ( 1'b0      ),
    .ioctl_din  (           ),
    .mmr_dump   (           )
);

jtriders_obj #(
    .RAMW         ( 12      ),
    .HFLIP_OFFSET ( 10'd134 ),
    .SHADOW       ( 1       )
) u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .lgtnfght   ( 1'b0      ),

    .hs         ( hs        ),
    .lvbl       ( lvbl      ),
    .hdump      ( obj_h     ),
    .vdump      ( vdump     ),

    .ram_cs     ( objram_cs ),
    .ram_addr   ({2'd0,cpu_addr[10:1]}),
    .ram_din    ({2{cpu_dout}}),
    .ram_we     ( {~cpu_addr[0],cpu_addr[0]}&{2{cpu_we}} ),
    .cpu_din    ( obj16_dout),

    .reg_cs     ( objreg_cs ),
    .mmr_addr   (cpu_addr[3:0]),
    .mmr_din    ({8'd0,cpu_dout}),
    .mmr_we     ( cpu_we    ),
    .mmr_dsn    ({1'b1,cpu_addr[0]}),

    .dma_bsy    (           ),

    .rom_data   ( lyro_data ),
    .rom_ok     ( lyro_ok   ),
    .rom_cs     ( lyro_cs   ),
    .rom_addr   ({nco,lyro_addr}),
    .objcha_n   ( 1'b1      ),

    .shd        ( obj_shd   ),
    .prio       (           ),
    .pxl        ( obj_pxl   ),

    .ioctl_ram  ( 1'b0      ),
    .ioctl_addr ( 14'd0     ),
    .dump_ram   (           ),
    .dump_reg   (           ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

jtrollerg_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    .cpu_addr   (cpu_addr[10:0]),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( cpu_we & pal_cs ),
    .cpu_din    ( pal_dout  ),

    .psac_pxl   ( psac_pxl  ),
    .psac_blnk_n( psac_blnk_n & gfx_en[1] ),
    .obj_pxl    ( obj_pxl   ),
    .obj_shd    ( obj_shd   ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule
