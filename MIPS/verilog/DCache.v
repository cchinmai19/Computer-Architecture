/************************************************
Data Cache
2-way set associative cache of size 32KB
    32B/line (8 words)
    2lines/set = 64B/set
    32KB/64B=  512sets
    2lines/set*512sets=1024lines    
32-byte addresses:
    5 bits: byte within line
    18 bits: tag
    9 bits: index
**************************************************/

module DCache
	#(
parameter sets = 512,
parameter ways = 2,
parameter lines = 1024,
parameter linewords = 8,
parameter block_bits = 256
	 )
	(
	input CLK,
	input RESET,
	input read, //load
	input write, //store
	input [31:0] data_address, //address of data
	inout [1:0] writeSize,
	input [31:0] WriteData, //store word
	input [255:0] dataRead_blk,
	output reg blkRead,
	output reg blkWrite,
	output reg [31:0] data_memaddr,
	output reg [31:0] ReadData,
	output reg [255:0] dataWrite_blk,
	output reg Stall	
	);	

reg [block_bits-1:0] dcache_data1 [sets-1:0];
reg [block_bits-1:0] dcache_data2 [sets-1:0];
reg [17:0] dcache_tag1 [sets-1:0];
reg [17:0] dcache_tag2 [sets-1:0];
reg valid1 [sets-1:0];
reg valid2 [sets-1:0];
reg dirty1 [sets-1:0];
reg dirty2 [sets-1:0];
reg last_set [sets-1:0];
reg busy;
reg need_writeback;
reg [31:0] writeback_address;
reg [3:0] word_count;
reg [8:0] index_test;
wire way;
wire hit1way;
wire hit2way;
wire [17:0] tag;
wire [8:0] index;
wire [4:0] offset;
//wire blkread;
//wire blkwrite;
reg [31:0] dcache_miss_addr;

assign tag = data_address[31:14];
assign index = data_address[13:5];
assign offset = data_address[4:0];
//assign dcache_miss_addr =  {data_address[31:5],5'b00000};
assign data_memaddr =  blkRead ? dcache_miss_addr : (blkWrite ? writeback_address: 32'hdead_beef);
assign Stall = (read|write)?(~(hit1way|hit2way)):1'b0;
//assign Stall = (read|write)&&(hit1way|hit2way)|(!read && !write) ;
//assign blkRead = Stall|~busy;
//assign blkWrite = need_writeback;
//assign blkWrite = need_writeback|~busy;
assign way = Stall?(last_set[index]?1:0):(hit1way?0:hit2way);//way on miss or hit
assign	hit1way = ((tag==dcache_tag1[index])&&(valid1[index]==1) );
assign	hit2way = ((tag==dcache_tag2[index])&&(valid2[index]==1));	

always@(*)begin 
	if(read) begin 
		if(hit1way)begin
			$display("Performing read on way1");
			last_set[index] = 1'b0;
			case(offset[4:2])
			3'b111:begin ReadData = dcache_data1[index][31:0]; $display("case 0");end
			3'b110:begin ReadData = dcache_data1[index][63:32]; $display("case 1");end
			3'b101:begin ReadData = dcache_data1[index][95:64]; $display("case 2");end
			3'b100:begin ReadData = dcache_data1[index][127:96]; $display("case 3");end
			3'b011:begin ReadData = dcache_data1[index][159:128]; $display("case 4");end
			3'b010:begin ReadData = dcache_data1[index][191:160]; $display("case 5");end
			3'b001:begin ReadData = dcache_data1[index][223:192]; $display("case 6");end
			3'b000:begin ReadData = dcache_data1[index][255:224]; $display("case 7");end
			endcase
	 	end else if(hit2way) begin 
			$display("Performing read on way2");
			last_set[index] = 1'b1;
			case(offset[4:2])
			3'b111:begin ReadData = dcache_data2[index][31:0]; $display("case 0");end
			3'b110:begin ReadData = dcache_data2[index][63:32]; $display("case 1");end
			3'b101:begin ReadData = dcache_data2[index][95:64]; $display("case 2");end
			3'b100:begin ReadData = dcache_data2[index][127:96]; $display("case 3");end
			3'b011:begin ReadData = dcache_data2[index][159:128]; $display("case 4");end
			3'b010:begin ReadData = dcache_data2[index][191:160]; $display("case 5");end
			3'b001:begin ReadData = dcache_data2[index][223:192]; $display("case 6");end
			3'b000:begin ReadData = dcache_data2[index][255:224]; $display("case 7");end
			endcase
		end
	end
end 

always @(posedge CLK)begin
$display("write dcache_data1[@%d]:%x",index_test,dcache_data1[index_test]);
		$display("write dcache_data2[@%d]:%x",index_test,dcache_data2[index_test]);
	  if(write) begin 
		
		index_test <= index;
		if(hit1way) begin 
		$display("Performing write on way1");
		last_set[index] = 1'b0;
		dirty1[index] = 1'b1;
			case(offset[4:2])
			3'b111:begin $display("case 0");
			       case(writeSize)
				0: begin dcache_data1[index][31:0] = WriteData; $display("bytes [0]");end
				1: begin dcache_data1[index][7:0] = WriteData[7:0]; $display("bytes [1]");end
				2: begin dcache_data1[index][15:0] = WriteData[15:0]; $display("bytes [2]");end
				3: begin dcache_data1[index][23:0] = WriteData[23:0]; $display("bytes [3]");end
			       endcase end
			3'b110:begin $display("case 1");
				case(writeSize)
				0: begin dcache_data1[index][63:32] = WriteData;$display("bytes [0]"); end
				1: begin dcache_data1[index][39:32] = WriteData[7:0];$display("bytes [1]"); end
				2: begin dcache_data1[index][47:32] = WriteData[15:0]; $display("bytes [2]");end
				3: begin dcache_data1[index][55:32] = WriteData[23:0]; $display("bytes [3]");end
			       endcase end
			3'b101:begin $display("case 2");
				case(writeSize)
				0: begin dcache_data1[index][95:64] = WriteData; $display("bytes [0]");end
				1: begin dcache_data1[index][71:64] = WriteData[7:0]; $display("bytes [1]");end
				2: begin dcache_data1[index][79:64] = WriteData[15:0]; $display("bytes [2]");end
				3: begin dcache_data1[index][87:64] = WriteData[23:0]; $display("bytes [3]");end
			       endcase end
			3'b100:begin $display("case 3");
				case(writeSize)
				0: begin dcache_data1[index][127:96] = WriteData; $display("bytes [0]");end
				1: begin dcache_data1[index][103:96] = WriteData[7:0]; $display("bytes [1]");end
				2: begin dcache_data1[index][111:96] = WriteData[15:0]; $display("bytes [2]");end
				3: begin dcache_data1[index][119:96] = WriteData[23:0]; $display("bytes [3]");end
			       endcase end
			3'b011:begin $display("case 4");
				case(writeSize)
				0: begin dcache_data1[index][159:128] = WriteData; $display("bytes [0]");end
				1: begin dcache_data1[index][135:128] = WriteData[7:0]; $display("bytes [1]");end
				2: begin dcache_data1[index][143:128] = WriteData[15:0]; $display("bytes [2]");end
				3: begin dcache_data1[index][151:128] = WriteData[23:0]; $display("bytes [3]");end
			       endcase end
			3'b010:begin $display("case 5");
				case(writeSize) 
				0: begin dcache_data1[index][191:160] = WriteData;  $display("bytes [0]");end
				1: begin dcache_data1[index][167:160] = WriteData[7:0];  $display("bytes [1]");end
				2: begin dcache_data1[index][175:160] = WriteData[15:0];  $display("bytes [2]");end
				3: begin dcache_data1[index][183:160] = WriteData[23:0];  $display("bytes [3]");end
			       endcase end
			3'b001:begin $display("case 6");
				case(writeSize) 
				0: begin dcache_data1[index][223:192] = WriteData;$display("bytes [0]");end
				1: begin dcache_data1[index][199:192] = WriteData[7:0];$display("bytes [1]");end
				2: begin dcache_data1[index][207:192] = WriteData[15:0];$display("bytes [2]");end
				3: begin dcache_data1[index][215:192] = WriteData[23:0];$display("bytes [3]");end
			       endcase end
			3'b000:begin $display("case 7");
				case(writeSize) 
				0: begin dcache_data1[index][255:224] = WriteData;$display("bytes [0]");end
				1: begin dcache_data1[index][231:224] = WriteData[7:0];$display("bytes [1]");end
				2: begin dcache_data1[index][239:224] = WriteData[15:0];$display("bytes [2]");end
				3: begin dcache_data1[index][247:224] = WriteData[23:0];$display("bytes [3]");end
			       endcase end
			endcase
		end else if(hit2way) begin 
		$display("Performing write on way2");
		last_set[index] = 1'b1;
		dirty2[index] = 1'b1;
			case(offset[4:2])
			3'b111:begin $display("case 0");
			       case(writeSize)
				0: begin dcache_data2[index][31:0] = WriteData;$display("bytes [0]"); end
				1: begin dcache_data2[index][7:0] = WriteData[7:0];$display("bytes [1]"); end
				2: begin dcache_data2[index][15:0] = WriteData[15:0]; $display("bytes [2]");end
				3: begin dcache_data2[index][23:0] = WriteData[23:0]; $display("bytes [3]");end
			       endcase
				end
			3'b110:begin $display("case 1");
				case(writeSize)
				0: begin dcache_data2[index][63:32] = WriteData; $display("bytes [0]");end
				1: begin dcache_data2[index][39:32] = WriteData[7:0]; $display("bytes [1]");end
				2: begin dcache_data2[index][47:32] = WriteData[15:0]; $display("bytes [2]");end
				3: begin dcache_data2[index][55:32] = WriteData[23:0]; $display("bytes [3]");end
			       endcase
				end
			3'b101:begin $display("case 2");
				case(writeSize)
				0: begin dcache_data2[index][95:64] = WriteData; $display("bytes [0]");end
				1: begin dcache_data2[index][71:64] = WriteData[7:0]; $display("bytes [1]");end
				2: begin dcache_data2[index][79:64] = WriteData[15:0]; $display("bytes [2]");end
				3: begin dcache_data2[index][87:64] = WriteData[23:0]; $display("bytes [3]");end
			       endcase end
			3'b100:begin $display("case 3");
				case(writeSize)
				0: begin dcache_data2[index][127:96] = WriteData; $display("bytes [0]");end
				1: begin dcache_data2[index][103:96] = WriteData[7:0]; $display("bytes [1]");end
				2: begin dcache_data2[index][111:96] = WriteData[15:0]; $display("bytes [2]");end
				3: begin dcache_data2[index][119:96] = WriteData[23:0]; $display("bytes [3]");end
			       endcase end
			3'b011:begin $display("case 4");
				case(writeSize) 
				0: begin dcache_data2[index][159:128] = WriteData; $display("bytes [0]");end
				1: begin dcache_data2[index][135:128] = WriteData[7:0]; $display("bytes [1]");end
				2: begin dcache_data2[index][143:128] = WriteData[15:0]; $display("bytes [2]");end
				3: begin dcache_data2[index][151:128] = WriteData[23:0]; $display("bytes [3]");end
			       endcase end
			3'b010:begin $display("case 5");
				case(writeSize) 
				0: begin dcache_data2[index][191:160] = WriteData;  $display("bytes [0]");end
				1: begin dcache_data2[index][167:160] = WriteData[7:0];  $display("bytes [1]");end
				2: begin dcache_data2[index][175:160] = WriteData[15:0];  $display("bytes [2]");end
				3: begin dcache_data2[index][183:160] = WriteData[23:0];  $display("bytes [3]");end
			       endcase end
			3'b001:begin $display("case 6");
				case(writeSize) 
				0: begin dcache_data2[index][223:192] = WriteData;$display("bytes [0]");end
				1: begin dcache_data2[index][199:192] = WriteData[7:0];$display("bytes [1]");end
				2: begin dcache_data2[index][207:192] = WriteData[15:0];$display("bytes [2]");end
				3: begin dcache_data2[index][215:192] = WriteData[23:0];$display("bytes [3]");end
			       endcase end
			3'b000:begin $display("case 7");
				case(writeSize) 
				0: begin dcache_data2[index][255:224] = WriteData;$display("bytes [0]");end
				1: begin dcache_data2[index][231:224] = WriteData[7:0];$display("bytes [1]");end
				2: begin dcache_data2[index][239:224] = WriteData[15:0];$display("bytes [2]");end
				3: begin dcache_data2[index][247:224] = WriteData[23:0];$display("bytes [3]");end
			       endcase end
			endcase
		end
	end
end

always @(posedge CLK or negedge RESET) begin 
	if(!RESET) begin 
	hit1way = 1'b0;
	hit1way = 1'b0;
	busy <= 1'b0;
	Stall = 1'b0;
	blkRead <= 1'b0;
	blkWrite <= 1'b0;	
	need_writeback <= 1'b0;
	end else if(CLK) begin
		$display("***********DATA CACHE*************");
		$display("Data address= %x",data_address);
		$display("Tag= %d Index= %d Offset= %d",tag,index,offset);
		$display("Hit1way %x Hit2way %x way %x last_set %x Stall %x",hit1way,hit2way,way,last_set[index],Stall);
		$display("Read %x Wite %x",read,write);
		$display("Current Memory Address: data_memaddr %x",data_memaddr);
		$display("ReadData %x",ReadData);
		$display("dcache_data1[@%d]:%x",index,dcache_data1[index]);
		$display("dcache_data2[@%d]:%x",index,dcache_data2[index]);
		if(read|write) begin 
		if((hit1way|hit2way))begin
			$display("**************DCACHE HIT**************");
			busy <= 1'b0;
			if(read) begin // cache hit & load operation
				 //send whole word to memory
				$display("*****dcache READ******");
				$display("dcache_data1[@%d]:%x",index,dcache_data1[index]);
				$display("dcache_data2[@%d]:%x",index,dcache_data2[index]);
				
			end else if(write) begin //cache hit & store operation
				// write to cache as per the size
				$display("*****dcache WRITE******");
				$display("dcache_data1[@%d]:%x",index,dcache_data1[index]);
				$display("dcache_data2[@%d]:%x",index,dcache_data2[index]);
				$display("WriteSize %x WriteData %x",writeSize,WriteData);
			end			
		end else begin
			// cache miss & load or store operation
			$display("**************DCACHE MISS*************");
			dcache_miss_addr <= {data_address[31:5],5'b00000};
			$display("Missed Data adddress %x",dcache_miss_addr);
			$display("blkRead %x blkWrite %x",blkRead,blkWrite);
			$display("Missed Data block dataRead_blk %x",dataRead_blk);
			busy <= 1'b0;
			case(way)
			0: begin 
				if(dirty1[index]) begin 	
					case(word_count)
					4'b0000: begin word_count <= 4'b0001;
						       //need_writeback <= 1; 
						       blkWrite <= 1;
						       writeback_address <= {dcache_tag1[index],index,5'b00000};
							dataWrite_blk <= dcache_data1[index];
						       //busy <= 1'b1;  
						       //valid1[index] <= 1'b0;
						       //dcache_tag1[index] <= 18'b0000_0000_0000_0000_00;
						       $display("Write back blk: dcache_data1[@%d]:%x",index,dcache_data1[index]); 
						 end
					4'b0001: begin word_count <= 4'b0010; busy <= 1'b1;
						       $display("*********Performing Write Back %x",blkWrite);
						       $display("Write to: writeback_address %x",writeback_address);
						       
						       blkWrite <= 0;
						       need_writeback <= 0; 
						       writeback_address <= 0; 
						 end
					4'b0010: begin word_count <= 4'b0011; busy <= 1'b1; 
						       $display("dataWrite_blk %x",dataWrite_blk); 
						       $display("Writeback done!!");
						 end
					4'b0011: begin word_count <= 4'b0100; busy <= 1'b1; end 
					4'b0100: begin word_count <= 4'b0101; busy <= 1'b1; end
					4'b0101: begin word_count <= 4'b0110; busy <= 1'b1; end
					4'b0110: begin word_count <= 4'b0111; busy <= 1'b1; end 
					4'b0111: begin word_count <= 4'b1000; busy <= 1'b1; end
					4'b1000: begin word_count <= 4'b1001; busy <= 1'b1; end
					4'b1001: begin word_count <= 4'b1010; busy <= 1'b1; blkRead <= 1; end
					4'b1010: begin word_count <= 4'b0000; busy <= 1'b0;
						       dcache_data1[index] <= dataRead_blk;
						       valid1[index] <= 1'b1; 
						       dirty1[index] <= 1'b0;
						       blkRead <= 0;
						       dcache_tag1[index] <= data_address[31:14];
						       $display("Cache miss request complete!!!");
						       $display("data_memaddr %x block loaded",data_memaddr);
						       $display("dataRead_blk %x",dataRead_blk);
						       $display("data_data1[@%d]:%x",index,dcache_data1[index]);
						       $display("Done!!");
						 end
					endcase
				end else begin 
					need_writeback <= 0;
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
					4'b1001: begin word_count <= 4'b1010; busy <= 1'b1; blkRead <= 1; end
					4'b1010: begin word_count <= 4'b0000; busy <= 1'b0;
						       dcache_data1[index] <= dataRead_blk;
						       valid1[index] <= 1'b1; 
						       blkRead <= 0;
						       dcache_tag1[index] <= data_address[31:14];
						       $display("Cache miss request complete!!!");
						       $display("data_memaddr %x block loaded",data_memaddr);
						       $display("dataRead_blk %x",dataRead_blk);
						       $display("data_data1[@%d]:%x",index,dcache_data1[index]);
						       $display("Done!!");
						 end
					endcase
				end
			   end
			1: begin 
				if(dirty2[index]) begin 
					case(word_count)
					4'b0000: begin word_count <= 4'b0001; busy <= 1'b1;
						       //need_writeback <= 1;
						       blkWrite <= 1;
				        	       writeback_address <= {dcache_tag2[index],index,5'b00000}; 
							dataWrite_blk <= dcache_data2[index];
						       //valid2[index] <= 1'b0;
						       //dcache_tag2[index] <= 18'b0000_0000_0000_0000_00;
						       $display("Write back blk dcache_data2[@%d]:%x",index,dcache_data2[index]);
						 end
					4'b0001: begin word_count <= 4'b0010; busy <= 1'b1; 
	                			       $display("*********Performing Write Back %x",need_writeback);
						       blkWrite <= 0;
						       
						       $display("Write to: writeback_address %x",writeback_address);
						       need_writeback <= 0; 
						       writeback_address <= 0; 
						 end
					4'b0010: begin word_count <= 4'b0011; busy <= 1'b1;
						       $display("dataWrite_blk %x",dataWrite_blk); 
						       $display("Writeback done!!");
						 end
					4'b0011: begin word_count <= 4'b0100; busy <= 1'b1; end 
					4'b0100: begin word_count <= 4'b0101; busy <= 1'b1; end
					4'b0101: begin word_count <= 4'b0110; busy <= 1'b1; end
					4'b0110: begin word_count <= 4'b0111; busy <= 1'b1; end 
					4'b0111: begin word_count <= 4'b1000; busy <= 1'b1; end
					4'b1000: begin word_count <= 4'b1001; busy <= 1'b1; end
					4'b1001: begin word_count <= 4'b1010; busy <= 1'b1; blkRead <= 1; end
					4'b1010: begin word_count <= 4'b0000; busy <= 1'b0;
						       dcache_data2[index] = dataRead_blk;
						       valid2[index] <= 1'b1;
						       dirty2[index] <= 1'b0;
						       blkRead <= 0;
						       dcache_tag2[index] <= data_address[31:14];
						       $display("Cache miss request complete!!!");
						       $display("data_memaddr %x block loaded",data_memaddr);
						       $display("dataRead_blk %x",dataRead_blk);
						       $display("data_data2[@%d]:%x",index,dcache_data2[index]);
						       $display("Done!!");
						 end
					endcase					
				end else begin 
					need_writeback <= 0;
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
					4'b1001: begin word_count <= 4'b1010; busy <= 1'b1; blkRead <= 1 ;end
					4'b1010: begin word_count <= 4'b0000; busy <= 1'b0;
						       dcache_data2[index] = dataRead_blk;
						       valid2[index] <= 1'b1;
						       blkRead <= 0;
						       dcache_tag2[index] <= data_address[31:14];
						       $display("Cache miss request complete!!!");
						       $display("data_memaddr %x block loaded",data_memaddr);
						       $display("dataRead_blk %x",dataRead_blk);
						       $display("data_data2[@%d]:%x",index,dcache_data2[index]);
						       $display("Done!!");
						 end
					endcase
				end
			   end
			endcase
		end
		end
	end
end

endmodule

