/************************************************************
Instruction Cache 
Direct Mapped cache of size 32KB 
   Set(block) = 32B log2(32) = 5bits offset
   sets - 32KB/32B = 1024 sets =log2(1024) = 10bits index
   words = 32B/(4B) = 8 words
   Tag = 32 - 10 -5 = 17 bits   
32-byte addresses:
    5 bits: byte 
    17 bits: tag
    10 bits: index
**************************************************************/
module ICache
	#(
	parameter sets = 1024,
	parameter tag_bits = 17,
	parameter block_bits = 256 //32B * 8  
	)
	(
	input CLK,
	input RESET,
	input [31:0] Instr_addr,
	input [255:0] mem_block, //memory block currently read
	output iBlkread1,
	output reg [31:0] Instr_out,
	output Instr_valid,
	output [31:0] mem_address
	);

	
	reg [(block_bits-1):0] icache_data [(sets-1) : 0];
	reg [1023:0] icache_valid;
	reg [tag_bits-1:0] icache_taglist [(sets-1):0];
	//reg [3:0] delay;
	reg busy;
	reg [31:0] cache_miss_addr;
	reg [3:0] word_count;

	wire match;	
	wire [16:0] tag; //[31:15] instr_addr
	wire [9:0] index; //[14:5] instr_addr
	wire [4:0] offset;//[4:0] instr_addr

	assign tag = Instr_addr[31:15];
	assign index = Instr_addr[14:5];
	assign offset = Instr_addr[4:0];
	assign match = ((tag == icache_taglist[index])&&(icache_valid[index] == 1));	
	assign mem_address = busy?cache_miss_addr : 32'h0000_0000;
	assign Instr_valid = ~match;
	assign iBlkread1 = ~match|~busy;

always@(*) begin
	case(Instr_addr[4:2]) //loading block from the previous cycle
		3'b111 : begin Instr_out = icache_data[index][31:0];$display("case 0");end
		3'b110 : begin Instr_out = icache_data[index][63:32];$display("case 1");end
		3'b101 : begin Instr_out = icache_data[index][95:64];$display("case 2");end
		3'b100 : begin Instr_out = icache_data[index][127:96];$display("case 3");end
		3'b011 : begin Instr_out = icache_data[index][159:128];$display("case 4");end
		3'b010 : begin Instr_out = icache_data[index][191:160];$display("case 5");end
		3'b001 : begin Instr_out = icache_data[index][223:192];$display("case 6");end
		3'b000 : begin Instr_out = icache_data[index][255:224];$display("case 7");end
         endcase
end

always @(posedge CLK or negedge RESET) begin 
    if(!RESET) begin
	//delay <= 0;
	icache_valid <= {1024{1'b0}};
    end else if(CLK) begin
	$display("**********INSTRUCTION CACHE***********");
	$display("ICACHE: Instruction address= %x",Instr_addr);
	$display("ICACHE: Tag= %d Index= %d Offset= %d",tag,index,offset);
        if(match) begin // cache hit
        busy <= 1'b0;
	$display("********ICACHE HIT*******");
	$display("ICache Block= %x",icache_data[index]);
	$display("Instruction Block from Memory= %x",mem_block);
	$display("ICACHE: icache_word0= %x,icache_word1= %x,icache_word2= %x,icache_word3= %x,icache_word4= %x,icache_word5= %x,icache_word6= %x,icache_word7= %x",icache_data[index][31:0],icache_data[index][63:32],icache_data[index][95:64],icache_data[index][127:96],icache_data[index][159:128],icache_data[index][191:160],icache_data[index][223:192],icache_data[index][255:224]);
	$display("Instruction Fetched= %x",Instr_out);
	end else begin // cache miss
	     $display("********ICACHE MISS********");
	     cache_miss_addr <= {Instr_addr[31:5],5'b00000};  
	     word_count <= 4'b0000;
		case(word_count)
		4'b0000: begin word_count <= 4'b0001; busy <= 1'b1; end
		4'b0001: begin word_count <= 4'b0010; busy <= 1'b1; end
		4'b0010: begin word_count <= 4'b0011; busy <= 1'b1; end
		4'b0011: begin word_count <= 4'b0100; busy <= 1'b1; end 
		4'b0100: begin word_count <= 4'b0101; busy <= 1'b1; end
		4'b0101: begin word_count <= 4'b0110; busy <= 1'b1; end
		4'b0110: begin word_count <= 4'b0111; busy <= 1'b1; end 
		4'b0111: begin word_count <= 4'b1000; busy <= 1'b1; end
		4'b1000: begin word_count <= 4'b1001; busy <= 1'b1; end
		4'b1001: begin
			 icache_valid[index] <= 1'b1;
			 icache_data[index] <= mem_block;
			 icache_taglist[index] <= Instr_addr[31:15]; 
			 word_count <= 4'b0000; busy <= 1'b0;  
			 $display("ICACHE missed block address= %x",cache_miss_addr);
	     		 $display("Memory Block missed= %x",mem_block);
			 $display("ICache data= %x ICache Tag= %x",icache_data[index],icache_taglist[index]);
			 $display("ICACHE miss serviced!!!");
			 end
		endcase
	     
	end 
    end

end 
endmodule 
