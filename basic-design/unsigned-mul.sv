`include "util.sv"

module unsigned_mul #(
    parameter WIDTH = 24
    // parameter n_boothMul = 7,
    // parameter n_Level = 4
)
(
    input  wire [WIDTH-1:0] IN1,
    input  wire [WIDTH-1:0] IN2,
    output wire [WIDTH*2-1:0] OUT
);


wire [11:0] Res_6x6 [3:0];
wire [13:0] Res_7x7 [1:0];
wire [23:0] Res_12x12 [1:0];
wire [25:0] Res_13x13;
wire [47:0] Res_24x24;

// used function
function int level_num(input int init, input int L_rank);
    integer res;
    for(int i=0; i<=L_rank; i=i+1) begin
        if(i==0) 
            res = init;
        else
            res = res - $floor(res / 3);
    end
    return res;    
endfunction

// generate 4 6x6 booth multiplier
genvar mul6x6, mul6x6_booth;
generate
    for(mul6x6=0; mul6x6<4; mul6x6=mul6x6+1) begin: mul6x6_gen
        wire [8:0] r16_booth_6x6 [8:0];
        Radix16_Booth_Encoder #(6) booth_6x6_i (
            .Multiplicand(IN1[mul6x6*6+:6]),
            .Multiplicand_Encoded(r16_booth_6x6)
        );

        wire [8:0] Multiplier = {2'b0, IN2[mul6x6*6+:6], 1'b0};
        
        wire [9:0] boothRes_6x6 [1:0];
        for(mul6x6_booth=0; mul6x6_booth<2; mul6x6_booth=mul6x6_booth+1) begin: boothRes_6x6_gen
            Radix16_Booth_Sel #(6) booth_sel_6x6_i (
                .Multiplicand_encoded(r16_booth_6x6),
                .Multiplier(Multiplier[mul6x6_booth*4+:5]),
                .PartialProduct(boothRes_6x6[mul6x6_booth])
            );
        end

        assign Res_6x6[mul6x6] = {{2{boothRes_6x6[0][9]}}, boothRes_6x6[0]} 
                                + {boothRes_6x6[1], 4'b0};
    end
endgenerate

// generate 2 7x7 booth multiplier
genvar mul7x7, mul7x7_booth;
generate
    for(mul7x7 = 0; mul7x7 < 2; mul7x7 = mul7x7+1) begin: mul7x7_gen
        wire [6:0] mul7x7_num1 = IN1[mul7x7*2*6+:6] + IN1[(mul7x7*2*6+6)+:6];
        wire [6:0] mul7x7_num2 = IN2[mul7x7*2*6+:6] + IN2[(mul7x7*2*6+6)+:6];

        wire [9:0] r16_booth_7x7 [8:0];
        Radix16_Booth_Encoder #(7) booth_7x7_i (
            .Multiplicand(mul7x7_num1),
            .Multiplicand_Encoded(r16_booth_7x7)
        );

        wire [8:0] Multiplier = {1'b0, mul7x7_num2, 1'b0};
        
        wire [10:0] boothRes_7x7 [1:0];
        for(mul7x7_booth=0; mul7x7_booth<2; mul7x7_booth=mul7x7_booth+1) begin: boothRes_7x7_gen
            Radix16_Booth_Sel #(7) booth_sel_7x7_i (
                .Multiplicand_encoded(r16_booth_7x7),
                .Multiplier(Multiplier[mul7x7_booth*4+:5]),
                .PartialProduct(boothRes_7x7[mul7x7_booth])
            );
        end

        assign Res_7x7[mul7x7] = {{2{boothRes_7x7[0][9]}}, boothRes_7x7[0]} 
                                + {boothRes_7x7[1], 4'b0};
    end
endgenerate

// generate 2 12x12 mul result
genvar mul12x12_res;
generate 
    for(mul12x12_res=0; mul12x12_res<2; mul12x12_res=mul12x12_res+1) begin: mul12x12_res_gen
        wire [11:0] z0_12x12 = Res_6x6[mul12x12_res*2];
        wire [11:0] z2_12x12 = Res_6x6[mul12x12_res*2+1];
        

        wire [13:0] z0_plus_z2_12x12 = z0_12x12 + z2_12x12;
        wire [13:0] z1_12x12 = Res_7x7[mul12x12_res] + ~z0_plus_z2_12x12 + 1'b1;

        assign Res_12x12[mul12x12_res] = {z2_12x12, z0_12x12} 
                                        + {z1_12x12, 6'b0};
    end
endgenerate

// 13x13 mul result
wire [12:0] mul13x13_num1 = IN1[23:12] + IN1[11:0];
wire [12:0] mul13x13_num2 = IN2[23:12] + IN2[11:0];

wire [15:0] r16_booth_13x13 [8:0];
Radix16_Booth_Encoder #(13) booth_13x13_i (
    .Multiplicand(mul13x13_num1),
    .Multiplicand_Encoded(r16_booth_13x13)
);

wire [16:0] Multiplier = {3'b0, mul13x13_num2, 1'b0};

wire [16:0] boothRes_13x13 [3:0];
wire [25:0] levelRes_13x13 [2:0][3:0];

genvar mul13x13_booth, mul13x13_csa;
generate
    for(mul13x13_booth=0; mul13x13_booth<4; mul13x13_booth=mul13x13_booth+1) begin: boothRes_13x13_gen
        Radix16_Booth_Sel #(13) booth_sel_13x13_i (
            .Multiplicand_encoded(r16_booth_13x13),
            .Multiplier(Multiplier[mul13x13_booth*4+:5]),
            .PartialProduct(boothRes_13x13[mul13x13_booth])
        );

        assign levelRes_13x13[0][mul13x13_booth] = 
                        (mul13x13_booth==0) ? {!boothRes_13x13[mul13x13_booth][16], {4{boothRes_13x13[mul13x13_booth][16]}}, boothRes_13x13[mul13x13_booth]}
                               : ((mul13x13_booth == 3) ? {boothRes_13x13[mul13x13_booth], {mul13x13_booth*4{1'b0}}}
                               : {{3{1'b1}}, !boothRes_13x13[mul13x13_booth][16], boothRes_13x13[mul13x13_booth], {mul13x13_booth*4{1'b0}}});

    end

    for(mul13x13_csa=0; mul13x13_csa<2; mul13x13_csa=mul13x13_csa+1) begin: mul13x13_csa_gen
        localparam num1 = level_num(4, mul13x13_csa);
        localparam num2 = level_num(4, mul13x13_csa+1);
        CSA_Layer #(num1, num2, 26) csa_layer(
            .IN(levelRes_13x13[mul13x13_csa][num1-1:0]),
            .OUT(levelRes_13x13[mul13x13_csa+1][num2-1:0])
        );
    end
endgenerate

assign Res_13x13 = levelRes_13x13[2][0] + levelRes_13x13[2][1];

// cal final 24x24 mul result
wire [23:0] z0_24x24 = Res_12x12[0];
wire [23:0] z2_24x24 = Res_12x12[1];

wire [25:0] z0_plus_z2_24x24 = z0_24x24 + z2_24x24;
wire [25:0] z1_24x24 = Res_13x13 + ~z0_plus_z2_24x24 + 1'b1;

assign Res_24x24 = {z2_24x24, z0_24x24}
                    + {z1_24x24, 12'b0};



assign OUT = Res_24x24;    
endmodule