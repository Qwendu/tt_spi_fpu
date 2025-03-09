`default_nettype none


// In reference to http://users.encs.concordia.ca/~asim/COEN_6501/Lecture_Notes/L4_Slides.pdf


`define WIDTH (MANTISSA_WIDTH + EXPONENT_WIDTH + 1)
`define EXP(f) f[MANTISSA_WIDTH +: EXPONENT_WIDTH]
`define MAN(f) f[0              +: MANTISSA_WIDTH]
`define SIGN(f) f[MANTISSA_WIDTH + EXPONENT_WIDTH]
module float_adder_v2 #(
	parameter MANTISSA_WIDTH = 23,
	parameter EXPONENT_WIDTH = 8
) (
	input clock,
	input reset,
	input                 in_valid,
	input  [`WIDTH - 1:0] in_a,
	input  [`WIDTH - 1:0] in_b,
	output                out_valid,
	output [`WIDTH - 1:0] out,

	/* verilator lint_off UNUSED */
	input [`WIDTH - 1 :0] out_reference

);

	wire [EXPONENT_WIDTH - 1 : 0] ref_exp;
	wire [MANTISSA_WIDTH - 1 : 0] ref_man;
	assign ref_exp = `EXP(out_reference);
	assign ref_man = `MAN(out_reference);
	/* verilator lint_on UNUSED */


	// Stage 1
	//  Swap inputs correct way around
	//  compute exponent difference

	reg s1_valid;
	reg s1_nan;
	reg s1_inf;
	reg [`WIDTH - 1 : 0] s1_smaler;
	reg [`WIDTH - 1 : 0] s1_larger;
	reg [EXPONENT_WIDTH - 1 : 0] s1_in_a_exp_comb;
	reg [EXPONENT_WIDTH - 1 : 0] s1_in_b_exp_comb;
	reg signed [EXPONENT_WIDTH + 1:0] s1_exponent_difference_comb;
	reg [EXPONENT_WIDTH + 1:0] s1_exp_diff;

	reg s1_a_nan_comb;
	reg s1_b_nan_comb;
	reg s1_a_inf_comb;
	reg s1_b_inf_comb;
	always @(*)
	begin
		s1_in_a_exp_comb = `EXP(in_a) == 0 ? 1 : `EXP(in_a);
		s1_in_b_exp_comb = `EXP(in_b) == 0 ? 1 : `EXP(in_b);
		s1_exponent_difference_comb = $signed({2'sb0, s1_in_a_exp_comb}) - $signed({2'sb0, s1_in_b_exp_comb});
	end
	reg s1_flip;

	always @(*)
		s1_flip = s1_exponent_difference_comb < 0;
	always @(*)
	begin
		s1_a_nan_comb = ((`EXP(in_a) == (1 << EXPONENT_WIDTH) - 1) &&  |`MAN(in_a));
		s1_b_nan_comb = ((`EXP(in_b) == (1 << EXPONENT_WIDTH) - 1) &&  |`MAN(in_b));
		s1_a_inf_comb = ((`EXP(in_a) == (1 << EXPONENT_WIDTH) - 1) && ~|`MAN(in_a));
		s1_b_inf_comb = ((`EXP(in_b) == (1 << EXPONENT_WIDTH) - 1) && ~|`MAN(in_b));
	end

	always @(posedge clock) if(reset) s1_valid <= 0; else
	begin
		s1_valid <= in_valid;
		s1_exp_diff <= s1_flip ? -s1_exponent_difference_comb : s1_exponent_difference_comb;
		s1_larger   <= s1_flip ? in_b : in_a;
		s1_smaler   <= s1_flip ? in_a : in_b;
		s1_nan      <= s1_a_nan_comb || s1_b_nan_comb || (`SIGN(in_a) != `SIGN(in_b) && s1_a_inf_comb && s1_b_inf_comb);
		s1_inf      <= ((`SIGN(in_a) & `SIGN(in_b)) & s1_a_inf_comb & s1_b_inf_comb) || ((`SIGN(in_a) != `SIGN(in_b)) & (s1_a_inf_comb ^ s1_b_inf_comb));
	end


	// Stage 2
	//  Right shifter
	//  bit inverter
	reg s2_valid;
	reg s2_flip_sign;
	reg s2_nan;
	reg s2_inf;
	reg s2_shared_sign;
	reg  signed [2 * MANTISSA_WIDTH + 3 - 1 : 0] s2_smaler_mant_expanded_comb;
	reg  signed [2 * MANTISSA_WIDTH + 3 - 1 : 0] s2_larger_mant_expanded_comb;
	wire signed [2 * MANTISSA_WIDTH + 3 - 1 : 0] s2_smaler_mant_comb;
	reg  signed [2 * MANTISSA_WIDTH + 3 - 1 : 0] s2_smaler;
	reg  signed [2 * MANTISSA_WIDTH + 3 - 1 : 0] s2_larger;
	reg  signed [EXPONENT_WIDTH + 1 : 0] s2_exponent;
	always @(*)
	begin
		s2_smaler_mant_expanded_comb = 0;
		s2_larger_mant_expanded_comb = 0;
		s2_smaler_mant_expanded_comb[MANTISSA_WIDTH +: MANTISSA_WIDTH + 1] = {`EXP(s1_smaler) == 0 ? 1'b0 : 1'b1, `MAN(s1_smaler)};
		s2_larger_mant_expanded_comb[MANTISSA_WIDTH +: MANTISSA_WIDTH + 1] = {`EXP(s1_larger) == 0 ? 1'b0 : 1'b1, `MAN(s1_larger)};
	end
	right_shifter #(
		.WIDTH(2 * MANTISSA_WIDTH + 3)
	) s1_rs (
		.value(s2_smaler_mant_expanded_comb),
		.ammount(s1_exp_diff > 10'b11_1111 ? 6'b11_1111 : s1_exp_diff[5:0]),
		.result(s2_smaler_mant_comb)
	);

	always @(posedge clock) if(reset) s2_valid <= 0; else
	begin
		s2_valid <= s1_valid;
		s2_flip_sign <= `SIGN(s1_smaler) ^ `SIGN(s1_larger);
		s2_smaler <= s2_smaler_mant_comb;
		s2_larger <= s2_larger_mant_expanded_comb;
		s2_exponent <= {2'sb0, `EXP(s1_larger)};
		s2_nan <= s1_nan;
		s2_inf <= s1_inf;
		s2_shared_sign <= `SIGN(s1_larger);
	end

	// Stage 3
	//  Addition

	reg s3_valid;
	reg s3_nan;
	reg s3_inf;
	reg s3_flipped;
	reg s3_shared_sign;
	reg  signed [2 * MANTISSA_WIDTH + 3 - 1 : 0] s3_sum;
	reg  signed [EXPONENT_WIDTH + 1 : 0] s3_exponent;
	
	always @(posedge clock) if(reset) s3_valid <= 0; else
	begin
		s3_valid <= s2_valid;
		s3_sum   <= s2_smaler + (s2_flip_sign ? -s2_larger : s2_larger);
		s3_exponent <= s2_exponent;
		s3_nan <= s2_nan;
		s3_inf <= s2_inf;
		s3_flipped <= s2_flip_sign;
		s3_shared_sign <= s2_shared_sign;
	end



	// Stage 4
	//  first bit position
	reg s4_valid;
	reg s4_flipped;
	reg s4_shared_sign;
	reg s4_nan;
	reg s4_inf;
	reg  signed [EXPONENT_WIDTH + 1 : 0] s4_exponent;
	reg  [EXPONENT_WIDTH + 1 : 0] s4_exponent_adjust_comb;
	reg  [2 * MANTISSA_WIDTH + 3 - 1 : 0] s4_mant_comb;
	reg  [EXPONENT_WIDTH + 1 : 0] s4_exponent_adjust;
	reg  [2 * MANTISSA_WIDTH + 3 - 1 : 0] s4_mant;
	reg  signed [2 * MANTISSA_WIDTH + 3 - 1 : 0] s4_sum;
	wire [5:0] s4_pos;

	always @(*)
	begin
		s4_mant_comb =  s3_sum < 0 ? -s3_sum : s3_sum;
		s4_exponent_adjust_comb = LEADING_1_POSITION - {4'b0, s4_pos};
		if(s4_exponent_adjust_comb > s3_exponent)
		begin
			s4_exponent_adjust_comb = s3_exponent + 1;
		end
	end

	first_bit_position #(
		.WIDTH(2 * MANTISSA_WIDTH + 3)
	) s5_fbp (
		.value(s4_mant_comb),
		.pos(s4_pos)
	);


	always @(posedge clock) if(reset) s4_valid <= 0; else
	begin
		s4_valid <= s3_valid;
		s4_exponent_adjust <= s4_exponent_adjust_comb;
		s4_mant <= s4_mant_comb;
		s4_flipped <= s3_flipped;
		s4_shared_sign <= s3_shared_sign;
		s4_sum <= s3_sum;
		s4_exponent <= s3_exponent;
		s4_nan <= s3_nan;
		s4_inf <= s3_inf;
	end

	localparam LEADING_1_POSITION = 2 * MANTISSA_WIDTH + 1;





	// Stage 5
	//  Complement
	reg s5_valid;
	reg s5_sign;
	reg [MANTISSA_WIDTH : 0] s5_mant;
	reg s5_R;
	reg s5_S;
	reg s5_nan;
	reg s5_inf;


	reg  signed [EXPONENT_WIDTH + 1: 0] s5_exponent;

	wire [2 * MANTISSA_WIDTH + 3 - 1 : 0] s5_mant_shifted_comb;

	left_shifter #(
		.WIDTH(2 * MANTISSA_WIDTH + 3)
	) s5_ls (
		.value(s4_mant),
		.ammount(s4_exponent_adjust > 10'b11_1111 ? 6'b11_1111 : s4_exponent_adjust[5:0]),
		.result(s5_mant_shifted_comb)
	);


	always @(posedge clock) if(reset) s5_valid <= 0; else
	begin
		s5_valid <= s4_valid;
		if(s4_flipped)
			s5_sign <= s4_sum < 0 ^ (s4_shared_sign ^ s4_flipped);
		else
			s5_sign <= s4_shared_sign;
		s5_mant <=  s5_mant_shifted_comb[MANTISSA_WIDTH + 1 +: MANTISSA_WIDTH + 1];
		s5_R    <=  s5_mant_shifted_comb[MANTISSA_WIDTH + 0 +: 1];
		s5_S    <= |s5_mant_shifted_comb[MANTISSA_WIDTH - 1  : 0];
		if(s3_exponent == 0 && s5_mant_shifted_comb[LEADING_1_POSITION])
			s5_exponent <= s4_exponent - s4_exponent_adjust + 2;
		else
			s5_exponent <= s4_exponent - s4_exponent_adjust + 1;
		s5_nan <= s4_nan;
		s5_inf <= s4_inf;
	end

	// Stage 6
	//  Rounding
	//  Overflow

	reg s6_valid;
	reg s6_sign;
	reg [MANTISSA_WIDTH - 1 : 0] s6_mant;
	reg [EXPONENT_WIDTH - 1 : 0] s6_expo;

	reg [MANTISSA_WIDTH     : 0] s6_mant_comb;
	reg signed [EXPONENT_WIDTH + 1 : 0] s6_expo_comb;
	always @(*)
	if((s5_R & s5_S) || (s5_mant[0] & s5_R & !s5_S))
	begin
		if(&s5_mant)
		begin
			if(s5_exponent == (1 << EXPONENT_WIDTH) - 2)
				s6_expo_comb = (1 << EXPONENT_WIDTH) - 1;
			else
				s6_expo_comb = s5_exponent + 1;
			s6_mant_comb = 0;
		end else
		begin
			s6_mant_comb = s5_mant + 1;
			s6_expo_comb = s5_exponent;
		end
		
	end else
	begin
		s6_expo_comb = s5_exponent;
		s6_mant_comb = s5_mant;
	end


	always @(posedge clock) if (reset) s6_valid <= 0; else
	begin
		s6_valid <= s5_valid;
		s6_sign <= s5_sign;
		if(s5_nan)
		begin
			s6_expo <= (1 << EXPONENT_WIDTH) - 1;
			s6_mant <= 1;
		end else if(s5_inf || s6_expo_comb >= (1 << EXPONENT_WIDTH) - 1) begin
			s6_expo <= (1 << EXPONENT_WIDTH) - 1;
			s6_mant <= 0;
		end else begin
			s6_expo <= s6_mant_comb == 0 ? 0 : s6_expo_comb[EXPONENT_WIDTH - 1 : 0];
			s6_mant <= s6_mant_comb[MANTISSA_WIDTH - 1 : 0];
		end


	end




	assign out_valid = s6_valid;
	assign out       = {s6_sign, s6_expo, s6_mant};
endmodule



