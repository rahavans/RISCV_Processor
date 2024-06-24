`timescale 1ns / 1ps

`define opcode IR_decode[6:0]
`define opcode_pl IR_decode_pipelined[6:0]
`define R_type 7'b0110011 
`define I_type 7'b0010011
`define S_type 7'b0100011
`define B_type 7'b1100011
`define LUI 7'b0110111
`define AUIPC 7'b0010111
`define JAL 7'b1101111
`define JALR 7'b1101111
`define LOAD 7'b0000011

/*
R-type:  | funct7 | rs2 | rs1 | funct3 | rd | opcode |
I-type:  | imm[11:0] | rs1 | funct3 | rd | opcode |
S-type:  | imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode |
B-type:  | imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode |
U-type:  | imm[31:12] | rd | opcode |
J-type:  | imm[20|10:1|11|19:12] | rd | opcode |
*/

module RISCV_Processor(
    input clk,
    input rst,
    input [31:0] instruction,
    output signed reg [31:0] GPR [31:0]
);
reg [31:0] IR_fetch;
reg [31:0] IR_decode;
reg [31:0] IR_decode_pipelined; // pipelined to execute
reg signed[31:0] execute;
reg signed[32:0] execute_w_overflow;
reg [31:0] write_back;

reg [31:0] program_mem [31:0];
reg [31:0] data_mem [31:0];

reg zero_flag;
reg negative_flag;
reg carry_flag;
reg overflow_flag;
reg read_flag;

reg [7:0] count;
reg [7:0] PC;
genvar i;
generate
    for(i = 0; i < 32; i = i + 1) begin
        always @(posedge clk) begin
            if(rst) begin
                GPR[i] <= {32{1'b0}};
                program_mem[i] <= <= {32{1'b0}};
                data_mem[i] <= <= {32{1'b0}};
            end
        end
    end
endgenerate

always(@posedge clk) begin
    if(rst) begin
        read_flag <= 1'b0;
    end else begin
        if(read_flag == 1'b0) begin
        $readmemb("File path for a .mem file that contains 32 instructions", program_mem);
        // using $readmemb only for proof of functionality, in reality, would need to connect external controller for synthesis purposes
        end
        read_flag <= 1'b1;
    end
end

always@(posedge clk) begin
    if(rst) begin
        count <= {8{1'b0}};
        PC <= {8{1'b0}};
    end else begin
        if(read_flag == 1'b1) begin
        if(count < 8b'00000100) begin
            count <= count + 8b'00000001; // delay
        end else begin
            count <= 8b'0000000000;
            PC <= PC + 8b'00000100;
        end
    end
    end
end

always@(posedge clk) begin
    if(rst) begin
        IR_fetch <= {32{1'b0}};
        IR_decode <= {32{1'b0}};
        IR_decode_pipelined <= {32{1'b0}};
        execute <= {32{1'b0}};
        execute_w_overflow <= {33{1'b0}};
        mem_access <= {32{1'b0}};
        write_back <= {32{1'b0}};
        zero_flag <= 1'b0;
        negative_flag <= 1'b0;
        carry_flag <= 1'b0;
        overflow_flag <= 1'b0;
    end else begin
    if(read_flag == 1'b1) begin
        IR_fetch <= program_mem[PC << 2];
        IR_decode <= IR_fetch;
        GPR[5] <= {{20{IR_fetch[31]}}, IR_fetch[31:20]}; // EXTRACT IMMEDIATE VALUE. SIGN EXTEND TO 32 BITS, AND STORE IN TEMP REGISTER for I-type
        GPR[6] <= {11{IR_fetch[31]}, IR_fetch[31], IR_fetch[19:12], IR_fetch[20], IR_fetch[30:21], 1'b0}; // EXTRACT IMMEDIATE VALUE, SIGN EXTEND TO 32 BITS, AND STORE IN TEMP REGISTER FOR JAL
    case(`opcode)
    IR_decode_pipelined <= IR_decode;
    `R_type: begin
        if(IR_decode[14:12] == 3'b000 && IR_decode[31:25] == 7'b0000000) begin
            execute_w_overflow <= GPR[IR_decode[19:15]] + GPR[IR_decode[24:20]]; // ADD
            execute <= ((GPR[IR_decode[19:15]] + GPR[IR_decode[24:20]]))[31:0];
            zero_flag <= ((GPR[IR_decode[19:15]] + GPR[IR_decode[24:20]]) == 0);
            carry_flag <= (GPR[IR_decode[19:15]] + GPR[IR_decode[24:20]])[32];
            negative_flag <= (GPR[IR_decode[19:15]] + GPR[IR_decode[24:20]])[31];
            overflow_flag <= ((GPR[IR_decode[19:15]][31] == GPR[IR_decode[24:20]][31]) && (execute[31] != GPR[IR_decode[19:15]][31]));
        end 
        else if (IR_decode[14:12] == 3'b000 && IR_decode[31:25] == 7'b0100000) begin
            execute_w_overflow <= GPR[IR_decode[19:15]] - GPR[IR_decode[24:20]]; // SUB
            execute <= (GPR[IR_decode[19:15]] - GPR[IR_decode[24:20]])[31:0];
            zero_flag <= ((GPR[IR_decode[19:15]] - GPR[IR_decode[24:20]]) == 0);
            carry_flag <= ((GPR[IR_decode[19:15]] - GPR[IR_decode[24:20]]))[32];
            negative_flag <= (GPR[IR_decode[19:15]] - GPR[IR_decode[24:20]])[31];
            overflow_flag <= ((GPR[IR_decode[19:15]][31] == GPR[IR_decode[24:20]][31]) && (execute[31] != GPR[IR_decode[19:15]][31]));
        end
        else if (IR_decode[14:12] == 3'b100 && IR_decode[31:25] == 7'b0000000) begin
            execute <= GPR[IR_decode[19:15]] ^ GPR[IR_decode[24:20]]; // XOR
            zero_flag <= ((GPR[IR_decode[19:15]] ^ GPR[IR_decode[24:20]]) == 0);
            negative_flag <= (GPR[IR_decode[19:15]] ^ GPR[IR_decode[24:20]])[31];
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3'b110 && IR_decode[31:25] == 7'b0000000) begin
            execute <= GPR[IR_decode[19:15]] | GPR[IR_decode[24:20]]; // OR
            zero_flag <= ((GPR[IR_decode[19:15]] | GPR[IR_decode[24:20]]) == 0);
            negative_flag <= (GPR[IR_decode[19:15]] | GPR[IR_decode[24:20]])[31];
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3'b111 && IR_decode[31:25] == 7'b0000000) begin
            execute <= GPR[IR_decode[19:15]] & GPR[IR_decode[24:20]]; // AND
            zero_flag <= ((GPR[IR_decode[19:15]] & GPR[IR_decode[24:20]]) == 0);
            negative_flag <= (GPR[IR_decode[19:15]] & GPR[IR_decode[24:20]])[31];
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3'b001 && IR_decode[31:25] == 7'b0000000) begin
            execute <= GPR[IR_decode[19:15]] << GPR[IR_decode[24:20]]; // LEFT SHIFT
            zero_flag <= ((GPR[IR_decode[19:15]] << GPR[IR_decode[24:20]]) == 0);
            negative_flag <= (GPR[IR_decode[19:15]] << GPR[IR_decode[24:20]])[31];
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3'b101 && IR_decode[31:25] == 7'b0000000) begin
            execute <= GPR[IR_decode[19:15]] >> GPR[IR_decode[24:20]]; // RIGHT SHIFT
            zero_flag <= ((GPR[IR_decode[19:15]] >> GPR[IR_decode[24:20]]) == 0);
            negative_flag <= (GPR[IR_decode[19:15]] >> GPR[IR_decode[24:20]])[31];
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3'b101 && IR_decode[31:25] == 7'b0100000) begin
            execute <= (GPR[IR_decode[19:15]] >>> GPR[IR_decode[24:20]]); // ARITHMETIC RIGHT SHIFT
            zero_flag <= ((GPR[IR_decode[19:15]] >>> GPR[IR_decode[24:20]]) == 0);
            negative_flag <= ((GPR[IR_decode[19:15]] >>> GPR[IR_decode[24:20]]))[31];
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3'b010 && IR_decode[31:25] == 7'b0000000) begin
            execute <= ((GPR[IR_decode[19:15]]) < (GPR[IR_decode[24:20]])) ? 1 : 0; // SET LESS THAN
            zero_flag <= 1'b0;
            negative_flag <= 1'b0;
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end 
        else if (IR_decode[14:12] == 3'b011 && IR_decode[31:25] == 7'b0000000) begin
            execute <= ($unsigned(GPR[IR_decode[19:15]]) < $unsigned(GPR[IR_decode[24:20]])) ? 1 : 0; // SET LESS THAN UNSIGNED
            zero_flag <= 1'b0;
            negative_flag <= 1'b0;
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
    end
    `I_type: begin
        if(IR_decode[14:12] == 3'b000) begin
            execute_w_overflow <= GPR[IR_decode[19:15]] + GPR[5]; // ADDI
            execute <= ((GPR[IR_decode[19:15]] + GPR[5]))[31:0];
            zero_flag <= ((GPR[IR_decode[19:15]] + GPR[5]) == 0);
            carry_flag <= (GPR[IR_decode[19:15]] + GPR[5])[32];
            negative_flag <= (GPR[IR_decode[19:15]] + GPR[5])[31];
            overflow_flag <= ((GPR[IR_decode[19:15]][31] == GPR[5][31]) && (execute[31] != GPR[IR_decode[19:15]][31]));
        end
        else if(IR_decode[14:12] == 3b'100) begin
            execute <= (GPR[IR_decode[19:15]] ^ GPR[5]); // XORI
            zero_flag <= ((GPR[IR_decode[19:15]] ^ GPR[5]) == 0);
            negative_flag <= (GPR[IR_decode[19:15]] ^ GPR[5])[31];
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3b'110) begin 
            execute <= (GPR[IR_decode[19:15]] | GPR[5]); // ORI
            zero_flag <= ((GPR[IR_decode[19:15]] | GPR[5]) == 0);
            negative_flag <= (GPR[IR_decode[19:15]] | GPR[5])[31];
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3b'111) begin 
            execute <= GPR[IR_decode[19:15]] & GPR[5]; // ANDI
            zero_flag <= ((GPR[IR_decode[19:15]] & GPR[5]) == 0);
            negative_flag <= (GPR[IR_decode[19:15]] & GPR[5])[31];
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3b'001 && IR_decode[31:25] == 7'b0000000) begin
            execute <= GPR[IR_decode[19:15]] << GPR[5]; // SLLI
            zero_flag <= ((GPR[IR_decode[19:15]] << GPR[5]) == 0);
            negative_flag <= (GPR[IR_decode[19:15]] << GPR[5])[31];
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3b'101 && IR_decode[31:25] == 7'b0000000) begin
            execute <= GPR[IR_decode[19:15]] >> GPR[5]; // SRLI
            zero_flag <= ((GPR[IR_decode[19:15]] >> GPR[5]) == 0);
            negative_flag <= (GPR[IR_decode[19:15]] >> GPR[5])[31];
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3b'101 && IR_decode[31:25] == 7'b0100000) begin
            execute <= (GPR[IR_decode[19:15]] >>> GPR[5]); // SRAI
            zero_flag <= ((GPR[IR_decode[19:15]] >>> GPR[5]) == 0);
            negative_flag <= (GPR[IR_decode[19:15]] >>> GPR[5])[31];
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3b'010) begin
            execute <= ((GPR[IR_decode[19:15]]) < (GPR[5])) ? 1 : 0; // SLTI
            zero_flag <= 1'b0;
            negative_flag <= 1'b0;
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
        else if(IR_decode[14:12] == 3b'011) begin
            execute <= ($unsigned(GPR[IR_decode[19:15]]) < $unsigned(GPR[5])) ? 1 : 0; // SLTIU
            zero_flag <= 1'b0;
            negative_flag <= 1'b0;
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end
    end
    `S_type: begin
        if(IR_decode[14:12] == 3b'000) begin
            data_mem[GPR[IR_decode[19:15]] + {20'b0, GPR[IR_decode[31:25]], GPR[IR_decode[11:7]]}][7:0] <= GPR[IR_decode[24:20]][7:0]; // SB
        end
        else if(IR_decode[14:12] == 3b'001) begin
            data_mem[GPR[IR_decode[19:15]] + {20'b0, GPR[IR_decode[31:25]], GPR[IR_decode[11:7]]}][15:0] <= GPR[IR_decode[24:20]][15:0]; // SH
        end
        else if(IR_decode[14:12] == 3b'010) begin
            data_mem[GPR[IR_decode[19:15]] + {20'b0, GPR[IR_decode[31:25]], GPR[IR_decode[11:7]]}][31:0] <= GPR[IR_decode[24:20]][31:0]; // SW
        end
    end
    `B_type: begin
        if(IR_decode[14:12] == 3'b000) begin
            (GPR[IR_decode[19:15]] == GPR[IR_decode[24:20]]) ? PC <= PC + {20'b0, GPR[IR_decode[31:25]], GPR[IR_decode[11:7]]} : PC <= PC; // BEQ
        end
        else if(IR_decode[14:12] == 3b'001) begin
            (GPR[IR_decode[19:15]] != GPR[IR_decode[24:20]]) ? PC <= PC + {20'b0, GPR[IR_decode[31:25]], GPR[IR_decode[11:7]]} : PC <= PC; // BNE
        end
        else if(IR_decode[14:12] == 3b'100) begin
            (GPR[IR_decode[19:15]] < GPR[IR_decode[24:20]]) ? PC <= PC + ({20'b0, GPR[IR_decode[31:25]], GPR[IR_decode[11:7]]}) : PC <= PC; // BLT
        end
        else if(IR_decode[14:12] == 3b'101) begin
            (GPR[IR_decode[19:15]] >= GPR[IR_decode[24:20]]) ? PC <= PC + ({20'b0, GPR[IR_decode[31:25]], GPR[IR_decode[11:7]]}) : PC <= PC; // BGE
        end
        else if(IR_decode[14:12] == 3b'110) begin
            ($unsigned(GPR[IR_decode[19:15]]) < $unsigned(GPR[IR_decode[24:20]])) ? PC <= PC + (({20'b0, GPR[IR_decode[31:25]], GPR[IR_decode[11:7]]})) : PC <= PC; // BLTU
        end
        else if(IR_decode[14:12] == 3b'111) begin
            ($unsigned(GPR[IR_decode[19:15]]) >= $unsigned(GPR[IR_decode[24:20]])) ? PC <= PC + ({20'b0, GPR[IR_decode[31:25]], GPR[IR_decode[11:7]]}) : PC <= PC; // BGEU
        end
    end
    `LUI: begin
        execute <= GPR[IR_decode[31:12]] << 12; // LUI
    end
    `AUIPC: begin
        PC <= PC + (GPR[IR_decode[31:12]] << 12); // AUIPC
    end
    `JAL: begin
        PC <= PC + GPR[6]; // JAL
        execute <= PC + 4; // RETURN ADDRESS
    end
    `JALR: begin
        PC <= GPR[IR_decode[19:15]] + {20{GPR[IR_decode[31]]}, GPR[IR_decode[31:20]]}; // JALR
        execute <= PC + 4; // RETURN ADDRESS
    end
    `LOAD: begin
        if(IR_decode[14:12] == 3b'000) begin
            execute <= data_mem[GPR[IR_decode[19:15]] + {20{IR_decode[31]}, IR_decode[31:20]}][7:0]; // LB
        end
        else if(IR_decode[14:12] == 3b'001) begin
            execute <= data_mem[GPR[IR_decode[19:15]] + {20{IR_decode[31]}, IR_decode[31:20]}][15:0]; // LH
        end
        else if(IR_decode[14:12] == 3b'010) begin
            execute <= data_mem[GPR[IR_decode[19:15]] + {20{IR_decode[31]}, IR_decode[31:20]}][31:0]; // LW
        end
        else if(IR_decode[14:12] == 3b'100) begin
            execute <= data_mem[GPR[IR_decode[19:15]] + {20'b0, $unsigned(IR_decode[31:20])}][7:0]; // LBU
        end
        else if(IR_decode[14:12] == 3b'101) begin
            execute <= data_mem[GPR[IR_decode[19:15]] + {20'b0, $unsigned(IR_decode[31:20])}][15:0]; // LHU
        end
    end
    endcase
    case(`opcode_pl): begin
        `R_type: begin
            GPR[IR_decode_pipelined[11:7]] <= execute;
        end
        `I_type: begin
            GPR[IR_decode_pipelined[11:7]] <= execute;
        end
        `LUI: begin
            GPR[IR_decode_pipelined[11:7]] <= execute;
        end
        `AUIPC: begin
            GPR[IR_decode_pipelined[11:7]] <= execute;
        end
        `JAL: begin
            GPR[IR_decode_pipelined[11:7]] <= execute;
        end
        `JALR: begin
            GPR[IR_decode_pipelined[11:7]] <= execute;
        end
        `LOAD: begin
            GPR[IR_decode_pipelined[11:7]] <= execute;
        end
    end
    endcase
    end
    end
end

endmodule