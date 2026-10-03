/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-10-2026 */

module jtrollerg_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] cpu_addr;
wire [ 8:0] vdump;
wire [ 7:0] cpu_dout, snd2main, pal_dout, obj_dout, psac_dout, st_main;
wire        cpu_cen, cpu_we, snd_irq, snd_cs_main, rmrd, wrap, psac_cpu_ok,
            pal_cs, objram_cs, objreg_cs, psac_vr_cs, psacreg_cs;

assign debug_view = st_main;
assign ram_din    = cpu_dout;
assign dip_flip   = ~dipsw[16];

jtrollerg_main u_main(
    .rst            ( rst48         ),
    .clk            ( clk48         ),
    .cen_ref        ( cen24         ),
    .cpu_cen        ( cpu_cen       ),

    .cpu_dout       ( cpu_dout      ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_we         ( cpu_we        ),

    .rom_addr       ( main_addr     ),
    .rom_data       ( main_data     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),

    .ram_we         ( ram_we        ),
    .ram_dout       ( ram_dout      ),

    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( service       ),

    .LVBL           ( LVBL          ),
    .vdump          ( vdump         ),
    .pal_dout       ( pal_dout      ),
    .obj_dout       ( obj_dout      ),
    .psac_dout      ( psac_dout     ),
    .psac_data      ( psac_data     ),
    .psac_ok        ( psac_cpu_ok   ),
    .pal_cs         ( pal_cs        ),
    .objram_cs      ( objram_cs     ),
    .objreg_cs      ( objreg_cs     ),
    .psac_cs        ( psac_vr_cs    ),
    .psacreg_cs     ( psacreg_cs    ),
    .rmrd           ( rmrd          ),
    .wrap           ( wrap          ),

    .snd_irq        ( snd_irq       ),
    .snd_cs         ( snd_cs_main   ),
    .snd2main       ( snd2main      ),

    .dip_test       ( dip_test      ),
    .dip_pause      ( dip_pause     ),
    .dipsw          ( dipsw[23:0]   ),

    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_main       )
);

jtrollerg_sound u_sound(
    .rst        ( rst48         ),
    .clk        ( clk48         ),
    .cen_fm     ( cen_fm        ),

    .snd_irq    ( snd_irq       ),
    .main_dout  ( cpu_dout      ),
    .main_din   ( snd2main      ),
    .main_addr  ( cpu_addr[0]   ),
    .main_rnw   ( ~(snd_cs_main & cpu_we) ),

    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),

    .pcma_addr  ( pcma_addr     ),
    .pcma_dout  ( pcma_data     ),
    .pcma_cs    ( pcma_cs       ),

    .pcmb_addr  ( pcmb_addr     ),
    .pcmb_dout  ( pcmb_data     ),
    .pcmb_cs    ( pcmb_cs       ),

    .pcmc_addr  ( pcmc_addr     ),
    .pcmc_dout  ( pcmc_data     ),
    .pcmc_cs    ( pcmc_cs       ),

    .pcmd_addr  ( pcmd_addr     ),
    .pcmd_dout  ( pcmd_data     ),
    .pcmd_cs    ( pcmd_cs       ),

    .fm         ( fm            ),
    .pcm_l      ( pcm_l         ),
    .pcm_r      ( pcm_r         ),

    .snd_en     ( snd_en        ),
    .debug_bus  ( debug_bus     )
);

jtrollerg_video u_video(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),
    .cen24          ( cen24         ),

    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .vdump          ( vdump         ),

    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_we         ( cpu_we        ),
    .pal_cs         ( pal_cs        ),
    .objram_cs      ( objram_cs     ),
    .objreg_cs      ( objreg_cs     ),
    .psac_cs        ( psac_vr_cs    ),
    .psacreg_cs     ( psacreg_cs    ),
    .wrap           ( wrap          ),
    .pal_dout       ( pal_dout      ),
    .obj_dout       ( obj_dout      ),
    .psac_dout      ( psac_dout     ),
    .psac_ok        ( psac_cpu_ok   ),

    .psac_addr      ( psac_addr     ),
    .psac_cs_rom    ( psac_cs       ),
    .psac_rom_ok    ( psac_ok       ),
    .psac_data      ( psac_data     ),

    .lyro_addr      ( lyro_addr     ),
    .lyro_cs        ( lyro_cs       ),
    .lyro_ok        ( lyro_ok       ),
    .lyro_data      ( lyro_data     ),

    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),

    .gfx_en         ( gfx_en        ),
    .debug_bus      ( debug_bus     )
);

endmodule
