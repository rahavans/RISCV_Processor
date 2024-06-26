`timescale 1ns / 1ps

`define opcode IR_fetch[6:0]
`define opcode_pl IR_decode[6:0]
`define opcode_pl_1 IR_decode_pl[6:0]
`define opcode_pl_2 IR_decode_pl_1[6:0]
`define R_type 7'b0110011 
`define I_type 7'b0010011
`define S_type 7'b0100011
`define B_type 7'b1100011
`define LUI 7'b0110111
`define AUIPC 7'b0010111
`define JAL 7'b1101111
`define JALR 7'b1100111
`define LOAD 7'b0000011

module RISCV_Processor(
    input clk,
    input rst,
    output reg signed [31:0] GPR [0:31]
);
reg [31:0] IR_fetch;
reg [31:0] IR_decode;
reg [31:0] IR_decode_pl;
reg [31:0] IR_decode_pl_1;
reg [31:0] IR_decode_pl_2;

reg signed[32:0] execute;
reg [31:0] address;
reg [31:0] address_pl;
reg [31:0] address_pl_1;
reg signed [31:0] write_back;

reg [31:0] program_mem [31:0];
reg [31:0] data_mem [31:0];

reg signed [31:0] rs1;
reg signed [31:0] rs2;
reg signed [31:0] imm;
reg [31:0] rd;

wire zero_flag;
wire negative_flag;
wire carry_flag;
wire overflow_flag;
reg read_flag;
reg branch_flag;

assign zero_flag = (execute == 0);
assign negative_flag = execute[31];
assign carry_flag = (execute > 2147483647 || execute < -2147483648);
assign overflow_flag = (execute[32] == 1'b1);

reg [31:0] PC;
genvar i;

generate
    for(i = 0; i < 32; i = i + 1) begin
        always @(posedge clk) begin
            if(rst) begin
                GPR[i] <= {32{1'b0}};
                program_mem[i] <= {32{1'b0}};
                data_mem[i] <= {32{1'b0}};
            end
        end
    end
endgenerate

always @(posedge clk) begin
    if(rst) begin
        read_flag <= 1'b0;
    end else begin
        if(read_flag == 1'b0) begin
        $readmemb("program.mem", program_mem, 0, 31);
        // using $readmemb only for proof of functionality, in reality, would need to connect external controller for synthesis purposes
        end
        read_flag <= 1'b1;
    end
end

always@(posedge clk) begin
    if(rst) begin
        PC <= {32{1'b0}};
        branch_flag <= 1'b0;
    end else begin
        if(read_flag == 1'b1) begin
            if(IR_decode_pl_2[6:0] == `B_type || IR_decode_pl_2[6:0] == `JAL || IR_decode_pl_2[6:0] == `JALR) begin
                PC <= address_pl_1;
                address_pl_1 <= {32{1'b0}};
            end else begin
                if(branch_flag == 1'b1) begin
                    PC <= PC;
                end else begin
                    PC <= PC + 4;
                end 
            end
        end
    end
end

always@(posedge clk) begin
    if(rst) begin
        IR_fetch <= {32{1'b0}};
    end else begin
        if(read_flag == 1'b1) begin
            if(branch_flag == 1'b0) begin
                IR_fetch <= program_mem[PC >> 2];
            end else begin
                IR_fetch <= 51;
        end
        if(program_mem[PC >> 2][6:0] == `B_type || program_mem[PC >> 2][6:0] == `JAL || program_mem[PC >> 2][6:0] == `JALR) begin
            branch_flag <= 1'b1;
        end
    end
end
end

always@(posedge clk) begin
    if(rst) begin
        IR_decode <= {32{1'b0}};
        rs1 <= {32{1'b0}};
        rs2 <= {32{1'b0}};
        imm <= {32{1'b0}};
    end else begin
        if(read_flag == 1'b1) begin
            IR_decode <= IR_fetch;
    case(`opcode)
    `R_type: begin
        rs1 <= GPR[{{20{1'b0}}, IR_fetch[19:15]}];
        rs2 <= GPR[{{20{1'b0}}, IR_fetch[24:20]}];
        imm <= {32{1'b0}};
    end
    `I_type: begin
        rs1 <= GPR[{{27{1'b0}}, IR_fetch[19:15]}];
        rs2 <= {32{1'b0}};
        imm <= {{20{IR_fetch[31]}}, IR_fetch[31:20]};
    end
    `S_type: begin
        rs1 <= GPR[IR_fetch[19:15]];
        rs2 <= GPR[IR_fetch[24:20]];
        imm <= {{20{IR_fetch[31]}}, GPR[IR_fetch[31:25]], GPR[IR_fetch[11:7]]};
    end
    `B_type: begin
        rs1 <= GPR[IR_fetch[19:15]];
        rs2 <= GPR[IR_fetch[24:20]];
        imm <= {{20{IR_fetch[31]}}, IR_fetch[31], IR_fetch[7], IR_fetch[31:25], IR_fetch[11:8]};
    end
    `LUI: begin
        rs1 <= {32{1'b0}};
        rs2 <= {32{1'b0}};
        imm <= {{12{IR_fetch[31]}}, IR_fetch[31:12]};
    end
    `AUIPC: begin
        rs1 <= {32{1'b0}};
        rs2 <= {32{1'b0}};
        imm <= {{12{IR_fetch[31]}}, IR_fetch[31:12]};
    end
    `JAL: begin
        rs1 <= {32{1'b0}};
        rs2 <= {32{1'b0}};
        imm <= {{11{IR_fetch[31]}}, IR_fetch[31], IR_fetch[19:12], IR_fetch[20], IR_fetch[30:21], 1'b0};
    end
    `JALR: begin
        rs1 <= GPR[IR_fetch[19:15]];
        rs2 <= {32{1'b0}};
        imm <= {{20{GPR[IR_fetch[31]]}}, GPR[IR_fetch[31:20]]};
    end
    `LOAD: begin
        rs1 <= GPR[IR_fetch[19:15]];
        rs2 <= {32{1'b0}};
        imm <= {{20{IR_fetch[31]}}, IR_fetch[31:20]};
    end
    endcase
    end
    end
end

always@(posedge clk) begin
    if(rst) begin
        execute <= {33{1'b0}};
        address <= {32{1'b0}};
        IR_decode_pl <= {32{1'b0}};
    end else begin
        if(read_flag == 1'b1) begin
            IR_decode_pl <= IR_decode;
        case(`opcode_pl)
        `R_type: begin
            address <= {32{1'b0}};
            if(IR_decode[14:12] == 3'b000 && IR_decode[31:25] == 7'b0000000) begin
                execute <= rs1 + rs2; // ADD
            end
            else if(IR_decode[14:12] == 3'b000 && IR_decode[31:25] == 7'b0100000) begin
                execute <= rs1 - rs2; // SUB
            end
            else if(IR_decode[14:12] == 3'b100 && IR_decode[31:25] == 7'b0000000) begin
                execute <= rs1 ^ rs2; // XOR
            end
            else if(IR_decode[14:12] == 3'b110 && IR_decode[31:25] == 7'b0000000) begin
                execute <= rs1 | rs2; // OR
            end
            else if(IR_decode[14:12] == 3'b111 && IR_decode[31:25] == 7'b0000000) begin
                execute <= rs1 & rs2; // AND
            end
            else if(IR_decode[14:12] == 3'b001 && IR_decode[31:25] == 7'b0000000) begin
                execute <= rs1 << rs2; // LEFT SHIFT
            end
            else if(IR_decode[14:12] == 3'b101 && IR_decode[31:25] == 7'b0000000) begin
                execute <= rs1 >> rs2; // RIGHT SHIFT
            end
            else if(IR_decode[14:12] == 3'b101 && IR_decode[31:25] == 7'b0100000) begin
                execute <= rs1 >>> rs2; // ARITHMETIC RIGHT SHIFT
            end
            else if(IR_decode[14:12] == 3'b010 && IR_decode[31:25] == 7'b0000000) begin
                execute <= (rs1 < rs2) ? 1 : 0; // SLT
            end
            else if(IR_decode[14:12] == 3'b011 && IR_decode[31:25] == 7'b0000000) begin
                execute <= ($unsigned(rs1) < $unsigned(rs2)) ? 1 : 0; // SLTU
            end
        end
        `I_type: begin
            address <= {32{1'b0}};
            if(IR_decode[14:12] == 3'b000) begin
                execute <= rs1 + imm; // ADDI
            end
            else if(IR_decode[14:12] == 3'b100) begin
                execute <= rs1 ^ imm; // XORI
            end
            else if(IR_decode[14:12] == 3'b110) begin
                execute <= rs1 | imm; // ORI
            end
            else if(IR_decode[14:12] == 3'b111) begin
                execute <= rs1 & imm; // ANDI
            end
            else if(IR_decode[14:12] == 3'b001 && IR_decode[31:25] == 7'b0000000) begin
                execute <= rs1 << imm; // SLLI
            end
            else if(IR_decode[14:12] == 3'b101 && IR_decode[31:25] == 7'b0000000) begin
                execute <= rs1 >> imm; // SRLI
            end
            else if(IR_decode[14:12] == 3'b101 && IR_decode[31:25] == 7'b0100000) begin
                execute <= rs1 >>> imm; // SRAI
            end
            else if(IR_decode[14:12] == 3'b010) begin
                execute <= (rs1 < imm) ? 1 : 0; // SLTI
            end
            else if(IR_decode[14:12] == 3'b011) begin
                execute <= ($unsigned(rs1) < $unsigned(imm)) ? 1 : 0; // SLTU
            end
        end
        `S_type: begin
            address <= rs1 + imm;
            execute <= rs2;
        end
        `B_type: begin
            if(IR_decode[14:12] == 3'b000) begin
                address <= (rs1 == rs2) ? PC + imm : PC + 4; // BEQ
            end
            else if(IR_decode[14:12] == 3'b001) begin
                address <= (rs1 != rs2) ? PC + imm : PC + 4; // BNE
            end
            else if(IR_decode[14:12] == 3'b100) begin
                address <= (rs1 < rs2) ? PC + imm : PC + 4; // BLT
            end
            else if(IR_decode[14:12] == 3'b101) begin
                address <= (rs1 >= rs2) ? PC + imm : PC + 4; // BGE
            end
            else if(IR_decode[14:12] == 3'b110) begin
                address <= ($unsigned(rs1) < $unsigned(rs2)) ? PC + imm : PC + 4; // BLTU
            end
            else if(IR_decode[14:12] == 3'b111) begin
                address <= ($unsigned(rs1) >= $unsigned(rs2)) ? PC + imm : PC + 4; // BLTU
            end
        end
        `LUI: begin
            execute <= imm << 12;
        end
        `AUIPC: begin
            execute <= PC + (imm << 12);
        end
        `JAL: begin
            address <= PC + imm;
            execute <= PC + 4;
        end
        `JALR: begin
            address <= PC + rs1 + imm;
            execute <= PC + 4;
        end
        `LOAD: begin
            address <= rs1 + imm;
        end
        endcase
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        write_back <= {32{1'b0}};
        address_pl <= {32{1'b0}};
        IR_decode_pl_1 <= {32{1'b0}};
        rd <= {32{1'b0}};
        end else begin
        if(read_flag == 1'b1) begin
            IR_decode_pl_1 <= IR_decode_pl;
            case(`opcode_pl_1)
                `R_type: begin
                    if(IR_decode_pl[14:12] == 3'b000 && IR_decode_pl[31:25] == 7'b0000000) begin
                        write_back <= execute[31:0];
                        rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                    end 
                    else if(IR_decode_pl[14:12] == 3'b000 && IR_decode_pl[31:25] == 7'b0100000) begin
                        write_back <= execute[31:0];
                        rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                    end else begin
                    write_back <= execute[31:0];
                    rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                end
                end
                `I_type: begin
                    if(IR_decode_pl[14:12] == 3'b000) begin
                        write_back <= execute[31:0];
                        rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                    end else begin
                        write_back <= execute;
                        rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                    end
                    rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                end
                `S_type: begin
                    if(IR_decode_pl[14:12] == 3'b000) begin
                        data_mem[address][7:0] <= execute[7:0]; // SB
                    end
                    else if(IR_decode[14:12] == 3'b001) begin
                        data_mem[address][15:0] <= execute[15:0]; // SH

                    end
                    else if(IR_decode[14:12] == 3'b010) begin
                        data_mem[address][31:0] <= execute[31:0]; // SW
                    end
                end
                `B_type: begin
                    address_pl <= address;
                end
                `LUI: begin
                    write_back <= execute;
                    rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                end
                `AUIPC: begin
                    write_back <= execute;
                    rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                end
                `JAL: begin
                    address_pl <= address;
                    write_back <= execute;
                    rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                end
                `JALR: begin
                    address_pl <= address;
                    write_back <= execute;
                    rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                end
                `LOAD: begin
                    if(IR_decode_pl[14:12] == 3'b000) begin
                        write_back <= {{24{data_mem[address][7]}}, data_mem[address][7:0]}; // LB
                        rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                    end
                    else if(IR_decode_pl[14:12] == 3'b001) begin
                        write_back <= {{16{data_mem[address][15]}}, data_mem[address][15:0]}; // LH
                        rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                    end
                    else if(IR_decode_pl[14:12] == 3'b010) begin
                        write_back <= data_mem[address][31:0]; // LW
                        rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                    end
                    else if(IR_decode_pl[14:12] == 3'b100) begin
                        write_back <= {24'b0, data_mem[address][7:0]}; // LBU
                        rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                    end
                    else if(IR_decode_pl[14:12] == 3'b100) begin
                        write_back <= {16'b0, data_mem[address][15:0]}; // LHU
                        rd <= {{27{1'b0}}, IR_decode_pl[11:7]};
                    end
                end
            endcase
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        address_pl_1 <= {32{1'b0}};
        IR_decode_pl_2 <= {32{1'b0}};
    end else begin
        if(read_flag == 1'b1) begin
        address_pl_1 <= address_pl;
        IR_decode_pl_2 <= IR_decode_pl_1;
        case(`opcode_pl_2)
            `R_type: begin
                GPR[rd] <= write_back;
            end
            `I_type: begin
                GPR[rd] <= write_back;
            end
            `B_type: begin
                branch_flag <= 1'b0;
            end
            `LOAD: begin
                GPR[rd] <= write_back;
            end
            `JAL: begin
                GPR[rd] <= write_back;
                branch_flag <= 1'b0;
            end
            `JALR: begin
                GPR[rd] <= write_back;
                branch_flag <= 1'b0;
            end
            `LUI: begin
                GPR[rd] <= write_back;
            end
            `AUIPC: begin
                GPR[rd] <= write_back;
            end
        endcase
        end
    end
    end
endmodule