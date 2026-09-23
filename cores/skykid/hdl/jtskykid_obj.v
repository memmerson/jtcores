/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-9-2026 */

// 3bpp sprites. Planes 1 and 2 come packed as nibble pairs on the obj bus,
// the third plane on obj2: high nibble for codes 128-255, low nibble below
// that, and no third plane at all from code 256 up. See init_skykid.
module jtskykid_obj(
    input             rst,
    input             clk, pxl_cen, hs, lvbl, flip, rot,
    input      [ 8:0] hdump, vdump,

    // Look-up table
    output     [12:1] ram_addr,
    input      [15:0] ram_dout,
    // Palette PROM
    output     [ 8:0] pal_addr,
    input      [ 7:0] pal_data,

    output            rom_cs,
    output     [14:1] rom_addr,
    input      [15:0] rom_data,
    input             rom_ok,
    output            rom2_cs,
    output     [13:1] rom2_addr,
    input      [15:0] rom2_data,

    output     [ 7:0] pxl,

    input      [ 7:0] debug_bus
);

wire [31:0] sorted;
wire [ 8:0] addr_hi;
wire [ 3:0] addr_v;
wire        addr_h, hmsb;
wire        hflip, vflip, dr_busy, dr_draw;
wire [ 8:0] code, hpos;
wire [ 5:0] pal;
wire [ 4:0] ysub;
wire        vsize, hsize;
reg         blankn;

wire [ 8:0] code_eff = { addr_hi[8:2],
    vsize ? ysub[4]^vflip : addr_hi[1],     // V16
    hsize ?    hmsb^hflip : addr_hi[0] };   // H16

// the sort makes the two bytes of a row adjacent, see gfx_sort in mem.yaml
assign rom_addr  = { code_eff, addr_v[3], addr_h, addr_v[2:0] };
assign rom2_addr = rom_addr[13:1];
assign rom2_cs   = rom_cs;

// {plane3, plane2, plane1, plane0}, 8 pixels each. jtframe_draw takes the
// leftmost pixel from bit 0 and shifts right, so the nibbles are reversed here
wire [7:0] lo = rom_data [ 7:0], hi = rom_data [15:8];
wire [7:0] l2 = rom2_data[ 7:0], h2 = rom2_data[15:8];
wire [7:0] p0 = { hi[0],hi[1],hi[2],hi[3], lo[0],lo[1],lo[2],lo[3] };
wire [7:0] p1 = { hi[4],hi[5],hi[6],hi[7], lo[4],lo[5],lo[6],lo[7] };
wire [7:0] p2 = code_eff[8] ? 8'd0 :
                code_eff[7] ? { h2[4],h2[5],h2[6],h2[7], l2[4],l2[5],l2[6],l2[7] }
                            : { h2[0],h2[1],h2[2],h2[3], l2[0],l2[1],l2[2],l2[3] };
assign sorted = { 8'd0, p2, p1, p0 };

always @(posedge clk) blankn <= !(vdump>9'hf8 && vdump<9'h11d);

jtskykid_objscan u_scan(
    .clk        ( clk       ),
    .hs         ( hs        ),
    .blankn     ( blankn    ),
    .flip       ( flip      ),
    .rot        ( rot       ),
    .vrender    ( vdump     ),

    .code       ( code      ),
    .hsize      ( hsize     ),
    .vsize      ( vsize     ),
    .ysub       ( ysub      ),
    .pal        ( pal       ),
    .hpos       ( hpos      ),
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .hmsb       ( hmsb      ),

    .ram_addr   ( ram_addr  ),
    .ram_dout   ( ram_dout  ),

    .dr_busy    ( dr_busy   ),
    .dr_draw    ( dr_draw   ),

    .debug_bus  ( debug_bus )
);

// PW is palette width + 4: the module always works with 4bpp pixels,
// so the 3bpp value is padded and bit 3 dropped when indexing the PROM
jtframe_objdraw_gate #(.CW(9),.PW(10),.LATCH(1),
    .HFIX(0),.SWAPH(0),
    .ALPHA(255),
    .ALPHAW(8),
    .BUFDLY(1)
) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( 1'b0      ),      // the board does not mirror positions
    .hdump      ( hdump     ),

    .draw       ( dr_draw   ),
    .busy       ( dr_busy   ),
    .code       ( code      ),
    .xpos       ( hpos      ),
    .ysub       ( ysub[3:0] ),
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ),
    .trunc      ( 2'b0      ),

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( pal       ),

    .buf_pred   ( buf_pred  ),
    .buf_din    ({2'd0,pal_data}),

    .rom_addr   ( {addr_hi,addr_h,addr_v} ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( sorted    ),

    .pxl        ( {nc_pxl,pxl} )
);

wire [ 1:0] nc_pxl;
wire [ 9:0] buf_pred;

assign pal_addr = { buf_pred[9:4], buf_pred[2:0] };

endmodule
