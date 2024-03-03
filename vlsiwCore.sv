localparam INSTRUCTION_WIDTH = 44;
localparam FORMAT_WIDTH = 3;
localparam METADATA_WIDTH = FORMAT_WIDTH + 1 + /* Reserved */ 16;
localparam BATCH_WIDTH = INSTRUCTION_WIDTH + METADATA_WIDTH;
localparam BATCH_WIDTH_BYTES = BATCH_WIDTH / 8;

localparam ADDRESS_WIDTH = 64;

`include "functionalUnit"

module vlsiwCore #(
	parameter FUNCTIONAL_UNITS = 8,
	
	localparam FETCH_WIDTH = FUNCTIONAL_UNITS * BATCH_WIDTH,
	localparam FETCH_WIDTH_BYTES = FETCH_WIDTH / 8
) (
	input logic clock,
	input logic reset
);
	/* Temporary, will be replaced by actual memory */
	logic [(FETCH_WIDTH)-1:0] batch_memory;
	initial begin
		batch_memory[0] = 1'h0;
		batch_memory[19:1] = 19'h0;
		batch_memory[63:20] = 44'h11111111111;

		batch_memory[64+0] = 1'h1;
		batch_memory[64+19:64+1] = 19'h0;
		batch_memory[64+63:64+20] = 44'h22222222222;
	end


	logic [ADDRESS_WIDTH-1:0] pc;

	logic [FETCH_WIDTH-1:0] fetchBuffer;
	logic [FUNCTIONAL_UNITS-1:0] stopDaisyChain;
	logic [$clog2(FUNCTIONAL_UNITS)-1:0] nextBatch;
	logic stopBatches;
	logic doneFetch, haltFetch, endBatches, doneBatches, doingFetch;

	always_ff @( posedge clock ) begin
		if (reset) begin
			fetchBuffer <= 0;
			pc <= 0;
			haltFetch <= 0;
			doneFetch <= 0;
			doingFetch <= 1;
		end else if (doneBatches) begin 
			haltFetch <= 0;
			doingFetch <= 1;
		end else if (haltFetch) begin 
			/* Block fetches from occuring */
			endBatches <= 0;
		end else if (doneFetch) begin
			if (nextBatch != 0) begin
				pc <= pc + (nextBatch * BATCH_WIDTH_BYTES);
			end else begin 
				pc <= pc + FETCH_WIDTH_BYTES;
			end
			if (stopBatches) begin

				haltFetch <= 1;
				endBatches <= 1;
			end
			doneFetch <= 0;
		end else begin
			/* Fetch batches */
			fetchBuffer <= batch_memory[(pc << 3)+:FETCH_WIDTH];
			doneFetch <= 1;
			doingFetch <= 0;
		end
	end

	generate
		genvar batchIndex;
		for (batchIndex = 0; batchIndex < FUNCTIONAL_UNITS ; batchIndex ++) begin
			always_latch begin
				if (reset | haltFetch | doingFetch) begin 
					stopDaisyChain = 0;
					nextBatch = 0;
				end else if (stopDaisyChain[batchIndex] == 0) begin
					if (batchIndex != FUNCTIONAL_UNITS-1) begin
						if (fetchBuffer[batchIndex*BATCH_WIDTH+:BATCH_WIDTH][0]) begin
							stopDaisyChain[batchIndex+1] = 1;
							nextBatch = batchIndex+1;
							stopBatches = 1;
						end else begin
							stopDaisyChain[batchIndex+1] = 0;
						end
					end else begin
						if (fetchBuffer[batchIndex*BATCH_WIDTH+:BATCH_WIDTH][0]) begin
							stopBatches = 1;
						end
					end
				end
			end

			always_ff @( posedge clock ) begin
				if (reset | haltFetch | doingFetch) begin 
					scheduledBatches <= '{default:0};
				end else if (stopDaisyChain[batchIndex] == 0) begin
					scheduledBatches[batchIndex] <= fetchBuffer[batchIndex*BATCH_WIDTH+:BATCH_WIDTH];
				end
			end
		end
	endgenerate

	logic [BATCH_WIDTH-1:0] scheduledBatches [FUNCTIONAL_UNITS-1:0];

	generate
		genvar fuID;
		for (fuID = 0; fuID < FUNCTIONAL_UNITS ; fuID++ ) begin
			functionalUnit #(
				.FUID(fuID)
			) functionalUnit (
				.reset(reset),
				.clock(clock),

				.batch(scheduledBatches[fuID]),
				.endTag(endBatches),
				.doneBatches(doneBatches)
			);
		end
	endgenerate
	
endmodule
