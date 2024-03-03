
localparam PIPELINE_STAGES = 4;
localparam DECODE_STAGE = 0;
localparam EXECUTE_STAGE = 1;
localparam MEMORY_STAGE = 2;
localparam WRITEBACK_STAGE = 3;

module functionalUnit #(
	FUID
) (
	input logic clock,
	input logic reset,

	input logic [BATCH_WIDTH-1:0] batch,

	input logic endTag,

	output logic doneBatches
);

	logic [INSTRUCTION_WIDTH-1:0] pipelinedInstructions [BATCH_INSTRUCTION_WIDTH-1:0] [PIPELINE_STAGES-1:0];
	logic [FORMAT_WIDTH-1:0] pipelinedFormats [BATCH_INSTRUCTION_WIDTH-1:0] [PIPELINE_STAGES-1:0];
	logic endTagPipeline [PIPELINE_STAGES-1:0];


	always_ff @( posedge clock ) begin
		if (reset) begin
			endTagPipeline[0] <= 0;
		end else begin
			endTagPipeline[0] <= endTag;
		end
	end

	always_ff @( posedge clock ) begin
		if (reset) begin
			doneBatches <= 0;
		end else begin
			doneBatches <= endTagPipeline[PIPELINE_STAGES-1];
		end
	end

	generate
		genvar instrId;
		genvar pipelineStage;

		for (instrId = 0; instrId < BATCH_INSTRUCTION_WIDTH ; instrId++ ) begin

			always_ff @( posedge clock ) begin
				if (reset) begin
					pipelinedInstructions[instrId][0] <= 0;
					pipelinedFormats[instrId][0] <= 0;
				end else begin 
					pipelinedInstructions[instrId][0] <= batch[METADATA_WIDTH+(instrId*INSTRUCTION_WIDTH)+:INSTRUCTION_WIDTH];
					pipelinedFormats[instrId][0] <= batch[1+(instrId*FORMAT_WIDTH)+:FORMAT_WIDTH];
				end
			end

			for (pipelineStage = 1; pipelineStage < PIPELINE_STAGES ; pipelineStage++ ) begin
				always_ff @( posedge clock ) begin
					if (reset) begin
						pipelinedInstructions[instrId][pipelineStage] <= 0;
						pipelinedFormats[instrId][pipelineStage] <= 0;
						endTagPipeline[pipelineStage] <= 0;
					end else begin
						pipelinedInstructions[instrId][pipelineStage] <= pipelinedInstructions[instrId][pipelineStage-1];
						pipelinedFormats[instrId][pipelineStage] <= pipelinedFormats[instrId][pipelineStage-1];
						endTagPipeline[pipelineStage] <= endTagPipeline[pipelineStage-1];
					end
				end
			end
		end
	endgenerate
	
endmodule
