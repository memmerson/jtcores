/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-9-2026 */

// Sprite table scan. The three tables sit at +0x780, +0xf80 and +0x1780,
// the same layout as Pac-Land. See draw_sprites in skykid.cpp
module jtskykid_objscan(
    input             clk, hs, blankn,
    input             flip, rot,
    input      [ 8:0] vrender,

    output reg [ 8:0] code,
    output reg        hsize, vsize, hmsb,
    output reg [ 4:0] ysub,
    output reg [ 5:0] pal,
    output reg [ 8:0] hpos,
    output reg        hflip, vflip,

    output     [12:1] ram_addr,
    input      [15:0] ram_dout,

    input             dr_busy,
    output            dr_draw,

    input      [ 7:0] debug_bus
);

localparam [8:0] XOS=9'h1fa;    // -6, verified against MAME
localparam [7:0] YOS=8'd24;     // verified against MAME
// rot mirrors the positions on screen, see the rotated set in mame2mra.toml
localparam [8:0] XROT=9'd418;
localparam [7:0] YROT=8'd2;
localparam    HLARGE=1'b1;

reg  [7:0] y;
reg  [8:0] ydiff;
wire [5:0] objcnt;
wire [8:0] vlatch;
wire [7:0] raw_addr;
wire [1:0] st;
reg  [4:0] nx_ysub;
reg        inzone;
wire       draw_step, hsub, cen, hcnt_nx;

assign draw_step = st==3;
assign objcnt    = raw_addr[2+:6];

// sprite RAM starts at 0x4800, so the tables are at word 0x7C0 + st*0x400
assign ram_addr[12:11] = st[1:0] + 2'd1;
assign ram_addr[10: 7] = 4'b1111;
assign ram_addr[ 6: 1] = objcnt;

always @* begin
    ydiff = vlatch[8:0] + y;
    case( vsize )
        0: inzone = ydiff[8:4]==0; //  16
        1: inzone = ydiff[8:5]==0; //  32
    endcase
    nx_ysub = ydiff[4:0];
end

always @(posedge clk) if(cen) begin
    case(st)
        0: { pal, code[7:0] } <= ram_dout[13:0];
        1: { hpos[7:0], y }   <= ram_dout;
        2: begin
            // flip toggles each sprite's own flips, positions are left alone.
            // rot mirrors the positions and toggles the flips again
            { code[8], vsize, hsize } <= {ram_dout[7],ram_dout[3:2]};
            { vflip, hflip } <= ram_dout[1:0]^{2{flip^rot}};
            y    <= rot ? YROT + (ram_dout[3] ? 8'd32 : 8'd16) - (y + YOS + (ram_dout[3] ? 8'd16 : 8'd0))
                        :                                          y + YOS + (ram_dout[3] ? 8'd16 : 8'd0);
            hpos <= rot ? XROT - ({ram_dout[8],hpos[7:0]} + XOS) - (ram_dout[2] ? 9'd32 : 9'd16)
                        :         {ram_dout[8],hpos[7:0]} + XOS;
        end
        3: if(!dr_busy && !dr_draw && inzone) begin
            ysub <= nx_ysub;
            hmsb <= 0;
            if( hsize && !hcnt_nx ) begin // half of a 32 pixel object
                hpos <= hpos + 9'h10;
                hmsb <= ~hmsb;
            end
        end
    endcase
end

jtframe_objscan #(.OBJW(6),.STW(2),.HREPW(1),.HOLD_WHILE_DRBUSY(1))
u_scan(
    .clk        ( clk       ),
    .cen        ( cen       ),
    .hs         ( hs        ),
    .blankn     ( blankn    ),
    .vrender    ( vrender   ),
    .vlatch     ( vlatch    ),

    .draw_step  ( draw_step ),
    .skip       ( 1'b0      ),
    .inzone     ( inzone    ),

    .hsize      ( hsize     ),
    .hsub       ( hsub      ),
    .haddr      (           ),
    .hflip      ( hflip     ),
    .hcnt_nx    ( hcnt_nx   ),

    .dr_busy    ( dr_busy   ),
    .dr_draw    ( dr_draw   ),

    .addr       ( raw_addr  ),
    .step       ( st        )
);

endmodule
