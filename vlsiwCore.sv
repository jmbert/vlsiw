
localparam BATCH_INSTRUCTION_WIDTH = 5;
localparam INSTRUCTION_WIDTH = 44;
localparam TEMPLATE_WIDTH = FORMAT_WIDTH * BATCH_INSTRUCTION_WIDTH;
localparam METADATA_WIDTH = TEMPLATE_WIDTH + 1 + /* Reserved */ 20;
localparam BATCH_WIDTH = BATCH_INSTRUCTION_WIDTH * INSTRUCTION_WIDTH + METADATA_WIDTH;
localparam BATCH_WIDTH_BYTES = BATCH_WIDTH / 8;
localparam FORMAT_WIDTH = 3;

localparam ADDRESS_WIDTH = 64;

`include "functionalUnit"

module vlsiwCore #(
	parameter FUNCTIONAL_UNITS = 8,
	
	localparam FETCH_WIDTH = FUNCTIONAL_UNITS * BATCH_WIDTH
) (
	input logic clock,
	input logic reset
);
	/* Temporary, will be replaced by actual memory */
	logic [(FETCH_WIDTH*2)-1:0] batch_memory;
	initial begin
		batch_memory[0] = 1'h0;
		batch_memory[35:1] = 35'h0;
		batch_memory[255:36] = 220'h55555555555_44444444444_33333333333_22222222222_11111111111;

		batch_memory[256] = 1'h1;
		batch_memory[256+35:256+1] = 35'h0;
		batch_memory[256+255:256+36] = 220'hAAAAAAAAAAA_99999999999_88888888888_77777777777_66666666666;
	end


	logic [ADDRESS_WIDTH-1:0] pc;

	logic [FETCH_WIDTH-1:0] fetchBuffer;
	logic [FUNCTIONAL_UNITS-1:0] stopDaisyChain;
	logic [$clog2(FUNCTIONAL_UNITS)-1:0] nextBatch;
	logic doneFetch, haltFetch, endBatches, doneBatches, doingFetch;

	always_ff @( posedge clock ) begin
		if (reset) begin
			fetchBuffer <= 0;
			pc <= 0;
			haltFetch <= 0;
			doneFetch <= 0;
		end else if (doneBatches) begin 
			haltFetch <= 0;
			doingFetch <= 1;
		end else if (haltFetch) begin 
			/* Block fetches from occuring */
			endBatches <= 0;
		end else if (doneFetch) begin
			if (nextBatch != 0) begin
				pc <= pc + (nextBatch * BATCH_WIDTH_BYTES);
				haltFetch <= 1;
				endBatches <= 1;
			end else begin 
				pc <= pc + BATCH_WIDTH_BYTES;
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
					stopDaisyChain[batchIndex+1] = fetchBuffer[batchIndex*BATCH_WIDTH+:BATCH_WIDTH][0];
				end else begin
					nextBatch = batchIndex;
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
