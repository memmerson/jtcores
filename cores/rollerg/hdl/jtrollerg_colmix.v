/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-10-2026 */

module jtrollerg_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             lhbl,
    input             lvbl,

    input      [10:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    input             cpu_we,
    output     [ 7:0] cpu_din,

    input      [ 7:0] psac_pxl,
    input             psac_blnk_n,
    input      [ 8:0] obj_pxl,
    input             obj_shd,

    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue
);

wire [ 7:0] pal_dout;
wire [10:0] pal_addr;
wire        obj_blnk_n, obj_over;
reg  [ 9:0] pxl;
reg  [15:0] pxl_aux;
reg  [23:0] bgr;
reg         pal_half, shad, shl;

assign obj_blnk_n = obj_pxl[3:0]!=0;
assign obj_over   = obj_pxl[8] | ~psac_blnk_n;
assign pal_addr   = { pxl, pal_half };
assign {blue,green,red} = (lvbl & lhbl) ? bgr : 24'd0;

always @* begin
    pxl  = obj_blnk_n && obj_over ? { 2'b01, obj_pxl[7:0] } :
           psac_blnk_n            ? { 4'd0,  psac_pxl[5:0] } : 10'h100;
    shad = obj_shd & ~obj_blnk_n & obj_over;
end

function [23:0] dim( input [14:0] cin, input shade );
    dim = !shade ? { cin[14:10], cin[14:12],
                     cin[ 9: 5], cin[ 9: 7],
                     cin[ 4: 0], cin[ 4: 2] } :
                   { 1'b0, cin[14:10], cin[14:13],
                     1'b0, cin[ 9: 5], cin[ 9: 8],
                     1'b0, cin[ 4: 0], cin[ 4: 3] };
endfunction

always @(posedge clk) begin
    if( rst ) begin
        pal_half <= 0;
        bgr      <= 0;
        shl      <= 0;
        pxl_aux  <= 0;
    end else begin
        pxl_aux <= { pxl_aux[7:0], pal_dout };
        if( pxl_cen ) begin
            shl      <= shad;
            bgr      <= dim( pxl_aux[14:0], shl );
            pal_half <= 0;
        end else
            pal_half <= ~pal_half;
    end
end

jtframe_dual_ram #(.AW(11),.SIMFILE("pal.bin")) u_ram(
    .clk0   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr  ),
    .we0    ( cpu_we    ),
    .q0     ( cpu_din   ),

    .clk1   ( clk       ),
    .data1  ( 8'd0      ),
    .addr1  ( pal_addr  ),
    .we1    ( 1'b0      ),
    .q1     ( pal_dout  )
);

endmodule
