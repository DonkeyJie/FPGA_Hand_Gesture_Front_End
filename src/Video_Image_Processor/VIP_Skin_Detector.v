/*-----------------------------------------------------------------------
								 \\\|///
							   \\  - -  //
								(  @ @  )
+-----------------------------oOOo-(_)-oOOo-----------------------------+
CONFIDENTIAL IN CONFIDENCE
This confidential and proprietary software may be only used as authorized
by a licensing agreement from CrazyBingo (Thereturnofbingo).
In the event of publication, the following notice is applicable:
Copyright (C) 2011-20xx CrazyBingo Corporation
The entire notice above must be reproduced on all authorized copies.
Author				:		CrazyBingo
Technology blogs 	: 		http://blog.chinaaet.com/crazybingo
Email Address 		: 		thereturnofbingo@gmail.com
Filename			:		VIP_Sobel_Edge_Detector.v
Data				:		2013-05-26
Description			:		Image edge detector with Sobel.
							Give up the 1th and 2th row edge data caculate for simple process
							Give up the 1th and 2th point of 1 line for simple process
Modification History	:
Data			By			Version			Change Description
=========================================================================
13/05/26		CrazyBingo	1.0				Original
14/03/16		CrazyBingo	2.0				Modification
-------------------------------------------------------------------------
|                                     Oooo								|
+-------------------------------oooO--(   )-----------------------------+
                               (   )   ) /
                                \ (   (_/
                                 \_)
-----------------------------------------------------------------------*/ 

`timescale 1ns/1ns
module VIP_Skin_Detector
#(
	parameter	[9:0]	IMG_HDISP = 10'd640,	//640*480
	parameter	[9:0]	IMG_VDISP = 10'd480
)
(
	//global clock
	input	clk,
	input	rst_n,
	
	//Image data prepred to be processd
	input				per_frame_vsync,	//Prepared Image data vsync valid signal
	input				per_frame_href,		//Prepared Image data href vaild  signal
	input				per_frame_clken,	//Prepared Image data output/capture enable clock
	input		[7:0]	per_img_Y,			//Prepared Image brightness input
	input		[7:0]	per_img_Cb,			//Prepared Image brightness input
	input		[7:0]	per_img_Cr,			//Prepared Image brightness input
	
	//Image data has been processd
	output				post_frame_vsync,	//Processed Image data vsync valid signal
	output				post_frame_href,	//Processed Image data href vaild  signal
	output				post_frame_clken,	//Processed Image data output/capture enable clock
	output				post_img		//Processed Image Bit flag outout(1: Value, 0:inValid)
	
	//user interface
);

reg Detect_by_YCbCr;
// detector
always @(posedge clk or negedge rst_n)
begin
	if(~rst_n)
		Detect_by_YCbCr <= 0;
	else
		Detect_by_YCbCr <= ((per_img_Cb >(100)) &&  (per_img_Cb < (127)) && (per_img_Cr >(133)) && (per_img_Cr < (173))) ? 1 : 0;
end
assign	post_frame_vsync 	= 	per_frame_vsync;
assign	post_frame_href 	= 	per_frame_href;
assign	post_frame_clken 	= 	per_frame_clken;
assign	post_img		=	Detect_by_YCbCr;
endmodule