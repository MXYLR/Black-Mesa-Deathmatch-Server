"resource/screens/vgui_tram_screen.res"
{
	"BuildModeDialog"
	{
		"ControlName"		"BuildModeDialog"
		"fieldName"		"BuildModeDialog"
		"xpos"		"584"
		"ypos"		"230"
		"wide"		"360"
		"tall"		"420"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"settitlebarvisible"		"1"
		"title"		"#Frame_Untitled"
	}
	
	"Background"
	{
		"ControlName"	"MaterialImage"
		"fieldName"		"Background"
		"xpos"			"0"
		"ypos"			"0"
		"zpos"			"-2"
		"wide"			"480"
		"tall"			"620"
		"material"		"vgui/screens/tram/vgui_tram_background"
	}
		
	"Panel_LL"
	{
		"ControlName"	"Panel"
		"fieldName"		"Panel_LL"
		"xpos"			"10"
		"ypos"			"110"
		"wide"			"4"
		"tall"			"480"
		"visible"		"1"
		"enabled"		"1"
		"bgcolor_override"	"161 118 26 100"
	}
			
	"Panel_M"
	{
		"ControlName"	"Panel"
		"fieldName"		"Panel_M"
		"xpos"			"340"
		"ypos"			"110"
		"wide"			"4"
		"tall"			"480"
		"visible"		"1"
		"enabled"		"1"
		"bgcolor_override"	"161 118 26 100"
	}
	
	"Panel_RR"
	{
		"ControlName"	"Panel"
		"fieldName"		"Panel_RR"
		"xpos"			"464"
		"ypos"			"110"
		"wide"			"4"
		"tall"			"480"
		"visible"		"1"
		"enabled"		"1"
		"bgcolor_override"	"161 118 26 100"
	}
	
	"Panel_UC"
	{
		"ControlName"	"Panel"
		"fieldName"		"Panel_UC"
		"xpos"			"10"
		"ypos"			"110"
		"wide"			"460"
		"tall"			"5"
		"visible"		"1"
		"enabled"		"1"
		"bgcolor_override"	"161 118 26 100"
	}
			
	"Panel_MC"
	{
		"ControlName"	"Panel"
		"fieldName"		"Panel_MC"
		"xpos"			"10"
		"ypos"			"460"
		"wide"			"330"
		"tall"			"5"
		"visible"		"1"
		"enabled"		"1"
		"bgcolor_override"	"161 118 26 100"
	}
	
	"Panel_LC"
	{
		"ControlName"	"Panel"
		"fieldName"		"Panel_LC"
		"xpos"			"10"
		"ypos"			"585"
		"wide"			"460"
		"tall"			"5"
		"visible"		"1"
		"enabled"		"1"
		"bgcolor_override"	"161 118 26 100"
	}
	
	"Level_FAST"
	{
		"ControlName"	"TrainButton"
		"fieldName"		"Level_FAST"
		"xpos"			"355"
		"ypos"			"150"
		"wide"			"100"
		"tall"			"40"
		"autoResize"	"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"	"2"
		"labelText"		""
		"textAlignment"	"center"
		"dulltext"		"0"
		"brighttext"	"0"
		"Default"		"0"
		"command"		"Level 4"
		"paintborder"	"0"

		"enabledImage"
		{
			"material"	"vgui/screens/tram/vgui_accel_up_active"
			"color" "255 255 255 255"
		}

		"disabledImage"
		{
			"material"	"vgui/screens/tram/vgui_accel_up_disabled"
			"color" "255 255 255 255"
		}
	}
	
	"Level_MEDIUM"
	{
		"ControlName"	"TrainButton"
		"fieldName"		"Level_MEDIUM"
		"xpos"			"355"
		"ypos"			"225"
		"wide"			"100"
		"tall"			"60"
		"autoResize"	"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"	"2"
		"labelText"		""
		"textAlignment"	"center"
		"dulltext"		"0"
		"brighttext"	"0"
		"Default"		"0"
		"command"		"Level 3"
		"paintborder"	"0"

		"enabledImage"
		{
			"material"	"vgui/screens/tram/vgui_accel_level_active"
			"color" "255 255 255 255"
		}

		"disabledImage"
		{
			"material"	"vgui/screens/tram/vgui_accel_level_disabled"
			"color" "255 255 255 255"
		}
	}
	
	"Level_SLOW"
	{
		"ControlName"	"TrainButton"
		"fieldName"		"Level_SLOW"
		"xpos"			"355"
		"ypos"			"330"
		"wide"			"100"
		"tall"			"60"
		"autoResize"	"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"	"2"
		"labelText"		""
		"textAlignment"	"center"
		"dulltext"		"0"
		"brighttext"	"0"
		"Default"		"0"
		"command"		"Level 2"
		"paintborder"	"0"

		"enabledImage"
		{
			"material"	"vgui/screens/tram/vgui_accel_level_active"
			"color" "255 255 255 255"
		}


		"disabledImage"
		{
			"material"	"vgui/screens/tram/vgui_accel_level_disabled"
			"color" "255 255 255 255"
		}
	}
	
	"Level_NEUTRAL"
	{
		"ControlName"	"TrainButton"
		"fieldName"		"Level_NEUTRAL"
		"xpos"			"355"
		"ypos"			"435"
		"wide"			"100"
		"tall"			"60"
		"autoResize"	"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"	"2"
		"labelText"		""
		"textAlignment"	"center"
		"dulltext"		"0"
		"brighttext"	"0"
		"Default"		"0"
		"command"		"Level 1"
		"paintborder"	"0"

		"enabledImage"
		{
			"material"	"vgui/screens/tram/vgui_accel_level_active"
			"color" "255 255 255 255"
		}

		"disabledImage"
		{
			"material"	"vgui/screens/tram/vgui_accel_level_disabled"
			"color" "255 255 255 255"
		}
	}
	
	"Level_BACK"
	{
		"ControlName"	"TrainButton"
		"fieldName"		"Level_BACK"
		"xpos"			"355"
		"ypos"			"530"
		"wide"			"100"
		"tall"			"40"
		"autoResize"	"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"	"2"
		"labelText"		""
		"textAlignment"	"center"
		"dulltext"		"0"
		"brighttext"	"0"
		"Default"		"0"
		"command"		"Level 5"
		"paintborder"	"0"

		"enabledImage"
		{
			"material"	"vgui/screens/tram/vgui_accel_down_active"
			"color" "255 255 255 255"
		}

		"disabledImage"
		{
			"material"	"vgui/screens/tram/vgui_accel_down_disabled"
			"color" "255 255 255 255"
		}
	}
	
	"TramSpeed"
	{
		"ControlName"		"Label"
		"fieldName"			"TramSpeed"
		"xpos"				"50"
		"ypos"				"120"
		"wide"				"275"
		"tall"				"340"
		"autoResize"		"0"
		"pinCorner"			"0"
		"visible"			"1"
		"enabled"			"1"
		"tabPosition"		"0"
		"labelText"			"0"
		"textAlignment"		"center"
		"dulltext"			"0"
		"brighttext"		"0"
		"wrap"				"0"
		"centerwrap"		"0"
		"textinsetx"		"0"
		"textinsety"		"0"
	}
	
	"TramOnline"
	{
		"ControlName"		"Label"
		"fieldName"			"TramOnline"
		"xpos"				"15"
		"ypos"				"480"
		"wide"				"325"
		"tall"				"100"
		"autoResize"		"0"
		"pinCorner"			"0"
		"visible"			"1"
		"enabled"			"1"
		"tabPosition"		"0"
		"labelText"			"Enabled"
		"textAlignment"		"center"
		"dulltext"			"0"
		"brighttext"		"0"
		"wrap"				"0"
		"centerwrap"		"0"
		"textinsetx"		"0"
		"textinsety"		"0"
	}
}
