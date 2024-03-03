
localparam PIPELINE_STAGES = 4;
localparam DECODE_STAGE = 0;
localparam EXECUTE_STAGE = 1;
localparam MEMORY_STAGE = 2;
localparam WRITEBACK_STAGE = 3;

localparam MEMORY_FORMAT = 0;
localparam IALU_FORMAT = 1;

module functionalUnit #(
	FUID
) (
	input logic clock,
	input logic reset,

	input logic [BATCH_WIDTH-1:0] batch,

	input logic endTag,

	output logic doneBatches
);

	logic [INSTRUCTION_WIDTH-1:0] instructionPipeline [PIPELINE_STAGES-1:0];
	logic [FORMAT_WIDTH-1:0] formatPipeline [PIPELINE_STAGES-1:0];
	logic endTagPipeline [PIPELINE_STAGES-1:0];


	always_ff @( posedge clock ) begin
		if (reset) begin
			doneBatches <= 0;
			instructionPipeline[0] <= 0;
			formatPipeline[0] <= 0;
			endTagPipeline[0] <= 0;
		end else begin
			instructionPipeline[0] <= batch[METADATA_WIDTH+:INSTRUCTION_WIDTH];
			formatPipeline[0] <= batch[1+:FORMAT_WIDTH];
			endTagPipeline[0] <= endTag;
			doneBatches <= endTagPipeline[PIPELINE_STAGES-1];
		end
	end

	generate
		genvar pipelineStage;

		for (pipelineStage = 1; pipelineStage < PIPELINE_STAGES ; pipelineStage++ ) begin
			always_ff @( posedge clock ) begin
				if (reset) begin
					instructionPipeline[pipelineStage] <= 0;
					formatPipeline[pipelineStage] <= 0;
					endTagPipeline[pipelineStage] <= 0;
				end else begin
					instructionPipeline[pipelineStage] <= instructionPipeline[pipelineStage-1];
					formatPipeline[pipelineStage] <= formatPipeline[pipelineStage-1];
					endTagPipeline[pipelineStage] <= endTagPipeline[pipelineStage-1];
				end
			end
		end
	endgenerate
	
endmodule
