//-------------------------------------------------------
// Multicycle MIPS processor
//------------------------------------------------

module mips(input        clk, reset,
            output [31:0] adr, writedata,
            output        memwrite,
            input [31:0] readdata);

  wire        zero, pcen, irwrite, regwrite,
               alusrca, iord, memtoreg, regdst;
  wire [1:0]  alusrcb, pcsrc;
  wire [2:0]  alucontrol;
  wire [5:0]  op, funct;

  controller c(clk, reset, op, funct, zero,
               pcen, memwrite, irwrite, regwrite,
               alusrca, iord, memtoreg, regdst, 
               alusrcb, pcsrc, alucontrol);
  datapath dp(clk, reset, 
              pcen, irwrite, regwrite,
              alusrca, iord, memtoreg, regdst,
              alusrcb, pcsrc, alucontrol,
              op, funct, zero,
              adr, writedata, readdata);
endmodule

// Todo: Implement controller module
module controller(input       clk, reset,
                  input [5:0] op, funct,
                  input       zero,
                  output       pcen, memwrite, irwrite, regwrite,
                  output       alusrca, iord, memtoreg, regdst,
                  output [1:0] alusrcb, pcsrc,
                  output [2:0] alucontrol);

// **PUT YOUR CODE HERE**
    wire [1:0] aluop;
    wire branch;
    wire pcwrite;

    maindec md(clk, reset, op, memtoreg, memwrite, pcwrite, branch,
                regdst, regwrite, irwrite, iord, alusrca, aluop, pcsrc, alusrcb); 
    aludec ad(funct, aluop, alucontrol);

    assign pcen = (branch & zero) | pcwrite; 
endmodule

module maindec(input clk, reset,
                input [5:0] op,
                output  memtoreg, memwrite, pcwrite,
                output  branch,
                output  regdst, regwrite, irwrite,
                output  iord, alusrca,
                output  [1:0] aluop, pcsrc, alusrcb); 

    reg[3:0] current_state, next_state; //hold current and next state 0 to 11

	parameter Fetch = 4'b0000;
	parameter Decode = 4'b0001;
	parameter MemAdr = 4'b0010;
	parameter MemRd = 4'b0011;
	parameter MemWB = 4'b0100;
	parameter MemWr = 4'b0101;
	parameter RtypeEx = 4'b0110;
	parameter RtypeWB = 4'b0111;
	parameter BeqEx = 4'b1000;
	parameter AddiEx = 4'b1001;
	parameter AddiWB = 4'b1010;
	parameter JEx = 4'b1011;

	always@  (posedge  clk) begin  //determines and gets the next state
		if(reset == 1'b1) begin
			current_state <= Fetch; //reset to s0 (fetch)
		end else  begin
			current_state <= next_state; //sets curr state to next
		end
    end

	always@(negedge clk) begin
		if(reset == 1'b1) begin
			next_state <= Decode;
		end else  begin
			case(current_state) //get new next state based on current state
				default: next_state = Fetch; //->s0 (fetch)
				Fetch: next_state = Decode; //->s1 (decode)
				Decode: case(op)
						6'b000000: next_state = RtypeEx; //rtype ->s6(Execute)
						6'b100011: next_state = MemAdr; //lw ->s2
						6'b101011: next_state = MemAdr; //sw ->s2
						6'b000100: next_state = BeqEx; //beq ->s8
						6'b001000: next_state = AddiEx; //addi ->s9
						6'b000010: next_state = JEx; //jump ->s11

					endcase
				MemAdr: case(op)
						6'b100011: next_state = MemRd; //lw ->s3
						6'b101011: next_state = MemWr; //sw ->s5
					endcase
				MemRd: next_state = MemWB; //->s4
				MemWB: next_state = Fetch; //->s0
				MemWr: next_state = Fetch; //->s0
				RtypeEx: next_state = RtypeWB; //->s7
				RtypeWB: next_state = Fetch; //->s0
				BeqEx: next_state = Fetch; //->s0
				AddiEx: next_state = AddiWB; //->s10
				AddiWB: next_state = Fetch;  //->s0
				JEx: next_state = Fetch; //->s0
					
			endcase
		end
	end

	reg [14:0] controls;
	assign {pcwrite, memwrite, irwrite, regwrite, alusrca, branch,
		iord, memtoreg, regdst, alusrcb, pcsrc, aluop} = controls;

	//set outputs for given state
	always@ (current_state) begin
  
		case (current_state)  
			// Determine controls for each state based on table 4 
			Fetch:  controls <= 15'b101000000010000; 
			Decode: controls <= 15'b000000000110000;
			MemAdr: controls <= 15'b000010000100000;
			MemRd: controls <= 15'b000000100000000;
			MemWB: controls <= 15'b000100010000000;
			MemWr: controls <= 15'b010000100000000;
			RtypeEx: controls <= 15'b000010000000010;
			RtypeWB: controls <= 15'b000100001000000;
			BeqEx: controls <= 15'b000011000000101;
			AddiEx: controls <= 15'b000010000100000;
			AddiWB: controls <= 15'b000100000000000;
			JEx: controls <= 15'b100000000001000;
		endcase
	end

endmodule

module aludec(input [5:0] funct,
                input [1:0] aluop,
                output  reg[2:0] alucontrol);
    always @*
    	case(aluop)
        	2'b00: alucontrol <= 3'b010; // add (for lw/sw/addi)
        	2'b01: alucontrol <= 3'b110; // sub (for beq)
        default: case(funct) // R-type instructions
            6'b100000: alucontrol <= 3'b010; // add
            6'b100010: alucontrol <= 3'b110; // sub
            6'b100100: alucontrol <= 3'b000; // and
            6'b100101: alucontrol <= 3'b001; // or
            6'b101010: alucontrol <= 3'b111; // slt
            default: alucontrol <= 3'bxxx; // ???
        	endcase
    	endcase
endmodule

// Todo: Implement datapath
module datapath(input        clk, reset,
                input        pcen, irwrite, regwrite,
                input        alusrca, iord, memtoreg, regdst,
                input [1:0]  alusrcb, pcsrc, 
                input [2:0]  alucontrol,
                output [5:0]  op, funct,
                output        zero,
                output [31:0] adr, writedata, 
                input [31:0] readdata);

// **PUT YOUR CODE HERE** 

	wire [4:0] writereg;
	wire [31:0] wd3result,pcnext;
	wire [31:0] pc;
	wire [31:0] signimm, signimmsh;
	wire [31:0] srca, srcb;
	wire [31:0] regf_rd1, regf_rd2; // from register file ouput
	wire [31:0] a, b; //a and b from reg file after register
	
    wire [31:0] aluresult;
	wire [31:0] aluout;

	wire [31:0] instr; //instr wire after irwrite reg
	wire [31:0] data; //data wire after register for wd3

	
	
	//PC logic
	enr #(32) pcreg(clk,reset,pcnext,pcen,pc); //pc register controled by pcen
	mux2 #(32) iordreg(pc, aluout, iord, adr); //mux that determines adr controlled by iord
	
	//instruction logic
	enr #(32) instrreg(clk,reset,readdata,irwrite,instr); // irwrite enable reg for instr
	flopr #(32) datareg(clk,reset,readdata,data);

	assign op = instr[31:26];
	assign funct = instr[5:0];

	signext	se(instr[15:0], signimm); //sign extension
	sl2 #(32) immsh(signimm, signimmsh); //sign extension shift 2


	//reg file logic
	mux2 #(5) wrmux(instr[20:16], instr[15:11], //mux for A3 in regfile
                    	regdst, writereg);
	mux2 #(32) wd3mux(aluout, data, 	//mux for wd3 input to regfile
			memtoreg, wd3result);
	regfile rf(clk, regwrite, instr[25:21], instr[20:16],
                writereg, wd3result, regf_rd1, regf_rd2);
	
	flopr #(32) a_reg(clk,reset, regf_rd1, a); //a register control
	flopr #(32) b_reg(clk,reset, regf_rd2, b); //b register control
	assign writedata = b;
	
	//ALU logic
	//wire [31:0] fourwire = 1'd4;
	mux2 #(32) srca_mux(pc,a,alusrca,srca); //mux determine scra
	mux4 #(32) srcb_mux(b, 32'd4, signimm,signimmsh,alusrcb,srcb); //mux determine scrb
	ALU        alu(srca, srcb, alucontrol, aluresult, zero); //alu
	flopr #(32) alureg(clk,reset,aluresult,aluout); //aluresult register
	
	//jump logic
	wire [27:0] endof_pcjump;
	sl2 #(28) pcjumpshift({2'b00,instr[25:0]}, endof_pcjump); // shift of instr to get end bits of pcjump
	wire [31:0] nullval = 32'b0;
	mux4 #(32) threetoonemux(aluresult,aluout,{pc[31:28],endof_pcjump}, nullval,pcsrc, pcnext);
	

endmodule

module flopr #(parameter WIDTH = 8) //registers no enable
                (input clk, reset,
                input [WIDTH-1:0] d,
                output reg[WIDTH-1:0] q);

    always @(posedge clk, posedge reset)
        if (reset) q <= 0;
        else q <= d;

endmodule

module enr #(parameter WIDTH = 8) //enabled controlled registers 
                (input clk, reset,
                input [WIDTH-1:0] d,
		        input en,
                output reg[WIDTH-1:0] q);

    always @(posedge clk, posedge reset)
        if (reset) q <= 0;
        else if(en) q <= d;

endmodule

module regfile(input  clk, ///regfile pulled from single cycle
                input  we3,
                input  [4:0] ra1, ra2, wa3,
                input  [31:0] wd3,
                output [31:0] rd1, rd2);

    reg [31:0] rf[31:0];
    always @(posedge clk)
        if (we3) rf[wa3] <= wd3;
    
    assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
    assign rd2 = (ra2 != 0) ? rf[ra2] : 0;

endmodule

module sl2 #(parameter WIDTH = 8)
		(input  [WIDTH-1:0] a, //shift left by 2 module
            output  [WIDTH-1:0] y);
    // shift left by 2
    assign y = {a[WIDTH-3:0], 2'b00};
endmodule

module signext(input  [15:0] a, ///sign extend module
                output  [31:0] y);
    
    assign y = {{16{a[15]}}, a};
endmodule

module mux2 #(parameter WIDTH = 8) //2 input mux module
                (input [WIDTH-1:0] d0, d1,
                input s,
                output [WIDTH-1:0] y);
    
    assign y = s ? d1 : d0;
endmodule

module mux4 #(parameter WIDTH = 8) //4 to 1 mux
		(input [WIDTH-1:0] d0, d1, d2, d3,
		input [1:0]s,
		output [WIDTH-1:0] y);

	assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);

endmodule
