`timescale 1ns / 1ps

/**
 * Module: pucch_xor_matrix_x2
 * Description: Hard-coded XOR matrix for LFSR x2 state transformation.
 * Used for fast-forwarding the scrambling sequence generator.
 */

module pucch_xor_matrix_x2 (
    input  wire [30:0] i_state,
    output wire [30:0] o_state_next
);

    assign o_state_next[0]  = i_state[1] ^ i_state[2] ^ i_state[3] ^ i_state[8] ^ i_state[12] ^ i_state[16] ^ i_state[19] ^ i_state[20] ^ i_state[23];
    assign o_state_next[1]  = i_state[2] ^ i_state[3] ^ i_state[4] ^ i_state[9] ^ i_state[13] ^ i_state[17] ^ i_state[20] ^ i_state[21] ^ i_state[24];
    assign o_state_next[2]  = i_state[3] ^ i_state[4] ^ i_state[5] ^ i_state[10] ^ i_state[14] ^ i_state[18] ^ i_state[21] ^ i_state[22] ^ i_state[25];
    assign o_state_next[3]  = i_state[4] ^ i_state[5] ^ i_state[6] ^ i_state[11] ^ i_state[15] ^ i_state[19] ^ i_state[22] ^ i_state[23] ^ i_state[26];
    assign o_state_next[4]  = i_state[5] ^ i_state[6] ^ i_state[7] ^ i_state[12] ^ i_state[16] ^ i_state[20] ^ i_state[23] ^ i_state[24] ^ i_state[27];
    assign o_state_next[5]  = i_state[6] ^ i_state[7] ^ i_state[8] ^ i_state[13] ^ i_state[17] ^ i_state[21] ^ i_state[24] ^ i_state[25] ^ i_state[28];
    assign o_state_next[6]  = i_state[7] ^ i_state[8] ^ i_state[9] ^ i_state[14] ^ i_state[18] ^ i_state[22] ^ i_state[25] ^ i_state[26] ^ i_state[29];
    assign o_state_next[7]  = i_state[8] ^ i_state[9] ^ i_state[10] ^ i_state[15] ^ i_state[19] ^ i_state[23] ^ i_state[26] ^ i_state[27] ^ i_state[30];
    assign o_state_next[8]  = i_state[0] ^ i_state[1] ^ i_state[2] ^ i_state[3] ^ i_state[9] ^ i_state[10] ^ i_state[11] ^ i_state[16] ^ i_state[20] ^ i_state[24] ^ i_state[27] ^ i_state[28];
    assign o_state_next[9]  = i_state[1] ^ i_state[2] ^ i_state[3] ^ i_state[4] ^ i_state[10] ^ i_state[11] ^ i_state[12] ^ i_state[17] ^ i_state[21] ^ i_state[25] ^ i_state[28] ^ i_state[29];
    assign o_state_next[10] = i_state[2] ^ i_state[3] ^ i_state[4] ^ i_state[5] ^ i_state[11] ^ i_state[12] ^ i_state[13] ^ i_state[18] ^ i_state[22] ^ i_state[26] ^ i_state[29] ^ i_state[30];
    assign o_state_next[11] = i_state[0] ^ i_state[1] ^ i_state[2] ^ i_state[4] ^ i_state[5] ^ i_state[6] ^ i_state[12] ^ i_state[13] ^ i_state[14] ^ i_state[19] ^ i_state[23] ^ i_state[27] ^ i_state[30];
    assign o_state_next[12] = i_state[0] ^ i_state[5] ^ i_state[6] ^ i_state[7] ^ i_state[13] ^ i_state[14] ^ i_state[15] ^ i_state[20] ^ i_state[24] ^ i_state[28];
    assign o_state_next[13] = i_state[1] ^ i_state[6] ^ i_state[7] ^ i_state[8] ^ i_state[14] ^ i_state[15] ^ i_state[16] ^ i_state[21] ^ i_state[25] ^ i_state[29];
    assign o_state_next[14] = i_state[2] ^ i_state[7] ^ i_state[8] ^ i_state[9] ^ i_state[15] ^ i_state[16] ^ i_state[17] ^ i_state[22] ^ i_state[26] ^ i_state[30];
    assign o_state_next[15] = i_state[0] ^ i_state[1] ^ i_state[2] ^ i_state[8] ^ i_state[9] ^ i_state[10] ^ i_state[16] ^ i_state[17] ^ i_state[18] ^ i_state[23] ^ i_state[27];
    assign o_state_next[16] = i_state[1] ^ i_state[2] ^ i_state[3] ^ i_state[9] ^ i_state[10] ^ i_state[11] ^ i_state[17] ^ i_state[18] ^ i_state[19] ^ i_state[24] ^ i_state[28];
    assign o_state_next[17] = i_state[2] ^ i_state[3] ^ i_state[4] ^ i_state[10] ^ i_state[11] ^ i_state[12] ^ i_state[18] ^ i_state[19] ^ i_state[20] ^ i_state[25] ^ i_state[29];
    assign o_state_next[18] = i_state[3] ^ i_state[4] ^ i_state[5] ^ i_state[11] ^ i_state[12] ^ i_state[13] ^ i_state[19] ^ i_state[20] ^ i_state[21] ^ i_state[26] ^ i_state[30];
    assign o_state_next[19] = i_state[0] ^ i_state[1] ^ i_state[2] ^ i_state[3] ^ i_state[4] ^ i_state[5] ^ i_state[6] ^ i_state[12] ^ i_state[13] ^ i_state[14] ^ i_state[20] ^ i_state[21] ^ i_state[22] ^ i_state[27];
    assign o_state_next[20] = i_state[1] ^ i_state[2] ^ i_state[3] ^ i_state[4] ^ i_state[5] ^ i_state[6] ^ i_state[7] ^ i_state[13] ^ i_state[14] ^ i_state[15] ^ i_state[21] ^ i_state[22] ^ i_state[23] ^ i_state[28];
    assign o_state_next[21] = i_state[2] ^ i_state[3] ^ i_state[4] ^ i_state[5] ^ i_state[6] ^ i_state[7] ^ i_state[8] ^ i_state[14] ^ i_state[15] ^ i_state[16] ^ i_state[22] ^ i_state[23] ^ i_state[24] ^ i_state[29];
    assign o_state_next[22] = i_state[3] ^ i_state[4] ^ i_state[5] ^ i_state[6] ^ i_state[7] ^ i_state[8] ^ i_state[9] ^ i_state[15] ^ i_state[16] ^ i_state[17] ^ i_state[23] ^ i_state[24] ^ i_state[25] ^ i_state[30];
    assign o_state_next[23] = i_state[0] ^ i_state[1] ^ i_state[2] ^ i_state[3] ^ i_state[4] ^ i_state[5] ^ i_state[6] ^ i_state[7] ^ i_state[8] ^ i_state[9] ^ i_state[10] ^ i_state[16] ^ i_state[17] ^ i_state[18] ^ i_state[24] ^ i_state[25] ^ i_state[26];
    assign o_state_next[24] = i_state[1] ^ i_state[2] ^ i_state[3] ^ i_state[4] ^ i_state[5] ^ i_state[6] ^ i_state[7] ^ i_state[8] ^ i_state[9] ^ i_state[10] ^ i_state[11] ^ i_state[17] ^ i_state[18] ^ i_state[19] ^ i_state[25] ^ i_state[26] ^ i_state[27];
    assign o_state_next[25] = i_state[2] ^ i_state[3] ^ i_state[4] ^ i_state[5] ^ i_state[6] ^ i_state[7] ^ i_state[8] ^ i_state[9] ^ i_state[10] ^ i_state[11] ^ i_state[12] ^ i_state[18] ^ i_state[19] ^ i_state[20] ^ i_state[26] ^ i_state[27] ^ i_state[28];
    assign o_state_next[26] = i_state[3] ^ i_state[4] ^ i_state[5] ^ i_state[6] ^ i_state[7] ^ i_state[8] ^ i_state[9] ^ i_state[10] ^ i_state[11] ^ i_state[12] ^ i_state[13] ^ i_state[19] ^ i_state[20] ^ i_state[21] ^ i_state[27] ^ i_state[28] ^ i_state[29];
    assign o_state_next[27] = i_state[4] ^ i_state[5] ^ i_state[6] ^ i_state[7] ^ i_state[8] ^ i_state[9] ^ i_state[10] ^ i_state[11] ^ i_state[12] ^ i_state[13] ^ i_state[14] ^ i_state[20] ^ i_state[21] ^ i_state[22] ^ i_state[28] ^ i_state[29] ^ i_state[30];
    assign o_state_next[28] = i_state[0] ^ i_state[1] ^ i_state[2] ^ i_state[3] ^ i_state[5] ^ i_state[6] ^ i_state[7] ^ i_state[8] ^ i_state[9] ^ i_state[10] ^ i_state[11] ^ i_state[12] ^ i_state[13] ^ i_state[14] ^ i_state[15] ^ i_state[21] ^ i_state[22] ^ i_state[23] ^ i_state[29] ^ i_state[30];
    assign o_state_next[29] = i_state[0] ^ i_state[4] ^ i_state[6] ^ i_state[7] ^ i_state[8] ^ i_state[9] ^ i_state[10] ^ i_state[11] ^ i_state[12] ^ i_state[13] ^ i_state[14] ^ i_state[15] ^ i_state[16] ^ i_state[22] ^ i_state[23] ^ i_state[24] ^ i_state[30];
    assign o_state_next[30] = i_state[0] ^ i_state[2] ^ i_state[3] ^ i_state[5] ^ i_state[7] ^ i_state[8] ^ i_state[9] ^ i_state[10] ^ i_state[11] ^ i_state[12] ^ i_state[13] ^ i_state[14] ^ i_state[15] ^ i_state[16] ^ i_state[17] ^ i_state[23] ^ i_state[24] ^ i_state[25];

endmodule