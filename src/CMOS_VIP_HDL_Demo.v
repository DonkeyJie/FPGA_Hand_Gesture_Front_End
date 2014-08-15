/*-----------------------------------------------------------------------
								 \\\|///
							   \\  - -  //
								(  @ @  )
+-----------------------------oOOo-(_)-oOOo-----------------------------+
CONFIDENTIAL IN CONFIDENCE
This confidential and proprietary software may be only used as authorized
by a licensing agreement from CrazyBingo (Thereturnofbingo).
In the event of publication, the following notice is applicable:
Copyright (C) 2012-20xx CrazyBingo Corporation
The entire notice above must be reproduced on all authorized copies.
Author				:		CrazyBingo
Technology blogs 	: 		http://blog.chinaaet.com/crazybingo
Email Address 		: 		thereturnofbingo@gmail.com
Filename			:		CMOS_VIP_HDL_Demo.v
Data				:		2014-05-16
Description			:		Convert RAW to RGB888.
Modification History	:
Data			By			Version			Change Description
=========================================================================
14/05/18		CrazyBingo	1.0				Original
-------------------------------------------------------------------------
|                                     Oooo								|
+------------------------------oooO--(   )-----------------------------+
                              (   )   ) /
                               \ (   (_/
                                \_)
----------------------------------------------------------------------*/ 

`timescale 1ns / 1ns
module CMOS_VIP_HDL_Demo
(
	//global clock 50MHz
	input				clk,			//50MHz
	input				rst_n,			//global reset
	
	//sdram control
	output				sdram_clk,		//sdram clock
	output				sdram_cke,		//sdram clock enable
	output				sdram_cs_n,		//sdram chip select
	output				sdram_we_n,		//sdram write enable
	output				sdram_cas_n,	//sdram column address strobe
	output				sdram_ras_n,	//sdram row address strobe
//	output		[3:0]	sdram_dqm,		//sdram data enable
	output		[1:0]	sdram_ba,		//sdram bank address
	output		[11:0]	sdram_addr,		//sdram address
	inout		[23:0]	sdram_data,		//sdram data
	
	//lcd port
	output				lcd_dclk,		//lcd pixel clock			
	output				lcd_hs,			//lcd horizontal sync 
	output				lcd_vs,			//lcd vertical sync
//	output				lcd_sync,		//lcd sync
	output				lcd_blank,		//lcd blank(L:blank)
	output		[7:0]	lcd_red,		//lcd red data
	output		[7:0]	lcd_green,		//lcd green data
	output		[7:0]	lcd_blue,		//lcd blue data

	//cmos interface
	output				cmos_sclk,		//cmos i2c clock
	inout				cmos_sdat,		//cmos i2c data
	input				cmos_pclk,		//cmos pxiel clock
	output				cmos_xclk,		//cmos externl clock
	input				cmos_vsync,		//cmos vsync
	input				cmos_href,		//cmos hsync refrence
	input		[7:0]	cmos_data,		//cmos data

	//user interface
	input		[1:0]	key_data,
	
	//74595 led interface
	output				led595_dout,	//74hc595 serial data input	
	output				led595_clk,		//74hc595 shift clock (rising edge)
	output				led595_latch	//74hc595 latch clock (risign edge)
);

//---------------------------------------------
//system global clock control
wire	sys_rst_n;		//global reset
wire	clk_ref;		//sdram ctrl clock
wire	clk_refout;		//sdram clock output
wire	clk_vga;		//vga clock
wire	clk_cmos;		//24MHz cmos clock
wire	clk_48M;		//48MHz SignalTap II Clock
system_ctrl_pll	u_system_ctrl_pll
(
	.clk				(clk),			//global clock
	.rst_n				(rst_n),		//external reset
	
	.sys_rst_n			(sys_rst_n),	//global reset
	.clk_c0				(clk_ref),		//100MHz 
	.clk_c1				(clk_refout),	//100MHz -90deg
	.clk_c2				(clk_vga),		//25MHz
	.clk_c3				(clk_cmos)		//24MHz
//	.clk_c4				(clk_48M)		//48MHz SignalTap II Clock
);
localparam	CLOCK_MAIN	=	100_000000;
localparam	CLOCK_CMOS	=	24_000000;

//----------------------------------------------
//i2c timing controller module
wire	[7:0]	i2c_config_index;
wire	[15:0]	i2c_config_data;
wire	[7:0]	i2c_config_size;
wire			i2c_config_done;
wire	[7:0]	i2c_rdata;		//i2c register data
i2c_timing_ctrl
#(
	.CLK_FREQ	(CLOCK_MAIN),	//100 MHz
	.I2C_FREQ	(400_000)		//10 KHz(<= 400KHz)
)
u_i2c_timing_ctrl
(
	//global clock
	.clk				(clk_ref),		//100MHz
	.rst_n				(sys_rst_n),	//system reset
			
	//i2c interface
	.i2c_sclk			(cmos_sclk),	//i2c clock
	.i2c_sdat			(cmos_sdat),	//i2c data for bidirection

	//i2c config data
	.i2c_config_index	(i2c_config_index),	//i2c config reg index, read 2 reg and write xx reg
	.i2c_config_data	({8'h42, i2c_config_data}),	//i2c config data
	.i2c_config_size	(i2c_config_size),	//i2c config data counte
	.i2c_config_done	(i2c_config_done),	//i2c config timing complete
	.i2c_rdata			(i2c_rdata)			//i2c register data while read i2c slave
);

//----------------------------------------------
//I2C Configure Data of OV7725
//I2C_OV7725_RGB565_Config	u_I2C_OV7725_RGB565_Config
I2C_OV7725_YUV422_Config	u_I2C_OV7725_YUV422_Config
(
	.LUT_INDEX		(i2c_config_index),
	.LUT_DATA		(i2c_config_data),
	.LUT_SIZE		(i2c_config_size)
);


//--------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------
//cmos video image capture
wire			cmos_init_done = i2c_config_done;	///cmos camera init done
wire			cmos_frame_vsync;	//cmos frame data vsync valid signal
wire			cmos_frame_href;	//cmos frame data href vaild  signal
//wire	[15:0]	cmos_frame_data;	//cmos frame data output: {cmos_data[7:0]<<8, cmos_data[7:0]}	
wire			cmos_frame_clken;	//cmos frame data output/capture enable clock
wire	[7:0]	cmos_fps_rate;		//cmos image output rate
wire	[7:0]	cmos_frame_Y;
wire	[7:0]	cmos_frame_CbCr;
CMOS_Capture_RGB565	
#(
	.CMOS_FRAME_WAITCNT		(4'd10)				//Wait n fps for steady(OmniVision need 10 Frame)
)
u_CMOS_Capture_RGB565
(
	//global clock
	.clk_cmos				(clk_cmos),			//24MHz CMOS Driver clock input
	.rst_n					(sys_rst_n & cmos_init_done),	//global reset

	//CMOS Sensor Interface
	.cmos_pclk				(cmos_pclk),  		//24MHz CMOS Pixel clock input
	.cmos_xclk				(cmos_xclk),		//24MHz drive clock
	.cmos_data				(cmos_data),		//8 bits cmos data input
	.cmos_vsync				(cmos_vsync),		//L: vaild, H: invalid
	.cmos_href				(cmos_href),		//H: vaild, L: invalid
	
	//CMOS SYNC Data output
	.cmos_frame_vsync		(cmos_frame_vsync),	//cmos frame data vsync valid signal
	.cmos_frame_href		(cmos_frame_href),	//cmos frame data href vaild  signal
	.cmos_frame_data		({cmos_frame_Y, cmos_frame_CbCr}),	//cmos frame RGB output: {{R[4:0],G[5:3]}, {G2:0}, B[4:0]}	
	.cmos_frame_clken		(cmos_frame_clken),	//cmos frame data output/capture enable clock
	
	//user interface
	.cmos_fps_rate			(cmos_fps_rate)		//cmos image output rate
);
//wire	[7:0]	led_data = cmos_fps_rate;
//wire	[7:0]	led_data = LUT_INDEX;
//wire	[7:0]	led_data = i2c_rdata;



//----------------------------------------------------
//Video Image processor module.
//Image data prepred to be processd
wire			per_frame_vsync	=	cmos_frame_vsync;	//Prepared Image data vsync valid signal
wire			per_frame_href	=	cmos_frame_href;	//Prepared Image data href vaild  signal
wire			per_frame_clken	=	cmos_frame_clken;	//Prepared Image data output/capture enable clock
wire	[15:0]	per_img_YCbCr	=	{cmos_frame_CbCr, cmos_frame_Y};		//Prepared Image brightness output
wire			post_frame_vsync;	//Processed Image data vsync valid signal
wire			post_frame_href;	//Processed Image data href vaild  signal
wire			post_frame_clken;	//Processed Image data output/capture enable clock
wire			post_img;		//Processed Image brightness output
Video_Image_Processor	u_Video_Image_Processor
(
	//global clock
	.clk					(cmos_pclk),  			//cmos video pixel clock
	.rst_n					(sys_rst_n),			//global reset

	//Image data prepred to be processd
	.per_frame_vsync		(per_frame_vsync),		//Prepared Image data vsync valid signal
	.per_frame_href			(per_frame_href),		//Prepared Image data href vaild  signal
	.per_frame_clken		(per_frame_clken),		//Prepared Image data output/capture enable clock
	.per_frame_YCbCr			(per_img_YCbCr),			//Prepared Image brightness input

	//Image data has been processd
	.post_frame_vsync		(post_frame_vsync),		//Processed Image data vsync valid signal
	.post_frame_href		(post_frame_href),		//Processed Image data href vaild  signal
	.post_frame_clken		(post_frame_clken),		//Processed Image data output/capture enable clock
	.post_img			(post_img),			//Processed Image Bit flag outout(1: Value, 0:inValid)
	
	//User interface
	.Sobel_Threshold		(Sobel_Threshold)		//Sobel Threshold for image edge detect
);

//--------------------------------------------------------------------
//--------------------------------------------------------------------
//Key scan with jitter detect
wire			key_flag;
wire	[1:0]	key_value;
key_counter_scan
#(
	.KEY_WIDTH	(2)
)
u_key_counter_scan
(
	//global
	.clk				(clk_ref),
	.rst_n				(rst_n),
	
	//key interface
	.key_data			(key_data),		
	
	//user interface
	.key_flag			(key_flag),
	.key_value			(key_value)	
);

//--------------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------
//Sdram_Control_2Port module 	
//sdram write port
wire			clk_write	=	cmos_pclk;	//Change with input signal											
wire	[23:0]	sys_data_in = 	post_img ? {3{8'b1111_1111}} : 0;	//White: 24'hFF;	Black: 24'h00(Input value bit : 1)
wire			sys_we 		= 	 cmos_frame_clken;
//sdram read port
wire			clk_read	=	clk_vga;	//Change with vga timing	
wire	[23:0]	sys_data_out;
wire			sys_rd;
wire			sdram_init_done;			//sdram init done
Sdram_Control_2Port	u_Sdram_Control_2Port
(
	//	HOST Side
	.REF_CLK			(clk_ref),			//sdram module clock
	.OUT_CLK			(clk_refout),		//sdram clock input
	.RESET_N			(sys_rst_n),		//sdram module reset

	//	SDRAM Side
	.SDR_CLK			(sdram_clk),		//sdram clock
	.CKE				(sdram_cke),		//sdram clock enable
	.CS_N				(sdram_cs_n),		//sdram chip select
	.WE_N				(sdram_we_n),		//sdram write enable
	.CAS_N				(sdram_cas_n),		//sdram column address strobe
	.RAS_N				(sdram_ras_n),		//sdram row address strobe
	.DQM				(),//(sdram_dqm),		//sdram data output enable
	.BA					(sdram_ba),			//sdram bank address
	.SA					(sdram_addr),		//sdram address
	.DQ					(sdram_data),		//sdram data

	//	FIFO Write Side
	.WR_CLK				(clk_write),		//write fifo clock
	.WR_LOAD			(1'b0),				//write register load & fifo clear
	.WR_DATA			(sys_data_in),		//write data input
	.WR					(sys_we),			//write data request
	.WR_MIN_ADDR		(22'd0),			//write start address
	.WR_MAX_ADDR		(22'd640 * 22'd480),	//write max address
	.WR_LENGTH			(9'd256),			//write burst length

	//	FIFO Read Side
	.RD_CLK				(clk_read),			//read fifo clock
	.RD_LOAD			(1'b0),				//read register load & fifo clear
	.RD_DATA			(sys_data_out),		//read data output
	.RD					(sys_rd),			//read request
	.RD_MIN_ADDR		(22'd0),            //read start address
	.RD_MAX_ADDR		(22'd640 * 22'd480),	//read max address
	.RD_LENGTH			(9'd256),			//read length
	
	//User interface add by CrazyBingo
	.Sdram_Init_Done	(sdram_init_done),	//SDRAM init done signal
	.Sdram_Read_Valid	(1'b1),				//Enable to read
	.Sdram_PingPong_EN	(1'b1)				//SDRAM PING-PONG operation enable
);


//-------------------------------------
//LCD driver timing
wire	[10:0]	lcd_xpos;		//lcd horizontal coordinate
wire	[10:0]	lcd_ypos;		//lcd vertical coordinate
wire	[23:0]	lcd_data_in;		//lcd data input
lcd_driver u_lcd_driver
(
	//global clock
	.clk			(clk_vga),		
	.rst_n			(sys_rst_n), 
	 
	 //lcd interface
	.lcd_dclk		(lcd_dclk),
	.lcd_blank		(lcd_blank),
	.lcd_sync		(),		    	
	.lcd_hs			(lcd_hs),		
	.lcd_vs			(lcd_vs),
	.lcd_en			(),		
	.lcd_rgb		({lcd_red, lcd_green ,lcd_blue}),

	
	//user interface
	.lcd_request	(sys_rd),
	.lcd_data		(sys_data_out),	
	.lcd_xpos		(lcd_xpos),	
	.lcd_ypos		(lcd_ypos)
);


//---------------------------
//The driver of 74HC595
led_74595_driver	u_led_74595_driver
(
	//global clock
	.clk				(clk_ref),
	.rst_n				(sys_rst_n),

	//74hc595 interface
	.led595_dout		(led595_dout),	//74hc595 serial data input	
	.led595_clk			(led595_clk),	//74hc595 shift clock (rising edge)
	.led595_latch		(led595_latch),	//74hc595 latch clock (risign edge)

	//user interface
	.led_data			({4'd0, Sobel_Grade})		//led data input	
);
endmodule
