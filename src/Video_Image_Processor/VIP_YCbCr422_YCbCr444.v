/*-----------------------------------------------------------------------
								 \\\|///
							   \\  - -  //
								(  @ @  )
+-----------------------------oOOo-(_)-oOOo-----------------------------+
CONFIDENTIAL IN CONFIDENCE
This confidential and proprietary software may be only used as authorized
by a licensing agreement from CrazyBingo (Thereturnofbingo).
In the event of publication, the following notice is applicable:
Copyright (C) 2013-20xx CrazyBingo Corporation
The entire notice above must be reproduced on all authorized copies.
Author				:		CrazyBingo
Technology blogs 	: 		http://blog.chinaaet.com/crazybingo
Email Address 		: 		thereturnofbingo@gmail.com
Filename			:		VIP_YCbCr422_YCbCr444.v
Data				:		2014-05-03
Description			:		The testbench of VIP_YCbCr422_YCbCr444.
Modification History	:
Data			By			Version			Change Description
=========================================================================
14/05/03		CrazyBingo	1.0				Original
-------------------------------------------------------------------------
|                                     Oooo								|
+-------------------------------oooO--(   )-----------------------------+
                               (   )   ) /
                                \ (   (_/
                                 \_)
-----------------------------------------------------------------------*/

`timescale 1ns/1ns
module VIP_YCbCr422_YCbCr444
(
	//global clock
	input				clk,  				//cmos video pixel clock
	input				rst_n,				//global reset

	//CMOS 16Bit YCbCr data input:	{CbYCrYCbYCrY}
	input				per_frame_vsync,	//Prepared Image data vsync valid signal
	input				per_frame_href,		//Prepared Image data href vaild  signal
	input				per_frame_clken,	//Prepared Image data output/capture enable clock	
	input		[15:0]	per_frame_YCbCr,	//Prepared Image data of YCbCr 4:2:2 {CbY} {CrY}
	
	//CMOS YCbCr444 data output
	output				post_frame_vsync,	//Processed Image data vsync valid signal
	output				post_frame_href,	//Processed Image data href vaild  signal
	output				post_frame_clken,	//Processed Image data output/capture enable clock	
	output	reg	[7:0]	post_img_Y,			//Processed Image data of YCbCr 4:4:4
	output	reg	[7:0]	post_img_Cb,		//Processed Image data of YCbCr 4:4:4
	output	reg	[7:0]	post_img_Cr			//Processed Image data of YCbCr 4:4:4
);

//------------------------------------------
//lag n pixel clocks	 
reg	[4:0]	post_frame_vsync_r;
reg	[4:0]	post_frame_href_r;
reg	[4:0]	post_frame_clken_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		post_frame_vsync_r 	<= 	0;
		post_frame_href_r 	<= 	0;
		post_frame_clken_r 	<= 	0;
		end
	else
		begin
		post_frame_vsync_r 	<= 	{post_frame_vsync_r[3:0], per_frame_vsync};
		post_frame_href_r 	<= 	{post_frame_href_r[3:0], per_frame_href};
		post_frame_clken_r 	<= 	{post_frame_clken_r[3:0], per_frame_clken};
		end
end
assign	post_frame_vsync 	= 	post_frame_vsync_r[4];
assign	post_frame_href 	= 	post_frame_href_r[4];
assign	post_frame_clken 	= 	post_frame_clken_r[4];
wire	yuv_process_href	= 	per_frame_href || post_frame_href_r[3];
wire	yuv_process_clken	= 	per_frame_clken || post_frame_clken_r[3];



//-------------------------------------------
//convert YCbCr422 to YCbCr444
reg	[2:0]	yuv_state;
reg	[7:0]	mY0, mY1, mY2, mY3;
reg	[7:0]	mCb0, mCb1;
reg	[7:0]	mCr0, mCr1;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		yuv_state <= 3'd0;
		{mY0, mCb0, mCr0} <= {8'h0, 8'h0, 8'h0};
		mY1 <= 8'h0;
		{mY2, mCb1, mCr1} <= {8'h0, 8'h0, 8'h0};
		mY3	<= 8'h0;
		{post_img_Y, post_img_Cb, post_img_Cr} <= {8'h0, 8'h0, 8'h0};
		end
	else if(yuv_process_href)	//lag 2 data enable clock and need 2 more clocks
		begin
		if(yuv_process_clken)	//lag 2 data enable clock and need 2 more clocks
			case(yuv_state)		//{Cb,Y},{Cr,Y}---YCbCr
			3'd0:	begin	//reg p0
					yuv_state <= 3'd1;	
					{mCb0, mY0} <= per_frame_YCbCr;	
					end		
			3'd1:	begin	//reg p1
					yuv_state <= 3'd2;	
					{mCr0, mY1} <= per_frame_YCbCr;	
					end		
			
			3'd2:	begin	//p0;	reg p2
					yuv_state <= 3'd3;	
					{mCb1, mY2} <= per_frame_YCbCr;	
					{post_img_Y, post_img_Cb, post_img_Cr} <= {mY0, mCb0, mCr0};	
					end	
			3'd3:	begin	//p1;	reg p3
					yuv_state <= 3'd4;	
					{mCr1, mY3} <= per_frame_YCbCr;	
					{post_img_Y, post_img_Cb, post_img_Cr} <= {mY1, mCb0, mCr0};
					end	
			3'd4:	begin	//p2;	reg	p0
					yuv_state <= 3'd5;	
					{mCb0, mY0} <= per_frame_YCbCr;	
					{post_img_Y, post_img_Cb, post_img_Cr} <= {mY2, mCb1, mCr1};	
					end		//p3;	reg p1
			3'd5:	begin	
					yuv_state <= 3'd2;	
					{mCr0, mY1} <= per_frame_YCbCr;	
					{post_img_Y, post_img_Cb, post_img_Cr} <= {mY3, mCb1, mCr1};	
					end	
			endcase
		else
			begin
			yuv_state <= yuv_state;
			{mY0, mCb0, mCr0} <= {mY0, mCb0, mCr0};
			mY1 <= mY1;
			{mY2, mCb1, mCr1} <= {mY2, mCb1, mCr1};
			mY3	<= mY3;
			{post_img_Y, post_img_Cb, post_img_Cr} <= {post_img_Y, post_img_Cb, post_img_Cr};
			end
		end
	else
		begin
		yuv_state <= 3'd0;
		{mY0, mCb0, mCr0} <= {8'h0, 8'h0, 8'h0};
		{mY1, mCb1, mCr1} <= {8'h0, 8'h0, 8'h0};
		{post_img_Y, post_img_Cb, post_img_Cr} <= {8'h0, 8'h0, 8'h0};
		end
end



endmodule
